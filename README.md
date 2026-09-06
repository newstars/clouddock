# CloudDock

[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-Support_CloudDock-FFDD00?style=flat-square&logo=buymeacoffee&logoColor=000000)](https://buymeacoffee.com/newstars)

CloudDock is a customizable macOS dock with live widgets, app groups, and quick access to your apps and developer tools.

Current MVP scope:

- Borderless floating macOS window
- Transparent, material-backed compact dock UI with automatic multi-row wrapping
- Dock-icon mode: CloudDock appears in the macOS Dock and opens the dock window when clicked
- Dock window stays visible until Dock-icon toggle, outside click, Escape, or explicit Hide
- Reset Position command returns the dock window to the selected screen edge preset
- Clock widget
- Date and Pomodoro widgets
- CPU and memory widgets with top process lists and manual terminate actions
- Process termination requires a destructive confirmation before SIGTERM is sent
- Network, disk, battery, clipboard, and quick note widgets
- Compact Tools palette opens as a popover so it does not resize the dock row
- Clipboard opens as a popover with the 10 most recent text clips
- Gear menu is fixed at the bottom-right of the dock and opens a popover for Settings, Hide, Reset Position, and Quit
- Default dock starts smaller with Tools, Clock, CPU, Memory, and Clipboard enabled
- App-icon based launcher tiles for default and user-added applications
- App icons can be reordered in the Tools popover by dragging one icon onto another
- Active dock widgets can be reordered in CloudDock by dragging between widget icons
- User-added application launchers stored in local preferences
- Git status widget
- Multi-repository Git status selection
- Shared refresh loop for command-backed widgets to avoid duplicate CPU/MEM process polling
- Widget construction split out of the root dock view to keep layout and service injection separate
- App launcher widget
- Click-to-expand clock details
- Widget enable/disable and reorder settings
- Searchable widget gallery with Quick Access, Daily Focus, Mac Controls, Utility, Business, Developer, and Cloud sections
- Dock position, transparency, always-on-top, and launch-at-login settings
- Minimal widget registry and UI preferences persistence foundation

## Build

```sh
swift build
```

## Run

```sh
Scripts/package_app.sh
open .build/dist/CloudDock.app
```

The app runs as a regular macOS app with a Dock icon and a menu bar item named `CloudDock`.

`swift run CloudDock` is useful for compile-time development, but the packaged `.app` path is the reliable way to exercise macOS app lifecycle behavior.

## Package Development App

```sh
Scripts/package_app.sh
```

The script creates an ad-hoc signed app bundle at `.build/dist/CloudDock.app`.

## CI

```sh
Scripts/ci.sh
```

CI builds debug and release, packages `.build/dist/CloudDock.app`, validates `Info.plist`, and verifies the app signature.

## Security Boundary

`DockPreferencesStore` is only for non-sensitive UI preferences. Future credential-backed widgets must use Keychain-backed storage; see `SECURITY.md`.

## Support

CloudDock is free to use. If it makes your day easier, you can support its development on [Buy Me a Coffee](https://buymeacoffee.com/newstars). Support is optional and does not unlock or restrict features.
