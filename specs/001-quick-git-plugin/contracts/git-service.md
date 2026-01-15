# GitService Contract

> Internal service contract for local git operations

## Overview

`GitService` is a QML Singleton that manages local git repository state and operations. It executes git commands via `Quickshell.Io.Process` and exposes reactive properties for UI binding.

---

## Properties (Reactive)

| Property | Type | Description |
|----------|------|-------------|
| `repoPath` | string | Current repository path |
| `branch` | string | Current branch name |
| `isRepo` | boolean | Whether path is a valid git repo |
| `status` | GitStatus | Current repository status |
| `isRefreshing` | boolean | Refresh operation in progress |
| `lastRefresh` | timestamp | When status was last updated |
| `error` | string | Last error message (empty if none) |

---

## Methods

### refresh()

Refresh repository status from git.

**Triggers**: File watch, timer, manual refresh
**Side Effects**: Updates `status`, `branch`, `isRefreshing`, `lastRefresh`

```
Input: none
Output: none (updates reactive properties)
Errors: Sets `error` property if git command fails
```

---

### setRepository(path: string)

Switch to a different repository.

```
Input:  path - Absolute path to repository root
Output: boolean - true if valid git repository
Errors: Sets `error` if path is not a git repo
```

**Side Effects**:
- Updates `repoPath`, clears `status`
- Adds to recent repos in SettingsService
- Triggers `refresh()`

---

### stage(filePath: string)

Stage a file for commit.

```
Input:  filePath - Relative path from repo root
Output: boolean - true on success
Git:    git add <filePath>
```

**Side Effects**: Triggers `refresh()` on completion

---

### unstage(filePath: string)

Remove a file from staging area.

```
Input:  filePath - Relative path from repo root
Output: boolean - true on success
Git:    git reset HEAD <filePath>
```

**Side Effects**: Triggers `refresh()` on completion

---

### stageAll()

Stage all modified and untracked files.

```
Input:  none
Output: boolean - true on success
Git:    git add -A
```

**Side Effects**: Triggers `refresh()` on completion

---

### commit(message: string)

Create a commit with staged files.

```
Input:  message - Commit message (non-empty)
Output: string - Commit SHA on success, empty on failure
Git:    git commit -m "<message>"
```

**Validation**:
- Message must be non-empty
- Must have staged files

**Side Effects**: Triggers `refresh()` on completion

---

### push()

Push local commits to remote.

```
Input:  none
Output: boolean - true on success
Git:    git push
```

**Preconditions**:
- Must have commits ahead of remote
- Must have remote configured

---

### getDiff(filePath: string): Diff

Get diff for a specific file.

```
Input:  filePath - Relative path from repo root
Output: Diff object (see data-model.md)
Git:    git diff <filePath> (unstaged)
        git diff --cached <filePath> (staged)
```

---

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `statusChanged` | none | Repository status updated |
| `branchChanged` | string newBranch | Branch switched |
| `commitCreated` | string sha | New commit created |
| `errorOccurred` | string message | Operation failed |

---

## Git Commands Used

| Operation | Command |
|-----------|---------|
| Check repo | `git rev-parse --git-dir` |
| Get branch | `git rev-parse --abbrev-ref HEAD` |
| Get status | `git status --porcelain` |
| Ahead/behind | `git rev-list --left-right --count HEAD...@{u}` |
| Stage file | `git add <path>` |
| Unstage | `git reset HEAD <path>` |
| Stage all | `git add -A` |
| Commit | `git commit -m "<message>"` |
| Push | `git push` |
| Diff (unstaged) | `git diff <path>` |
| Diff (staged) | `git diff --cached <path>` |

---

## Error Handling

| Error Code | Condition | User Message |
|------------|-----------|--------------|
| `NOT_A_REPO` | Path has no `.git/` | "Not a git repository" |
| `COMMAND_FAILED` | git exits non-zero | Git stderr message |
| `NO_STAGED_FILES` | Commit with nothing staged | "No files staged for commit" |
| `EMPTY_MESSAGE` | Commit with empty message | "Commit message required" |
| `NO_REMOTE` | Push with no upstream | "No remote configured" |
| `PUSH_REJECTED` | Remote rejected push | "Push rejected - pull first" |
