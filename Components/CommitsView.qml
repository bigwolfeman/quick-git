/**
 * CommitsView.qml - Git Staging and Commit Interface
 *
 * This component provides the main commit workflow UI:
 * - File list grouped by Staged/Unstaged/Untracked (collapsible sections)
 * - Individual file stage [+] and unstage [-] actions
 * - Inline diff viewer with expand/collapse toggle
 * - Stage All button for bulk staging
 * - Commit message TextArea with character count
 * - Commit button (disabled when no staged files or empty message)
 * - Push button (visible when ahead > 0)
 *
 * Tasks Implemented:
 * - T021: Create file list grouped by Staged/Unstaged/Untracked
 * - T022: Implement file item delegate with stage [+] and unstage [-] buttons
 * - T026: Add commit message TextArea with character count
 * - T028: Add Commit button with disabled state when no staged files
 * - T030: Add Push button visible when ahead > 0
 * - T036: Add expand/collapse toggle to file items
 * - T037: Embed DiffViewer inline when file is expanded
 *
 * @see specs/001-quick-git-plugin/spec.md (US2)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Services" as Services

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    /**
     * Filter text for filtering files by path
     */
    property string filterText: ""

    /**
     * Current commit message
     */
    property string commitMessage: ""

    /**
     * Whether a commit operation is in progress
     */
    property bool isCommitting: false

    /**
     * Whether a push operation is in progress
     */
    property bool isPushing: false

    /**
     * Maximum recommended commit message length (soft limit)
     */
    property int maxMessageLength: 72

    /**
     * Hard limit for commit message (first line)
     */
    property int hardMessageLimit: 100

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when a commit succeeds
     * @param sha - The SHA of the created commit
     */
    signal commitSucceeded(string sha)

    /**
     * Emitted when a push succeeds
     */
    signal pushSucceeded()

    /**
     * Emitted when a file is clicked (for expanding diff)
     * @param filePath - Path to the file
     * @param isStaged - Whether the file is in the staged section
     */
    signal fileClicked(string filePath, bool isStaged)

    // =========================================================================
    // INTERNAL STATE
    // =========================================================================

    QtObject {
        id: internal

        // Color palette (Catppuccin Mocha)
        readonly property color backgroundColor: "#1e1e2e"
        readonly property color surfaceColor: "#313244"
        readonly property color overlayColor: "#45475a"
        readonly property color textColor: "#cdd6f4"
        readonly property color subtextColor: "#a6adc8"
        readonly property color accentColor: "#89b4fa"
        readonly property color borderColor: "#45475a"

        // Status colors
        readonly property color stagedColor: "#a6e3a1"      // Green
        readonly property color unstagedColor: "#fab387"    // Orange/Peach
        readonly property color untrackedColor: "#9399b2"   // Gray/Overlay2
        readonly property color conflictColor: "#f38ba8"    // Red
        readonly property color addedColor: "#a6e3a1"       // Green
        readonly property color deletedColor: "#f38ba8"     // Red
        readonly property color modifiedColor: "#89b4fa"    // Blue
        readonly property color renamedColor: "#cba6f7"     // Mauve

        // Section collapse states
        property bool stagedCollapsed: false
        property bool unstagedCollapsed: false
        property bool untrackedCollapsed: false

        // Expanded file state (T036, T037)
        // Only one file can be expanded at a time
        property string expandedFilePath: ""
        property bool expandedFileIsStaged: false

        /**
         * Toggle file expansion state
         */
        function toggleFileExpansion(filePath, isStaged) {
            if (expandedFilePath === filePath && expandedFileIsStaged === isStaged) {
                // Collapse currently expanded file
                expandedFilePath = ""
                expandedFileIsStaged = false
                console.log("[CommitsView] Collapsed file diff")
            } else {
                // Expand new file (auto-collapses previous)
                expandedFilePath = filePath
                expandedFileIsStaged = isStaged
                console.log("[CommitsView] Expanded file diff:", filePath, "staged:", isStaged)
            }
        }

        /**
         * Check if a file is currently expanded
         */
        function isFileExpanded(filePath, isStaged) {
            return expandedFilePath === filePath && expandedFileIsStaged === isStaged
        }

        /**
         * Get status icon for a file
         */
        function getStatusIcon(status) {
            switch (status) {
                case 'M': return "\uf040"  // Pencil - modified
                case 'A': return "\uf067"  // Plus - added
                case 'D': return "\uf068"  // Minus - deleted
                case 'R': return "\uf064"  // Arrow-right - renamed
                case 'C': return "\uf0c5"  // Copy - copied
                case 'U': return "\uf071"  // Warning - unmerged
                case '?': return "\uf128"  // Question - untracked
                default:  return "\uf15b"  // File - default
            }
        }

        /**
         * Get status color for a file
         */
        function getStatusColor(status) {
            switch (status) {
                case 'M': return modifiedColor
                case 'A': return addedColor
                case 'D': return deletedColor
                case 'R': return renamedColor
                case 'C': return renamedColor
                case 'U': return conflictColor
                case '?': return untrackedColor
                default:  return subtextColor
            }
        }

        /**
         * Get filename from path
         */
        function getFilename(path) {
            if (!path) return ""
            var parts = path.split("/")
            return parts[parts.length - 1]
        }

        /**
         * Get directory from path
         */
        function getDirectory(path) {
            if (!path) return ""
            var parts = path.split("/")
            if (parts.length <= 1) return ""
            parts.pop()
            return parts.join("/") + "/"
        }

        /**
         * Filter files by filterText
         */
        function filterFiles(files) {
            if (!root.filterText || root.filterText.length === 0) {
                return files
            }
            var filter = root.filterText.toLowerCase()
            var result = []
            for (var i = 0; i < files.length; i++) {
                if (files[i].path.toLowerCase().indexOf(filter) !== -1) {
                    result.push(files[i])
                }
            }
            return result
        }

        /**
         * Get filtered staged files
         */
        function filteredStaged() {
            return filterFiles(Services.GitService.status.staged || [])
        }

        /**
         * Get filtered unstaged files
         */
        function filteredUnstaged() {
            return filterFiles(Services.GitService.status.unstaged || [])
        }

        /**
         * Get filtered untracked files
         */
        function filteredUntracked() {
            return filterFiles(Services.GitService.status.untracked || [])
        }

        /**
         * Check if commit is allowed
         */
        function canCommit() {
            return Services.GitService.stagedCount > 0 &&
                   root.commitMessage.trim().length > 0 &&
                   !root.isCommitting
        }

        /**
         * Check if push is allowed
         */
        function canPush() {
            return Services.GitService.aheadCount > 0 && !root.isPushing
        }
    }

    // =========================================================================
    // SERVICE CONNECTIONS
    // =========================================================================

    Connections {
        target: Services.GitService

        function onCommitCreated(sha) {
            root.isCommitting = false
            root.commitMessage = ""
            root.commitSucceeded(sha)
            console.log("[CommitsView] Commit created:", sha)
        }

        function onErrorOccurred(message) {
            root.isCommitting = false
            root.isPushing = false
            console.error("[CommitsView] Error:", message)
        }

        function onStatusChanged() {
            // Reset push state after successful push (ahead will be 0)
            if (root.isPushing && Services.GitService.aheadCount === 0) {
                root.isPushing = false
                root.pushSucceeded()
                console.log("[CommitsView] Push succeeded")
            }

            // Clear expanded file state when status changes
            // This ensures we don't show stale diffs when files move between sections
            if (internal.expandedFilePath !== "") {
                // Check if the expanded file still exists in the expected section
                const wasStaged = internal.expandedFileIsStaged
                const path = internal.expandedFilePath
                let stillExists = false

                if (wasStaged) {
                    const staged = Services.GitService.status.staged || []
                    stillExists = staged.some(f => f.path === path)
                } else {
                    const unstaged = Services.GitService.status.unstaged || []
                    const untracked = Services.GitService.status.untracked || []
                    stillExists = unstaged.some(f => f.path === path) ||
                                  untracked.some(f => f.path === path)
                }

                if (!stillExists) {
                    console.log("[CommitsView] Collapsing expanded diff - file moved or removed")
                    internal.expandedFilePath = ""
                    internal.expandedFileIsStaged = false
                }
            }
        }
    }

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // TOP ACTION BAR
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Stage All button
            Rectangle {
                id: stageAllButton
                Layout.preferredWidth: stageAllContent.width + 24
                Layout.preferredHeight: 32
                color: stageAllMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
                radius: 6
                border.color: internal.borderColor
                border.width: 1
                visible: Services.GitService.unstagedCount > 0 || Services.GitService.untrackedCount > 0

                RowLayout {
                    id: stageAllContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\uf067"  // Plus icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 11
                        color: internal.stagedColor
                    }

                    Text {
                        text: qsTr("Stage All")
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: internal.textColor
                    }
                }

                MouseArea {
                    id: stageAllMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        console.log("[CommitsView] Stage All clicked")
                        Services.GitService.stageAll()
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            Item { Layout.fillWidth: true }

            // Refresh button
            Rectangle {
                id: refreshButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                color: refreshMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
                radius: 6
                border.color: internal.borderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "\uf021"  // Refresh icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 12
                    color: internal.textColor

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: Services.GitService.isRefreshing
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !Services.GitService.isRefreshing

                    onClicked: {
                        console.log("[CommitsView] Refresh clicked")
                        Services.GitService.refresh()
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // =====================================================================
        // FILE LIST AREA (Scrollable)
        // =====================================================================

        ScrollView {
            id: fileListScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: fileListScrollView.availableWidth
                spacing: 8

                // =============================================================
                // STAGED SECTION (T021)
                // =============================================================

                FileSection {
                    id: stagedSection
                    Layout.fillWidth: true
                    sectionTitle: qsTr("Staged")
                    sectionCount: Services.GitService.stagedCount
                    sectionColor: internal.stagedColor
                    collapsed: internal.stagedCollapsed
                    files: internal.filteredStaged()
                    isStaged: true

                    onToggleCollapsed: internal.stagedCollapsed = !internal.stagedCollapsed
                    onStageFile: path => Services.GitService.stage(path)
                    onUnstageFile: path => Services.GitService.unstage(path)
                    onFileClicked: (path, staged) => root.fileClicked(path, staged)
                }

                // =============================================================
                // UNSTAGED SECTION (T021)
                // =============================================================

                FileSection {
                    id: unstagedSection
                    Layout.fillWidth: true
                    sectionTitle: qsTr("Unstaged")
                    sectionCount: Services.GitService.unstagedCount
                    sectionColor: internal.unstagedColor
                    collapsed: internal.unstagedCollapsed
                    files: internal.filteredUnstaged()
                    isStaged: false

                    onToggleCollapsed: internal.unstagedCollapsed = !internal.unstagedCollapsed
                    onStageFile: path => Services.GitService.stage(path)
                    onUnstageFile: path => Services.GitService.unstage(path)
                    onFileClicked: (path, staged) => root.fileClicked(path, staged)
                }

                // =============================================================
                // UNTRACKED SECTION (T021)
                // =============================================================

                FileSection {
                    id: untrackedSection
                    Layout.fillWidth: true
                    sectionTitle: qsTr("Untracked")
                    sectionCount: Services.GitService.untrackedCount
                    sectionColor: internal.untrackedColor
                    collapsed: internal.untrackedCollapsed
                    files: internal.filteredUntracked()
                    isStaged: false
                    isUntracked: true

                    onToggleCollapsed: internal.untrackedCollapsed = !internal.untrackedCollapsed
                    onStageFile: path => Services.GitService.stage(path)
                    onUnstageFile: path => Services.GitService.unstage(path)
                    onFileClicked: (path, staged) => root.fileClicked(path, staged)
                }

                // Empty repository guidance (T090)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: emptyRepoContent.height + 32
                    color: internal.surfaceColor
                    radius: 8
                    border.color: internal.borderColor
                    border.width: 1
                    visible: Services.GitService.hasNoCommits

                    ColumnLayout {
                        id: emptyRepoContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "\uf09b"  // Git icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 28
                                color: internal.accentColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("New Repository")
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("This repository has no commits yet.")
                                    font.pixelSize: 12
                                    color: internal.subtextColor
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: internal.borderColor
                        }

                        Text {
                            text: qsTr("To create your first commit:")
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: internal.textColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "1."
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: internal.accentColor
                                }
                                Text {
                                    text: qsTr("Add some files to your repository")
                                    font.pixelSize: 12
                                    color: internal.subtextColor
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "2."
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: internal.accentColor
                                }
                                Text {
                                    text: qsTr("Stage files using the [+] button")
                                    font.pixelSize: 12
                                    color: internal.subtextColor
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "3."
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: internal.accentColor
                                }
                                Text {
                                    text: qsTr("Write a commit message and click Commit")
                                    font.pixelSize: 12
                                    color: internal.subtextColor
                                }
                            }
                        }
                    }
                }

                // Empty state message (working tree clean)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "transparent"
                    visible: !Services.GitService.hasNoCommits &&
                             Services.GitService.stagedCount === 0 &&
                             Services.GitService.unstagedCount === 0 &&
                             Services.GitService.untrackedCount === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\uf00c"  // Checkmark
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 24
                            color: internal.stagedColor
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Working tree clean")
                            font.pixelSize: 13
                            color: internal.subtextColor
                        }
                    }
                }

                // Spacer
                Item { Layout.fillHeight: true }
            }
        }

        // =====================================================================
        // COMMIT MESSAGE AREA (T026)
        // =====================================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: commitMessageArea.implicitHeight + 24
            Layout.minimumHeight: 100
            Layout.maximumHeight: 150
            color: internal.surfaceColor
            radius: 8
            border.color: commitMessageInput.activeFocus ? internal.accentColor : internal.borderColor
            border.width: 1

            ColumnLayout {
                id: commitMessageArea
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: commitMessageInput
                        width: parent.width
                        placeholderText: qsTr("Commit message...")
                        placeholderTextColor: internal.subtextColor
                        text: root.commitMessage
                        font.pixelSize: 13
                        font.family: "monospace"
                        color: internal.textColor
                        wrapMode: TextArea.Wrap
                        selectByMouse: true

                        background: Rectangle {
                            color: "transparent"
                        }

                        onTextChanged: {
                            root.commitMessage = text
                        }

                        // Keyboard shortcut: Ctrl+Enter to commit
                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                                (event.modifiers & Qt.ControlModifier)) {
                                if (internal.canCommit()) {
                                    doCommit()
                                }
                                event.accepted = true
                            }
                        }
                    }
                }

                // Character count row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Character count indicator
                    Text {
                        id: charCountText
                        text: {
                            var firstLineLength = root.commitMessage.split('\n')[0].length
                            var color = firstLineLength > root.hardMessageLimit ? "#f38ba8" :
                                       firstLineLength > root.maxMessageLength ? "#fab387" :
                                       internal.subtextColor
                            return "<font color='" + color + "'>" + firstLineLength + "</font>" +
                                   "<font color='" + internal.subtextColor + "'>/" + root.maxMessageLength + "</font>"
                        }
                        textFormat: Text.RichText
                        font.pixelSize: 11
                    }

                    Text {
                        text: qsTr("first line")
                        font.pixelSize: 11
                        color: internal.subtextColor
                        visible: root.commitMessage.indexOf('\n') !== -1
                    }

                    Item { Layout.fillWidth: true }

                    // Ctrl+Enter hint
                    Text {
                        text: qsTr("Ctrl+Enter to commit")
                        font.pixelSize: 10
                        color: internal.subtextColor
                        visible: internal.canCommit()
                    }
                }
            }

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
        }

        // =====================================================================
        // ACTION BUTTONS ROW (T028, T030)
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Commit button (T028)
            Rectangle {
                id: commitButton
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: {
                    if (!internal.canCommit()) return internal.overlayColor
                    if (commitMouseArea.containsMouse) return Qt.lighter(internal.stagedColor, 1.1)
                    return internal.stagedColor
                }
                radius: 8
                opacity: internal.canCommit() ? 1.0 : 0.5

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    // Loading spinner when committing
                    Item {
                        width: 14
                        height: 14
                        visible: root.isCommitting

                        Text {
                            anchors.centerIn: parent
                            text: "\uf110"  // Spinner
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: internal.backgroundColor

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isCommitting
                            }
                        }
                    }

                    Text {
                        visible: !root.isCommitting
                        text: "\uf417"  // Git commit icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.backgroundColor
                    }

                    Text {
                        text: root.isCommitting ? qsTr("Committing...") : qsTr("Commit")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: internal.backgroundColor
                    }

                    // Staged count badge
                    Rectangle {
                        visible: Services.GitService.stagedCount > 0 && !root.isCommitting
                        width: stagedCountText.width + 12
                        height: 18
                        radius: 9
                        color: Qt.darker(internal.stagedColor, 1.2)

                        Text {
                            id: stagedCountText
                            anchors.centerIn: parent
                            text: Services.GitService.stagedCount.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: internal.backgroundColor
                        }
                    }
                }

                MouseArea {
                    id: commitMouseArea
                    anchors.fill: parent
                    cursorShape: internal.canCommit() ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    hoverEnabled: true
                    enabled: internal.canCommit()

                    onClicked: doCommit()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Push button (T030) - visible when ahead > 0
            Rectangle {
                id: pushButton
                Layout.preferredWidth: pushContent.width + 32
                Layout.preferredHeight: 40
                color: {
                    if (!internal.canPush()) return internal.overlayColor
                    if (pushMouseArea.containsMouse) return Qt.lighter(internal.accentColor, 1.1)
                    return internal.accentColor
                }
                radius: 8
                visible: Services.GitService.aheadCount > 0
                opacity: internal.canPush() ? 1.0 : 0.5

                RowLayout {
                    id: pushContent
                    anchors.centerIn: parent
                    spacing: 8

                    // Loading spinner when pushing
                    Item {
                        width: 14
                        height: 14
                        visible: root.isPushing

                        Text {
                            anchors.centerIn: parent
                            text: "\uf110"  // Spinner
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: internal.backgroundColor

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isPushing
                            }
                        }
                    }

                    Text {
                        visible: !root.isPushing
                        text: "\uf062"  // Arrow up icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.backgroundColor
                    }

                    Text {
                        text: root.isPushing ? qsTr("Pushing...") : qsTr("Push")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: internal.backgroundColor
                    }

                    // Ahead count badge
                    Rectangle {
                        visible: Services.GitService.aheadCount > 0 && !root.isPushing
                        width: aheadCountText.width + 12
                        height: 18
                        radius: 9
                        color: Qt.darker(internal.accentColor, 1.2)

                        Text {
                            id: aheadCountText
                            anchors.centerIn: parent
                            text: Services.GitService.aheadCount.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: internal.backgroundColor
                        }
                    }
                }

                MouseArea {
                    id: pushMouseArea
                    anchors.fill: parent
                    cursorShape: internal.canPush() ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    hoverEnabled: true
                    enabled: internal.canPush()

                    onClicked: doPush()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    // =========================================================================
    // ACTION FUNCTIONS
    // =========================================================================

    /**
     * Execute commit action
     */
    function doCommit() {
        if (!internal.canCommit()) return

        console.log("[CommitsView] Committing with message:", root.commitMessage.substring(0, 50) + "...")
        root.isCommitting = true
        Services.GitService.commit(root.commitMessage)
    }

    /**
     * Execute push action
     */
    function doPush() {
        if (!internal.canPush()) return

        console.log("[CommitsView] Pushing to remote")
        root.isPushing = true
        Services.GitService.push()
    }

    // =========================================================================
    // FILE SECTION COMPONENT (T021, T022, T036, T037)
    // =========================================================================

    component FileSection: Rectangle {
        id: sectionRoot

        // Properties
        property string sectionTitle: ""
        property int sectionCount: 0
        property color sectionColor: internal.textColor
        property bool collapsed: false
        property var files: []
        property bool isStaged: false
        property bool isUntracked: false

        // Expanded file tracking (from parent)
        property string expandedFilePath: internal.expandedFilePath
        property bool expandedFileIsStaged: internal.expandedFileIsStaged

        // Signals
        signal toggleCollapsed()
        signal stageFile(string path)
        signal unstageFile(string path)
        signal fileClicked(string path, bool staged)
        signal toggleFileExpand(string path, bool staged)

        // Layout - use Column-based approach for dynamic heights
        implicitHeight: sectionCount > 0 ? (collapsed ? headerHeight : headerHeight + contentHeight) : 0
        visible: sectionCount > 0
        color: "transparent"

        readonly property int headerHeight: 36
        readonly property int itemHeight: 36
        readonly property int expandedItemHeight: 300  // Height when diff is shown
        readonly property int contentHeight: calculateContentHeight()

        /**
         * Calculate dynamic content height based on expanded state
         */
        function calculateContentHeight() {
            let height = 8  // Padding
            for (let i = 0; i < files.length && i < 10; i++) {
                const file = files[i]
                const isExpanded = internal.isFileExpanded(file.path, isStaged)
                height += isExpanded ? expandedItemHeight : itemHeight
            }
            return height
        }

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Section Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: sectionRoot.headerHeight
                color: sectionHeaderMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // Collapse indicator
                    Text {
                        text: sectionRoot.collapsed ? "\ue5cf" : "\ue5ce"  // Chevron
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: sectionRoot.sectionColor

                        Behavior on text {
                            // No animation, instant change
                        }
                    }

                    // Section title
                    Text {
                        text: sectionRoot.sectionTitle
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: sectionRoot.sectionColor
                    }

                    // Count badge
                    Rectangle {
                        width: countText.width + 12
                        height: 20
                        radius: 10
                        color: sectionRoot.sectionColor
                        opacity: 0.2

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: sectionRoot.sectionCount.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: sectionRoot.sectionColor
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Stage/Unstage all button for section
                    Rectangle {
                        visible: !sectionRoot.isStaged && sectionRoot.sectionCount > 1
                        width: stageAllSectionContent.width + 16
                        height: 24
                        radius: 4
                        color: stageAllSectionMouse.containsMouse ? internal.overlayColor : "transparent"
                        border.color: internal.borderColor
                        border.width: 1

                        RowLayout {
                            id: stageAllSectionContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "\uf067"  // Plus
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: internal.stagedColor
                            }

                            Text {
                                text: qsTr("All")
                                font.pixelSize: 10
                                color: internal.subtextColor
                            }
                        }

                        MouseArea {
                            id: stageAllSectionMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                for (var i = 0; i < sectionRoot.files.length; i++) {
                                    sectionRoot.stageFile(sectionRoot.files[i].path)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: sectionHeaderMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    propagateComposedEvents: true

                    onClicked: sectionRoot.toggleCollapsed()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // File List (collapsible)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: sectionRoot.collapsed ? 0 : sectionRoot.contentHeight
                clip: true
                visible: !sectionRoot.collapsed

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ListView {
                    id: fileListView
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    model: sectionRoot.files
                    interactive: sectionRoot.files.length > 10
                    clip: true

                    // T093: Performance optimization for large file lists
                    cacheBuffer: 400

                    delegate: FileItemDelegate {
                        width: fileListView.width
                        // Dynamic height based on expansion (T036, T037)
                        height: isExpanded ? sectionRoot.expandedItemHeight : sectionRoot.itemHeight
                        filePath: modelData.path
                        fileStatus: modelData.status
                        statusLabel: modelData.statusLabel
                        isConflict: modelData.isConflict || false
                        isStaged: sectionRoot.isStaged
                        isUntracked: sectionRoot.isUntracked
                        // Pass expanded state
                        isExpanded: internal.isFileExpanded(modelData.path, sectionRoot.isStaged)

                        onStageClicked: sectionRoot.stageFile(filePath)
                        onUnstageClicked: sectionRoot.unstageFile(filePath)
                        onFileClicked: sectionRoot.fileClicked(filePath, sectionRoot.isStaged)
                        onToggleExpand: internal.toggleFileExpansion(filePath, sectionRoot.isStaged)

                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // FILE ITEM DELEGATE COMPONENT (T022, T036, T037)
    // =========================================================================

    component FileItemDelegate: Rectangle {
        id: fileItemRoot

        // Properties
        property string filePath: ""
        property string fileStatus: ""
        property string statusLabel: ""
        property bool isConflict: false
        property bool isStaged: false
        property bool isUntracked: false
        property bool isExpanded: false  // T036: Expansion state

        // Signals
        signal stageClicked()
        signal unstageClicked()
        signal fileClicked()
        signal toggleExpand()  // T036: Toggle expansion

        // Appearance
        color: fileItemMouseArea.containsMouse && !isExpanded ?
               internal.overlayColor : "transparent"
        radius: 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // File info row (always visible)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: fileItemRoot.isExpanded ? internal.surfaceColor :
                       (fileInfoMouseArea.containsMouse ? internal.overlayColor : "transparent")
                radius: fileItemRoot.isExpanded ? 4 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Status icon
                    Text {
                        text: internal.getStatusIcon(fileItemRoot.fileStatus)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: fileItemRoot.isConflict ? internal.conflictColor :
                               internal.getStatusColor(fileItemRoot.fileStatus)
                    }

                    // Directory path (dimmed)
                    Text {
                        text: internal.getDirectory(fileItemRoot.filePath)
                        font.pixelSize: 12
                        color: internal.subtextColor
                        elide: Text.ElideLeft
                        Layout.maximumWidth: 150
                        visible: text.length > 0
                    }

                    // Filename
                    Text {
                        Layout.fillWidth: true
                        text: internal.getFilename(fileItemRoot.filePath)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: fileItemRoot.isConflict ? internal.conflictColor : internal.textColor
                        elide: Text.ElideMiddle
                    }

                    // Conflict indicator
                    Text {
                        visible: fileItemRoot.isConflict
                        text: "\uf071"  // Warning triangle
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 11
                        color: internal.conflictColor
                    }

                    // Stage button [+] (for unstaged/untracked files)
                    Rectangle {
                        id: stageButton
                        visible: !fileItemRoot.isStaged
                        width: 24
                        height: 24
                        radius: 4
                        color: stageButtonMouse.containsMouse ? internal.stagedColor : internal.surfaceColor
                        border.color: internal.stagedColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf067"  // Plus
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 11
                            color: stageButtonMouse.containsMouse ? internal.backgroundColor : internal.stagedColor
                        }

                        MouseArea {
                            id: stageButtonMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                fileItemRoot.stageClicked()
                            }
                        }

                        ToolTip {
                            visible: stageButtonMouse.containsMouse
                            text: qsTr("Stage file")
                            delay: 500
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Unstage button [-] (for staged files)
                    Rectangle {
                        id: unstageButton
                        visible: fileItemRoot.isStaged
                        width: 24
                        height: 24
                        radius: 4
                        color: unstageButtonMouse.containsMouse ? internal.unstagedColor : internal.surfaceColor
                        border.color: internal.unstagedColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf068"  // Minus
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 11
                            color: unstageButtonMouse.containsMouse ? internal.backgroundColor : internal.unstagedColor
                        }

                        MouseArea {
                            id: unstageButtonMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                fileItemRoot.unstageClicked()
                            }
                        }

                        ToolTip {
                            visible: unstageButtonMouse.containsMouse
                            text: qsTr("Unstage file")
                            delay: 500
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Expand/Collapse button (T036)
                    Rectangle {
                        id: expandButton
                        width: 24
                        height: 24
                        radius: 4
                        color: expandButtonMouse.containsMouse ? internal.overlayColor : "transparent"

                        Text {
                            id: expandChevron
                            anchors.centerIn: parent
                            text: "\ue5cf"  // Chevron
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: fileItemRoot.isExpanded ? internal.accentColor : internal.subtextColor
                            // Rotate chevron when expanded (T036)
                            rotation: fileItemRoot.isExpanded ? 90 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            id: expandButtonMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                fileItemRoot.toggleExpand()
                            }
                        }

                        ToolTip {
                            visible: expandButtonMouse.containsMouse
                            text: fileItemRoot.isExpanded ? qsTr("Hide diff") : qsTr("View diff")
                            delay: 500
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                MouseArea {
                    id: fileInfoMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    acceptedButtons: Qt.NoButton
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Inline DiffViewer (T037) - shown when expanded
            Loader {
                id: diffViewerLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                active: fileItemRoot.isExpanded
                visible: fileItemRoot.isExpanded

                sourceComponent: DiffViewer {
                    filePath: fileItemRoot.filePath
                    isStaged: fileItemRoot.isStaged
                    maxLines: 500

                    Component.onCompleted: {
                        // Auto-load diff when component is created
                        loadDiff()
                    }
                }
            }
        }

        MouseArea {
            id: fileItemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
            z: -1  // Behind everything
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[CommitsView] Initialized")
    }

    Component.onDestruction: {
        console.log("[CommitsView] Destroyed")
    }
}
