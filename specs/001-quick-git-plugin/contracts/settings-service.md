# SettingsService Contract

> Internal service contract for user preferences management

## Overview

`SettingsService` is a QML Singleton that manages user preferences. Settings are persisted to `Quickshell.statePath("settings.json")` and loaded on plugin initialization.

---

## Properties (Reactive)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `colorblindMode` | boolean | `false` | Enable colorblind-friendly indicators |
| `colorblindPalette` | string | `"shapes"` | Selected accessibility palette |
| `recentRepos` | string[] | `[]` | Recently accessed repository paths |
| `maxRecentRepos` | number | `10` | Maximum repos to remember |
| `refreshInterval` | number | `30` | Auto-refresh interval (seconds) |
| `defaultView` | string | `"commits"` | Default panel view |
| `isLoaded` | boolean | `false` | Settings have been loaded |

---

## Methods

### load()

Load settings from disk.

```
Input:  none
Output: boolean - true if loaded successfully

File: Quickshell.statePath("settings.json")
```

**Side Effects**:
- Updates all reactive properties
- Sets `isLoaded` to `true`
- Creates default file if not exists

---

### save()

Persist settings to disk.

```
Input:  none
Output: boolean - true if saved successfully
```

**Note**: Called automatically when settings change (debounced 500ms)

---

### setColorblindMode(enabled: boolean)

Enable or disable colorblind mode.

```
Input:  enabled - true to enable
Output: none
```

**Side Effects**: Triggers `save()`

---

### setColorblindPalette(palette: string)

Set the colorblind palette.

```
Input:  palette - "shapes" | "highcontrast" | "deuteranopia" | "protanopia"
Output: none
```

**Validation**: Must be valid palette name

---

### addRecentRepo(path: string)

Add a repository to recent list.

```
Input:  path - Absolute repository path
Output: none
```

**Behavior**:
- Moves to front if already in list
- Removes oldest if exceeds `maxRecentRepos`
- Validates path exists

---

### removeRecentRepo(path: string)

Remove a repository from recent list.

```
Input:  path - Repository path to remove
Output: boolean - true if found and removed
```

---

### clearRecentRepos()

Clear all recent repositories.

```
Input:  none
Output: none
```

---

### setRefreshInterval(seconds: number)

Set auto-refresh interval.

```
Input:  seconds - Interval in seconds (5-300)
Output: none
```

**Validation**: Clamped to range [5, 300]

---

### setDefaultView(view: string)

Set default panel view.

```
Input:  view - "commits" | "issues"
Output: none
```

---

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `loaded` | none | Settings loaded from disk |
| `saved` | none | Settings saved to disk |
| `colorblindModeChanged` | boolean enabled | Colorblind mode toggled |
| `recentReposChanged` | none | Recent repos list changed |

---

## File Format

```json
{
  "version": 1,
  "colorblindMode": false,
  "colorblindPalette": "shapes",
  "recentRepos": [
    "/home/user/projects/quick-git",
    "/home/user/projects/other-repo"
  ],
  "maxRecentRepos": 10,
  "refreshInterval": 30,
  "defaultView": "commits"
}
```

---

## Migration

If `version` field is missing or lower than current:
1. Apply default values for new fields
2. Update `version` to current
3. Save immediately

---

## Error Handling

| Error | Condition | Recovery |
|-------|-----------|----------|
| File not found | First run | Create with defaults |
| Parse error | Corrupted JSON | Reset to defaults, warn user |
| Write error | Disk full/permissions | Keep in-memory, retry later |
