# Quick-Git Plugin Quickstart Guide

> Get the Quick-Git Noctalia plugin running in 5 minutes

---

## Prerequisites

- **Noctalia** 3.0.0+ installed and running
- **git** installed and configured
- **secret-tool** (libsecret) for secure token storage
- **curl** for HTTP requests

Check prerequisites:
```bash
noctalia --version  # Should show 3.0.0+
git --version
which secret-tool
which curl
```

---

## Installation

### Option 1: From Plugin Registry (Recommended)

```bash
noctalia plugin install quick-git
```

### Option 2: Manual Installation

```bash
# Clone to Noctalia plugins directory
git clone https://github.com/your-username/quick-git \
  ~/.config/noctalia/plugins/quick-git

# Restart Noctalia to load plugin
noctalia reload
```

---

## First Run

1. **Enable the plugin** in Noctalia settings
2. **Look for the git icon** in your bar
3. **Click the icon** to open the Quick-Git panel

---

## GitHub Authentication

To use GitHub features (issues, remote status):

1. Click the **GitHub octopus icon** in the panel
2. Copy the **8-character code** displayed
3. Visit **github.com/login/device** in your browser
4. Enter the code and authorize Quick-Git
5. Panel shows "Connected as @yourusername"

**Scopes requested**: `repo` (repository access), `user` (profile info)

---

## Basic Usage

### Check Repository Status

The bar widget shows your current repo state:
- ✓ **Clean** - No uncommitted changes
- ◐ **Modified** - Unstaged changes present
- ▲ **Ahead** - Commits ready to push

Hover for tooltip: branch name, file count, ahead/behind.

### Stage and Commit

1. Open panel → **Commits** view (default)
2. See files grouped: **Staged** / **Unstaged** / **Untracked**
3. Click **[+]** to stage a file
4. Enter commit message
5. Click **[Commit]**

### View Diffs

Click **[▼]** on any file to expand inline diff:
- Green lines = additions
- Red lines = deletions

### Manage Issues

1. Authenticate with GitHub (see above)
2. Toggle to **Issues** view
3. Click **[▼]** on an issue to expand
4. Add comments, close, or create new issues

---

## Settings

Access settings from the **gear icon** in the panel:

| Setting | Description |
|---------|-------------|
| Colorblind Mode | Enable shape+label indicators |
| Palette | Choose accessibility color scheme |
| Refresh Interval | How often to check for changes |
| Default View | Issues or Commits |

---

## Keyboard Shortcuts

Configure in Noctalia settings:

| Action | Suggested Binding |
|--------|-------------------|
| Toggle panel | `Super+G` |
| Refresh | `Ctrl+R` (when panel focused) |
| Commit | `Ctrl+Enter` (with message focused) |

---

## File Structure

```
~/.config/noctalia/plugins/quick-git/
├── manifest.json       # Plugin metadata
├── Main.qml            # Background services
├── BarWidget.qml       # Status indicator
├── Panel.qml           # Slide-down panel
├── Settings.qml        # Preferences UI
├── Components/         # Reusable UI components
├── Services/           # GitService, GitHubService, SettingsService
└── Assets/             # Icons
```

Settings stored at: `~/.local/state/quickshell/quick-git/settings.json`

---

## Troubleshooting

### "Not a git repository"

The current directory isn't a git repo. Use the repo dropdown to select a valid repository.

### "Session expired"

GitHub token needs refresh. Click the auth icon to re-authenticate.

### "Rate limited"

GitHub API limit reached. Wait for the reset time shown in the error message.

### Panel won't open

1. Check Noctalia logs: `journalctl --user -u noctalia`
2. Verify plugin is enabled in Noctalia settings
3. Try `noctalia reload`

### Token not saving

Ensure `secret-tool` and GNOME Keyring (or compatible) are working:
```bash
echo "test" | secret-tool store --label="Test" app test-app
secret-tool lookup app test-app
```

---

## Development

### Run with debug logging

```bash
QT_LOGGING_RULES="quick-git.*=true" noctalia
```

### Live reload

Quickshell auto-reloads QML files on save. Make changes and see them immediately.

### Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

---

## Links

- [Feature Specification](./spec.md)
- [Implementation Plan](./plan.md)
- [Data Model](./data-model.md)
- [API Contracts](./contracts/)
- [Quickshell Documentation](https://quickshell.org/docs/)
- [Noctalia Plugin Guide](https://docs.noctalia.dev/plugins)
