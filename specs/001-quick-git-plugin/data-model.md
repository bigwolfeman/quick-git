# Quick-Git Data Model

> Entity definitions for the Quick-Git Noctalia plugin

---

## Core Entities

### Repository

Represents a local git repository being managed by the plugin.

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Absolute filesystem path to repository root |
| `name` | string | Display name (derived from directory name) |
| `branch` | string | Current branch name |
| `remote` | string? | GitHub remote URL (if configured) |
| `owner` | string? | GitHub owner (parsed from remote) |
| `repo` | string? | GitHub repo name (parsed from remote) |
| `lastAccessed` | timestamp | When repository was last selected |

**Relationships:**
- Has one GitStatus (current state)
- Has many Issues (if GitHub remote configured)

**Validation:**
- `path` must exist and contain `.git/` directory
- `branch` updates on file system watch trigger

---

### GitStatus

Current working tree state of a repository.

| Field | Type | Description |
|-------|------|-------------|
| `staged` | FileChange[] | Files staged for commit |
| `unstaged` | FileChange[] | Modified files not staged |
| `untracked` | FileChange[] | New files not tracked |
| `ahead` | number | Commits ahead of remote |
| `behind` | number | Commits behind remote |
| `hasConflicts` | boolean | Merge conflicts present |
| `isClean` | boolean | No changes (derived) |

**Derived Properties:**
- `isClean` = staged.length === 0 && unstaged.length === 0 && untracked.length === 0
- `statusIcon` = derived from state (checkmark/half-circle/triangle/warning)

---

### FileChange

A single file that has been modified, staged, or is untracked.

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path from repository root |
| `status` | enum | `modified`, `added`, `deleted`, `renamed`, `copied`, `untracked` |
| `staged` | boolean | Whether file is in staging area |
| `hasConflict` | boolean | Has merge conflict markers |
| `oldPath` | string? | Previous path (for renames) |

**State Transitions:**
```
untracked → staged (git add)
unstaged → staged (git add)
staged → unstaged (git reset)
staged → committed (git commit)
```

---

### Diff

Diff information for a single file.

| Field | Type | Description |
|-------|------|-------------|
| `filePath` | string | Path to file |
| `hunks` | DiffHunk[] | List of diff hunks |
| `additions` | number | Total lines added |
| `deletions` | number | Total lines removed |
| `isBinary` | boolean | Binary file (no diff available) |
| `isTooLarge` | boolean | Diff exceeds size limit |

---

### DiffHunk

A single hunk within a diff (contiguous change region).

| Field | Type | Description |
|-------|------|-------------|
| `header` | string | Hunk header line (e.g., `@@ -1,3 +1,4 @@`) |
| `oldStart` | number | Starting line in old file |
| `oldCount` | number | Number of lines in old file |
| `newStart` | number | Starting line in new file |
| `newCount` | number | Number of lines in new file |
| `lines` | DiffLine[] | Individual diff lines |

---

### DiffLine

A single line within a diff hunk.

| Field | Type | Description |
|-------|------|-------------|
| `type` | enum | `add`, `remove`, `context` |
| `content` | string | Line content (without leading +/-/space) |
| `oldLineNumber` | number? | Line number in old file |
| `newLineNumber` | number? | Line number in new file |

---

### Issue

