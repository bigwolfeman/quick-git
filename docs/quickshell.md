# Quickshell Framework Documentation

> Reference documentation for building the Quick-Git Noctalia plugin

## Overview

Quickshell is a flexible toolkit for creating desktop shells using QtQuick/QML for Wayland and X11. It provides a declarative approach to building bars, widgets, panels, and other shell components.

**Official Resources:**
- Documentation: https://quickshell.org/docs/
- Repository: https://git.outfoxxed.me/quickshell/quickshell
- GitHub Mirror: https://github.com/quickshell-mirror/quickshell

## Architecture

### Configuration Structure

Quickshell configurations are stored in `~/.config/quickshell/`. Each named subfolder containing a `shell.qml` file is a valid configuration.

```
~/.config/quickshell/
├── my-shell/
│   └── shell.qml          # Entry point
├── another-config/
│   └── shell.qml
```

**Launching:**
```bash
# Default config
qs

# Specific config
qs --config my-shell
qs -c my-shell

# Path to config
qs --path /path/to/shell.qml
qs -p /path/to/shell.qml
```

### Technology Stack

- **QML (94.8%)** - Qt's declarative UI language
- **JavaScript** - Logic and automation
- **GLSL** - GPU shaders for visual effects

## Core Components

### Window Types

Quickshell provides two primary window types:

#### PanelWindow

Decorationless window attached to screen edges. Used for bars, widgets, and overlays.

```qml
import Quickshell
import QtQuick

PanelWindow {
    // Anchor to screen edges
    anchors {
        top: true
        left: true
        right: true
    }

    // When opposite anchors enabled, dimension spans full screen
    implicitHeight: 32

    // Render above normal windows (default: true)
    aboveWindows: true

    // Accept keyboard focus (default: false)
    focusable: false

    // Space reservation for other windows
    // exclusionMode: ExclusionMode.Auto (default)

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"

        Text {
            anchors.centerIn: parent
            text: "My Bar"
            color: "white"
        }
    }
}
```

**Key Properties:**
- `anchors.top/bottom/left/right` - Attach to screen edges (all default to false)
- `margins.top/bottom/left/right` - Offset from screen edges
- `exclusiveZone` - Reserved screen space
- `exclusionMode` - How panel interacts with window space
- `aboveWindows` - Render above standard windows

#### FloatingWindow

Standard desktop window for popups and dialogs.

```qml
import Quickshell
import QtQuick

FloatingWindow {
    width: 400
    height: 300

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
    }
}
```

### The Quickshell Singleton

Access shell-level properties and functions via the `Quickshell` singleton.

```qml
import Quickshell

// Properties
Quickshell.shellDir      // Shell root directory path
Quickshell.stateDir      // Per-shell state directory
Quickshell.cacheDir      // Per-shell cache directory
Quickshell.dataDir       // Per-shell data directory
Quickshell.processId     // Quickshell process ID
Quickshell.screens       // All connected screens (reactive)
Quickshell.clipboardText // System clipboard (Wayland: requires focus)

// Path utilities
Quickshell.shellPath("assets/icon.png")
Quickshell.cachePath("data.json")
Quickshell.statePath("config.json")
Quickshell.dataPath("user-data.json")

// Functions
Quickshell.env("HOME")                    // Get environment variable
Quickshell.iconPath("firefox")            // Resolve system icon path
Quickshell.reload(false)                  // Reload config (soft)
Quickshell.reload(true)                   // Reload config (hard)
Quickshell.execDetached(command)          // Launch detached process

// Signals
Quickshell.lastWindowClosed               // All windows closed
Quickshell.reloadCompleted                // Config reload succeeded
Quickshell.reloadFailed(errorString)      // Config reload failed
```

## Multi-Monitor Support

### Using Variants

The `Variants` type creates component instances for each item in a data model. Commonly used to create a window per screen.

```qml
import Quickshell
import QtQuick

Variants {
    model: Quickshell.screens

    PanelWindow {
        property var modelData  // Injected by Variants
        screen: modelData       // Assign to this screen

        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"

            Text {
                anchors.centerIn: parent
                text: modelData.name  // Screen name
                color: "white"
            }
        }
    }
}
```

### Screen Handling

As monitors connect/disconnect, the `Quickshell.screens` property updates automatically, and Variants will create/destroy window instances accordingly.

## Process Execution

### Running Commands

```qml
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    property string output: ""

    Process {
        id: gitProcess
        command: ["git", "status", "--porcelain"]
        workingDirectory: "/path/to/repo"

        running: true  // Start immediately

        stdout: SplitParser {
            onRead: line => {
                output += line + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("Git exited with code:", exitCode)
        }
    }

    // Run periodically
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: gitProcess.running = true
    }
}
```

### StdioCollector

For capturing complete output:

```qml
Process {
    id: proc
    command: ["cat", "/etc/hostname"]

    stdout: StdioCollector {
        onCollected: text => {
            console.log("Output:", text)
        }
    }
}
```

## Hyprland Integration

Import `Quickshell.Hyprland` for Hyprland window manager integration.

