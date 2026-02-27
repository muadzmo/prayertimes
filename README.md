# Prayer Times

A DankMaterialShell widget for displaying Islamic prayer times using the Aladhan API.

## Features

- Displays current and next prayer times in the Dank Bar
- Popout view showing all prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha) and dates (Hijri and Gregorian)
- Pure QML/JavaScript — no external tools (`curl`, `jq`, `bash`) required
- API data fetched via `XMLHttpRequest` and cached in-memory per day
- Configurable refresh interval and location (latitude/longitude)
- Toast notifications when a prayer time is reached

## Installation

### From Plugin Registry (Recommended)

```bash
# dms plugins install prayerTimes
# or install using the plugins tab on DMS settings
```

### Manual Installation

```bash
# Copy plugin to DMS plugins directory
cp -r "prayerTimesPlugin" ~/.config/DankMaterialShell/plugins/

# Enable in DMS plugins tab and add the widget to Dank Bar
```

## Configuration

- **Refresh Interval**: Set how often to update prayer times (1-60 minutes, default: 5 minutes)
- **Latitude**: Set your location's latitude (e.g., -6.2000 for Jakarta)
- **Longitude**: Set your location's longitude (e.g., 106.8166 for Jakarta)

Access settings through the DMS plugins settings panel.

## Requirements

- DankMaterialShell >= 0.2.4
- Wayland compositor (Niri, Hyprland, etc.)

> **Note:** No external tools required — API calls and JSON processing are handled entirely in QML/JavaScript.

## Compatibility

- **Compositors**: Niri and Hyprland
- **Distros**: Universal - works on any Linux distribution

## API

This plugin uses the [Aladhan Prayer Times API](https://aladhan.com/prayer-times-api) for accurate prayer time calculations.

## Contributing

Found a bug? Open an issue or submit a pull request!

## Author

Created by muadz

## Links

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Plugin Registry](https://github.com/AvengeMedia/dms-plugin-registry)
- [Aladhan API](https://aladhan.com/prayer-times-api)