A GitHub issue associated with a repository.

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | GitHub issue ID |
| `number` | number | Issue number (for display, e.g., #42) |
| `title` | string | Issue title |
| `body` | string | Issue body (markdown) |
| `state` | enum | `open`, `closed` |
| `stateReason` | enum? | `completed`, `not_planned`, `reopened` |
| `author` | User | Issue creator |
| `labels` | Label[] | Assigned labels |
| `assignees` | User[] | Assigned users |
| `comments` | Comment[] | Issue comments |
| `commentsCount` | number | Total comment count |
| `createdAt` | timestamp | Creation date |
| `updatedAt` | timestamp | Last update date |
| `closedAt` | timestamp? | Close date (if closed) |
| `htmlUrl` | string | GitHub web URL |

**Validation:**
- `title` is required, non-empty
- `number` is unique within repository

---

### Comment

A comment on a GitHub issue.

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | GitHub comment ID |
| `body` | string | Comment body (markdown) |
| `author` | User | Comment author |
| `createdAt` | timestamp | Creation date |
| `updatedAt` | timestamp | Last edit date |
| `authorAssociation` | enum | `OWNER`, `COLLABORATOR`, `CONTRIBUTOR`, `MEMBER`, `NONE` |

---

### User

A GitHub user (author, assignee, etc.).

| Field | Type | Description |
|-------|------|-------------|
| `login` | string | GitHub username |
| `id` | number | GitHub user ID |
| `avatarUrl` | string | URL to avatar image |

---

### Label

A GitHub issue label.

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | Label ID |
| `name` | string | Label name |
| `color` | string | Hex color (without #) |
| `description` | string? | Label description |

---

### AuthToken

GitHub OAuth authentication credentials.

| Field | Type | Description |
|-------|------|-------------|
| `accessToken` | string | OAuth access token |
| `tokenType` | string | Token type (always "bearer") |
| `scope` | string | Granted scopes (e.g., "repo,user") |
| `username` | string | Authenticated user's login |
| `avatarUrl` | string | User's avatar URL |
| `expiresAt` | timestamp? | Expiration (usually null for GitHub) |

**Secure Storage:**
- Token stored via `secret-tool` (libsecret)
- Never persisted in plain text files

---

### UserPreferences

User settings persisted between sessions.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `colorblindMode` | boolean | `false` | Enable colorblind-friendly indicators |
| `colorblindPalette` | enum | `shapes` | `shapes`, `highcontrast`, `deuteranopia`, `protanopia` |
| `recentRepos` | string[] | `[]` | Recently accessed repository paths |
| `maxRecentRepos` | number | `10` | Maximum recent repos to remember |
| `refreshInterval` | number | `30` | Auto-refresh interval in seconds |
| `defaultView` | enum | `commits` | `commits`, `issues` |

**Storage:**
- Persisted via `Quickshell.statePath("settings.json")`
- Loaded on plugin initialization

---

## Enums Reference

### FileStatus
```
modified  - File content changed
added     - New file staged
deleted   - File removed
renamed   - File moved/renamed
copied    - File copied
untracked - New file not tracked
```

### IssueState
```
open   - Issue is open
closed - Issue is closed
```

### IssueStateReason
```
completed   - Closed as resolved
not_planned - Closed as won't fix
reopened    - Reopened after closing
```

### DiffLineType
```
add     - Line added (green, +)
remove  - Line removed (red, -)
context - Unchanged line (gray, space)
```

### ColorblindPalette
```
shapes       - Shapes + text labels (recommended)
highcontrast - High contrast colors
deuteranopia - Red-green colorblind optimized
protanopia   - Red colorblind optimized
```

### AuthorAssociation
```
OWNER        - Repository owner
COLLABORATOR - Has push access
CONTRIBUTOR  - Has contributed
MEMBER       - Organization member
NONE         - No special association
```

---

## State Diagrams

### Repository Status Flow

```
┌─────────────────────────────────────────────────┐
│                    CLEAN                        │
│            (isClean: true)                      │
└─────────────────────────────────────────────────┘
        │ file modified            │ git pull
        ▼                          ▼
┌─────────────────────────────────────────────────┐
│                  MODIFIED                       │
│    (unstaged.length > 0 || untracked > 0)      │
└─────────────────────────────────────────────────┘
        │ git add                  │ git checkout
        ▼                          │
┌─────────────────────────────────────────────────┐
│                   STAGED                        │
│            (staged.length > 0)                  │
└─────────────────────────────────────────────────┘
        │ git commit               │ git reset
        ▼                          │
┌─────────────────────────────────────────────────┐
│                   AHEAD                         │
│              (ahead > 0)                        │
└─────────────────────────────────────────────────┘
        │ git push
        ▼
┌─────────────────────────────────────────────────┐
│                    CLEAN                        │
└─────────────────────────────────────────────────┘
```

### Issue State Flow

```
         ┌─────────┐
         │  OPEN   │
         └────┬────┘
              │
    ┌─────────┼─────────┐
    ▼         │         ▼
completed  not_planned  reopened
    │         │         │
    └─────────┴─────────┘
              │
              ▼
         ┌─────────┐
         │ CLOSED  │
         └─────────┘
              │
              │ reopen
              ▼
         ┌─────────┐
         │  OPEN   │
         └─────────┘
```
