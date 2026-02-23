import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string prayerInfo: "..."
    property string fajr: ""
    property string dhuhr: ""
    property string asr: ""
    property string maghrib: ""
    property string isha: ""
    property string dateHijr: ""
    property string dateGreg: ""
    property string currName: "Fajr" // Current prayer name: Fajr, Dhuhr, Asr, Maghrib, Isha
    property bool pluginDataLoaded: false
    property int refreshInterval: 5 * 60000 // default in minutes
    property string lat: "-6.2088" // default Jakarta
    property string lon: "106.8456" // default Jakarta
    property string method: ""     // Calculation method (empty = API auto-detects by location)
    property string school: "0"    // Asr calculation school: 0 = Shafi (default), 1 = Hanafi

    // In-memory cache:
    // Stores the API response for today so we only hit the network once per day.
    // On each refresh tick we just re-run processPrayerData() against this cache.
    property var cachedTimings: null     // The `data` object from the Aladhan /v1/timings response
    property string cachedDate: ""       // The date (dd-MM-yyyy) the cache was fetched for
    property string cachedMethod: ""     // The method the cache was fetched with (invalidate on change)
    property string cachedSchool: ""     // The school the cache was fetched with (invalidate on change)
    property bool fetching: false        // Guard flag — prevents overlapping concurrent HTTP requests
    property int retryCount: 0           // Tracks consecutive 429 failures for exponential backoff

    property string detailNotif: ""
    Process {
        id: sendNotif
        command: [
            "notify-send",
            "-a", "Prayer Widget",
            "-u", "critical",
            root.detailNotif
        ]
        running: false
    }

    // Settings handler:
    // Called whenever plugin settings change (refresh interval, lat, lon, method, school).
    // Can fire multiple times rapidly on startup as each setting loads,
    // so we funnel through a debounce timer instead of fetching directly.
    onPluginDataChanged: {
        root.refreshInterval = (Number(root.pluginData.refreshInterval) || 5) * 60000
        root.lat = root.pluginData.lat || "-6.2088"
        root.lon = root.pluginData.lon || "106.8456"
        root.method = root.pluginData.method || ""
        root.school = root.pluginData.school || "0"
        root.pluginDataLoaded = true
        debounceTimer.restart()  // restart (not start) to collapse multiple rapid signals
    }

    // Debounce timer:
    // Waits 500ms after the last onPluginDataChanged signal before triggering a fetch.
    // This prevents hammering the API when multiple settings load in quick succession
    // (e.g. lat, lon, and refreshInterval all arriving within milliseconds on startup).
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: fetchOrProcess()
    }

    // Periodic refresh timer:
    // Fires every `refreshInterval` (default 5 min) to re-evaluate which prayer is
    // current/next. This does NOT call the API each time — it reprocesses the cached
    // data. The API is only called if the date has changed (i.e. past midnight).
    Timer {
        interval: root.refreshInterval
        running: root.pluginDataLoaded
        repeat: true
        triggeredOnStart: false
        onTriggered: fetchOrProcess()
    }

    // Retry timer (rate-limit backoff):
    // Only used when the API returns HTTP 429 (Too Many Requests).
    // Waits an exponentially increasing delay (30s → 60s → 120s → … up to 10min)
    // before retrying, to be respectful to the API and avoid a ban.
    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root.fetching = false   // release the guard so fetchPrayerTimes() can run
            fetchPrayerTimes()
        }
    }

    // Cache-or-fetch decision:
    // Central routing function called by both the debounce and refresh timers.
    // If we already have today's data cached it just reprocess it (free, no network).
    // If the date, method, or school changed, or cache is empty then it fetches fresh data from the API.
    function fetchOrProcess() {
        var today = Qt.formatDate(new Date(), "dd-MM-yyyy")
        if (root.cachedDate === today && root.cachedMethod === root.method
                && root.cachedSchool === root.school && root.cachedTimings) {
            // Cache hit — reprocess to update current/next prayer based on new time-of-day
            processPrayerData(root.cachedTimings)
        } else {
            // Cache miss — date, method, or school changed, or first run; need fresh data from API
            fetchPrayerTimes()
        }
    }

    //  Pure JS API fetch — replaces the old bash script + Process/SplitParser
    //  Uses XMLHttpRequest (built into QML) instead of curl + jq.

    function fetchPrayerTimes() {
        // Prevent overlapping requests (e.g. timer fires while a request is in-flight)
        if (root.fetching) return
        root.fetching = true

        // Call Aladhan API with no date param — it returns today's times automatically.
        // This is simpler and avoids date formatting issues vs the old /calendar/from/to endpoint.
        // Append &method=X only if a specific calculation method is selected in settings.
        // Always append &school= since it defaults to 0 (Shafi).
        var url = "https://api.aladhan.com/v1/timings?latitude=" + root.lat + "&longitude=" + root.lon
                + "&school=" + root.school
        if (root.method !== "") {
            url += "&method=" + root.method
        }
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.fetching = false

                if (xhr.status === 200) {
                    // Success — reset retry counter and parse the response
                    root.retryCount = 0
                    try {
                        var json = JSON.parse(xhr.responseText)
                        if (json.code === 200 && json.data) {
                            // Cache the response, stamp with today's date, method, and school
                            root.cachedTimings = json.data
                            root.cachedDate = Qt.formatDate(new Date(), "dd-MM-yyyy")
                            root.cachedMethod = root.method
                            root.cachedSchool = root.school
                            processPrayerData(json.data)
                        } else {
                            root.prayerInfo = "API error: " + (json.status || "Unknown")
                            ToastService.showError("Prayer Times", "API returned: " + (json.status || "Unknown"))
                        }
                    } catch (e) {
                        root.prayerInfo = "Parse error"
                        ToastService.showError("Prayer Times", "JSON parse error: " + e.message)
                    }

                } else if (xhr.status === 429) {
                    // Rate limited — use exponential backoff: 30s, 60s, 120s, … capped at 10min
                    root.retryCount++
                    var backoff = Math.min(30000 * Math.pow(2, root.retryCount - 1), 600000)
                    console.warn("Prayer Times: 429 rate-limited, retrying in " + (backoff / 1000) + "s")
                    root.prayerInfo = "Rate limited, retrying…"
                    retryTimer.interval = backoff
                    root.fetching = true   // keep guard up so nothing else triggers a request
                    retryTimer.restart()

                } else {
                    // Other HTTP errors (500, timeout, no network, etc.)
                    root.prayerInfo = "Network error (" + xhr.status + ")"
                    ToastService.showError("Prayer Times", "HTTP " + xhr.status)
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    //  Helper functions

    // Strips the timezone label that Aladhan appends to times.
    // e.g. "04:39 (WIB)" → "04:39", so we can do clean HH:mm comparisons.
    function stripTimezone(timeStr) {
        return timeStr ? timeStr.split(" ")[0] : ""
    }

    // Converts "HH:mm" to total minutes since midnight (e.g. "04:39" → 279).
    // Used to calculate how long ago a prayer started.
    function timeToMinutes(hhmm) {
        var parts = hhmm.split(":")
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10)
    }

    //  Prayer data processing — the JS equivalent of the old bash logic
    //  (get-prayer-times lines 59-121). Called on every refresh tick
    //  against cached data, NOT on every API call.

    function processPrayerData(data) {
        var timings = data.timings
        var dateInfo = data.date

        // Extract and clean all prayer times (strip timezone labels)
        var fajrTime    = stripTimezone(timings.Fajr)
        var sunriseTime = stripTimezone(timings.Sunrise)
        var dhuhrTime   = stripTimezone(timings.Dhuhr)
        var asrTime     = stripTimezone(timings.Asr)
        var maghribTime = stripTimezone(timings.Maghrib)
        var ishaTime    = stripTimezone(timings.Isha)

        // Update the display properties that the popout reads
        root.fajr    = fajrTime
        root.dhuhr   = dhuhrTime
        root.asr     = asrTime
        root.maghrib = maghribTime
        root.isha    = ishaTime

        // Format date strings for the popout header
        root.dateGreg = dateInfo.readable || ""
        if (dateInfo.hijri) {
            root.dateHijr = dateInfo.hijri.day + " " + dateInfo.hijri.month.en + " " + dateInfo.hijri.year
        }

        // Determine which prayer period we're in and what's next:
        // Compare current time (HH:mm string) against each prayer threshold.
        // String comparison works because HH:mm is zero-padded and lexicographic order = chronological order.
        var now = new Date()
        var nowStr = Qt.formatTime(now, "HH:mm")
        var nowMin = timeToMinutes(nowStr)

        var currName, currTime, nextName, nextTime

        if (nowStr < fajrTime) {
            currName = "Isha";    currTime = ishaTime      // Before Fajr → still in last night's Isha
            nextName = "Fajr";    nextTime = fajrTime
        } else if (nowStr < sunriseTime) {
            currName = "Fajr";    currTime = fajrTime
            nextName = "Sunrise"; nextTime = sunriseTime
        } else if (nowStr < dhuhrTime) {
            currName = "Sunrise"; currTime = sunriseTime
            nextName = "Dhuhr";   nextTime = dhuhrTime
        } else if (nowStr < asrTime) {
            currName = "Dhuhr";   currTime = dhuhrTime
            nextName = "Asr";     nextTime = asrTime
        } else if (nowStr < maghribTime) {
            currName = "Asr";     currTime = asrTime
            nextName = "Maghrib"; nextTime = maghribTime
        } else if (nowStr < ishaTime) {
            currName = "Maghrib"; currTime = maghribTime
            nextName = "Isha";    nextTime = ishaTime
        } else {
            currName = "Isha";    currTime = ishaTime      // After Isha → next is tomorrow's Fajr
            nextName = "Fajr";    nextTime = fajrTime
        }

        root.currName = currName  // Drives which icon is shown in the bar

        // Build the bar pill text (compact format):
        // If the current prayer started ≤30 minutes ago: "Maghrib 18:15 · Isha 19:26"
        // Otherwise just the next prayer:                 "Isha 19:26"
        var currMin = timeToMinutes(currTime)
        var diff = nowMin - currMin             // minutes since current prayer started
        if (diff < 0) diff += 1440              // handle day wraparound (Isha → Fajr)

        var result = ""
        if (diff <= 30) {
            result = currName + " " + currTime + " · "

            // Fire a toast notification if the prayer JUST started (within one refresh cycle).
            // e.g. at 5min refresh: toast fires when diff is 0–5min, so you see it once.
            if (diff * 60000 <= root.refreshInterval) {
                root.detailNotif = "Prayer time - " + currName + " " + currTime
                sendNotif.running = true;
            }
        }
        result += nextName + " " + nextTime

        // "Coming up" notification:
        // Notify when the next prayer is ≤15 minutes away.
        // Only fires once per prayer: triggers when timeUntilNext first falls within
        // one refresh interval of the 15-minute mark (i.e. between 15min and 15min−refresh).
        var nextMin = timeToMinutes(nextTime)
        var timeUntilNext = nextMin - nowMin        // minutes until next prayer
        if (timeUntilNext < 0) timeUntilNext += 1440  // handle day wraparound
        if (timeUntilNext <= 15 && timeUntilNext > 0) {
            // Fire only once: when we first enter the ≤15min window (within one refresh cycle of 15min)
            if ((15 - timeUntilNext) * 60000 < root.refreshInterval) {
                root.detailNotif = nextName + " in " + timeUntilNext + " min"
                sendNotif.running = true;
            }
        }

        root.prayerInfo = result
    }

    popoutContent: Component {
        Column {
            id: prayerPopup
            spacing: Theme.spacingS
            padding: Theme.spacingM

            Repeater {
                model: getPrayerTimesList()

                delegate: Row {
                    spacing: Theme.spacingM

                    DankIcon {
                        name: modelData.icon
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.label + ": " + modelData.value
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            rightPadding: Theme.spacingS

            DankIcon {
                name: root.prayerIcons[root.currName] || "mosque"
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.prayerInfo
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            MouseArea {
                onClicked: {
                    // Open prayer times popup
                }
            }
        }
    }

    property var prayerIcons: ({
        "Fajr": "sunny",
        "Dhuhr": "light_mode",
        "Asr": "partly_cloudy_day",
        "Maghrib": "wb_twilight",
        "Isha": "nightlight"
    })

    function getPrayerIcon(name) {
        return prayerIcons[name || root.currName] || "mosque"
    }

    function getPrayerTimesList() {
        return [
            { label: "Hijri", value: root.dateHijr, icon: "calendar_today" },
            { label: "Gregorian", value: root.dateGreg, icon: "calendar_today" },

            { label: "Fajr", value: root.fajr, icon: getPrayerIcon("Fajr") },
            { label: "Dhuhr", value: root.dhuhr, icon: getPrayerIcon("Dhuhr") },
            { label: "Asr", value: root.asr, icon: getPrayerIcon("Asr") },
            { label: "Maghrib", value: root.maghrib, icon: getPrayerIcon("Maghrib") },
            { label: "Isha", value: root.isha, icon: getPrayerIcon("Isha") }
        ];
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.prayerIcons[root.currName] || "mosque"
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
