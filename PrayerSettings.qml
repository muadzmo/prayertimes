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
        text: "Configure how often the prayer times are refreshed."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // SliderSetting {
    //     settingKey: "refreshInterval"
    //     label: "Refresh Interval"
    //     description: "How often to update prayer times (in minutes)"
    //     defaultValue: 5
    //     minimum: 1
    //     maximum: 60
    //     unit: "min"
    //     leftIcon: "schedule"
    // }

    StringSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval (float)"
        description: "How often to update prayer times (in minutes)"
        defaultValue: "5"
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

<<<<<<< HEAD
    SelectionSetting {
        settingKey: "method"
        label: "Calculation Method"
        description: "Method used to calculate prayer times. Leave on Auto to let the API choose based on your location."
        defaultValue: ""
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
    }

    SelectionSetting {
        settingKey: "school"
        label: "Asr Calculation School"
        description: "Juristic school used to calculate the Asr prayer time."
        defaultValue: "0"
        options: [
            { label: "Shafi (Default)", value: "0" },
            { label: "Hanafi", value: "1" }
        ]
    }
}
=======
    ToggleSetting {
        settingKey: "use12HourFormat"
        label: "12-Hour Format"
        description: "Display prayer times in 12-hour format instead of 24-hour"
        defaultValue: false
    }
}
>>>>>>> upstream/main
