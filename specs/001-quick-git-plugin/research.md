# Quick-Git Plugin Technical Research

> Research findings for Noctalia/Quickshell Git management plugin

---

## 1. QML Singleton Pattern in Quickshell

### Decision

Use `pragma Singleton` with `Singleton {}` wrapper as documented in Quickshell. Create a `GitService.qml` singleton for shared state and a `GitHubService.qml` singleton for API operations.

### Rationale

Quickshell provides native singleton support through its `Singleton` type, which integrates with its lifecycle management. This approach:

- Ensures single instance across the entire shell
- Provides reactive property bindings that automatically update UI
- Follows the established pattern used by other Noctalia plugins
- Avoids the need for manual instance management

The documented pattern from `quickshell.md` shows:

```qml
// GitService.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property string branch: ""
    property var stagedFiles: []
    property var unstagedFiles: []
    property bool isRepo: false

    function refresh() { /* ... */ }
    function stage(file) { /* ... */ }
    function commit(message) { /* ... */ }
}
```

Usage from any component:
```qml
import "." as Root

Text {
    text: Root.GitService.branch
}
```

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Qt's `qmlRegisterSingletonType` | Requires C++ registration; overkill for pure-QML plugin |
| Global properties via `QtObject` | No lifecycle management; doesn't integrate with Quickshell's architecture |
| Passing state via context properties | More complex wiring; harder to maintain |

---

## 2. Process Execution with Quickshell.Io

### Decision

Use `Process` type with `StdioCollector` for single-output commands (branch name, commit SHA) and `SplitParser` for line-by-line output (status, log, diff).

### Rationale

Quickshell.Io provides two parsing strategies optimized for different use cases:

**StdioCollector** - Best for commands returning complete output:
```qml
Process {
    id: gitBranch
    command: ["git", "rev-parse", "--abbrev-ref", "HEAD"]

    stdout: StdioCollector {
        onCollected: text => {
            currentBranch = text.trim()
        }
    }

    onExited: (exitCode, exitStatus) => {
        if (exitCode !== 0) {
            console.error("Git command failed")
        }
    }
}
```

**SplitParser** - Best for streaming line-by-line output:
```qml
Process {
    id: gitStatus
    command: ["git", "status", "--porcelain"]

    stdout: SplitParser {
        onRead: line => {
            // Parse each status line incrementally
            const status = line.substring(0, 2)
            const file = line.substring(3)
            // Process file...
        }
    }
}
```

**Async Pattern:**
- Set `running: true` to start process
- Connect to `onExited` for completion handling
- Use Timer for periodic refresh

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| `Qt.exec()` / synchronous calls | Blocks UI thread; poor UX |
| `Quickshell.execDetached()` | No output capture; for fire-and-forget only |
| Custom C++ process wrapper | Unnecessary complexity; native solution exists |

---

## 3. OAuth Device Flow Implementation

### Decision

Implement OAuth Device Flow using `Process` + `curl` for HTTP requests, `Timer` for polling, and `secret-tool` (libsecret) for secure token storage.

### Rationale

**Device Flow Implementation:**

The OAuth Device Flow is ideal for desktop applications because:
- No redirect URL required (no embedded web server)
- No client secret needed (safer for distributed apps)
- User authenticates in their browser (familiar flow)

Implementation pattern from `github-api.md`:

```qml
// Step 1: Request device code
Process {
    id: deviceCodeRequest
    command: ["curl", "-s", "-X", "POST",
        "-H", "Accept: application/json",
        "-H", "Content-Type: application/json",
        "-d", JSON.stringify({
            client_id: "YOUR_CLIENT_ID",
            scope: "repo user"
        }),
        "https://github.com/login/device/code"
    ]
    stdout: StdioCollector { /* parse response */ }
}

// Step 2: Poll for token at `interval` seconds
Timer {
    id: pollTimer
    interval: pollInterval * 1000
    repeat: true
    onTriggered: tokenRequest.running = true
}
```

**Token Storage with secret-tool:**

