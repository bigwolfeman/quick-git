# Implementation Plan: Quick-Git Noctalia Plugin

**Branch**: `001-quick-git-plugin` | **Date**: 2026-01-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-quick-git-plugin/spec.md`

## Summary

Build a Noctalia plugin that provides a slide-down panel for Git repository management and GitHub issue tracking. The plugin includes a bar widget showing repository status at a glance, a dual-view panel (Issues/Commits) with full staging/committing/diffing capabilities, GitHub OAuth device flow authentication, and colorblind-friendly accessibility options.

## Technical Context

**Language/Version**: QML (Qt 6) + JavaScript ES6
**Primary Dependencies**: Quickshell, Noctalia Plugin API, Quickshell.Io (Process execution)
**Storage**: JSON files via Quickshell.statePath() for settings, system keyring for tokens (optional)
**Testing**: Manual QML testing, git command verification scripts
**Target Platform**: Linux (Wayland) - Hyprland, Niri, Sway, labwc
**Project Type**: Noctalia plugin (QML-based desktop shell extension)
**Performance Goals**: Panel opens <500ms, status refresh <1s, smooth scrolling with 100+ items
**Constraints**: Must work offline for local git operations, GitHub features require network
**Scale/Scope**: Single-user desktop application, manages multiple local repositories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Status**: Template placeholder - no project-specific gates defined yet.

Applying general software engineering principles:
- [x] **Simplicity**: Plugin follows Noctalia's standard structure (manifest.json, entry points)
- [x] **Testability**: Git operations can be verified via command output
- [x] **Separation of Concerns**: Services (GitService, GitHubService) separate from UI components
- [x] **Accessibility**: Colorblind-friendly mode is a core requirement, not an afterthought

No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/001-quick-git-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal service contracts)
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
quick-git/
├── manifest.json           # Plugin metadata
├── preview.png             # Preview image for registry
├── Main.qml                # Background logic, service initialization
├── BarWidget.qml           # Status indicator in Noctalia bar
├── Panel.qml               # Slide-down panel container
├── Settings.qml            # User preferences UI
├── settings.json           # User settings data (auto-generated)
├── Components/
│   ├── IssuesView.qml      # GitHub issues list and detail view
│   ├── CommitsView.qml     # Staging, files, commit UI
│   ├── DiffViewer.qml      # Inline diff display
│   ├── IssueEditor.qml     # Issue create/edit/comment form
│   ├── RepoSelector.qml    # Repository dropdown
│   └── StatusIndicator.qml # Colorblind-friendly status icons
├── Services/
│   ├── GitService.qml      # Singleton: git command execution
│   ├── GitHubService.qml   # Singleton: GitHub API + OAuth
│   └── SettingsService.qml # Singleton: user preferences
├── i18n/
│   └── en.json             # English translations
├── Assets/
│   └── icons/              # Status icons, GitHub logo
└── docs/                   # Reference documentation (already created)
    ├── quickshell.md
    ├── noctalia-plugins.md
    └── github-api.md
```

**Structure Decision**: Standard Noctalia plugin structure with Services/ for QML singletons and Components/ for reusable UI elements. No backend server needed - all logic runs in the Quickshell process.

## Complexity Tracking

No violations requiring justification. The plugin follows Noctalia's standard patterns without introducing unnecessary complexity.

## Research Areas (Phase 0)

1. **QML Singleton Pattern**: Best practices for GitService/GitHubService state management
2. **Process Execution**: Quickshell.Io.Process for git commands, stdout parsing
3. **OAuth Device Flow**: Token polling, secure storage options
4. **Markdown Rendering**: QML options for rendering GitHub-flavored markdown
5. **File System Watching**: Auto-refresh when repository files change
6. **Diff Parsing**: git diff output format, syntax highlighting approach
