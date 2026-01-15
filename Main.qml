/**
 * Main.qml - Background Entry Point for Quick-Git Plugin
 *
 * This component handles:
 * - Service initialization and lifecycle
 * - IPC command handlers for external communication
 * - File system watchers for .git/HEAD and .git/index
 * - Periodic git status refresh timer
 * - Current working directory detection on load
 *
 * Task: T003 - Create Main.qml with service initialization and IPC handlers
 */
import Quickshell
import Quickshell.Io
import QtQuick
import "Services" as Services

Item {
    id: root

    // =========================================================================
    // EXPOSED PROPERTIES (bound to Services)
    // =========================================================================

    // Current repository state - bound to GitService
    property string currentBranch: Services.GitService.branch
    property bool hasChanges: Services.GitService.hasChanges
    property bool isRepo: Services.GitService.isRepo
    property string repoPath: Services.GitService.repoPath

    // Status summary for bar widget tooltip
    property int stagedCount: Services.GitService.stagedCount
    property int unstagedCount: Services.GitService.unstagedCount
    property int untrackedCount: Services.GitService.untrackedCount
    property int aheadCount: Services.GitService.aheadCount
    property int behindCount: Services.GitService.behindCount

    // Detailed file lists for panel view
    property var stagedFiles: Services.GitService.status.staged
    property var unstagedFiles: Services.GitService.status.unstaged
    property var untrackedFiles: Services.GitService.status.untracked

    // Loading/error state
    property bool isRefreshing: Services.GitService.isRefreshing
    property string lastError: Services.GitService.error

    // =========================================================================
    // SERVICE REFERENCES (for convenient access)
    // =========================================================================

    // Settings service singleton
    readonly property var settings: Services.SettingsService

    // Git service singleton
    readonly property var git: Services.GitService

    // TODO (T040): Import and reference GitHubService singleton
    // readonly property var github: Services.GitHubService

    // =========================================================================
    // IPC COMMAND HANDLERS
    // =========================================================================

    /**
     * Handle IPC commands from external processes
     * Usage: qs ipc -c quick-git call <command> [--args]
     *
     * @param command - Command name to execute
     * @param args - Object containing command arguments
     * @returns Object with result or error
     */
    function handleCommand(command, args) {
        console.log("[Quick-Git] IPC command received:", command, JSON.stringify(args))

        switch (command) {
            case "refresh":
                // Force refresh git status
                refresh()
                return { success: true, message: "Refresh triggered" }

            case "status":
                // Return current status summary
                return {
                    success: true,
                    data: {
                        branch: currentBranch,
                        isRepo: isRepo,
                        hasChanges: hasChanges,
                        staged: stagedCount,
                        unstaged: unstagedCount,
                        untracked: untrackedCount,
                        ahead: aheadCount,
                        behind: behindCount
                    }
                }

            case "stage":
                // Stage a file: qs ipc -c quick-git call stage --file="path/to/file"
                if (!args || !args.file) {
                    return { success: false, error: "Missing 'file' argument" }
                }
                // TODO (T023): Delegate to GitService.stage(args.file)
                return { success: false, error: "Not implemented - see T023" }

            case "unstage":
                // Unstage a file: qs ipc -c quick-git call unstage --file="path/to/file"
                if (!args || !args.file) {
                    return { success: false, error: "Missing 'file' argument" }
                }
                // TODO (T024): Delegate to GitService.unstage(args.file)
                return { success: false, error: "Not implemented - see T024" }

            case "commit":
                // Create commit: qs ipc -c quick-git call commit --message="Commit message"
                if (!args || !args.message) {
                    return { success: false, error: "Missing 'message' argument" }
                }
                // TODO (T027): Delegate to GitService.commit(args.message)
                return { success: false, error: "Not implemented - see T027" }

            case "push":
                // Push to remote: qs ipc -c quick-git call push
                // TODO (T029): Delegate to GitService.push()
                return { success: false, error: "Not implemented - see T029" }

            case "setRepo":
                // Switch repository: qs ipc -c quick-git call setRepo --path="/path/to/repo"
                if (!args || !args.path) {
                    return { success: false, error: "Missing 'path' argument" }
                }
                // TODO (T008): Delegate to GitService.setRepository(args.path)
                return { success: false, error: "Not implemented - see T008" }

            default:
                return { success: false, error: "Unknown command: " + command }
        }
    }

    // =========================================================================
    // REFRESH LOGIC
    // =========================================================================

    /**
     * Refresh git repository status
     * Called by: timer, file watchers, IPC, manual trigger
     */
    function refresh() {
        if (isRefreshing) {
            console.log("[Quick-Git] Refresh already in progress, skipping")
            return
        }

        if (!repoPath) {
            console.log("[Quick-Git] No repository path set, skipping refresh")
            return
        }

        console.log("[Quick-Git] Starting refresh for:", repoPath)
        isRefreshing = true
        lastError = ""

        // Reset file lists before collecting new data
        stagedFiles = []
        unstagedFiles = []
        untrackedFiles = []

        // Start git commands
        // TODO (T010): branchProcess.running = true
        // TODO (T009): statusProcess.running = true
        // TODO (T011): aheadBehindProcess.running = true

        // Temporary: simulate completion for skeleton
        isRefreshing = false
    }

    // =========================================================================
    // GIT COMMAND PROCESSES
    // =========================================================================

    // Process: Get current branch name
    // TODO (T010): Implement branch detection
    Process {
        id: branchProcess
        command: ["git", "-C", repoPath, "rev-parse", "--abbrev-ref", "HEAD"]
        running: false

        stdout: StdioCollector {
            onCollected: text => {
                currentBranch = text.trim()
                console.log("[Quick-Git] Branch detected:", currentBranch)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("[Quick-Git] Failed to get branch, exit code:", exitCode)
                currentBranch = ""
                isRepo = false
            } else {
                isRepo = true
            }
        }
    }

    // Process: Get repository status (staged, unstaged, untracked files)
    // TODO (T009): Implement status parsing
    Process {
        id: statusProcess
        command: ["git", "-C", repoPath, "status", "--porcelain"]
        running: false

        property var tempStaged: []
        property var tempUnstaged: []
        property var tempUntracked: []

        stdout: SplitParser {
            onRead: line => {
                if (line.length < 3) return

                // Parse porcelain format: XY filename
                // X = index status, Y = worktree status
                const indexStatus = line.charAt(0)
                const worktreeStatus = line.charAt(1)
                const filePath = line.substring(3)

                // Staged files (index has changes)
                if (indexStatus !== ' ' && indexStatus !== '?') {
                    statusProcess.tempStaged.push({
                        status: indexStatus,
                        path: filePath
                    })
                }

                // Unstaged files (worktree has changes)
                if (worktreeStatus !== ' ' && worktreeStatus !== '?') {
                    statusProcess.tempUnstaged.push({
                        status: worktreeStatus,
                        path: filePath
                    })
                }

                // Untracked files
                if (indexStatus === '?' && worktreeStatus === '?') {
                    statusProcess.tempUntracked.push({
                        status: '?',
                        path: filePath
                    })
                }
            }
        }

        onStarted: {
            tempStaged = []
            tempUnstaged = []
            tempUntracked = []
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                stagedFiles = tempStaged
                unstagedFiles = tempUnstaged
                untrackedFiles = tempUntracked

                stagedCount = stagedFiles.length
                unstagedCount = unstagedFiles.length
                untrackedCount = untrackedFiles.length

                hasChanges = stagedCount > 0 || unstagedCount > 0 || untrackedCount > 0

                console.log("[Quick-Git] Status updated - staged:", stagedCount,
                           "unstaged:", unstagedCount, "untracked:", untrackedCount)
            } else {
                console.error("[Quick-Git] Failed to get status, exit code:", exitCode)
                lastError = "Failed to get git status"
            }

            isRefreshing = false
        }
    }

    // Process: Get ahead/behind count relative to upstream
    // TODO (T011): Implement ahead/behind detection
    Process {
        id: aheadBehindProcess
        command: ["git", "-C", repoPath, "rev-list", "--left-right", "--count", "HEAD...@{u}"]
        running: false

        stdout: StdioCollector {
            onCollected: text => {
                // Output format: "ahead\tbehind"
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 2) {
                    aheadCount = parseInt(parts[0]) || 0
                    behindCount = parseInt(parts[1]) || 0
                    console.log("[Quick-Git] Ahead:", aheadCount, "Behind:", behindCount)
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // No upstream configured - this is not an error
                aheadCount = 0
                behindCount = 0
            }
        }
    }

    // Process: Validate repository path
    Process {
        id: repoValidateProcess
        command: ["git", "-C", repoPath, "rev-parse", "--git-dir"]
        running: false

        onExited: (exitCode, exitStatus) => {
            isRepo = (exitCode === 0)
            if (isRepo) {
                console.log("[Quick-Git] Valid git repository:", repoPath)
                refresh()
            } else {
                console.log("[Quick-Git] Not a git repository:", repoPath)
                currentBranch = ""
                hasChanges = false
                stagedFiles = []
                unstagedFiles = []
                untrackedFiles = []
            }
        }
    }

    // =========================================================================
    // FILE SYSTEM WATCHERS
    // =========================================================================

    // Watch .git/HEAD for branch changes (T017)
    FileView {
        id: gitHeadWatcher
        path: Services.GitService.repoPath ? Services.GitService.repoPath + "/.git/HEAD" : ""
        watchChanges: true

        onFileChanged: {
            console.log("[Quick-Git] .git/HEAD changed - branch may have switched")
            Services.GitService.refresh()
        }
    }

    // Watch .git/index for staging area changes (T017)
    FileView {
        id: gitIndexWatcher
        path: Services.GitService.repoPath ? Services.GitService.repoPath + "/.git/index" : ""
        watchChanges: true

        onFileChanged: {
            console.log("[Quick-Git] .git/index changed - staging area updated")
            Services.GitService.refresh()
        }
    }

    // =========================================================================
    // PERIODIC REFRESH TIMER
    // =========================================================================

    // Timer-based polling fallback for working directory changes (T018)
    Timer {
        id: refreshTimer
        // Interval bound to SettingsService.refreshInterval (default 30 seconds)
        interval: Services.SettingsService.refreshInterval * 1000
        running: Services.GitService.isRepo && Services.SettingsService.isLoaded
        repeat: true

        onTriggered: {
            console.log("[Quick-Git] Timer triggered refresh")
            Services.GitService.refresh()
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    /**
     * Detect current working directory on plugin load
     * Uses PWD environment variable or falls back to home directory
     */
    function detectWorkingDirectory() {
        // Try to get current working directory
        // TODO: Integrate with Noctalia's active window tracking for better CWD detection
        const pwd = Quickshell.env("PWD")
        const home = Quickshell.env("HOME")

        if (pwd && pwd.length > 0) {
            console.log("[Quick-Git] Detected PWD:", pwd)
            setRepository(pwd)
        } else if (home && home.length > 0) {
            console.log("[Quick-Git] Falling back to HOME:", home)
            setRepository(home)
        } else {
            console.log("[Quick-Git] Could not detect working directory")
        }
    }

    /**
     * Set the active repository path and validate it
     * @param path - Absolute path to repository root
     */
    function setRepository(path) {
        if (!path || path === Services.GitService.repoPath) return

        console.log("[Quick-Git] Setting repository path:", path)

        // Use GitService to set and validate repository
        Services.GitService.setRepository(path)

        // Add to recent repos if valid
        if (Services.GitService.isRepo) {
            Services.SettingsService.addRecentRepo(path)
        }
    }

    Component.onCompleted: {
        console.log("[Quick-Git] Main.qml initialized")
        console.log("[Quick-Git] Plugin directory:", Quickshell.shellDir)
        console.log("[Quick-Git] State directory:", Quickshell.stateDir)

        // Initialize SettingsService and load saved settings
        Services.SettingsService.load()

        // Detect current working directory on load (T074)
        detectWorkingDirectory()
    }

    Component.onDestruction: {
        console.log("[Quick-Git] Main.qml destroyed")
        refreshTimer.stop()
    }
}