```qml
// Store token
Process {
    command: ["secret-tool", "store",
        "--label=Quick-Git GitHub Token",
        "application", "quick-git",
        "type", "github-token"
    ]
    stdin: token  // Pass token via stdin
}

// Retrieve token
Process {
    command: ["secret-tool", "lookup",
        "application", "quick-git",
        "type", "github-token"
    ]
    stdout: StdioCollector {
        onCollected: text => { accessToken = text.trim() }
    }
}
```

**Token Refresh:**

GitHub OAuth tokens don't expire by default, but can be revoked. Handle gracefully:
- Check for 401 responses on API calls
- Clear stored token and prompt re-authentication
- Consider implementing token validation on startup

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Plain file storage (`~/.config/quick-git/token`) | Insecure; token stored in plaintext |
| KWallet | KDE-specific; secret-tool works across DEs |
| Environment variable | Not persistent; user must set manually |
| In-memory only | Lost on restart; poor UX |
| OAuth web redirect flow | Requires embedded server; more complex |

---

## 4. Markdown Rendering in QML

### Decision

Use Qt's native `TextEdit.MarkdownText` format for rendering markdown in issue bodies and comments. This provides CommonMark + GitHub extensions support without external dependencies.

### Rationale

Since Qt 5.14, QML Text and TextEdit support markdown natively:

```qml
TextEdit {
    textFormat: TextEdit.MarkdownText
    text: issueBody
    readOnly: true
    wrapMode: Text.Wrap
    color: "#cdd6f4"
}
```

**Supported Features (CommonMark + GitHub):**
- Headers, bold, italic, strikethrough
- Code blocks (monospace font)
- Links (clickable with `onLinkActivated`)
- Lists (ordered and unordered)
- Tables (GitHub extension)
- Task lists with checkboxes (GitHub extension)
- Block quotes (indented)

**Limitations:**
- Code blocks use default monospace without syntax highlighting
- No surrounding highlight box for inline code
- Block quotes show indentation but no vertical line
- Cannot interactively type markdown (render-only)

**For diff/code display**, syntax highlighting requires additional work (see Section 6).

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| WebView + HTML rendering | Heavy dependency; overkill for panel widget |
| External markdown library | Additional dependency; Qt native is sufficient |
| Custom markdown parser | Reinventing the wheel; fragile |
| TextArea.RichText + manual conversion | More complex; less feature-complete |
| `application/vnd.github.html+json` (pre-rendered) | Requires HTML rendering; still need WebView |

---

## 5. File System Watching

### Decision

Use Quickshell's `FileView` with `watchChanges: true` for specific files (e.g., `.git/HEAD`, `.git/index`), combined with a Timer-based polling fallback for git status.

### Rationale

**FileView with watchChanges:**

Quickshell provides `FileView` in `Quickshell.Io` which supports file change monitoring:

```qml
import Quickshell.Io

FileView {
    id: gitHead
    path: repoPath + "/.git/HEAD"
    watchChanges: true

    onFileChanged: {
        // Branch changed, refresh status
        GitService.refresh()
    }
}
```

**Hybrid Approach:**

1. **Watch `.git/HEAD`** - Detects branch switches
2. **Watch `.git/index`** - Detects staging area changes
3. **Timer polling** - Catches working directory changes not reflected in git internals

```qml
// Fallback polling for working directory changes
Timer {
    interval: manifest.settings?.refreshInterval * 1000 ?? 30000
    running: true
    repeat: true
    onTriggered: GitService.refresh()
}
```

**Why Hybrid:**
- File watchers are efficient but can miss transient changes
- Git operations modify multiple files atomically
- Timer provides reliable baseline; watchers provide responsiveness

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Pure QFileSystemWatcher | Not exposed to QML in Quickshell; requires C++ |
| Watch entire `.git/` directory | Too noisy; many files change during operations |
| Timer-only polling | Less responsive; misses immediate changes |
| `inotifywait` via Process | External dependency; complex signal handling |
| Polling `.git/` directory mtime | Hacky; filesystem-dependent |

---

## 6. Git Diff Parsing

### Decision

Parse unified diff format manually with regex, apply inline styling for additions/deletions, and use monospace font without full syntax highlighting for initial version.

### Rationale

**Unified Diff Format Structure:**

