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
    property string scriptPath: Qt.resolvedUrl("get-prayer-times").toString().replace("file://", "")

    onPluginDataChanged: {
        root.refreshInterval = (Number(root.pluginData.refreshInterval) || 5) * 60000
        root.lat = root.pluginData.lat || "-6.2088"
        root.lon = root.pluginData.lon || "106.8456"
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

            // width: 50
            spacing: Theme.spacingS
            padding: Theme.spacingM

            StyledText { text: "🗓️ Hijri: " + root.dateHijr }
            StyledText { text: "🗓️ Gregorian: " + root.dateGreg }
            StyledText { text: "🌅 Fajr: " + root.fajr }
            StyledText { text: "☀️ Dhuhr: " + root.dhuhr }
            StyledText { text: "🌤️ Asr: " + root.asr }
            StyledText { text: "🌇 Maghrib: " + root.maghrib }
            StyledText { text: "🌙 Isha: " + root.isha }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            rightPadding: Theme.spacingS

            StyledText {
                text: "🕌 "
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.prayerInfo
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                onClicked: {
                    // loadPrayerData(() => { prayerPopup.open(); });
                    // jsonFile.read();
                    // prayerPopup.open();
                }
            }
        }
    }

    function getPrayerIcon() {
        switch(root.currName) {
            case "Fajr": return "sunny";
            case "Dhuhr": return "light_mode";
            case "Asr": return "partly_cloudy_day";
            case "Maghrib": return "sunset";
            case "Isha": return "nightlight";
            default: return "mosque";
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.getPrayerIcon()
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
