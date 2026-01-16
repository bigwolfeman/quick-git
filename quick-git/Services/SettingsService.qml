/**
 * SettingsService.qml - Settings Management Singleton
 *
 * This service handles:
 * - User preferences persistence to Quickshell.statePath("settings.json")
 * - Reactive properties for colorblind mode, recent repos, refresh interval
 * - Debounced auto-save (500ms) on property changes
 * - File format version migration
 *
 * Task: T006 - Create SettingsService singleton with load/save and reactive properties
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    // File format version for migration support
    readonly property int currentVersion: 1

    // Valid values for enum-like properties
    readonly property var validPalettes: ["shapes", "highcontrast", "deuteranopia", "protanopia"]
    readonly property var validViews: ["commits", "issues"]

    // Refresh interval bounds (seconds)
    readonly property int minRefreshInterval: 5
    readonly property int maxRefreshInterval: 300

    // =========================================================================
    // REACTIVE PROPERTIES (from contract)
    // =========================================================================

    /**
     * Enable colorblind-friendly indicators
     * When true, status is shown with shapes in addition to colors
     */
    property bool colorblindMode: false

    /**
     * Selected accessibility palette
     * Valid values: "shapes" | "highcontrast" | "deuteranopia" | "protanopia"
     */
    property string colorblindPalette: "shapes"

    /**
     * Recently accessed repository paths
     * Most recent first, limited to maxRecentRepos
     */
    property var recentRepos: []

    /**
     * Maximum number of recent repos to remember
     */
    property int maxRecentRepos: 10

    /**
     * Auto-refresh interval in seconds
     * Clamped to range [5, 300]
     */
    property int refreshInterval: 30

    /**
     * Default panel view when opening
     * Valid values: "commits" | "issues"
     */
    property string defaultView: "commits"

    /**
     * Whether settings have been loaded from disk
     * Set to true after successful load() or on first save with defaults
     */
    property bool isLoaded: false

    // =========================================================================
    // SIGNALS (from contract)
    // =========================================================================

    /**
     * Emitted when settings are loaded from disk
     */
    signal loaded()

    /**
     * Emitted when settings are saved to disk
     */
    signal saved()

    // Note: colorblindModeChanged and recentReposChanged signals are auto-generated
    // by their respective properties (colorblindMode, recentRepos)

    // =========================================================================
    // INTERNAL STATE
    // =========================================================================

    // Flag to prevent save during load
    property bool _loading: false

    // Flag to track if save is pending
    property bool _savePending: false

    // Path to settings file
    readonly property string _settingsPath: Quickshell.statePath("settings.json")

    // =========================================================================
    // FILE I/O COMPONENTS
    // =========================================================================

    /**
     * FileView for reading settings file
     */
    FileView {
        id: settingsFile
        path: root._settingsPath

        onTextChanged: {
            if (root._loading && text && text.length > 0) {
                root._parseAndApplySettings(text)
            } else if (root._loading && (!text || text.length === 0)) {
                // File doesn't exist or is empty - create defaults
                console.log("[SettingsService] Settings file not found or empty")
                console.log("[SettingsService] Creating default settings")
                root._loading = false
                root.isLoaded = true
                root._scheduleSave()
                root.loaded()
            }
        }
    }

    /**
     * FileView for writing settings file
     */
    FileView {
        id: settingsWriter
        path: root._settingsPath
        // Note: FileView doesn't have an error property, errors handled in _performSave
    }

    /**
     * Debounce timer for save operations (500ms)
     */
    Timer {
        id: saveDebounceTimer
        interval: 500
        repeat: false

        onTriggered: {
            root._performSave()
        }
    }

    // =========================================================================
    // PUBLIC METHODS (from contract)
    // =========================================================================

    /**
     * Load settings from disk
     * Creates default file if not exists
     *
     * @returns boolean - true if load was initiated successfully
     */
    function load() {
        console.log("[SettingsService] Loading settings from:", _settingsPath)

        _loading = true

        // Trigger reload by touching the FileView
        // FileView will emit textChanged or errorChanged
        settingsFile.reload()

        return true
    }

    /**
     * Persist settings to disk
     * Automatically debounced (500ms)
     *
     * @returns boolean - true if save was scheduled
     */
    function save() {
        if (_loading) {
            console.log("[SettingsService] Skipping save during load")
            return false
        }

        _scheduleSave()
        return true
    }

    /**
     * Enable or disable colorblind mode
     *
     * @param enabled - true to enable colorblind mode
     */
    function setColorblindMode(enabled) {
        if (typeof enabled !== "boolean") {
            console.error("[SettingsService] setColorblindMode: expected boolean, got", typeof enabled)
            return
        }

        if (colorblindMode !== enabled) {
            colorblindMode = enabled
            console.log("[SettingsService] Colorblind mode:", enabled)
            colorblindModeChanged(enabled)
            _scheduleSave()
        }
    }

    /**
     * Set the colorblind palette
     *
     * @param palette - "shapes" | "highcontrast" | "deuteranopia" | "protanopia"
     */
    function setColorblindPalette(palette) {
        if (!_validatePalette(palette)) {
            console.error("[SettingsService] Invalid palette:", palette,
                         "Valid options:", validPalettes.join(", "))
            return
        }

        if (colorblindPalette !== palette) {
            colorblindPalette = palette
            console.log("[SettingsService] Colorblind palette:", palette)
            _scheduleSave()
        }
    }

    /**
     * Add a repository to the recent list
     * Moves to front if already exists, deduplicates, limits to maxRecentRepos
     *
     * @param path - Absolute path to repository
     */
    function addRecentRepo(path) {
        if (!path || typeof path !== "string" || path.trim().length === 0) {
            console.error("[SettingsService] addRecentRepo: invalid path")
            return
        }

        const normalizedPath = path.trim()

        // Create new array with path at front, removing any existing occurrence
        let newRepos = [normalizedPath]

        for (let i = 0; i < recentRepos.length; i++) {
            if (recentRepos[i] !== normalizedPath) {
                newRepos.push(recentRepos[i])
            }
        }

        // Limit to maxRecentRepos
        if (newRepos.length > maxRecentRepos) {
            newRepos = newRepos.slice(0, maxRecentRepos)
        }

        recentRepos = newRepos
        console.log("[SettingsService] Added recent repo:", normalizedPath,
                   "Total:", recentRepos.length)
        recentReposChanged()
        _scheduleSave()
    }

    /**
     * Remove a repository from the recent list
     *
     * @param path - Repository path to remove
     * @returns boolean - true if found and removed
     */
    function removeRecentRepo(path) {
        if (!path || typeof path !== "string") {
            return false
        }

        const normalizedPath = path.trim()
        const index = recentRepos.indexOf(normalizedPath)

        if (index === -1) {
            console.log("[SettingsService] Repo not in recent list:", normalizedPath)
            return false
        }

        let newRepos = []
        for (let i = 0; i < recentRepos.length; i++) {
            if (recentRepos[i] !== normalizedPath) {
                newRepos.push(recentRepos[i])
            }
        }

        recentRepos = newRepos
        console.log("[SettingsService] Removed recent repo:", normalizedPath)
        recentReposChanged()
        _scheduleSave()
        return true
    }

    /**
     * Clear all recent repositories
     */
    function clearRecentRepos() {
        if (recentRepos.length === 0) {
            return
        }

        recentRepos = []
        console.log("[SettingsService] Cleared all recent repos")
        recentReposChanged()
        _scheduleSave()
    }

    /**
     * Set the auto-refresh interval
     *
     * @param seconds - Interval in seconds (clamped to [5, 300])
     */
    function setRefreshInterval(seconds) {
        if (typeof seconds !== "number" || isNaN(seconds)) {
            console.error("[SettingsService] setRefreshInterval: expected number, got", typeof seconds)
            return
        }

        // Clamp to valid range
        const clamped = Math.max(minRefreshInterval, Math.min(maxRefreshInterval, Math.round(seconds)))

        if (refreshInterval !== clamped) {
            refreshInterval = clamped
            console.log("[SettingsService] Refresh interval:", clamped, "seconds")
            _scheduleSave()
        }
    }

    /**
     * Set the default panel view
     *
     * @param view - "commits" | "issues"
     */
    function setDefaultView(view) {
        if (!_validateView(view)) {
            console.error("[SettingsService] Invalid view:", view,
                         "Valid options:", validViews.join(", "))
            return
        }

        if (defaultView !== view) {
            defaultView = view
            console.log("[SettingsService] Default view:", view)
            _scheduleSave()
        }
    }

    // =========================================================================
    // INTERNAL METHODS
    // =========================================================================

    /**
     * Validate a palette name
     * @param palette - Palette name to validate
     * @returns boolean - true if valid
     */
    function _validatePalette(palette) {
        return validPalettes.indexOf(palette) !== -1
    }

    /**
     * Validate a view name
     * @param view - View name to validate
     * @returns boolean - true if valid
     */
    function _validateView(view) {
        return validViews.indexOf(view) !== -1
    }

    /**
     * Schedule a debounced save operation
     */
    function _scheduleSave() {
        if (_loading) {
            return
        }

        _savePending = true
        saveDebounceTimer.restart()
    }

    /**
     * Perform the actual save operation
     */
    function _performSave() {
        if (!_savePending) {
            return
        }

        _savePending = false

        const settings = {
            version: currentVersion,
            colorblindMode: colorblindMode,
            colorblindPalette: colorblindPalette,
            recentRepos: recentRepos,
            maxRecentRepos: maxRecentRepos,
            refreshInterval: refreshInterval,
            defaultView: defaultView
        }

        const json = JSON.stringify(settings, null, 2)

        console.log("[SettingsService] Saving settings to:", _settingsPath)
        settingsWriter.setText(json)

        saved()
    }

    /**
     * Parse JSON text and apply settings
     * @param text - JSON text from settings file
     */
    function _parseAndApplySettings(text) {
        _loading = false

        let settings
        try {
            settings = JSON.parse(text)
        } catch (e) {
            console.error("[SettingsService] Failed to parse settings JSON:", e)
            console.log("[SettingsService] Resetting to defaults")
            isLoaded = true
            _scheduleSave()
            loaded()
            return
        }

        // Check version for migration
        const fileVersion = settings.version || 0
        if (fileVersion < currentVersion) {
            console.log("[SettingsService] Migrating settings from version",
                       fileVersion, "to", currentVersion)
        }

        // Apply settings with validation and defaults
        if (typeof settings.colorblindMode === "boolean") {
            colorblindMode = settings.colorblindMode
        }

        if (_validatePalette(settings.colorblindPalette)) {
            colorblindPalette = settings.colorblindPalette
        }

        if (Array.isArray(settings.recentRepos)) {
            // Filter to strings only
            const validRepos = settings.recentRepos.filter(r => typeof r === "string" && r.length > 0)
            recentRepos = validRepos
        }

        if (typeof settings.maxRecentRepos === "number" && settings.maxRecentRepos > 0) {
            maxRecentRepos = Math.round(settings.maxRecentRepos)
        }

        if (typeof settings.refreshInterval === "number") {
            refreshInterval = Math.max(minRefreshInterval, Math.min(maxRefreshInterval, Math.round(settings.refreshInterval)))
        }

        if (_validateView(settings.defaultView)) {
            defaultView = settings.defaultView
        }

        console.log("[SettingsService] Settings loaded successfully")
        console.log("[SettingsService]   colorblindMode:", colorblindMode)
        console.log("[SettingsService]   colorblindPalette:", colorblindPalette)
        console.log("[SettingsService]   recentRepos:", recentRepos.length, "entries")
        console.log("[SettingsService]   refreshInterval:", refreshInterval, "seconds")
        console.log("[SettingsService]   defaultView:", defaultView)

        isLoaded = true

        // Save if migration occurred
        if (fileVersion < currentVersion) {
            _scheduleSave()
        }

        loaded()
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[SettingsService] Initialized")
        console.log("[SettingsService] Settings path:", _settingsPath)
    }

    Component.onDestruction: {
        // Ensure any pending save is flushed
        if (_savePending) {
            console.log("[SettingsService] Flushing pending save on destruction")
            saveDebounceTimer.stop()
            _performSave()
        }
        console.log("[SettingsService] Destroyed")
    }
}
