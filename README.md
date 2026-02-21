🛑 This project is under development 🛑
# Quick Git

Git management panel with GitHub integration for Noctalia. View repository status at a glance, stage and commit changes, review diffs, and manage GitHub issues - all from a slide-down panel without leaving your workflow.

## Features

- **Repository Status**: View branch status, ahead/behind counts, and change indicators at a glance
- **Git Operations**: Stage, unstage, commit, push, and pull directly from the panel
- **Diff Viewer**: Review file changes with syntax highlighting and inline diffs
- **GitHub Integration**: Manage issues, create/edit issues, and view repository information
- **Multi-Repository Support**: Switch between different git repositories easily
- **Accessibility**: Colorblind-friendly indicators with shapes and text labels
- **Keyboard Shortcuts**: Full keyboard navigation support

## Requirements

- Noctalia 3.0.0+
- git
- secret-tool (libsecret) for secure token storage
- curl for HTTP requests

## Installation

### From Plugin Registry (Recommended)

```bash
noctalia plugin install quick-git
```

### Manual Installation

```bash
git clone https://github.com/bigwolfeman/quick-git \
  ~/.config/noctalia/plugins/quick-git

noctalia reload
```

## Configuration

The plugin can be configured through Noctalia's settings interface. Key settings include:

- **Colorblind Mode**: Enable colorblind-friendly indicators
- **Refresh Interval**: How often to refresh repository status (default: 30 seconds)
- **Default View**: Choose between Commits or Issues view
- **GitHub Token**: Securely store your GitHub OAuth token for issue management

## Usage

1. Enable the plugin in Noctalia settings
2. Look for the git icon in your bar
3. Click the icon to open the Quick-Git panel
4. Select a repository or let it auto-detect from your current directory
5. Use the panel to manage your git operations and GitHub issues

## Keyboard Shortcuts

See the [Quickstart Guide](specs/001-quick-git-plugin/quickstart.md) for detailed keyboard shortcuts and usage instructions.

## Development

This is a Noctalia plugin built with QML/Qt. See the [specification](specs/001-quick-git-plugin/spec.md) for architecture details.

## License

MIT

## Author

Quick-Git Contributors
