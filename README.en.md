# TTCalendar

English | [简体中文](README.md)

TTCalendar is a macOS desktop widget calendar app for quickly checking the current month, next month, lunar calendar dates, holidays, solar terms, weekends, and adjusted workdays from your desktop.

The main app handles permissions, holiday calendar syncing, update checks, and usage guidance. The WidgetKit extension renders the calendar, supports month navigation, and shows upcoming holiday reminders.

![TTCalendar widget preview](ttcalendar/Assets.xcassets/WidgetPreview.imageset/widget-preview.png)

## Download

[Download the latest macOS installer](https://github.com/akmumu/ttcalendar/releases/latest/download/ttcalendar.dmg)

## Installation and Usage

Open the installer, drag the app into Applications, and launch it once from Launchpad. Then right-click an empty area on the desktop, choose "Edit Widgets", search for "抬头日历", and add the large or extra-large widget.

Once the widget is added it keeps showing on its own — you don't need to keep the app running or have it stay resident in the background.

## Features

- Large desktop widget: shows a single-month calendar with lunar dates, holidays, solar terms, weekends, and adjusted workday markers.
- Extra-large desktop widget: shows the current month and next month together, plus today's details and upcoming holiday or solar term reminders.
- Widget month navigation: switch to the previous month, next month, or return to the current month.
- Custom special dates: add important dates (birthdays, meetings, anniversaries, etc.) in the main app — names are up to three characters with a customizable single-character corner marker. They appear in the widget with a purple style and an upcoming countdown reminder.
- Apple Calendar sync: reads local calendars whose names contain "节假日", "假日", or "holiday" to improve adjusted workday and rest day accuracy.
- Sparkle updates: supports manual update checks inside the app.

## Requirements

- macOS 26.5 or later
- Xcode 26 or later
- SwiftUI / WidgetKit / AppIntents
- Swift package dependency: Sparkle 2.9.3

## Run Locally

1. Open `ttcalendar.xcodeproj` in Xcode.
2. Select the `ttcalendar` scheme.
3. Select a macOS target and run.
4. After the first launch, grant calendar access inside the app.
5. Right-click an empty area on the desktop, choose "Edit Widgets", search for "抬头日历", and add the large or extra-large widget.

## Debug the Widget

Use the helper script to build, install, and register a debug version:

```sh
Scripts/install_debug_widget.sh
```

The script will:

- Build the Debug version with `xcodebuild`.
- Verify the app and widget extension signatures.
- Install the app to `/Applications/抬头日历.app`.
- Register the WidgetKit extension.
- Launch the app and prompt you to reopen the widget picker.

Default values can be overridden with environment variables:

```sh
SCHEME=ttcalendar CONFIGURATION=Debug DERIVED_DATA=/private/tmp/ttcalendar-widget-dev Scripts/install_debug_widget.sh
```

## Release

See `RELEASE.md` for the release process. The current flow keeps Xcode Archive for exporting the app, then uses scripts to package the DMG and generate the Sparkle appcast:

```sh
Scripts/package_dmg.sh
Scripts/update_appcast.sh
```

Before the first release, generate a Sparkle private key and write the public key:

```sh
Scripts/generate_sparkle_keys.sh
```

## Project Structure

```text
.
├── ttcalendar/                 # Main macOS app
├── CalendarWidget/             # WidgetKit widget extension
├── Shared/                     # Shared calendar models, holidays, lunar calendar, and navigation logic
├── Scripts/                    # Build, install, and icon generation scripts
├── GeneratedIcon.appiconset/   # Generated icon assets
└── ttcalendar.xcodeproj/       # Xcode project
```

## Key Modules

- `ttcalendar/ContentView.swift`: main app UI, including widget preview, permission state, holiday calendar detection, and update entry points.
- `ttcalendar/HolidayEventSync.swift`: reads Apple Calendar events, caches holiday and adjusted workday data, and refreshes widget timelines.
- `ttcalendar/UpdaterViewModel.swift`: wraps Sparkle update checks.
- `CalendarWidget/CalendarWidget.swift`: WidgetKit entry point, timeline provider, calendar layout, and widget interaction buttons.
- `Shared/CalendarContent.swift`: generates calendar month data, today's details, and upcoming holiday or solar term reminders.
- `Shared/WidgetMonthNavigation.swift`: stores the widget month offset state.
- `Shared/CalendarWidgetIdentity.swift`: defines the widget kind identifier.

## Calendar Data

TTCalendar prioritizes holiday data from local Apple Calendar calendars, then combines it with built-in lunar calendar, holiday, and solar term logic to generate widget content. If calendar permission is not granted, the app can still display built-in data, but adjusted workday and rest day information may be less complete than the system holiday calendar.

## Icon Generation

The project includes an icon generation script:

```sh
swift Scripts/generate_app_icon.swift
```

Generated files are written to `GeneratedIcon.appiconset/` and can be synced to the app or widget `Assets.xcassets/AppIcon.appiconset/` as needed.
