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
    property string lat: "" // default Jakarta
    property string lon: "" // default Jakarta
    property bool use12HourFormat: false
    property string scriptPath: Qt.resolvedUrl("get-prayer-times").toString().replace("file://", "")
    
    function getFormattedPrayerInfo() {
        if (!prayerInfo) return prayerInfo;
        
        // prayerInfo format: "Next: Asr 04:32" or "Current: Asr 04:32 - Next: Dhuhr 12:34"
        var match = prayerInfo.match(/([A-Za-z]+):\s+([A-Za-z]+)\s+(\d{2}):(\d{2})/);
        if (!match) return prayerInfo;
        
        var prefix = match[1]; // "Next" or "Current"
        var prayerName = match[2]; // "Asr", "Dhuhr", etc
        var time24h = match[3] + ":" + match[4]; // "04:32"
        
        var formattedTime = formatTime(time24h);
        var result = prefix + ": " + prayerName + " " + formattedTime;
        
        // Handle "Current: X XX:XX - Next: Y YY:YY" format
        var remainingIndex = match.index + match[0].length;
        if (remainingIndex < prayerInfo.length) {
            result += prayerInfo.substring(remainingIndex);
        }
        
        return result;
    }

    onPluginDataChanged: {
        root.refreshInterval = (Number(root.pluginData.refreshInterval) || 5) * 60000
        root.lat = root.pluginData.lat
        root.lon = root.pluginData.lon
        root.use12HourFormat = root.pluginData.use12HourFormat === "true" || root.pluginData.use12HourFormat === true
        root.pluginDataLoaded = true
        // Run process immediately when pluginData is loaded
        prayerProcess.running = true;
    }

    Process {
        id: prayerProcess
        command: ["bash", root.scriptPath, root.lat, root.lon, root.refreshInterval]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    var data = JSON.parse(data)
                    root.fajr = data.Fajr
                    root.dhuhr = data.Dhuhr
                    root.asr = data.Asr
                    root.maghrib = data.Maghrib
                    root.isha = data.Isha
                    root.prayerInfo = data.prayerInfo

                    root.dateGreg = data.DateGreg
                    root.dateHijr = data.DateHijr
                    root.currName = data.currName || "Fajr"

                } catch (e) {
                    ToastService.showError("JSON error:", e.message);
                    root.prayerInfo = e.message
                    console.error("prayer JSON error:", e)
                }
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: root.pluginDataLoaded
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            prayerProcess.running = true;
        }
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
                text: root.getFormattedPrayerInfo()
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

    function formatTime(time24h) {
        if (!time24h || time24h === "") return "";
        
        if (!root.use12HourFormat) {
            return time24h;
        }
        
        // Parse HH:MM format
        var parts = time24h.split(":");
        if (parts.length !== 2) return time24h;
        
        var hours = parseInt(parts[0]);
        var minutes = parts[1];
        var ampm = hours >= 12 ? "PM" : "AM";
        
        // Convert to 12-hour format
        if (hours > 12) {
            hours = hours - 12;
        } else if (hours === 0) {
            hours = 12;
        }
        
        // Pad hours with leading zero if needed
        var hoursStr = hours < 10 ? "0" + hours : hours.toString();
        
        return hoursStr + ":" + minutes + " " + ampm;
    }

    function getPrayerTimesList() {
        return [
            { label: "Hijri", value: root.dateHijr, icon: "calendar_today" },
            { label: "Gregorian", value: root.dateGreg, icon: "calendar_today" },

            { label: "Fajr", value: root.formatTime(root.fajr), icon: getPrayerIcon("Fajr") },
            { label: "Dhuhr", value: root.formatTime(root.dhuhr), icon: getPrayerIcon("Dhuhr") },
            { label: "Asr", value: root.formatTime(root.asr), icon: getPrayerIcon("Asr") },
            { label: "Maghrib", value: root.formatTime(root.maghrib), icon: getPrayerIcon("Maghrib") },
            { label: "Isha", value: root.formatTime(root.isha), icon: getPrayerIcon("Isha") }
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
