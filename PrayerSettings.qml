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

    ToggleSetting {
        settingKey: "use12HourFormat"
        label: "12-Hour Format"
        description: "Display prayer times in 12-hour format instead of 24-hour"
        defaultValue: false
    }
}