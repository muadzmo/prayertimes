import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "prayerTimes"

    StyledText {
        width: parent.width
        text: "Prayer Times & Fasting Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure location, calculation method, notifications, and display preferences"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "language"
        label: "Display & Notification Language"
        description: "Choose language for widget UI text and system notifications"
        options: [
            { label: "العربية (Arabic)", value: "ar" },
            { label: "English", value: "en" }
        ]
        defaultValue: "en"
    }

    StyledRect {
        width: parent.width
        height: fastingColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: fastingColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Sunnah Fasting Reminders"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: "Includes Mondays, Thursdays, The White Days (13, 14, 15 Hijri), Arafah, Tasu'a, and Ashura."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            ToggleSetting {
                settingKey: "fastingReminderEveEnabled"
                label: "Eve Reminder (Night Before)"
                description: "Send desktop notification the evening before fasting for preparation and intention"
                defaultValue: true
            }

            StringSetting {
                settingKey: "fastingReminderEveHour"
                label: "Evening Reminder Hour (24h)"
                description: "Hour to trigger reminder the night before (Default: 21 for 9 PM)"
                defaultValue: "21"
            }

            ToggleSetting {
                settingKey: "fastingReminderMorningEnabled"
                label: "Morning Reminder (Fasting Day)"
                description: "Send notification at the start of the fasting day (e.g. Suhur / Fajr time)"
                defaultValue: true
            }

            StringSetting {
                settingKey: "fastingReminderMorningHour"
                label: "Morning Reminder Hour (24h)"
                description: "Hour to trigger reminder on the day of fasting (Default: 4 for 4 AM)"
                defaultValue: "4"
            }
        }
    }

    SelectionSetting {
        settingKey: "method"
        label: "Calculation Method"
        description: "Calculation method used by the Aladhan API."
        options: [
            { label: "Auto (method for entered coordinates)", value: "" },
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
        description: "Juristic school used to calculate Asr prayer time."
        options: [
            { label: "Shafi / Standard (Default)", value: "0" },
            { label: "Hanafi", value: "1" }
        ]
        defaultValue: "0"
    }

    ToggleSetting {
        settingKey: "notificationsEnabled"
        label: "Enable Notifications"
        description: "Show prayer reminders, prayer-time alerts, and fasting notifications."
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "notificationUrgency"
        label: "Notification Priority"
        description: "Priority level for desktop notifications."
        options: [
            { label: "Low", value: "low" },
            { label: "Normal", value: "normal" },
            { label: "Critical", value: "critical" }
        ]
        defaultValue: "critical"
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
                description: "Enter latitude manually (e.g., 26.5568)"
                defaultValue: "-6.2088"
            }

            StringSetting {
                settingKey: "lon"
                label: "Longitude"
                description: "Enter longitude manually (e.g., 31.6948)"
                defaultValue: "106.8456"
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
                description: "Minutes before prayer time to send reminder"
                defaultValue: "15"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: offsetColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: offsetColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Prayer Time Adjustments"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: "Fine-tune prayer times by adding or subtracting minutes (use negative values like -2)."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            StringSetting { settingKey: "tuneImsak"; label: "Imsak Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneFajr"; label: "Fajr Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneSunrise"; label: "Sunrise Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneDhuhr"; label: "Dhuhr Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneAsr"; label: "Asr Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneMaghrib"; label: "Maghrib Offset (minutes)"; defaultValue: "0" }
            StringSetting { settingKey: "tuneIsha"; label: "Isha Offset (minutes)"; defaultValue: "0" }
        }
    }

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
                description: "Show only the prayer icon in the bar, hiding the name and countdown."
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showSeconds"
                label: "Show Seconds in Countdown"
                description: "Display seconds in countdown timer (disabling saves CPU cycles)."
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
                text: "Displays Islamic prayer times and Sunnah fasting notifications using the Aladhan API.\n\nData provided by aladhan.com"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
