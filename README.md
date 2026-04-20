# SnapState

A macOS menu bar application for saving and restoring workspace layouts. Capture your perfect desktop setup and restore it instantly with a single click.

![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Quick Capture** - Save your current workspace with a single click from the menu bar
- **Window Position Restore** - Automatically restores app window positions using Accessibility APIs
- **App Launch Management** - Specify which apps to launch and which to close for each workspace
- **URL Preservation** - Saves browser URLs (Safari, Chrome, Edge, Brave, and Arc) so you can resume exactly where you left off
- **Monitor Auto-Restore** - Automatically restores a workspace when you connect/disconnect external displays
- **Menu Bar Only** - Runs entirely from the menu bar with no dock icon

## Requirements

- macOS 12.0 or later
- **Accessibility Permission** - Required for reading and restoring window positions

## Installation

### From DMG
1. Download `SnapState.dmg` from the Releases
2. Open the DMG and drag SnapState to Applications
3. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)

### Building from Source
```bash
# Clone the repository
git clone https://github.com/SoulSniper-V2/SnapState.git
cd SnapState

# Open in Xcode
open SnapState.xcodeproj

# Build and run (Cmd+R)
```

## Usage

1. **Launch the app** - SnapState appears in your menu bar (no dock icon)
2. **Capture a workspace**:
   - Click the menu bar icon
   - Click the `+` button
   - Give your workspace a name
   - Click the camera icon to capture
3. **Restore a workspace** - Click any saved workspace card
4. **Manage workspaces**:
   - Click "Settings" to open the full management window
   - Edit workspace names, icons, and colors
   - Delete workspaces
   - Set up auto-restore for monitor changes

## Permissions

### Accessibility (Required)
SnapState needs Accessibility permission to:
- Read current window positions
- Restore window positions after launching apps

Grant permission in: **System Settings → Privacy & Security → Accessibility**

## How It Works

1. **Capture** - When you save a workspace, SnapState records:
   - Running applications
   - Browser URLs (Safari/Chrome)
   - Window positions and sizes
   - Display configuration

2. **Restore** - When restoring a workspace:
   - Launches specified apps (with URLs if saved)
   - Closes apps that should not be running
   - Waits for apps to launch
   - Restores window positions using Accessibility APIs

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **AppKit** - System integration
- **ApplicationServices** - Accessibility APIs for window management
- **Combine/Observable** - Reactive state management

## License

MIT License - See LICENSE file for details