```
diff --git a/file.txt b/file.txt
index abc123..def456 100644
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,4 @@
 unchanged line
-removed line
+added line
+another added line
 unchanged line
```

**Parsing Approach:**

```javascript
function parseDiff(diffText) {
    const lines = diffText.split('\n')
    const hunks = []
    let currentHunk = null

    for (const line of lines) {
        if (line.startsWith('@@')) {
            // Hunk header: @@ -start,count +start,count @@
            currentHunk = { header: line, lines: [] }
            hunks.push(currentHunk)
        } else if (currentHunk) {
            const type = line[0] === '+' ? 'add' :
                        line[0] === '-' ? 'remove' : 'context'
            currentHunk.lines.push({ type, content: line.substring(1) })
        }
    }
    return hunks
}
```

**Display with Inline Styling:**

```qml
ListView {
    model: diffLines
    delegate: Rectangle {
        width: parent.width
        height: lineText.height
        color: modelData.type === 'add' ? "#1a3d1a" :
               modelData.type === 'remove' ? "#3d1a1a" : "transparent"

        Text {
            id: lineText
            text: modelData.content
            font.family: "monospace"
            color: modelData.type === 'add' ? "#a6e3a1" :
                   modelData.type === 'remove' ? "#f38ba8" : "#cdd6f4"
        }
    }
}
```

**Syntax Highlighting (Future Enhancement):**

For full syntax highlighting, consider:
1. Shell out to `delta` or `bat` for pre-colored output (ANSI codes)
2. Use a JavaScript syntax highlighter library (Prism.js, highlight.js)
3. Parse ANSI escape codes and map to QML colors

For MVP, monospace + add/remove colors is sufficient and keeps dependencies minimal.

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Use `git diff --color` + ANSI parsing | Complex ANSI parsing; limited color control |
| External highlighter (delta, bat) | Extra dependency; output parsing overhead |
| WebView with highlight.js | Heavy; overkill for diff panel |
| Pre-render to HTML | Still need HTML renderer |
| TreeSitter/language servers | Very heavy; not justified for diff viewer |

---

## Summary of Technical Decisions

| Topic | Decision | Key Dependency |
|-------|----------|----------------|
| Singleton Pattern | `pragma Singleton` + `Singleton {}` | Quickshell native |
| Process Execution | `Process` + `SplitParser`/`StdioCollector` | Quickshell.Io |
| OAuth Flow | Device flow + `curl` + `Timer` polling | GitHub API |
| Token Storage | `secret-tool` (libsecret) | System keyring |
| Markdown Rendering | `TextEdit.MarkdownText` | Qt 5.14+ native |
| File Watching | `FileView.watchChanges` + Timer polling | Quickshell.Io |
| Diff Parsing | Manual unified diff parser + inline styles | None (pure JS) |

---

## References

### Quickshell
- [Quickshell Documentation](https://quickshell.org/docs/)
- [Quickshell.Io Types](https://quickshell.org/docs/types/Quickshell.Io/)
- [FileView Documentation](https://quickshell.org/docs/types/Quickshell.Io/FileView/)

### Qt/QML
- [QML Timer](https://doc.qt.io/qt-6/qml-qtqml-timer.html)
- [QML Text with Markdown](https://doc.qt.io/qt-6/qml-qtquick-text.html)
- [Render Markdown in QML](https://raymii.org/s/snippets/QML_Render_Markdown_in_Text.html)
- [QFileSystemWatcher](https://doc.qt.io/qt-6/qfilesystemwatcher.html)

### GitHub API
- [OAuth Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow)
- [Issues API](https://docs.github.com/en/rest/issues)

### Linux Security
- [GNOME Keyring and libsecret](https://jpmens.net/2024/10/24/notes-to-self-gnome-keyring-and-libsecret/)
- [GNOME Keyring ArchWiki](https://wiki.archlinux.org/title/GNOME/Keyring)
- [libsecret Project](https://wiki.gnome.org/Projects/Libsecret)

### Git Diff
- [Git Diff Format Documentation](https://git-scm.com/docs/diff-format)
- [Delta - Syntax Highlighting Pager](https://github.com/dandavison/delta)
- [Unified Diff Format](https://en.wikipedia.org/wiki/Diff)
