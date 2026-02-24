&import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "prayerTimes"

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
    property bool use12HourFormat: false

    // Persistent state:
    // We use pluginService to store the monthly calendar data across sessions.
    // This allows the plugin to work offline if data for the current month has been fetched once.
    property var calendarData: null
    property int cachedMonth: 0
    property int cachedYear: 0
    property string cachedMethod: ""
    property string cachedSchool: ""

    Component.onCompleted: {
        var state = pluginService.loadPluginState(root.pluginId, "cache", {});
        if (state.calendar) {
            root.calendarData = state.calendar;
            root.cachedMonth = state.month || 0;
            root.cachedYear = state.year || 0;
            root.cachedMethod = state.method || "";
            root.cachedSchool = state.school || "";
            if (root.pluginDataLoaded) {
                processTodayFromCalendar(root.calendarData);
            }
        }
    }

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
    // Called whenever plugin settings change (refresh interval, lat, lon, method, school, format).
    onPluginDataChanged: {
        root.refreshInterval = (Number(root.pluginData.refreshInterval) || 5) * 60000
        root.lat = root.pluginData.lat || "-6.2088"
        root.lon = root.pluginData.lon || "106.8456"
        root.method = root.pluginData.method || ""
        root.school = root.pluginData.school || "0"
        root.use12HourFormat = root.pluginData.use12HourFormat === "true" || root.pluginData.use12HourFormat === true
        root.pluginDataLoaded = true
        debounceTimer.restart()
    }

    // Debounce timer:
    // Waits 500ms after the last onPluginDataChanged signal before triggering a fetch.
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: fetchOrProcess()
    }

    // Periodic refresh timer:
    // Fires every `refreshInterval` (default 5 min) to re-evaluate which prayer is current/next.
    Timer {
        interval: root.refreshInterval
        running: root.pluginDataLoaded
        repeat: true
        triggeredOnStart: false
        onTriggered: fetchOrProcess()
    }

    // Retry timer (rate-limit backoff):
    // Only used when the API returns HTTP 429 (Too Many Requests).
    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root.fetching = false
            fetchPrayerTimes()
        }
    }

    // Cache-or-fetch decision:
    function fetchOrProcess() {
        var date = new Date()
        var month = date.getMonth() + 1
        var year = date.getFullYear()

        // Check if we have valid monthly data in our persistent cache
        if (root.calendarData && root.cachedMonth === month && root.cachedYear === year
                && root.cachedMethod === root.method && root.cachedSchool === root.school) {
            processTodayFromCalendar(root.calendarData)
        } else {
            // Need fresh data from API
            fetchPrayerTimes()
        }
    }

    // Finds today's entry in the monthly calendar array and processes it.
    function processTodayFromCalendar(calendar) {
        var day = parseInt(Qt.formatDate(new Date(), "d"), 10)
        // Aladhan calendar data is an array where entries are day-ordered (index 0 = day 1)
        var entry = calendar[day - 1]
        if (entry) {
            processPrayerData(entry)
        } else {
            // Fallback: if array is not day-ordered, search by date string
            var todayStr = Qt.formatDate(new Date(), "dd-MM-yyyy")
            for (var i = 0; i < calendar.length; i++) {
                if (calendar[i].date.gregorian.date === todayStr) {
                    processPrayerData(calendar[i])
                    break
                }
            }
        }
    }

    // Fetches the full monthly calendar from the Aladhan API.
    function fetchPrayerTimes() {
        if (root.fetching) return
        root.fetching = true

        var date = new Date()
        var month = date.getMonth() + 1
        var year = date.getFullYear()

        // We fetch the whole month to support offline use for the remaining days.
        var url = "https://api.aladhan.com/v1/calendar?latitude=" + root.lat 
                + "&longitude=" + root.lon 
                + "&school=" + root.school
                + "&month=" + month
                + "&year=" + year
        if (root.method !== "") {
            url += "&method=" + root.method
        }

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.fetching = false

                if (xhr.status === 200) {
                    root.retryCount = 0
                    try {
                        var json = JSON.parse(xhr.responseText)
                        if (json.code === 200 && json.data && json.data.length > 0) {
                            // Update persistent state
                            var newState = {
                                calendar: json.data,
                                month: month,
                                year: year,
                                method: root.method,
                                school: root.school
                            }
                            pluginService.savePluginState(root.pluginId, "cache", newState);
                            
                            // Re-update internal properties from the new state
                            root.calendarData = json.data
                            root.cachedMonth = month
                            root.cachedYear = year
                            root.cachedMethod = root.method
                            root.cachedSchool = root.school

                            processTodayFromCalendar(json.data)
                        } else {
                            root.prayerInfo = "API error: " + (json.status || "Unknown")
                            ToastService.showError("Prayer Times", "API returned: " + (json.status || "Unknown"))
                        }
                    } catch (e) {
                        root.prayerInfo = "Parse error"
                        console.error("Prayer Times: JSON parse error: " + e.message)
                        ToastService.showError("Prayer Times", "JSON parse error: " + e.message)
                    }

                } else if (xhr.status === 429) {
                    root.retryCount++
                    var backoff = Math.min(30000 * Math.pow(2, root.retryCount - 1), 600000)
                    console.warn("Prayer Times: 429 rate-limited, retrying in " + (backoff / 1000) + "s")
                    root.prayerInfo = "Rate limited, retrying…"
                    retryTimer.interval = backoff
                    root.fetching = true
                    retryTimer.restart()

                } else {
                    root.prayerInfo = "Network error (" + xhr.status + ")"
                    ToastService.showError("Prayer Times", "HTTP " + xhr.status)
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    //  Helper functions

    function stripTimezone(timeStr) {
        return timeStr ? timeStr.split(" ")[0] : ""
    }

    function timeToMinutes(hhmm) {
        var parts = hhmm.split(":")
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10)
    }

    function formatTime(time24h) {
        if (!time24h || time24h === "") return ""
        if (!root.use12HourFormat) return time24h
        
        var parts = time24h.split(":")
        if (parts.length < 2) return time24h
        
        var hours = parseInt(parts[0], 10)
        var minutes = parts[1]
        var ampm = hours >= 12 ? "PM" : "AM"
        
        hours = hours % 12
        if (hours === 0) hours = 12
        var hoursStr = hours < 10 ? "0" + hours : hours.toString()
        
        return hoursStr + ":" + minutes + " " + ampm
    }

    // Processes a single day's prayer timings.
    function processPrayerData(data) {
        var timings = data.timings
        var dateInfo = data.date

        var fajrTime    = stripTimezone(timings.Fajr)
        var sunriseTime = stripTimezone(timings.Sunrise)
        var dhuhrTime   = stripTimezone(timings.Dhuhr)
        var asrTime     = stripTimezone(timings.Asr)
        var maghribTime = stripTimezone(timings.Maghrib)
        var ishaTime    = stripTimezone(timings.Isha)

        root.fajr    = fajrTime
        root.dhuhr   = dhuhrTime
        root.asr     = asrTime
        root.maghrib = maghribTime
        root.isha    = ishaTime

        root.dateGreg = dateInfo.readable || ""
        if (dateInfo.hijri) {
            root.dateHijr = dateInfo.hijri.day + " " + dateInfo.hijri.month.en + " " + dateInfo.hijri.year
        }

        var now = new Date()
        var nowStr = Qt.formatTime(now, "HH:mm")
        var nowMin = timeToMinutes(nowStr)

        var currName, currTime, nextName, nextTime

        if (nowStr < fajrTime) {
            currName = "Isha";    currTime = ishaTime
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
            currName = "Isha";    currTime = ishaTime
            nextName = "Fajr";    nextTime = fajrTime
        }

        root.currName = currName

        var currMin = timeToMinutes(currTime)
        var diff = nowMin - currMin
        if (diff < 0) diff += 1440

        var result = ""
        if (diff <= 30) {
            result = currName + " " + formatTime(currTime) + " · "
            if (diff * 60000 <= root.refreshInterval) {
                root.detailNotif = "Prayer time - " + currName + " " + formatTime(currTime)
                sendNotif.running = true
            }
        }
        result += nextName + " " + formatTime(nextTime)

        var nextMin = timeToMinutes(nextTime)
        var timeUntilNext = nextMin - nowMin
        if (timeUntilNext < 0) timeUntilNext += 1440
        if (timeUntilNext <= 15 && timeUntilNext > 0) {
            if ((15 - timeUntilNext) * 60000 < root.refreshInterval) {
                root.detailNotif = nextName + " in " + timeUntilNext + " min"
                sendNotif.running = true
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
            { label: "Fajr", value: formatTime(root.fajr), icon: getPrayerIcon("Fajr") },
            { label: "Dhuhr", value: formatTime(root.dhuhr), icon: getPrayerIcon("Dhuhr") },
            { label: "Asr", value: formatTime(root.asr), icon: getPrayerIcon("Asr") },
            { label: "Maghrib", value: formatTime(root.maghrib), icon: getPrayerIcon("Maghrib") },
            { label: "Isha", value: formatTime(root.isha), icon: getPrayerIcon("Isha") }
        ]
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
