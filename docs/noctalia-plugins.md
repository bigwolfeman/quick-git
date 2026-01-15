# Noctalia Plugin Development Guide

> Reference documentation for building the Quick-Git Noctalia plugin

## Overview

Noctalia is a minimal Wayland desktop shell built on Quickshell with a "quiet by design" philosophy. It provides a modular plugin system for extending shell functionality.

**Official Resources:**
- Documentation: https://docs.noctalia.dev/
- Repository: https://github.com/noctalia-dev/noctalia-shell
- Plugin Registry: https://noctalia.dev/plugins
- Discord: https://discord.noctalia.dev

**Supported Compositors:**
- Niri (native)
- Hyprland (native)
- Sway (native)
- MangoWC (native)
- labwc (native)
- Other Wayland compositors (may require additional configuration)

## Plugin Architecture

### Core Concepts

Noctalia uses a service-oriented architecture with:
- **QML Singleton Services** - Shared state and functionality
- **Reactive Property Bindings** - Automatic UI updates
- **Dynamic Widget Loading** - Plugins loaded via BarWidgetRegistry
- **IPC Command Handlers** - Inter-process communication via IPCService

### Plugin File Structure

```
my-plugin/
├── manifest.json       # Plugin metadata (REQUIRED)
├── preview.png         # Preview image for registry (recommended)
├── Main.qml            # Background logic & IPC handlers (optional)
├── BarWidget.qml       # Bar widget component (optional)
├── Panel.qml           # Full-screen overlay panel (optional)
├── Settings.qml        # Settings UI component (optional)
├── settings.json       # User settings data (auto-generated)
├── i18n/               # Translations (optional)
│   ├── en.json
│   └── es.json
└── README.md           # Plugin documentation
```

## Plugin Manifest

Every plugin requires a `manifest.json` file.

### Complete Manifest Reference

```json
{
  "id": "quick-git",
  "name": "Quick Git",
  "version": "1.0.0",
  "description": "Git management panel with GitHub integration",
  "author": "Your Name",
  "license": "MIT",
  "repository": "https://github.com/you/quick-git",
  "minNoctaliaVersion": "3.0.0",
  "category": "Development",
  "tags": ["git", "github", "development", "vcs"],
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml",
    "settings": "Settings.qml"
  },
  "dependencies": [],
  "settings": {
    "githubToken": {
      "type": "string",
      "default": "",
      "description": "GitHub personal access token"
    },
    "refreshInterval": {
      "type": "number",
      "default": 30,
      "description": "Refresh interval in seconds"
    }
  }
}
```

### Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier, must match directory name |
| `name` | Yes | Display name |
| `version` | Yes | Semantic versioning (x.y.z) |
| `description` | No | Brief description |
| `author` | No | Author name or handle |
| `license` | No | License identifier (MIT, GPL, etc.) |
| `repository` | No | Repository URL |
| `minNoctaliaVersion` | No | Minimum Noctalia version required |
| `category` | No | Plugin category for registry |
| `tags` | No | Search tags |
| `entryPoints` | Yes | Component file mappings |
| `dependencies` | No | Other required plugins |
| `settings` | No | Configurable plugin settings |

### Entry Points

The `entryPoints` object specifies which components your plugin provides. All are optional, but at least one is required.

```json
{
  "entryPoints": {
    "main": "Main.qml",           // Background logic
    "barWidget": "BarWidget.qml", // Bar widget
    "panel": "Panel.qml",         // Overlay panel
    "settings": "Settings.qml"    // Settings UI
  }
}
```

## Plugin Context

All plugin components have access to these context properties:

```qml
// Available in all plugin components
manifest          // Plugin manifest data object
currentLanguage   // Current UI language code (e.g., "en")
mainInstance      // Reference to instantiated Main.qml
barWidget         // Reference to bar widget Component
```

### Core Functions

```qml
// Save plugin settings to settings.json
saveSettings()

// Open plugin panel on specified screen
openPanel(screen)

// Close plugin panel on specified screen
closePanel(screen)

// Translation function
tr("key")
tr("key", { "name": "value" })  // With interpolations
```

## Bar Widget (BarWidget.qml)

Bar widgets are displayed in the Noctalia status bar.

### Basic Bar Widget

```qml
import QtQuick
import QtQuick.Layouts

// Root must be an Item or layout
Item {
    id: root

    // Required: specify size
    implicitWidth: layout.implicitWidth
    implicitHeight: 32

    // Allow user settings for this widget
    property bool allowUserSettings: true

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 8

        // Git branch icon
        Image {
            source: "assets/git-branch.svg"
            sourceSize: Qt.size(16, 16)
        }

        // Branch name
        Text {
            text: mainInstance?.currentBranch ?? "No repo"
            color: "#cdd6f4"
            font.pixelSize: 13
        }

        // Status indicator
        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: mainInstance?.hasChanges ? "#f38ba8" : "#a6e3a1"
        }
    }

    // Click to open panel
    MouseArea {
        anchors.fill: parent
        onClicked: openPanel(screen)
    }
}
```

