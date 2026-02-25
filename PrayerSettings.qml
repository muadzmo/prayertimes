import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "prayerTimes"

    StyledText {
        width: parent.width
        text: "Prayer Times Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure location, calculation method, and display preferences"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "method"
        label: "Calculation Method"
        description: "Method used to calculate prayer times. Leave on Auto to let the API choose based on your location."
        options: [
            { label: "Auto (based on location)", value: "" },
            { label: "Jafari / Shia Ithna-Ashari", value: "0" },
            { label: "University of Islamic Sciences, Karachi", value: "1" },
            { label: "Islamic Society of North America", value: "2" },
            { label: "Muslim World League", value: "3" },
            { label: "Umm Al-Qura University, Makkah", value: "4" },
            { label: "Egyptian General Authority of Survey", value: "5" },
            { label: "Institute of Geophysics, University of Tehran", value: "7" },
            { label: "Gulf Region", value: "8" },
            { label: "Kuwait", value: "9" },
            { label: "Qatar", value: "10" },
            { label: "Majlis Ugama Islam Singapura, Singapore", value: "11" },
            { label: "Union Organization islamic de France", value: "12" },
            { label: "Diyanet İşleri Başkanlığı, Turkey", value: "13" },
            { label: "Spiritual Administration of Muslims of Russia", value: "14" },
            { label: "Moonsighting Committee Worldwide", value: "15" },
            { label: "Dubai (experimental)", value: "16" },
            { label: "JAKIM, Malaysia", value: "17" },
            { label: "Tunisia", value: "18" },
            { label: "Algeria", value: "19" },
            { label: "KEMENAG, Indonesia", value: "20" },
            { label: "Morocco", value: "21" },
            { label: "Comunidade Islamica de Lisboa", value: "22" },
            { label: "Ministry of Awqaf, Jordan", value: "23" }
        ]
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "school"
        label: "Asr Calculation School"
        description: "Juristic school used to calculate the Asr prayer time."
        options: [
            { label: "Shafi (Default)", value: "0" },
            { label: "Hanafi", value: "1" }
        ]
        defaultValue: "0"
    }

    StyledRect {
        width: parent.width
        height: locationColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: locationColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Location & Timing"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "lat"
                label: "Latitude"
                description: "Example: -6.2000"
                defaultValue: "0.0"
            }

            StringSetting {
                settingKey: "lon"
                label: "Longitude"
                description: "Example: 106.8166"
                defaultValue: "0.0"
            }

            StringSetting {
                settingKey: "refreshInterval"
                label: "Refresh Interval (minutes)"
                description: "How often to update prayer times from the API"
                defaultValue: "5"
            }

            StringSetting {
                settingKey: "notifyMinutes"
                label: "Notification Threshold (minutes)"
                description: "How many minutes before the next prayer to send a reminder"
                defaultValue: "15"
            }
        }
    }

    // ToDo: Fix the SelectionSetting not remembering the selected value under StyledRect object.
    // StyledRect {
    //     width: parent.width
    //     height: calculationColumn.implicitHeight + Theme.spacingL * 2
    //     radius: Theme.cornerRadius
    //     color: Theme.surfaceContainerHigh

    //     Column {
    //         id: calculationColumn
    //         anchors.fill: parent
    //         anchors.margins: Theme.spacingL
    //         spacing: Theme.spacingM

    //         StyledText {
    //             text: "Calculation"
    //             font.pixelSize: Theme.fontSizeMedium
    //             font.weight: Font.Medium
    //             color: Theme.surfaceText
    //         }

    //         SelectionSetting {
    //             settingKey: "method"
    //             label: "Calculation Method"
    //             description: "Method used to calculate prayer times. Leave on Auto to let the API choose based on your location."
    //             options: [
    //                 { label: "Auto (based on location)", value: "" },
    //                 { label: "Jafari / Shia Ithna-Ashari", value: "0" },
    //                 { label: "University of Islamic Sciences, Karachi", value: "1" },
    //                 { label: "Islamic Society of North America", value: "2" },
    //                 { label: "Muslim World League", value: "3" },
    //                 { label: "Umm Al-Qura University, Makkah", value: "4" },
    //                 { label: "Egyptian General Authority of Survey", value: "5" },
    //                 { label: "Institute of Geophysics, University of Tehran", value: "7" },
    //                 { label: "Gulf Region", value: "8" },
    //                 { label: "Kuwait", value: "9" },
    //                 { label: "Qatar", value: "10" },
    //                 { label: "Majlis Ugama Islam Singapura, Singapore", value: "11" },
    //                 { label: "Union Organization islamic de France", value: "12" },
    //                 { label: "Diyanet İşleri Başkanlığı, Turkey", value: "13" },
    //                 { label: "Spiritual Administration of Muslims of Russia", value: "14" },
    //                 { label: "Moonsighting Committee Worldwide", value: "15" },
    //                 { label: "Dubai (experimental)", value: "16" },
    //                 { label: "JAKIM, Malaysia", value: "17" },
    //                 { label: "Tunisia", value: "18" },
    //                 { label: "Algeria", value: "19" },
    //                 { label: "KEMENAG, Indonesia", value: "20" },
    //                 { label: "Morocco", value: "21" },
    //                 { label: "Comunidade Islamica de Lisboa", value: "22" },
    //                 { label: "Ministry of Awqaf, Jordan", value: "23" }
    //             ]
    //             defaultValue: ""
    //         }

    //         SelectionSetting {
    //             settingKey: "school"
    //             label: "Asr Calculation School"
    //             description: "Juristic school used to calculate the Asr prayer time."
    //             options: [
    //                 { label: "Shafi (Default)", value: "0" },
    //                 { label: "Hanafi", value: "1" }
    //             ]
    //             defaultValue: "0"
    //         }
    //     }
    // }

    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "iconOnly"
                label: "Icon Only Mode"
                description: "Show only the prayer icon in the bar, hiding the next prayer name and countdown."
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showSeconds"
                label: "Show Seconds in Countdown"
                description: "Show seconds in the countdown timer. Disabling this also reduces CPU usage by ticking once per minute instead of every second."
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "use12H"
                label: "12-Hour Format"
                description: "Display prayer times in 12-hour format instead of 24-hour"
                defaultValue: false
            }
        }
    }

    StyledRect {
        width: parent.width
        height: aboutColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: aboutColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "About Prayer Times"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "Displays Islamic prayer times using the Aladhan API with live countdown to the next prayer.\n\n• Fajr, Dhuhr, Asr, Maghrib, Isha — plus Imsak & Sunrise\n• Hijri & Gregorian date display\n• Desktop notifications 15 minutes before prayer and at prayer time\n• Configurable calculation method and Asr juristic school\n\nData provided by aladhan.com"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
