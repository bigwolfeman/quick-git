/**
 * BarWidget.qml - Quick-Git Noctalia Bar Widget
 *
 * Displays git repository status at a glance in the Noctalia status bar.
 * Registers with the Noctalia BarWidgetRegistry for dynamic loading.
 *
 * Task: T014 - Create BarWidget.qml skeleton that registers with Noctalia bar
 *
 * Features:
 * - StatusIndicator showing current repo state (clean, modified, ahead, behind, conflict)
 * - Optional branch name display (configurable based on available space)
 * - Rich tooltip with: branch name, file counts, ahead/behind info
 * - Click to open the Quick-Git panel
 * - Colorblind accessibility support via SettingsService
 *
 * Requirements:
 * - FR-006: Bar widget indicator (clean, modified, ahead of remote)
 * - FR-007: Tooltip on hover showing branch, changed file count, commits ahead/behind
 * - FR-029: Shape-based indicators in addition to color
 * - FR-030: Colorblind-friendly mode toggle
 *
 * @see specs/001-quick-git-plugin/spec.md (US1 - View Git Status at a Glance)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Services" as Services
import "Components" as Components

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    /**
     * Allow user settings for this widget (Noctalia widget standard)
     */
    property bool allowUserSettings: true

    /**
     * Show branch name alongside status indicator
     * Can be toggled to save space in narrow bars
     */
    property bool showBranchName: true

    /**
     * Maximum width for branch name (truncates with ellipsis)
     */
    property int maxBranchWidth: 120

    /**
     * Compact mode for narrow bar configurations
     */
    property bool compactMode: false

    // =========================================================================
    // SIZING
    // =========================================================================

    implicitWidth: layout.implicitWidth + (compactMode ? 8 : 16)
    implicitHeight: 32

    // =========================================================================
    // PRIVATE COMPUTED PROPERTIES
    // =========================================================================

    /**
     * Compute the current status based on GitService state
     *
     * Priority order (highest to lowest):
     * 1. conflict - Merge conflicts require immediate attention
     * 2. loading  - Currently refreshing
     * 3. modified - Uncommitted changes exist
     * 4. behind   - Remote has new commits
     * 5. ahead    - Local commits not pushed
     * 6. clean    - Everything up to date
     */
    readonly property string currentStatus: {
        // Check if we're refreshing
        if (Services.GitService.isRefreshing) {
            return "loading"
        }

        // Check for conflicts first (highest priority)
        if (Services.GitService.hasConflicts) {
            return "conflict"
        }

        // Check if not a valid repo
        if (!Services.GitService.isRepo) {
            return "clean" // Neutral state when no repo
        }

        // Check for uncommitted changes
        if (Services.GitService.hasChanges) {
            return "modified"
        }

        // Check for commits behind remote
        if (Services.GitService.behindCount > 0) {
            return "behind"
        }

        // Check for unpushed commits
        if (Services.GitService.aheadCount > 0) {
            return "ahead"
        }

        // All clean
        return "clean"
    }

    /**
     * Branch display text with fallback for no repo
     */
    readonly property string branchDisplayText: {
        if (!Services.GitService.isRepo) {
            return qsTr("No repo")
        }

        if (!Services.GitService.branch || Services.GitService.branch.length === 0) {
            return qsTr("No branch")
        }

        return Services.GitService.branch
    }

    /**
     * Build rich tooltip text with full status details
     */
    readonly property string tooltipText: internal.buildTooltipText()

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: compactMode ? 4 : 8

        // Status Indicator Component
        Components.StatusIndicator {
            id: statusIndicator
            Layout.alignment: Qt.AlignVCenter

            status: root.currentStatus
            size: compactMode ? 14 : 16
            compact: root.compactMode

            // Bind accessibility settings from SettingsService
            colorblindMode: Services.SettingsService.colorblindMode
            colorblindPalette: Services.SettingsService.colorblindPalette

            // Hide the built-in label if we're showing branch name
            // (avoid duplicate text in the widget)
            showLabel: Services.SettingsService.colorblindMode && !root.showBranchName

            // Use our custom tooltip instead of the built-in one
            tooltipText: ""
        }

        // Branch Name Text (optional)
        Text {
            id: branchText
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxBranchWidth

            visible: root.showBranchName && !root.compactMode

            text: root.branchDisplayText
            color: internal.getBranchTextColor()
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideMiddle

            // Subtle animation on branch change
            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: branchText; property: "opacity"; to: 0.5; duration: 100 }
                    NumberAnimation { target: branchText; property: "opacity"; to: 1.0; duration: 200 }
                }
            }
        }

        // Change count badge (shown when there are changes and not in compact mode)
        Rectangle {
            id: changeBadge
            Layout.alignment: Qt.AlignVCenter

            visible: !root.compactMode && internal.totalChangeCount > 0

            width: Math.max(18, changeCountText.implicitWidth + 8)
            height: 18
            radius: 9
            color: statusIndicator.statusColor
            opacity: 0.8

            Text {
                id: changeCountText
                anchors.centerIn: parent
                text: internal.totalChangeCount
                color: "#ffffff"
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
    }

    // =========================================================================
    // TOOLTIP
    // =========================================================================

    ToolTip {
        id: tooltip
        visible: mouseArea.containsMouse && root.tooltipText.length > 0
        delay: 400
        timeout: 10000
        text: root.tooltipText

        // Custom styling for rich tooltip
        background: Rectangle {
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            radius: 6
        }

        contentItem: Text {
            text: tooltip.text
            color: "#cdd6f4"
            font.pixelSize: 12
            font.family: "monospace"
            lineHeight: 1.4
            textFormat: Text.PlainText
        }
    }

    // =========================================================================
    // MOUSE INTERACTION
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            console.log("[BarWidget] Clicked - opening panel")
            // Open the Quick-Git panel on the current screen
            // This uses Noctalia's built-in panel management
            openPanel(screen)
        }

        onEntered: {
            root.scale = 1.02
        }

        onExited: {
            root.scale = 1.0
        }
    }

    // Subtle scale animation on hover
    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
        }
    }

    // =========================================================================
    // INTERNAL HELPERS
    // =========================================================================

    QtObject {
        id: internal

        /**
         * Total count of changed files (staged + unstaged + untracked)
         */
        readonly property int totalChangeCount: {
            return Services.GitService.stagedCount +
                   Services.GitService.unstagedCount +
                   Services.GitService.untrackedCount
        }

        /**
         * Get appropriate text color for branch name based on status
         */
        function getBranchTextColor() {
            if (!Services.GitService.isRepo) {
                return "#6c7086" // Dim gray for no repo
            }

            // Use Catppuccin Mocha palette (Noctalia default)
            switch (root.currentStatus) {
                case "conflict":
                    return "#f38ba8" // Red
                case "modified":
                    return "#fab387" // Peach/Orange
                case "ahead":
                    return "#89b4fa" // Blue
                case "behind":
                    return "#cba6f7" // Mauve/Purple
                default:
                    return "#cdd6f4" // Default text
            }
        }

        /**
         * Build detailed tooltip text showing full repository status
         *
         * Format:
         *   Branch: main
         *   Status: Clean (or Modified, Ahead, Behind, Conflict)
         *   ---
         *   Changes: X files (Y staged, Z unstaged, W untracked)
         *   Ahead: N commits | Behind: M commits
         */
        function buildTooltipText() {
            let lines = []

            // Branch info (T085 - enhanced no repo guidance)
            if (Services.GitService.isRepo) {
                lines.push("Branch: " + (Services.GitService.branch || "(no branch)"))
            } else {
                lines.push("Not a Git Repository")
                lines.push("---")
                lines.push("Current directory is not tracked by git.")
                lines.push("")
                lines.push("Click to open Quick-Git panel")
                lines.push("for options to get started.")
                return lines.join("\n")
            }

            // Status line with description
            lines.push("Status: " + getStatusDescription(root.currentStatus))

            // Separator
            lines.push("---")

            // File changes summary
            const staged = Services.GitService.stagedCount
            const unstaged = Services.GitService.unstagedCount
            const untracked = Services.GitService.untrackedCount
            const total = staged + unstaged + untracked

            if (total === 0) {
                lines.push("Working tree clean")
            } else {
                let changeParts = []
                if (staged > 0) changeParts.push(staged + " staged")
                if (unstaged > 0) changeParts.push(unstaged + " modified")
                if (untracked > 0) changeParts.push(untracked + " untracked")

                lines.push("Changes: " + total + " files")
                lines.push("  " + changeParts.join(", "))
            }

            // Ahead/behind info
            const ahead = Services.GitService.aheadCount
            const behind = Services.GitService.behindCount

            if (ahead > 0 || behind > 0) {
                let syncParts = []
                if (ahead > 0) syncParts.push(ahead + " ahead")
                if (behind > 0) syncParts.push(behind + " behind")
                lines.push("Sync: " + syncParts.join(" | "))
            }

            // Conflict warning
            if (Services.GitService.hasConflicts) {
                lines.push("")
                lines.push("!! Merge conflicts detected !!")
            }

            // Click hint
            lines.push("")
            lines.push("Click to open panel")

            return lines.join("\n")
        }

        /**
         * Get human-readable status description
         */
        function getStatusDescription(status) {
            switch (status) {
                case "clean":
                    return "Clean - all changes committed"
                case "modified":
                    return "Modified - uncommitted changes"
                case "ahead":
                    return "Ahead - unpushed commits"
                case "behind":
                    return "Behind - remote has updates"
                case "conflict":
                    return "Conflict - merge resolution needed"
                case "loading":
                    return "Refreshing..."
                default:
                    return status
            }
        }
    }

    // =========================================================================
    // SETTINGS PERSISTENCE
    // =========================================================================

    // Save widget-specific settings when they change
    onShowBranchNameChanged: {
        if (allowUserSettings) {
            saveSettings()
        }
    }

    onCompactModeChanged: {
        if (allowUserSettings) {
            saveSettings()
        }
    }

    // =========================================================================
    // LIFECYCLE
    // =========================================================================

    Component.onCompleted: {
        console.log("[BarWidget] Component loaded")
        console.log("[BarWidget] GitService isRepo:", Services.GitService.isRepo)
        console.log("[BarWidget] GitService branch:", Services.GitService.branch)

        // Trigger an initial refresh if GitService is available and repo is set
        if (Services.GitService.isRepo && !Services.GitService.isRefreshing) {
            console.log("[BarWidget] Triggering initial status refresh")
            Services.GitService.refresh()
        }
    }

    Component.onDestruction: {
        console.log("[BarWidget] Component destroyed")
    }

    // =========================================================================
    // DEBUG/DEVELOPMENT
    // =========================================================================

    // Uncomment for development testing
    /*
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            console.log("[BarWidget] Status:", root.currentStatus,
                       "Branch:", root.branchDisplayText,
                       "Changes:", internal.totalChangeCount)
        }
    }
    */
}