### Widget with Settings

```qml
Item {
    id: root

    property bool allowUserSettings: true

    // User-configurable settings
    property bool showBranchName: true
    property bool showChangeCount: true

    // Settings are automatically saved when changed
    onShowBranchNameChanged: saveSettings()
    onShowChangeCountChanged: saveSettings()

    // Widget UI...
}
```

## Panel (Panel.qml)

Panels are full-screen overlays that slide in from screen edges.

### NPanel Base Component

All panels inherit from `NPanel`, which provides:
- Positioning and anchoring
- Slide animations
- Lifecycle management
- Registration with PanelService

### Basic Panel Structure

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qrc:/Widgets" as Widgets

Widgets.NPanel {
    id: panel

    // Panel identification (required for PanelService)
    objectName: "quick-git-panel"

    // Panel dimensions
    width: 400
    height: parent.height

    // Anchoring (determines slide direction)
    anchors.top: parent.top
    anchors.right: parent.right

    // Panel content
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Quick Git"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#cdd6f4"
                }

                Item { Layout.fillWidth: true }

                // Close button
                Button {
                    text: "Close"
                    onClicked: closePanel(screen)
                }
            }

            // Content area
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Git UI content here...
            }
        }
    }
}
```

### Slide Animations

Panel slide direction is determined by the panel's barycenter (center point) distance to each screen edge. For a panel anchored to the top-right, it will slide in from the right.

**Slide Direction Rules:**
- Panel closer to top edge: Slides from top
- Panel closer to right edge: Slides from right
- Floating panels: Use configured animation style

### Panel Lifecycle Signals

```qml
Widgets.NPanel {
    // Emitted when panel is about to open
    signal willOpenPanel()

    // Emitted when panel has closed
    signal closedPanel()

    Component.onCompleted: {
        // Panel registered with PanelService
    }

    Component.onDestruction: {
        // Panel unregistered
    }
}
```

### PanelService Integration

PanelService manages all panels and ensures:
- Only one panel open per screen at a time
- Automatic closing of current panel when new one opens
- Panel state coordination across screens

```qml
// Accessing PanelService (if needed)
// Available via qs.Services.UI

// From bar widget or main
openPanel(screen)   // Opens this plugin's panel
closePanel(screen)  // Closes this plugin's panel
```

## Main Component (Main.qml)

Background logic that runs independent of UI visibility.

### Main Component Structure

```qml
import QtQuick
import Quickshell.Io

Item {
    id: root

    // Exposed properties for other components
    property string currentBranch: ""
    property bool hasChanges: false
    property var stagedFiles: []
    property var unstagedFiles: []
    property var commits: []
    property var issues: []

    // IPC command handlers
    function handleCommand(command, args) {
        switch (command) {
            case "refresh":
                refreshGitStatus()
                return { success: true }
            case "stage":
                return stageFile(args.file)
            case "commit":
                return commit(args.message)
            default:
                return { error: "Unknown command" }
        }
    }

    // Git command execution
    Process {
        id: gitBranch
        command: ["git", "rev-parse", "--abbrev-ref", "HEAD"]

        stdout: StdioCollector {
            onCollected: text => {
                currentBranch = text.trim()
            }
        }
    }

    Process {
        id: gitStatus
        command: ["git", "status", "--porcelain"]

        stdout: SplitParser {
            onRead: line => {
                // Parse git status output
                const status = line.substring(0, 2)
                const file = line.substring(3)

                if (status[0] !== ' ' && status[0] !== '?') {
                    stagedFiles.push({ status: status[0], file: file })
                }
                if (status[1] !== ' ') {
                    unstagedFiles.push({ status: status[1], file: file })
                }
            }
        }

        onExited: {
            hasChanges = stagedFiles.length > 0 || unstagedFiles.length > 0
        }
    }

    function refreshGitStatus() {
        stagedFiles = []
        unstagedFiles = []
        gitBranch.running = true
        gitStatus.running = true
    }

    // Periodic refresh
    Timer {
        interval: manifest.settings?.refreshInterval * 1000 ?? 30000
        running: true
        repeat: true
        onTriggered: refreshGitStatus()
    }

    Component.onCompleted: {
        refreshGitStatus()
    }
}
```

### IPC Communication

Noctalia provides IPCService for external communication:

```bash
# Send command to plugin
qs ipc -c quick-git call refresh