```qml
import Quickshell.Hyprland
```

### Hyprland Singleton

```qml
// Properties
Hyprland.focusedMonitor     // Currently focused monitor
Hyprland.focusedWorkspace   // Currently focused workspace
Hyprland.workspaces         // All workspaces (sorted by ID)
Hyprland.monitors           // All monitors
Hyprland.eventSocketPath    // Event socket path (.socket2.sock)
Hyprland.requestSocketPath  // Request socket path (.socket.sock)

// Functions
Hyprland.dispatch("workspace 1")          // Execute dispatcher
Hyprland.monitorFor(screen)               // Get HyprlandMonitor for screen
Hyprland.refreshMonitors()                // Force monitor state refresh
Hyprland.refreshWorkspaces()              // Force workspace state refresh

// Signals
Hyprland.rawEvent(event)    // Every event from Hyprland socket
```

### HyprlandWorkspace Properties

```qml
// workspace is a HyprlandWorkspace object
workspace.id           // Workspace ID
workspace.name         // Workspace name
workspace.focused      // True if active on focused monitor
workspace.active       // True if active on any monitor
workspace.urgent       // True if has urgent window
workspace.fullscreen   // True if has fullscreen client
workspace.toplevels    // List of windows on workspace
```

### Workspace Switcher Example

```qml
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 4

    Repeater {
        model: 9

        Rectangle {
            required property int index
            property int wsId: index + 1
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId

            width: 24
            height: 24
            radius: 4
            color: isActive ? "#89b4fa" : "#45475a"

            Text {
                anchors.centerIn: parent
                text: parent.wsId
                color: parent.isActive ? "#1e1e2e" : "#cdd6f4"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + wsId)
            }
        }
    }
}
```

### IPC Events

Handle Hyprland events in real-time:

```qml
Connections {
    target: Hyprland

    function onRawEvent(event) {
        // event.name - Event name (e.g., "workspace", "activewindow")
        // event.data - Event data string
        console.log("Event:", event.name, event.data)
    }
}
```

## Singleton Pattern

Create shared state accessible from any component:

```qml
// Time.qml
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    property string currentTime: ""

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            currentTime = Qt.formatDateTime(clock.now, "hh:mm:ss")
        }
    }
}
```

Usage:

```qml
import "." as Root

Text {
    text: Root.Time.currentTime
}
```

## Component Organization

### File Structure Best Practices

```
my-shell/
├── shell.qml           # Entry point
├── Bar.qml             # Bar component
├── Widgets/
│   ├── Clock.qml
│   ├── Workspaces.qml
│   └── GitStatus.qml
├── Services/
│   ├── Time.qml        # Singleton
│   └── GitService.qml  # Singleton
└── Assets/
    └── icons/
```

### Component Files

QML files with uppercase names become referenceable types:

```qml
// Bar.qml
import Quickshell
import QtQuick

PanelWindow {
    id: bar

    // Component implementation
}
```

```qml
// shell.qml
import Quickshell
import "." as Components

Variants {
    model: Quickshell.screens
    Components.Bar {
        screen: modelData
    }
}
```

## Built-in Modules

Quickshell includes integration modules:

| Module | Purpose |
|--------|---------|
| `Quickshell.Io` | Process execution, file I/O |
| `Quickshell.Hyprland` | Hyprland WM integration |
| `Quickshell.I3` | i3/Sway integration |
| `Quickshell.Services.SystemTray` | System tray icons |
| `Quickshell.Services.Notifications` | Desktop notifications |
| `Quickshell.Services.Mpris` | Media player control |
| `Quickshell.Services.UPower` | Power/battery info |
| `Quickshell.Services.Pipewire` | Audio device control |

## Live Reloading

Quickshell automatically reloads configuration files on save, enabling rapid development iteration without restarting.

## Tips for Quick-Git Plugin

1. **Use Singletons for Git State** - Create a GitService singleton to manage repository state, branches, and diffs.

2. **Process for Git Commands** - Use the Process type to execute git commands and parse output.

3. **Reactive Bindings** - Bind UI components to singleton properties for automatic updates.

4. **Panel for Slide-Down UI** - Use PanelWindow with top anchor for the slide-down panel.

5. **Hyprland Integration** - Use IPC to respond to workspace/window events if needed.

```qml
// Example: GitService singleton pattern
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property string branch: ""
    property var stagedFiles: []
    property var unstagedFiles: []
    property bool isRepo: false

    function refresh() {
        // Run git commands and update properties
    }

    function stage(file) {
        // git add file
    }

    function commit(message) {
        // git commit -m message
    }
}
```

## References

- [Quickshell Introduction](https://quickshell.org/docs/guide/introduction/)
- [Quickshell Types Reference](https://quickshell.org/docs/types/Quickshell/)
- [PanelWindow Documentation](https://quickshell.org/docs/master/types/Quickshell/PanelWindow/)
- [Hyprland Integration](https://quickshell.org/docs/types/Quickshell.Hyprland/Hyprland/)
- [Build Your Own Bar Tutorial](https://www.tonybtw.com/tutorial/quickshell/)
