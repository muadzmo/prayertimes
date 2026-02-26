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
    pluginId: "prayerTimes"

    // Prayer times data
    property string fajr: ""
    property string dhuhr: ""
    property string asr: ""
    property string maghrib: ""
    property string isha: ""
    property string imsak: ""
    property string sunrise: ""
    property string dateHijr: ""
    property string dateGreg: ""

    // Current prayer period
    property string currName: ""
    property string nextName: ""
    property string nextTime: ""
    property int nextTimeSec: 0
    property int nextTotalSeconds: 0

    // Settings properties. Bound directly to pluginData
    property int refreshInterval: (Number(pluginData.refreshInterval) || 5) * 60000
    property string lat: pluginData.lat || "-6.2088"
    property string lon: pluginData.lon || "106.8456"
    property string method: pluginData.method || ""
    property string school: pluginData.school || "0"
    property int notifyThresholdSec: (Number(pluginData.notifyMinutes) || 15) * 60
    property bool iconOnly: pluginData.iconOnly ?? false
    property bool showSeconds: pluginData.showSeconds ?? false
    property bool use12H: pluginData.use12H ?? false

    // Prayer time offset/tune settings (in minutes)
    // Only for displayed properties: Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
    property string tuneImsak: pluginData.tuneImsak || "0"
    property string tuneFajr: pluginData.tuneFajr || "0"
    property string tuneSunrise: pluginData.tuneSunrise || "0"
    property string tuneDhuhr: pluginData.tuneDhuhr || "0"
    property string tuneAsr: pluginData.tuneAsr || "0"
    property string tuneMaghrib: pluginData.tuneMaghrib || "0"
    property string tuneIsha: pluginData.tuneIsha || "0"

    // Internal state
    property bool fetching: false
    property int retryCount: 0
    property bool _wasUrgent: false
    property bool _wasAtTime: false

    // UI state properties
    readonly property bool isUrgent: nextTotalSeconds > 0 && nextTotalSeconds <= notifyThresholdSec
    readonly property color accentColor: Theme.primary
    readonly property color accentBg: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
    readonly property color subtleBg: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.05)

    // Notification processes
    Process {
        id: prayerNotifyProc
        running: false
    }

    Process {
        id: errorNotifyProc
        running: false
    }

    // Initialize on plugin service ready
    onPluginServiceChanged: {
        if (pluginService) {
            fetchOrProcess()
        }
    }

    // Debounce settings changes
    onLatChanged: debounceTimer.restart()
    onLonChanged: debounceTimer.restart()
    onMethodChanged: debounceTimer.restart()
    onSchoolChanged: debounceTimer.restart()
    
    // Debounce tune offset changes
    onTuneImsakChanged: debounceTimer.restart()
    onTuneFajrChanged: debounceTimer.restart()
    onTuneSunriseChanged: debounceTimer.restart()
    onTuneDhuhrChanged: debounceTimer.restart()
    onTuneAsrChanged: debounceTimer.restart()
    onTuneMaghribChanged: debounceTimer.restart()
    onTuneIshaChanged: debounceTimer.restart()

    // Timers
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: fetchOrProcess()
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: pluginService !== null
        repeat: true
        triggeredOnStart: false
        onTriggered: fetchOrProcess()
    }

    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
        onDateChanged: {
            if (root.nextTimeSec > 0)
                updateCountdown()
        }
    }

    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root.fetching = false
            fetchPrayerTimes()
        }
    }

    // Notification functions
    function sendPrayerNotification() {
        var mins = Math.ceil(root.nextTotalSeconds / 60)
        prayerNotifyProc.command = [
            "notify-send",
            "-a", "Prayer Widget",
            "-u", "critical",
            // "-i", "prayer_times", (was supposed to be an icon "prayer_times" as mentioned in google's material icons, but it does not work)
            root.nextName + " in " + mins + " min (at " + root.formatTime(root.nextTime) + ")"
        ]
        prayerNotifyProc.running = true
    }

    function sendPrayerTimeNotification() {
        prayerNotifyProc.command = [
            "notify-send",
            "-a", "Prayer Widget",
            "-u", "critical",
            // "-i", "prayer_times", (was supposed to be an icon "prayer_times" as mentioned in google's material icons, but it does not work)
            "Time for " + root.nextName + ""
        ]
        prayerNotifyProc.running = true
    }

    function sendErrorNotification(message) {
        errorNotifyProc.command = [
            "notify-send",
            "-a", "Prayer Widget",
            "-u", "critical",
            message
        ]
        errorNotifyProc.running = true
    }

    // Countdown and notification logic
    function updateCountdown() {
        var now    = clock.date
        var nowSec = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()

        // rawDiff = signed distance (negative means prayer already passed).
        // diff    = always-positive countdown (after midnight wrap).
        // We need rawDiff later to detect the exact prayer-time moment.
        var rawDiff = root.nextTimeSec - nowSec
        var diff = rawDiff
        if (diff < 0) diff += 86400        // midnight wraparound (Isha → Fajr)

        root.nextTotalSeconds = diff

        var urgent = diff > 0 && diff <= root.notifyThresholdSec
        var todayKey = Qt.formatDate(clock.date, "yyyy-MM-dd")
        var baseKey = todayKey + "|" + root.nextName + "|" + root.nextTime

        if (urgent && !root._wasUrgent) {
            var lastNotified = pluginService.loadPluginState("prayerTimes", "lastNotifiedThresholdKey", "")
            if (lastNotified !== baseKey) {
                pluginService.savePluginState("prayerTimes", "lastNotifiedThresholdKey", baseKey)
                sendPrayerNotification()
            }
        }

        var atTime = (rawDiff <= 0 && rawDiff > -60)
        if (atTime && !root._wasAtTime) {
            var lastAtTime = pluginService.loadPluginState("prayerTimes", "lastNotifiedAtKey", "")
            if (lastAtTime !== baseKey) {
                pluginService.savePluginState("prayerTimes", "lastNotifiedAtKey", baseKey)
                sendPrayerTimeNotification()
            }
        }

        root._wasUrgent = urgent
        root._wasAtTime = atTime
    }

    // Build tune string for API
    // Format: Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Sunset,Isha,Midnight
    // Note: Sunset and Midnight are kept fixed at 0 (not user-configurable) to keep consistent
    // with API expectations and avoid complications, since they are not displayed or used in countdown logic. 
    function buildTuneString() {
        return root.tuneImsak + "," +
               root.tuneFajr + "," +
               root.tuneSunrise + "," +
               root.tuneDhuhr + "," +
               root.tuneAsr + "," +
               root.tuneMaghrib + "," +
               "0" + "," +  // Sunset (always 0)
               root.tuneIsha + "," +
               "0"  // Midnight (always 0)
    }

    // Utility functions
    function stripTimezone(timeStr) {
        return timeStr ? timeStr.split(" ")[0] : ""
    }

    function timeToMinutes(hhmm) {
        var parts = hhmm.split(":")
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10)
    }

    function formatTime(time24h) {
        if (!time24h || time24h === "") return ""
        if (!root.use12H) return time24h

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

    function formatCountdown(totalSeconds) {
        if (totalSeconds <= 0) return root.showSeconds ? "00:00" : "0 min"
        var h  = Math.floor(totalSeconds / 3600)
        var m  = Math.floor((totalSeconds % 3600) / 60)
        var s  = totalSeconds % 60
        if (root.showSeconds) {
            var mm = (m < 10 ? "0" : "") + m
            var ss = (s < 10 ? "0" : "") + s
            if (h > 0) return (h < 10 ? "0" : "") + h + ":" + mm + ":" + ss
            return mm + ":" + ss
        } else {
            var mm2 = (m < 10 ? "0" : "") + m
            if (h > 0) return (h < 10 ? "0" : "") + h + ":" + mm2
            return m + " min"
        }
    }

    function determinePrayerPeriod(nowStr, fajrT, dhuhrT, asrT, maghribT, ishaT) {
        if (nowStr < fajrT)
            return { currName: "Isha",    currTime: ishaT,    nextName: "Fajr",    nextTime: fajrT    }
        if (nowStr < dhuhrT)
            return { currName: "Fajr",    currTime: fajrT,    nextName: "Dhuhr",   nextTime: dhuhrT   }
        if (nowStr < asrT)
            return { currName: "Dhuhr",   currTime: dhuhrT,   nextName: "Asr",     nextTime: asrT     }
        if (nowStr < maghribT)
            return { currName: "Asr",     currTime: asrT,     nextName: "Maghrib", nextTime: maghribT }
        if (nowStr < ishaT)
            return { currName: "Maghrib", currTime: maghribT, nextName: "Isha",    nextTime: ishaT    }
        return { currName: "Isha",    currTime: ishaT,    nextName: "Fajr",    nextTime: fajrT    }
    }

    function getTodayDataFromState() {
        var calendarData  = pluginService.loadPluginState("prayerTimes", "calendarData",  [])
        var fetchedMethod = pluginService.loadPluginState("prayerTimes", "fetchedMethod", "")
        var fetchedSchool = pluginService.loadPluginState("prayerTimes", "fetchedSchool", "0")
        var fetchedTune   = pluginService.loadPluginState("prayerTimes", "fetchedTune", "0,0,0,0,0,0,0,0,0")
        if (!calendarData || calendarData.length === 0) return null
        if (fetchedMethod !== root.method || fetchedSchool !== root.school) return null
        if (fetchedTune !== buildTuneString()) return null
        var today = Qt.formatDate(new Date(), "dd-MM-yyyy")
        for (var i = 0; i < calendarData.length; i++) {
            var entry = calendarData[i]
            if (entry.date && entry.date.gregorian && entry.date.gregorian.date === today)
                return entry
        }
        return null
    }

    function tryFallbackFromState() {
        var calendarData = pluginService.loadPluginState("prayerTimes", "calendarData", [])
        if (!calendarData || calendarData.length === 0) return
        var today = Qt.formatDate(new Date(), "dd-MM-yyyy")
        for (var i = 0; i < calendarData.length; i++) {
            var entry = calendarData[i]
            if (entry.date && entry.date.gregorian && entry.date.gregorian.date === today) {
                processPrayerData(entry)
                return
            }
        }
        processPrayerData(calendarData[0])
    }

    function fetchOrProcess() {
        var todayData = getTodayDataFromState()
        if (todayData) processPrayerData(todayData)
        else           fetchPrayerTimes()
    }

    // Force a fresh API fetch, discarding the cache completely.
    function forceRefresh() {
        if (root.fetching) return
        pluginService.savePluginState("prayerTimes", "calendarData", [])
        pluginService.savePluginState("prayerTimes", "fetchedMethod", "__force__")
        fetchPrayerTimes()
    }

    // 7-day cache fetch:
    function fetchPrayerTimes() {
        if (root.fetching) return
        root.fetching = true

        var fromDate = new Date()
        var toDate   = new Date(fromDate)
        toDate.setDate(toDate.getDate() + 6)

        var fromStr = Qt.formatDate(fromDate, "dd-MM-yyyy")
        var toStr   = Qt.formatDate(toDate,   "dd-MM-yyyy")

        var url = "https://api.aladhan.com/v1/calendar/from/" + fromStr
                + "/to/" + toStr
                + "?latitude="  + root.lat
                + "&longitude=" + root.lon
                + "&school="    + root.school
        if (root.method !== "") url += "&method=" + root.method
        
        // Add tune parameter for prayer time offsets
        var tuneString = buildTuneString()
        if (tuneString !== "0,0,0,0,0,0,0,0,0") {
            url += "&tune=" + tuneString
        }

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.fetching = false

            if (xhr.status === 200) {
                root.retryCount = 0
                try {
                    var json = JSON.parse(xhr.responseText)
                    if (json.code === 200 && json.data && json.data.length > 0) {
                        pluginService.savePluginState("prayerTimes", "calendarData",  json.data)
                        pluginService.savePluginState("prayerTimes", "fetchedMethod", root.method)
                        pluginService.savePluginState("prayerTimes", "fetchedSchool", root.school)
                        pluginService.savePluginState("prayerTimes", "fetchedTune", buildTuneString())
                        var todayStr  = Qt.formatDate(new Date(), "dd-MM-yyyy")
                        var todayData = null
                        for (var i = 0; i < json.data.length; i++) {
                            if (json.data[i].date && json.data[i].date.gregorian
                                    && json.data[i].date.gregorian.date === todayStr) {
                                todayData = json.data[i]; break
                            }
                        }
                        processPrayerData(todayData || json.data[0])
                    } else {
                        var fb = getTodayDataFromState()
                        if (fb) processPrayerData(fb)
                        else sendErrorNotification("API error: " + (json.status || "Unknown"))
                    }
                } catch (e) {
                    var cached = getTodayDataFromState()
                    if (cached) processPrayerData(cached)
                    else sendErrorNotification("JSON parse error: " + e.message)
                }

            } else if (xhr.status === 429) {
                root.retryCount++
                var backoff = Math.min(30000 * Math.pow(2, root.retryCount - 1), 600000)
                var rateFb = getTodayDataFromState()
                if (rateFb) processPrayerData(rateFb)
                retryTimer.interval = backoff
                root.fetching = true
                retryTimer.restart()

            } else {
                tryFallbackFromState()
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    // Prayer data processing
    function processPrayerData(data) {
        var timings  = data.timings
        var dateInfo = data.date

        var fajrTime    = stripTimezone(timings.Fajr)
        var dhuhrTime   = stripTimezone(timings.Dhuhr)
        var asrTime     = stripTimezone(timings.Asr)
        var maghribTime = stripTimezone(timings.Maghrib)
        var ishaTime    = stripTimezone(timings.Isha)

        root.fajr    = fajrTime
        root.dhuhr   = dhuhrTime
        root.asr     = asrTime
        root.maghrib = maghribTime
        root.isha    = ishaTime
        root.imsak   = stripTimezone(timings.Imsak   || "")
        root.sunrise = stripTimezone(timings.Sunrise || "")

        root.dateGreg = dateInfo.readable || ""
        if (dateInfo.hijri) {
            root.dateHijr = dateInfo.hijri.day + " "
                          + dateInfo.hijri.month.en + " "
                          + dateInfo.hijri.year
        }

        var nowStr = Qt.formatTime(clock.date, "HH:mm")
        var period = determinePrayerPeriod(
            nowStr, fajrTime, dhuhrTime, asrTime, maghribTime, ishaTime
        )

        // Cache next-prayer seconds-since-midnight for fast countdown math
        root.nextTimeSec = timeToMinutes(period.nextTime) * 60

        // Reset edge detection when the prayer cycle advances so the
        // notification can fire fresh for the new upcoming prayer.
        if (root.nextName !== period.nextName) {
            root._wasUrgent = false
            root._wasAtTime = false
        }

        root.currName = period.currName
        root.nextName = period.nextName
        root.nextTime = period.nextTime

        // Immediate UI sync — don't wait for the next SystemClock tick.
        updateCountdown()
    }

    // Prayer icons:
    property var prayerIcons: ({
        "Fajr":    "bedtime",
        "Dhuhr":   "wb_sunny",
        "Asr":     "light_mode",
        "Maghrib": "wb_twilight",
        "Isha":    "bedtime"
    })

    function getPrayerIcon(name) {
        return root.prayerIcons[name] || "mosque"
    }

    // Horizontal bar pill:
    horizontalBarPill: Component {
        Row {
            spacing: root.iconOnly ? 0 : Theme.spacingXS
            rightPadding: root.iconOnly ? 0 : Theme.spacingS

            DankIcon {
                name: root.getPrayerIcon(root.currName)
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !root.iconOnly
                text: root.nextTime !== ""
                      ? (root.nextName + " " + root.formatTime(root.nextTime))
                      : "Loading…"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconOnly ? 0 : implicitWidth
            }

            StyledText {
                visible: !root.iconOnly && root.nextTime !== ""
                text: "·"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                leftPadding: 2
                rightPadding: 2
                anchors.verticalCenter: parent.verticalCenter
                width: (!root.iconOnly && root.nextTime !== "") ? implicitWidth : 0
            }

            StyledText {
                visible: !root.iconOnly && root.nextTime !== ""
                text: root.formatCountdown(root.nextTotalSeconds)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: root.isUrgent ? Font.Bold : Font.Normal
                color: root.isUrgent ? root.accentColor : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: (!root.iconOnly && root.nextTime !== "") ? implicitWidth : 0
            }
        }
    }

    // Vertical bar pill:
    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                name: root.getPrayerIcon(root.currName)
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.nextTime !== ""
                text: root.formatCountdown(root.nextTotalSeconds)
                font.pixelSize: Theme.fontSizeSmall - 2
                color: root.isUrgent ? root.accentColor : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Popout panel:
    popoutContent: Component {
        Item {
            id: popoutRoot
            width: 260
            implicitWidth: 260
            implicitHeight: content.implicitHeight + Theme.spacingM * 2

            Column {
                id: content
                spacing: Theme.spacingS
                anchors.fill: parent
                anchors.margins: Theme.spacingM

                Item {
                    width: parent.width
                    height: Math.max(dateCol.implicitHeight, refreshPill.height)

                    Column {
                        id: dateCol
                        spacing: 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: root.dateHijr
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: root.dateGreg
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Rectangle {
                        id: refreshPill
                        width: 28
                        height: 28
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: refreshArea.containsMouse
                               ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12)
                               : root.subtleBg

                        DankIcon {
                            name: "refresh"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.forceRefresh()
                        }
                    }
                }

                // Countdown card. Themed with accent color
                Rectangle {
                    width: parent.width
                    height: cdCol.implicitHeight + Theme.spacingM * 2
                    radius: 8
                    color: root.accentBg
                    border.color: root.accentColor
                    border.width: 1

                    Column {
                        id: cdCol
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            text: root.nextName !== "" ? (root.nextName + "  in") : "—"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: root.nextTime !== ""
                                  ? root.formatCountdown(root.nextTotalSeconds)
                                  : "—"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: root.isUrgent ? root.accentColor : Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        StyledText {
                            text: root.nextTime !== "" ? ("at  " + root.formatTime(root.nextTime)) : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Prayer times list
                Repeater {
                    model: [
                        { label: "Imsak",   time: root.imsak,   icon: "moon_stars" },
                        { label: "Fajr",    time: root.fajr,    icon: "bedtime" },
                        { label: "Sunrise", time: root.sunrise, icon: "wb_twilight" },
                        { label: "Dhuhr",   time: root.dhuhr,   icon: "wb_sunny" },
                        { label: "Asr",     time: root.asr,     icon: "light_mode" },
                        { label: "Maghrib", time: root.maghrib,  icon: "wb_twilight" },
                        { label: "Isha",    time: root.isha,    icon: "bedtime" }
                    ]

                    delegate: Item {
                        width: parent.width
                        height: 36

                        readonly property bool isNext: modelData.label === root.nextName
                        readonly property bool isCurr: modelData.label === root.currName

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: height / 2
                            color: isNext ? root.accentBg : (isCurr ? root.subtleBg : "transparent")
                            border.color: isNext ? root.accentColor : "transparent"
                            border.width: isNext ? 1 : 0
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Row {
                                spacing: Theme.spacingS
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize
                                    color: isNext ? root.accentColor
                                                  : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: (isNext || isCurr) ? Font.Bold : Font.Normal
                                    color: isNext ? root.accentColor
                                                  : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                    width: 64
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: root.formatTime(modelData.time)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: (isNext || isCurr) ? Font.Bold : Font.Normal
                                color: isNext ? root.accentColor
                                              : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                width: 70
                            }
                        }
                    }
                }
            }
        }
    }
}