# With arguments
qs ipc -c quick-git call stage --file="src/main.qml"
```

Handle in Main.qml:

```qml
function handleCommand(command, args) {
    // Process IPC commands
}
```

## Settings UI (Settings.qml)

User-configurable settings interface.

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: settings
    spacing: 12

    // GitHub Token
    Label {
        text: tr("github_token")
        color: "#cdd6f4"
    }

    TextField {
        Layout.fillWidth: true
        text: manifest.settings?.githubToken ?? ""
        echoMode: TextInput.Password
        placeholderText: tr("enter_token")

        onTextChanged: {
            manifest.settings.githubToken = text
            saveSettings()
        }
    }

    // Refresh Interval
    Label {
        text: tr("refresh_interval")
        color: "#cdd6f4"
    }

    SpinBox {
        from: 5
        to: 300
        value: manifest.settings?.refreshInterval ?? 30
        stepSize: 5

        onValueChanged: {
            manifest.settings.refreshInterval = value
            saveSettings()
        }
    }

    // Repository Path
    Label {
        text: tr("repository_path")
        color: "#cdd6f4"
    }

    RowLayout {
        Layout.fillWidth: true

        TextField {
            id: repoPath
            Layout.fillWidth: true
            text: manifest.settings?.repoPath ?? ""
            placeholderText: "/path/to/repo"
        }

        Button {
            text: tr("browse")
            onClicked: {
                // Open file dialog
            }
        }
    }
}
```

## Internationalization (i18n)

### Translation Files

Create JSON files in the `i18n/` directory:

```json
// i18n/en.json
{
  "plugin_name": "Quick Git",
  "branch": "Branch",
  "staged_files": "Staged Files",
  "unstaged_files": "Unstaged Files",
  "commit_message": "Commit Message",
  "commit": "Commit",
  "push": "Push",
  "pull": "Pull",
  "github_token": "GitHub Token",
  "refresh_interval": "Refresh Interval (seconds)",
  "no_changes": "No changes",
  "files_changed": "{{count}} files changed"
}
```

### Using Translations

```qml
Text {
    text: tr("branch")
}

Text {
    // With interpolation
    text: tr("files_changed", { "count": changedFiles.length })
}
```

## Quick-Git Plugin Design

Based on the requirements, here's the recommended architecture:

### Manifest

```json
{
  "id": "quick-git",
  "name": "Quick Git",
  "version": "1.0.0",
  "description": "Git management panel with GitHub integration",
  "author": "Your Name",
  "license": "MIT",
  "minNoctaliaVersion": "3.0.0",
  "category": "Development",
  "tags": ["git", "github", "version-control"],
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml",
    "settings": "Settings.qml"
  },
  "settings": {
    "githubToken": {
      "type": "string",
      "default": "",
      "secure": true
    },
    "defaultRepo": {
      "type": "string",
      "default": ""
    },
    "refreshInterval": {
      "type": "number",
      "default": 30
    }
  }
}
```

### Component Responsibilities

1. **Main.qml**
   - Git command execution (status, diff, log, stage, commit, push, pull)
   - GitHub API communication
   - OAuth device flow authentication
   - Issue fetching and management
   - Background refresh timer

2. **BarWidget.qml**
   - Branch name display
   - Change indicator (staged/unstaged count)
   - Click to open panel
   - Optional: GitHub notification badge

3. **Panel.qml**
   - Slide-down from top
   - Tabbed interface:
     - **Changes**: Staged/unstaged files, diff viewer
     - **History**: Commit tree visualization
     - **Issues**: GitHub issues with markdown support
     - **Settings**: Quick settings access
   - Commit form with message input
   - File staging/unstaging controls

4. **Settings.qml**
   - GitHub token configuration
   - Default repository path
   - Refresh interval
   - UI preferences

### Recommended File Structure

```
quick-git/
├── manifest.json
├── preview.png
├── Main.qml
├── BarWidget.qml
├── Panel.qml
├── Settings.qml
├── Components/
│   ├── DiffViewer.qml
│   ├── CommitTree.qml
│   ├── IssueList.qml
│   ├── IssueCard.qml
│   ├── MarkdownRenderer.qml
│   ├── FileList.qml
│   └── CommitForm.qml
├── Services/
│   ├── GitService.qml
│   └── GitHubService.qml
├── Assets/
│   └── icons/
├── i18n/
│   ├── en.json
│   └── es.json
└── README.md
```

## Installation & Testing

### Installing Plugins

Plugins are installed to:
```
~/.config/quickshell/noctalia/plugins/
```

Or via Nix:
```nix
{
  programs.noctalia = {
    enable = true;
    plugins = [ "quick-git" ];
  };
}
```

### Development Mode

For development, symlink your plugin:

```bash
ln -s /path/to/quick-git ~/.config/quickshell/noctalia/plugins/quick-git
```

Changes are hot-reloaded automatically.

### Testing

```bash
# Start Noctalia
qs -c noctalia

# Check plugin logs
journalctl --user -u noctalia -f

# Test IPC
qs ipc -c quick-git call refresh
```

## References

- [Noctalia Plugin Overview](https://docs.noctalia.dev/plugins/overview/)
- [Plugin Manifest Reference](https://docs.noctalia.dev/plugins/manifest/)
- [Getting Started Guide](https://docs.noctalia.dev/plugins/getting-started/)
- [Bar Configuration](https://docs.noctalia.dev/configuration/bar/)
- [Control Center Documentation](https://docs.noctalia.dev/configuration/controlcenter/)
- [Noctalia GitHub Repository](https://github.com/noctalia-dev/noctalia-shell)
- [Plugin Registry](https://noctalia.dev/plugins)
