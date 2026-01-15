/**
 * IssuesView.qml - GitHub Issues List View Component
 *
 * Displays a searchable, filterable list of GitHub issues with pagination.
 * Features:
 * - Search/filter input for filtering issues by title
 * - State filter tabs (Open/Closed/All)
 * - Issue list with number, title, state icon, labels, comment count
 * - "New Issue" button opening create form
 * - Pagination via "Load More" button (infinite scroll pattern)
 * - Loading, empty, and unauthenticated state handling
 * - Offline state messaging
 *
 * Tasks Implemented:
 * - T050: Create Components/IssuesView.qml with issue list and search/filter
 * - T052: Implement issue list delegate with number, title, status indicator, labels
 * - T059: Implement "New Issue" button opening create form in IssueEditor
 * - T063: Implement pagination for issue lists (load more on scroll)
 * - T065: Handle offline/unauthenticated state with appropriate messaging
 *
 * @see specs/001-quick-git-plugin/spec.md (US3)
 * @see specs/001-quick-git-plugin/data-model.md (Issue entity)
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
     * Filter text for filtering issues by title
     */
    property string filterText: ""

    /**
     * Current state filter ("open", "closed", "all")
     */
    property string stateFilter: "open"

    /**
     * Repository owner (from git remote)
     */
    property string owner: ""

    /**
     * Repository name (from git remote)
     */
    property string repo: ""

    /**
     * Number of issues to load per page
     */
    property int pageSize: 30

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when an issue is selected/clicked
     * @param issue - The issue object that was clicked
     */
    signal issueSelected(var issue)

    /**
     * Emitted when "New Issue" is clicked
     */
    signal createIssueRequested()

    /**
     * Emitted when issue list is successfully loaded
     * @param count - Number of issues loaded
     */
    signal issuesLoaded(int count)

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

        // =====================================================================
        // COLORBLIND-ACCESSIBLE ISSUE STATE COLORS (T081)
        // =====================================================================

        // Get current palette from SettingsService
        readonly property string currentPalette: Services.SettingsService.colorblindPalette

        // Palette definitions for open state colors (Catppuccin Mocha based)
        readonly property var openColors: ({
            "shapes":       "#a6e3a1",  // Green (default)
            "highcontrast": "#00ff00",  // Bright green
            "deuteranopia": "#89b4fa",  // Blue (avoid red/green)
            "protanopia":   "#a6e3a1"   // Green (safe for protanopia)
        })

        // Palette definitions for closed state colors
        readonly property var closedColors: ({
            "shapes":       "#cba6f7",  // Purple/Mauve (default)
            "highcontrast": "#ff00ff",  // Magenta
            "deuteranopia": "#f5c2e7",  // Pink (distinct from blue)
            "protanopia":   "#cba6f7"   // Purple
        })

        // Dynamic colors based on current palette
        readonly property color openColor: openColors[currentPalette] || openColors["shapes"]
        readonly property color closedColor: closedColors[currentPalette] || closedColors["shapes"]
        readonly property color closedNotPlannedColor: "#6c7086"  // Gray (always same)

        // Status colors (not affected by palette)
        readonly property color errorColor: "#f38ba8"      // Red
        readonly property color warningColor: "#fab387"    // Peach

        // Issues data
        property var issues: []
        property bool isLoading: false
        property int currentPage: 1
        property bool hasMore: true
        property string error: ""

        // Selected issue for expanded view
        property var selectedIssue: null
        property bool showEditor: false

        // Create issue mode
        property bool isCreatingIssue: false

        /**
         * Filter issues by search text
         */
        function filteredIssues() {
            if (!root.filterText || root.filterText.length === 0) {
                return issues
            }
            const filter = root.filterText.toLowerCase()
            return issues.filter(issue => {
                return issue.title.toLowerCase().includes(filter) ||
                       (issue.number && issue.number.toString().includes(filter)) ||
                       (issue.labels && issue.labels.some(l => l.name.toLowerCase().includes(filter)))
            })
        }

        /**
         * Get state icon for issue
         */
        function getStateIcon(issue) {
            if (issue.state === "open") {
                return "\uf41b"  // Issue open icon
            } else {
                if (issue.state_reason === "not_planned") {
                    return "\uf52a"  // X circle - not planned
                }
                return "\uf058"  // Checkmark circle - completed
            }
        }

        /**
         * Get state color for issue
         */
        function getStateColor(issue) {
            if (issue.state === "open") {
                return openColor
            } else {
                if (issue.state_reason === "not_planned") {
                    return closedNotPlannedColor
                }
                return closedColor
            }
        }

        /**
         * Format relative time from ISO date string
         */
        function formatRelativeTime(dateString) {
            if (!dateString) return ""

            const date = new Date(dateString)
            const now = new Date()
            const diffMs = now - date
            const diffMins = Math.floor(diffMs / 60000)
            const diffHours = Math.floor(diffMs / 3600000)
            const diffDays = Math.floor(diffMs / 86400000)

            if (diffMins < 1) return qsTr("just now")
            if (diffMins < 60) return qsTr("%1m ago").arg(diffMins)
            if (diffHours < 24) return qsTr("%1h ago").arg(diffHours)
            if (diffDays < 7) return qsTr("%1d ago").arg(diffDays)
            if (diffDays < 30) return qsTr("%1w ago").arg(Math.floor(diffDays / 7))

            // Format as date for older issues
            return date.toLocaleDateString(Qt.locale(), "MMM d")
        }

        /**
         * Get contrasting text color for label background
         */
        function getLabelTextColor(hexColor) {
            if (!hexColor) return textColor

            // Remove # if present
            const hex = hexColor.replace("#", "")

            // Parse RGB values
            const r = parseInt(hex.substring(0, 2), 16)
            const g = parseInt(hex.substring(2, 4), 16)
            const b = parseInt(hex.substring(4, 6), 16)

            // Calculate luminance
            const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

            // Return black or white based on luminance
            return luminance > 0.5 ? "#1e1e2e" : "#ffffff"
        }

        /**
         * Load issues from GitHub API
         */
        function loadIssues(append) {
            if (isLoading) return
            if (!Services.GitHubService.isAuthenticated) {
                console.log("[IssuesView] Not authenticated, skipping load")
                return
            }

            if (!root.owner || !root.repo) {
                console.log("[IssuesView] No owner/repo configured")
                error = qsTr("No GitHub remote configured")
                return
            }

            console.log("[IssuesView] Loading issues page:", append ? currentPage + 1 : 1,
                       "state:", root.stateFilter)

            isLoading = true
            error = ""

            if (!append) {
                currentPage = 1
                issues = []
                hasMore = true
            } else {
                currentPage++
            }

            Services.GitHubService.listIssues(root.owner, root.repo, {
                state: root.stateFilter,
                page: currentPage,
                perPage: root.pageSize
            })
        }

        /**
         * Refresh issues (reload from page 1)
         */
        function refresh() {
            loadIssues(false)
        }

        /**
         * Load more issues (next page)
         */
        function loadMore() {
            if (!hasMore || isLoading) return
            loadIssues(true)
        }

        /**
         * Select an issue to view in editor
         */
        function selectIssue(issue) {
            selectedIssue = issue
            isCreatingIssue = false
            showEditor = true
            root.issueSelected(issue)
        }

        /**
         * Start creating a new issue
         */
        function startCreateIssue() {
            selectedIssue = null
            isCreatingIssue = true
            showEditor = true
            root.createIssueRequested()
        }

        /**
         * Close the editor panel
         */
        function closeEditor() {
            showEditor = false
            selectedIssue = null
            isCreatingIssue = false
        }
    }

    // =========================================================================
    // SERVICE CONNECTIONS
    // =========================================================================

    Connections {
        target: Services.GitHubService

        function onIssuesLoaded(loadedIssues) {
            console.log("[IssuesView] Received", loadedIssues.length, "issues")
            internal.isLoading = false

            if (internal.currentPage === 1) {
                internal.issues = loadedIssues
            } else {
                // Append to existing issues
                internal.issues = internal.issues.concat(loadedIssues)
            }

            // Check if there are more issues to load
            internal.hasMore = loadedIssues.length >= root.pageSize

            root.issuesLoaded(internal.issues.length)
        }

        function onErrorOccurred(message) {
            if (internal.isLoading) {
                internal.isLoading = false
                internal.error = message
                console.error("[IssuesView] Error:", message)
            }
        }

        function onIssueUpdated(issue) {
            // Update the issue in our list
            for (let i = 0; i < internal.issues.length; i++) {
                if (internal.issues[i].number === issue.number) {
                    internal.issues[i] = issue
                    internal.issues = internal.issues.slice() // Trigger update
                    break
                }
            }
        }

        function onAuthStateChanged(state) {
            // Reload issues when authentication changes
            if (state === "authenticated") {
                internal.refresh()
            } else if (state === "idle" || state === "error") {
                internal.issues = []
            }
        }
    }

    // =========================================================================
    // PROPERTY WATCHERS
    // =========================================================================

    onStateFilterChanged: {
        // Reload issues when filter changes
        internal.refresh()
    }

    onOwnerChanged: {
        if (owner && repo) internal.refresh()
    }

    onRepoChanged: {
        if (owner && repo) internal.refresh()
    }

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // HEADER: Search, Filters, New Issue Button
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Search/Filter Input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: internal.surfaceColor
                radius: 6
                border.color: issueSearchInput.activeFocus ? internal.accentColor : internal.borderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "\uf002"  // Search icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }

                    TextInput {
                        id: issueSearchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 13
                        color: internal.textColor
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 0
                            verticalAlignment: Text.AlignVCenter
                            text: qsTr("Search issues...")
                            font.pixelSize: 13
                            color: internal.subtextColor
                            visible: !issueSearchInput.text && !issueSearchInput.activeFocus
                        }

                        onTextChanged: {
                            root.filterText = text
                        }
                    }

                    // Clear button
                    Text {
                        visible: issueSearchInput.text.length > 0
                        text: "\uf00d"  // X icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 10
                        color: internal.subtextColor

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                issueSearchInput.text = ""
                                issueSearchInput.forceActiveFocus()
                            }
                        }
                    }
                }

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }

            // State Filter Toggle
            Rectangle {
                id: stateFilterContainer
                Layout.preferredWidth: stateFilterRow.width + 8
                Layout.preferredHeight: 36
                color: internal.surfaceColor
                radius: 6
                border.color: internal.borderColor
                border.width: 1

                RowLayout {
                    id: stateFilterRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Open filter
                    Rectangle {
                        id: openFilter
                        width: openFilterContent.width + 16
                        height: 28
                        radius: 4
                        color: root.stateFilter === "open" ? internal.openColor : "transparent"

                        RowLayout {
                            id: openFilterContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "\uf41b"  // Issue icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 11
                                color: root.stateFilter === "open" ? internal.backgroundColor : internal.openColor
                            }

                            Text {
                                text: qsTr("Open")
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.stateFilter === "open" ? internal.backgroundColor : internal.textColor
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stateFilter = "open"
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Closed filter
                    Rectangle {
                        id: closedFilter
                        width: closedFilterContent.width + 16
                        height: 28
                        radius: 4
                        color: root.stateFilter === "closed" ? internal.closedColor : "transparent"

                        RowLayout {
                            id: closedFilterContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "\uf058"  // Check circle
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 11
                                color: root.stateFilter === "closed" ? internal.backgroundColor : internal.closedColor
                            }

                            Text {
                                text: qsTr("Closed")
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.stateFilter === "closed" ? internal.backgroundColor : internal.textColor
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stateFilter = "closed"
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // All filter
                    Rectangle {
                        id: allFilter
                        width: allFilterContent.width + 16
                        height: 28
                        radius: 4
                        color: root.stateFilter === "all" ? internal.accentColor : "transparent"

                        Text {
                            id: allFilterContent
                            anchors.centerIn: parent
                            text: qsTr("All")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.stateFilter === "all" ? internal.backgroundColor : internal.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stateFilter = "all"
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }

            // New Issue Button (T059)
            Rectangle {
                id: newIssueButton
                Layout.preferredWidth: newIssueContent.width + 24
                Layout.preferredHeight: 36
                radius: 6
                color: newIssueMouseArea.containsMouse ?
                    Qt.lighter(internal.accentColor, 1.1) : internal.accentColor
                visible: Services.GitHubService.isAuthenticated

                RowLayout {
                    id: newIssueContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "\uf067"  // Plus icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: internal.backgroundColor
                    }

                    Text {
                        text: qsTr("New Issue")
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: internal.backgroundColor
                    }
                }

                MouseArea {
                    id: newIssueMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        console.log("[IssuesView] New Issue clicked")
                        internal.startCreateIssue()
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Refresh button
            Rectangle {
                id: refreshButton
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
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
                        running: internal.isLoading
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !internal.isLoading

                    onClicked: {
                        console.log("[IssuesView] Refresh clicked")
                        internal.refresh()
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // =====================================================================
        // CONTENT AREA: Issue List + Editor Split
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // -----------------------------------------------------------------
            // LEFT: Issue List
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: !internal.showEditor
                Layout.preferredWidth: internal.showEditor ? 300 : 0
                Layout.minimumWidth: internal.showEditor ? 280 : 0
                Layout.fillHeight: true
                color: "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Unauthenticated State (T065)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !Services.GitHubService.isAuthenticated

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16
                            width: parent.width * 0.8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf09b"  // GitHub icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 48
                                color: internal.subtextColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Sign in to GitHub")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: internal.textColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: qsTr("Connect your GitHub account to view and manage issues.")
                                font.pixelSize: 13
                                color: internal.subtextColor
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // Hint to use the auth button
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    text: "\uf0a7"  // Hand pointing
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 12
                                    color: internal.accentColor
                                }

                                Text {
                                    text: qsTr("Click the GitHub button in the footer to sign in")
                                    font.pixelSize: 12
                                    color: internal.accentColor
                                }
                            }
                        }
                    }

                    // No Remote Configured
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Services.GitHubService.isAuthenticated &&
                                (!root.owner || !root.repo)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf126"  // Git branch
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 48
                                color: internal.subtextColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("No GitHub Remote")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: internal.textColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("This repository doesn't have a GitHub remote configured.")
                                font.pixelSize: 13
                                color: internal.subtextColor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Error State
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Services.GitHubService.isAuthenticated &&
                                root.owner && root.repo &&
                                internal.error.length > 0 &&
                                !internal.isLoading &&
                                internal.issues.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf071"  // Warning
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 48
                                color: internal.errorColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Failed to Load Issues")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: internal.textColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: internal.error
                                font.pixelSize: 13
                                color: internal.subtextColor
                            }

                            // Retry button
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: retryContent.width + 24
                                height: 36
                                radius: 6
                                color: retryMouseArea.containsMouse ?
                                    internal.overlayColor : internal.surfaceColor
                                border.color: internal.borderColor
                                border.width: 1

                                RowLayout {
                                    id: retryContent
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "\uf021"  // Refresh
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: internal.textColor
                                    }

                                    Text {
                                        text: qsTr("Retry")
                                        font.pixelSize: 12
                                        color: internal.textColor
                                    }
                                }

                                MouseArea {
                                    id: retryMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: internal.refresh()
                                }
                            }
                        }
                    }

                    // Loading State (initial)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Services.GitHubService.isAuthenticated &&
                                root.owner && root.repo &&
                                internal.isLoading &&
                                internal.issues.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                id: loadingSpinner
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf110"  // Spinner
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 32
                                color: internal.accentColor

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: true
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Loading issues...")
                                font.pixelSize: 14
                                color: internal.subtextColor
                            }
                        }
                    }

                    // Empty State
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Services.GitHubService.isAuthenticated &&
                                root.owner && root.repo &&
                                !internal.isLoading &&
                                internal.error.length === 0 &&
                                internal.issues.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf41b"  // Issue icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 48
                                color: internal.subtextColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.stateFilter === "open" ?
                                    qsTr("No open issues") :
                                    root.stateFilter === "closed" ?
                                        qsTr("No closed issues") :
                                        qsTr("No issues")
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: internal.textColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Create a new issue to get started")
                                font.pixelSize: 13
                                color: internal.subtextColor
                            }
                        }
                    }

                    // Issue List (T052)
                    ScrollView {
                        id: issueListScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: Services.GitHubService.isAuthenticated &&
                                root.owner && root.repo &&
                                internal.issues.length > 0

                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ListView {
                            id: issueListView
                            anchors.fill: parent
                            model: internal.filteredIssues()
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds

                            // T093: Performance optimization for 100+ items
                            cacheBuffer: 600

                            // Detect scroll to bottom for pagination (T063)
                            onAtYEndChanged: {
                                if (atYEnd && internal.hasMore && !internal.isLoading) {
                                    console.log("[IssuesView] Reached bottom, loading more...")
                                    internal.loadMore()
                                }
                            }

                            delegate: IssueDelegate {
                                width: issueListView.width
                                issue: modelData
                                isSelected: internal.selectedIssue &&
                                           internal.selectedIssue.number === modelData.number

                                onClicked: {
                                    internal.selectIssue(modelData)
                                }
                            }

                            // Footer: Load More / Loading indicator
                            footer: Item {
                                width: issueListView.width
                                height: internal.hasMore ? 48 : 0
                                visible: internal.hasMore

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 8
                                    color: loadMoreMouse.containsMouse ?
                                        internal.overlayColor : internal.surfaceColor
                                    radius: 6
                                    border.color: internal.borderColor
                                    border.width: 1
                                    visible: !internal.isLoading

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Load more...")
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                    }

                                    MouseArea {
                                        id: loadMoreMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: internal.loadMore()
                                    }
                                }

                                // Loading spinner
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: internal.isLoading

                                    Text {
                                        text: "\uf110"  // Spinner
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 14
                                        color: internal.subtextColor

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: internal.isLoading
                                        }
                                    }

                                    Text {
                                        text: qsTr("Loading...")
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // RIGHT: Issue Editor (expanded view)
            // -----------------------------------------------------------------

            Loader {
                id: editorLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: internal.showEditor
                visible: internal.showEditor

                sourceComponent: IssueEditor {
                    issue: internal.selectedIssue
                    isCreating: internal.isCreatingIssue
                    owner: root.owner
                    repo: root.repo

                    onClose: {
                        internal.closeEditor()
                    }

                    onIssueCreated: newIssue => {
                        console.log("[IssuesView] Issue created:", newIssue.number)
                        // Refresh the list to include the new issue
                        internal.refresh()
                        internal.closeEditor()
                    }

                    onIssueUpdated: updatedIssue => {
                        console.log("[IssuesView] Issue updated:", updatedIssue.number)
                        // Update in list
                        for (let i = 0; i < internal.issues.length; i++) {
                            if (internal.issues[i].number === updatedIssue.number) {
                                internal.issues[i] = updatedIssue
                                internal.issues = internal.issues.slice()
                                break
                            }
                        }
                        internal.selectedIssue = updatedIssue
                    }
                }
            }
        }
    }

    // =========================================================================
    // ISSUE DELEGATE COMPONENT (T052)
    // =========================================================================

    component IssueDelegate: Rectangle {
        id: delegateRoot

        // Properties
        property var issue: ({})
        property bool isSelected: false

        // Signals
        signal clicked()

        // Appearance
        height: issueContent.height + 16
        color: isSelected ? Qt.alpha(internal.accentColor, 0.15) :
               delegateMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
        radius: 6
        border.color: isSelected ? internal.accentColor : "transparent"
        border.width: isSelected ? 1 : 0

        ColumnLayout {
            id: issueContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            // Top row: State icon, Title, Comment count
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // State icon
                Text {
                    text: internal.getStateIcon(issue)
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: internal.getStateColor(issue)
                }

                // Issue number
                Text {
                    text: "#" + (issue.number || "")
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: internal.subtextColor
                }

                // Title
                Text {
                    Layout.fillWidth: true
                    text: issue.title || ""
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: internal.textColor
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                // Comment count
                RowLayout {
                    visible: (issue.comments || 0) > 0
                    spacing: 4

                    Text {
                        text: "\uf075"  // Comment icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 11
                        color: internal.subtextColor
                    }

                    Text {
                        text: issue.comments || 0
                        font.pixelSize: 11
                        color: internal.subtextColor
                    }
                }
            }

            // Bottom row: Labels, Author, Time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Labels
                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: issue.labels || []

                        Rectangle {
                            width: labelText.width + 10
                            height: 18
                            radius: 9
                            color: "#" + (modelData.color || "6c7086")

                            Text {
                                id: labelText
                                anchors.centerIn: parent
                                text: modelData.name || ""
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: internal.getLabelTextColor(modelData.color)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Author avatar + login
                RowLayout {
                    spacing: 4

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: internal.overlayColor
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: issue.user ? issue.user.avatar_url : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready

                            layer.enabled: true
                            layer.effect: Item {}
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !parent.children[0].visible
                            text: "\uf007"  // User icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 8
                            color: internal.subtextColor
                        }
                    }

                    Text {
                        text: issue.user ? issue.user.login : ""
                        font.pixelSize: 11
                        color: internal.subtextColor
                        elide: Text.ElideRight
                        Layout.maximumWidth: 80
                    }
                }

                // Relative time
                Text {
                    text: internal.formatRelativeTime(issue.updated_at || issue.created_at)
                    font.pixelSize: 11
                    color: internal.subtextColor
                }
            }
        }

        MouseArea {
            id: delegateMouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                delegateRoot.clicked()
            }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[IssuesView] Initialized")

        // Load issues if authenticated and repo is configured
        if (Services.GitHubService.isAuthenticated && root.owner && root.repo) {
            internal.refresh()
        }
    }

    Component.onDestruction: {
        console.log("[IssuesView] Destroyed")
    }
}
