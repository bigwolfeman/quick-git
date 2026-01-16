/**
 * Panel.qml - Slide-Down Panel Container for Quick-Git
 *
 * This component provides:
 * - Slide-down animation from top of screen
 * - Header with repository selector, view toggle, and search
 * - Lazy-loaded child views (Issues/Commits) via Loader
 * - Keyboard navigation and escape to close
 * - Loading state indicator
 * - Outside click to close behavior
 * - GitHub authentication UI with device code flow (T046-T049)
 *
 * Task: T013 - Create Panel.qml slide-down container with view toggle and header layout
 * Task: T046 - Add auth UI showing device code and instructions during flow
 * Task: T047 - Add GitHub icon button in Panel footer with auth state indicator
 * Task: T048 - Show "Connected as @username" with avatar when authenticated
 * Task: T049 - Handle auth errors (expired, denied, rate limited) with user-friendly messages
 *
 * Views:
 * - "issues": GitHub issues for the current repository
 * - "commits": Recent commit history
 *
 * Usage:
 *   Panel {
 *       id: gitPanel
 *       onOpened: console.log("Panel opened")
 *       onViewChanged: view => console.log("View:", view)
 *   }
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "Services" as Services
import "Components" as Components

/**
 * Note: In Noctalia, this would extend Widgets.NPanel
 * For now, we use PanelWindow directly for Quickshell compatibility
 * NPanel integration can be added when Noctalia is the target environment
 */
PanelWindow {
    id: panel

    // =========================================================================
    // PANEL IDENTIFICATION
    // =========================================================================

    objectName: "quick-git-panel"

    // =========================================================================
    // POSITIONING
    // =========================================================================

    // Anchor to top of screen for slide-down behavior
    anchors {
        top: true
        left: true
        right: true
    }

    // Panel dimensions
    implicitHeight: internal.panelHeight
    exclusiveZone: 0  // Don't reserve space when closed

    // Render above normal windows
    aboveWindows: true

    // Accept keyboard focus for escape key handling
    focusable: true

    // Visibility controlled by isOpen state
    visible: isOpen || slideAnimation.running

    // =========================================================================
    // PUBLIC PROPERTIES (from contract)
    // =========================================================================

    /**
     * Current active view
     * Valid values: "issues" | "commits"
     */
    property string currentView: internal.initialView

    /**
     * Whether the panel is open/visible
     */
    property bool isOpen: false

    /**
     * Whether data is currently loading
     * Bound to service loading states
     */
    property bool isLoading: Services.GitService.isRefreshing

    /**
     * Current search/filter text
     */
    property string filterText: ""

    /**
     * Reference to main instance for service access
     */
    property var mainInstance: null

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when panel opens
     */
    signal opened()

    /**
     * Emitted when panel closes
     */
    signal closed()

    /**
     * Emitted when view changes
     * @param view - The new view name ("issues" | "commits")
     */
    signal viewChanged(string view)

    /**
     * Emitted when search is requested
     * @param query - The search query text
     */
    signal searchRequested(string query)

    // =========================================================================
    // PUBLIC METHODS
    // =========================================================================

    /**
     * Open the panel with slide-down animation
     */
    function open() {
        if (isOpen) return
        console.log("[Panel] Opening panel")
        isOpen = true
        slideAnimation.to = 0
        slideAnimation.start()
        panel.forceActiveFocus()
        opened()
    }

    /**
     * Close the panel with slide-up animation
     */
    function close() {
        if (!isOpen) return
        console.log("[Panel] Closing panel")
        slideAnimation.to = -internal.panelHeight
        slideAnimation.start()
        isOpen = false
        closed()
    }

    /**
     * Toggle panel open/closed state
     */
    function toggle() {
        if (isOpen) {
            close()
        } else {
            open()
        }
    }

    /**
     * Switch to a specific view
     * @param view - View name ("issues" | "commits")
     */
    function setView(view) {
        if (!internal.isValidView(view)) {
            console.warn("[Panel] Invalid view:", view)
            return
        }

        if (currentView !== view) {
            console.log("[Panel] Switching view to:", view)
            currentView = view
            viewChanged(view)
        }
    }

    // =========================================================================
    // INTERNAL STATE
    // =========================================================================

    QtObject {
        id: internal

        // Panel dimensions
        readonly property int panelHeight: 500
        readonly property int headerHeight: 56
        readonly property int contentTopMargin: 8

        // Animation timing
        readonly property int animationDuration: 250

        // Color palette (Catppuccin Mocha inspired)
        readonly property color backgroundColor: "#1e1e2e"
        readonly property color surfaceColor: "#313244"
        readonly property color overlayColor: "#45475a"
        readonly property color textColor: "#cdd6f4"
        readonly property color subtextColor: "#a6adc8"
        readonly property color accentColor: "#89b4fa"
        readonly property color accentDimColor: "#585b70"
        readonly property color borderColor: "#45475a"

        // GitHub auth colors (T047)
        readonly property color githubIconNormal: "#cdd6f4"
        readonly property color githubIconHover: "#89b4fa"
        readonly property color githubIconAuthenticated: "#a6e3a1"
        readonly property color errorColor: "#f38ba8"
        readonly property color warningColor: "#fab387"

        // Footer dimensions
        readonly property int footerHeight: 40

        // Valid views
        readonly property var validViews: ["issues", "commits"]

        // Initial view from settings
        readonly property string initialView: Services.SettingsService.defaultView || "commits"

        // Check if GitHub is available for issues view
        readonly property bool issuesAvailable: Services.GitHubService.isAuthenticated

        // GitHub repository info (T064 - parsed from git remote)
        property string gitHubOwner: ""
        property string gitHubRepo: ""
        property string remoteUrl: ""

        /**
         * Parse GitHub owner and repo from remote URL (T064)
         * Supports formats:
         * - https://github.com/owner/repo.git
         * - https://github.com/owner/repo
         * - git@github.com:owner/repo.git
         * - git@github.com:owner/repo
         *
         * @param url - The git remote URL
         */
        function parseGitHubRemote(url) {
            if (!url) {
                gitHubOwner = ""
                gitHubRepo = ""
                return
            }

            // HTTPS format: https://github.com/owner/repo.git
            let match = url.match(/github\.com[/:]([^/]+)\/([^/.]+)(?:\.git)?/)
            if (match) {
                gitHubOwner = match[1]
                gitHubRepo = match[2]
                console.log("[Panel] Parsed GitHub remote:", gitHubOwner + "/" + gitHubRepo)
                return
            }

            // Not a GitHub URL
            console.log("[Panel] Remote is not a GitHub URL:", url)
            gitHubOwner = ""
            gitHubRepo = ""
        }

        /**
         * Get user-friendly error message (T049)
         * @param errorCode - Error string from GitHubService
         * @returns User-friendly message
         */
        function getAuthErrorMessage(errorCode) {
            if (!errorCode) return ""

            // Map error codes to user-friendly messages
            if (errorCode.indexOf("expired") !== -1 || errorCode.indexOf("Code expired") !== -1) {
                return qsTr("The code has expired. Please try again.")
            }
            if (errorCode.indexOf("denied") !== -1 || errorCode.indexOf("Access denied") !== -1) {
                return qsTr("Access was denied. Please authorize the app on GitHub.")
            }
            if (errorCode.indexOf("rate") !== -1 || errorCode.indexOf("Rate limit") !== -1) {
                return qsTr("Rate limit exceeded. Please wait a moment and try again.")
            }
            if (errorCode.indexOf("Network") !== -1 || errorCode.indexOf("connection") !== -1) {
                return qsTr("Network error. Please check your internet connection.")
            }
            if (errorCode.indexOf("Invalid client") !== -1 || errorCode.indexOf("client_id") !== -1) {
                return qsTr("Configuration error. Please check the OAuth app settings.")
            }
            if (errorCode.indexOf("Session expired") !== -1 || errorCode.indexOf("log in again") !== -1) {
                return qsTr("Your session has expired. Please sign in again.")
            }
            // Fallback to the original error message
            return errorCode
        }

        /**
         * Validate view name
         */
        function isValidView(view) {
            return validViews.indexOf(view) !== -1
        }

        /**
         * Get view display label
         */
        function getViewLabel(view) {
            switch (view) {
                case "issues": return qsTr("Issues")
                case "commits": return qsTr("Commits")
                default: return view
            }
        }
    }

    // =========================================================================
    // SLIDE ANIMATION
    // =========================================================================

    /**
     * Y position for slide animation
     * -panelHeight when closed, 0 when open
     */
    property real slideY: isOpen ? 0 : -internal.panelHeight

    NumberAnimation {
        id: slideAnimation
        target: panel
        property: "slideY"
        duration: internal.animationDuration
        easing.type: Easing.OutCubic
    }

    // =========================================================================
    // KEYBOARD HANDLING
    // =========================================================================

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            // Close dropdowns first before closing panel
            if (repoSelector.dropdownOpen) {
                repoSelector.close()
            } else if (userDropdown.visible) {
                userDropdown.visible = false
            } else {
                close()
            }
        }
    }

    // =========================================================================
    // PANEL CONTENT
    // =========================================================================

    Rectangle {
        id: panelBackground
        anchors.fill: parent
        y: panel.slideY
        color: internal.backgroundColor
        radius: 12

        // Clip content to rounded corners
        clip: true

        // Bottom border only (panel is at top)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: internal.borderColor
        }

        // =====================================================================
        // MAIN LAYOUT
        // =====================================================================

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // =================================================================
            // HEADER
            // =================================================================

            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: internal.headerHeight
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    // ---------------------------------------------------------
                    // LEFT: Repository Selector (T072)
                    // ---------------------------------------------------------

                    Components.RepoSelector {
                        id: repoSelector
                        Layout.preferredWidth: 180
                        Layout.fillHeight: true
                        buttonWidth: 180
                        buttonHeight: internal.headerHeight

                        onRepoSelected: path => {
                            console.log("[Panel] Repository selected:", path)
                            // Fetch remote URL for new repo
                            if (Services.GitService.isRepo) {
                                remoteUrlProcess.command = ["git", "-C", path, "remote", "get-url", "origin"]
                                remoteUrlProcess.running = true
                            }
                        }

                        onDropdownToggled: isOpen => {
                            console.log("[Panel] Repo selector dropdown:", isOpen ? "opened" : "closed")
                            // Close other dropdowns when this opens
                            if (isOpen) {
                                userDropdown.visible = false
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // CENTER: View Toggle Buttons
                    // ---------------------------------------------------------

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                id: viewToggleBackground
                                width: viewToggleRow.width + 8
                                height: 36
                                color: internal.surfaceColor
                                radius: 8
                                border.color: internal.borderColor
                                border.width: 1

                                RowLayout {
                                    id: viewToggleRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    // Issues button
                                    Rectangle {
                                        id: issuesButton
                                        width: issuesButtonContent.width + 24
                                        height: 28
                                        radius: 6
                                        color: panel.currentView === "issues" ? internal.accentColor : "transparent"

                                        RowLayout {
                                            id: issuesButtonContent
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf41b"  // GitHub issue icon
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 12
                                                color: panel.currentView === "issues" ? internal.backgroundColor : internal.textColor
                                            }

                                            Text {
                                                text: qsTr("Issues")
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: panel.currentView === "issues" ? internal.backgroundColor : internal.textColor
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: panel.setView("issues")
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    // Commits button
                                    Rectangle {
                                        id: commitsButton
                                        width: commitsButtonContent.width + 24
                                        height: 28
                                        radius: 6
                                        color: panel.currentView === "commits" ? internal.accentColor : "transparent"

                                        RowLayout {
                                            id: commitsButtonContent
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf417"  // Git commit icon
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 12
                                                color: panel.currentView === "commits" ? internal.backgroundColor : internal.textColor
                                            }

                                            Text {
                                                text: qsTr("Commits")
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: panel.currentView === "commits" ? internal.backgroundColor : internal.textColor
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: panel.setView("commits")
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // RIGHT: Search Input and Settings
                    // ---------------------------------------------------------

                    Rectangle {
                        id: searchContainer
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        color: internal.surfaceColor
                        radius: 8
                        border.color: searchInput.activeFocus ? internal.accentColor : internal.borderColor
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            // Search icon
                            Text {
                                text: "\uf002"  // Search icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.subtextColor
                            }

                            // Search input
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 13
                                color: internal.textColor
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Search...")
                                    font.pixelSize: 13
                                    color: internal.subtextColor
                                    visible: !searchInput.text && !searchInput.activeFocus
                                }

                                onTextChanged: {
                                    panel.filterText = text
                                }

                                onAccepted: {
                                    panel.searchRequested(text)
                                }

                                // Debounced search as you type
                                Timer {
                                    id: searchDebounce
                                    interval: 300
                                    onTriggered: panel.searchRequested(searchInput.text)
                                }

                                onTextEdited: {
                                    searchDebounce.restart()
                                }
                            }

                            // Clear button
                            Text {
                                visible: searchInput.text.length > 0
                                text: "\uf00d"  // X icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: internal.subtextColor

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = ""
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Settings gear button
                    Rectangle {
                        id: settingsButton
                        Layout.preferredWidth: 40
                        Layout.fillHeight: true
                        color: settingsMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013"  // Gear icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: internal.textColor
                        }

                        MouseArea {
                            id: settingsMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                console.log("[Panel] Settings clicked - opening settings panel")
                                settingsOverlay.visible = true
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Close button
                    Rectangle {
                        id: closeButton
                        Layout.preferredWidth: 40
                        Layout.fillHeight: true
                        color: closeMouseArea.containsMouse ? "#f38ba8" : internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"  // X icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: closeMouseArea.containsMouse ? internal.backgroundColor : internal.textColor
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: panel.close()
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }

            // =================================================================
            // LOADING INDICATOR
            // =================================================================

            Rectangle {
                id: loadingBar
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: internal.surfaceColor
                visible: panel.isLoading

                Rectangle {
                    id: loadingIndicator
                    width: parent.width * 0.3
                    height: parent.height
                    color: internal.accentColor
                    radius: 1

                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: panel.isLoading

                        NumberAnimation {
                            from: -loadingIndicator.width
                            to: loadingBar.width
                            duration: 1000
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // =================================================================
            // CONTENT AREA (Lazy-loaded views)
            // =================================================================

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Status message when no repo (T085)
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: !Services.GitService.isRepo

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        width: Math.min(350, parent.width - 48)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\ue5fb"  // Folder open icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 48
                            color: internal.subtextColor
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Not a Git Repository")
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            color: internal.textColor
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: qsTr("The current directory is not a git repository.")
                            font.pixelSize: 13
                            color: internal.subtextColor
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        // Guidance section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: guidanceColumn.height + 24
                            color: internal.surfaceColor
                            radius: 8
                            border.color: internal.borderColor
                            border.width: 1

                            ColumnLayout {
                                id: guidanceColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 12
                                spacing: 12

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("To get started:")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }

                                // Option 1: Use repo selector
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "\uf07c"  // Folder icon
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 14
                                        color: internal.accentColor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Use the repository selector dropdown to switch to a git repository")
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Option 2: Terminal
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "\ue795"  // Terminal icon
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 14
                                        color: internal.accentColor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Or open a terminal in a git repository folder")
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Option 3: git init
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "\uf418"  // Git icon
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 14
                                        color: internal.accentColor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Run 'git init' to create a new repository here")
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                // View container with Loader for lazy loading
                Item {
                    anchors.fill: parent
                    visible: Services.GitService.isRepo

                    // Issues View Loader (T050, T052, T059, T063, T064, T065)
                    Loader {
                        id: issuesViewLoader
                        anchors.fill: parent
                        active: panel.currentView === "issues"
                        visible: active

                        // Load the IssuesView component
                        sourceComponent: Components.IssuesView {
                            filterText: panel.filterText
                            owner: internal.gitHubOwner
                            repo: internal.gitHubRepo

                            onIssueSelected: issue => {
                                console.log("[Panel] Issue selected:", issue.number, issue.title)
                            }

                            onCreateIssueRequested: {
                                console.log("[Panel] Create issue requested")
                            }

                            onIssuesLoaded: count => {
                                console.log("[Panel] Issues loaded:", count)
                            }
                        }
                    }

                    // Commits View Loader (T021-T031)
                    Loader {
                        id: commitsViewLoader
                        anchors.fill: parent
                        active: panel.currentView === "commits"
                        visible: active

                        // Load the CommitsView component
                        sourceComponent: Components.CommitsView {
                            filterText: panel.filterText

                            onCommitSucceeded: sha => {
                                console.log("[Panel] Commit succeeded:", sha)
                            }

                            onPushSucceeded: {
                                console.log("[Panel] Push succeeded")
                            }

                            onFileClicked: (filePath, isStaged) => {
                                console.log("[Panel] File clicked:", filePath, "staged:", isStaged)
                                // TODO: Show diff view for file
                            }
                        }
                    }
                }
            }

            // =================================================================
            // FOOTER (T047 - GitHub Auth Button)
            // =================================================================

            Rectangle {
                id: footer
                Layout.fillWidth: true
                Layout.preferredHeight: internal.footerHeight
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Settings gear button in footer (T082)
                    Rectangle {
                        id: footerSettingsButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: footerSettingsMouseArea.containsMouse ?
                            internal.overlayColor : internal.surfaceColor
                        border.color: internal.borderColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013"  // Gear icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: footerSettingsMouseArea.containsMouse ?
                                internal.accentColor : internal.textColor
                        }

                        MouseArea {
                            id: footerSettingsMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                console.log("[Panel] Footer settings clicked - opening settings panel")
                                settingsOverlay.visible = true
                            }
                        }

                        ToolTip {
                            visible: footerSettingsMouseArea.containsMouse
                            text: qsTr("Settings")
                            delay: 500
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Spacer to push GitHub button to the right
                    Item {
                        Layout.fillWidth: true
                    }

                    // GitHub Auth Button (T047)
                    Rectangle {
                        id: githubAuthButton
                        Layout.preferredWidth: Services.GitHubService.isAuthenticated ?
                            githubAuthButtonContent.width + 24 : 40
                        Layout.preferredHeight: 32
                        radius: 8
                        color: githubAuthMouseArea.containsMouse ?
                            internal.overlayColor : internal.surfaceColor
                        border.color: internal.borderColor
                        border.width: 1

                        // Pulsing animation for error/needs-reauth state
                        SequentialAnimation on opacity {
                            id: pulseAnimation
                            running: Services.GitHubService.authState === "error"
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1.0
                                to: 0.5
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                from: 0.5
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                        }

                        RowLayout {
                            id: githubAuthButtonContent
                            anchors.centerIn: parent
                            spacing: 8

                            // GitHub icon
                            Text {
                                text: "\uf09b"  // GitHub icon (Nerd Font)
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: {
                                    if (Services.GitHubService.authState === "error") {
                                        return internal.errorColor
                                    }
                                    if (Services.GitHubService.isAuthenticated) {
                                        return internal.githubIconAuthenticated
                                    }
                                    if (githubAuthMouseArea.containsMouse) {
                                        return internal.githubIconHover
                                    }
                                    return internal.githubIconNormal
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Auth status indicator dot
                            Rectangle {
                                visible: Services.GitHubService.isAuthenticated ||
                                         Services.GitHubService.authState === "polling" ||
                                         Services.GitHubService.authState === "awaiting_code"
                                width: 6
                                height: 6
                                radius: 3
                                color: {
                                    if (Services.GitHubService.isAuthenticated) {
                                        return internal.githubIconAuthenticated
                                    }
                                    if (Services.GitHubService.authState === "polling" ||
                                        Services.GitHubService.authState === "awaiting_code") {
                                        return internal.warningColor
                                    }
                                    return internal.subtextColor
                                }

                                // Pulsing animation during auth flow
                                SequentialAnimation on opacity {
                                    running: Services.GitHubService.authState === "polling" ||
                                             Services.GitHubService.authState === "awaiting_code"
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                                }
                            }

                            // Connected username (T048)
                            Text {
                                visible: Services.GitHubService.isAuthenticated
                                text: "@" + Services.GitHubService.username
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.textColor
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: githubAuthMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                if (Services.GitHubService.isAuthenticated) {
                                    // Show user dropdown
                                    userDropdown.visible = !userDropdown.visible
                                } else if (Services.GitHubService.authState === "polling" ||
                                           Services.GitHubService.authState === "awaiting_code") {
                                    // Auth in progress - show overlay
                                    authOverlay.visible = true
                                } else {
                                    // Start auth flow
                                    authOverlay.visible = true
                                    Services.GitHubService.startAuth()
                                }
                            }
                        }

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // BACKDROP BLUR EFFECT (visual enhancement)
        // =====================================================================

        // Note: Actual blur depends on compositor support
        // This provides a fallback semi-transparent overlay
        layer.enabled: true
        layer.effect: Item {
            // Placeholder for MultiEffect blur when available
            // MultiEffect {
            //     source: panelBackground
            //     anchors.fill: parent
            //     blurEnabled: true
            //     blur: 0.3
            // }
        }

        // =====================================================================
        // USER DROPDOWN (T048 - Connected as @username with avatar)
        // =====================================================================

        Rectangle {
            id: userDropdown
            visible: false
            width: 220
            height: userDropdownContent.height + 24

            // Position above the GitHub button
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: internal.footerHeight + 8

            color: internal.surfaceColor
            radius: 12
            border.color: internal.borderColor
            border.width: 1

            // Drop shadow
            layer.enabled: true
            layer.effect: Item {
                // Note: Replace with DropShadow when available
            }

            ColumnLayout {
                id: userDropdownContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                // User info row (T048)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Avatar
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: internal.overlayColor
                        clip: true

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: Services.GitHubService.avatarUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready

                            // Circular mask
                            layer.enabled: true
                            layer.effect: Item {
                                // Note: Add OpacityMask for circular clipping
                            }
                        }

                        // Fallback icon when no avatar
                        Text {
                            anchors.centerIn: parent
                            visible: avatarImage.status !== Image.Ready
                            text: "\uf007"  // User icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                            color: internal.subtextColor
                        }
                    }

                    // Username and connection status
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "@" + Services.GitHubService.username
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: internal.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 4

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: internal.githubIconAuthenticated
                            }

                            Text {
                                text: qsTr("Connected")
                                font.pixelSize: 11
                                color: internal.subtextColor
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: internal.borderColor
                }

                // Disconnect button
                Rectangle {
                    id: disconnectButton
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: disconnectMouseArea.containsMouse ?
                        Qt.alpha(internal.errorColor, 0.2) : "transparent"
                    border.color: disconnectMouseArea.containsMouse ?
                        internal.errorColor : internal.borderColor
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\uf2f5"  // Sign out icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: disconnectMouseArea.containsMouse ?
                                internal.errorColor : internal.subtextColor
                        }

                        Text {
                            text: qsTr("Disconnect")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: disconnectMouseArea.containsMouse ?
                                internal.errorColor : internal.textColor
                        }
                    }

                    MouseArea {
                        id: disconnectMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            Services.GitHubService.logout()
                            userDropdown.visible = false
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            // Close dropdown when clicking outside
            Behavior on visible {
                PropertyAnimation { duration: 150 }
            }
        }

        // Click-away handler for user dropdown
        MouseArea {
            anchors.fill: parent
            visible: userDropdown.visible
            z: -1
            onClicked: userDropdown.visible = false
        }

        // Click-away handler for repo selector dropdown (T072)
        MouseArea {
            anchors.fill: parent
            visible: repoSelector.dropdownOpen
            z: -1
            onClicked: repoSelector.close()
        }

        // =====================================================================
        // AUTH OVERLAY (T046 - Device code flow UI)
        // =====================================================================

        Rectangle {
            id: authOverlay
            visible: false
            anchors.fill: parent
            color: Qt.alpha(internal.backgroundColor, 0.95)
            z: 100

            // Close on escape
            Keys.onEscapePressed: {
                if (Services.GitHubService.authState === "polling" ||
                    Services.GitHubService.authState === "awaiting_code") {
                    Services.GitHubService.cancelAuth()
                }
                authOverlay.visible = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // Clicking outside the dialog doesn't close during auth
                    // Only clicking cancel button or pressing escape
                }
            }

            // Auth dialog content
            Rectangle {
                id: authDialog
                width: 380
                height: authDialogContent.height + 48
                anchors.centerIn: parent
                color: internal.surfaceColor
                radius: 16
                border.color: internal.borderColor
                border.width: 1

                ColumnLayout {
                    id: authDialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 20

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "\uf09b"  // GitHub icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 28
                            color: internal.textColor
                        }

                        Text {
                            text: qsTr("Sign in to GitHub")
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: internal.textColor
                            Layout.fillWidth: true
                        }

                        // Close button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: authCloseMouseArea.containsMouse ?
                                internal.overlayColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"  // X icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.subtextColor
                            }

                            MouseArea {
                                id: authCloseMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    if (Services.GitHubService.authState === "polling" ||
                                        Services.GitHubService.authState === "awaiting_code") {
                                        Services.GitHubService.cancelAuth()
                                    }
                                    authOverlay.visible = false
                                }
                            }
                        }
                    }

                    // Error state (T049)
                    Rectangle {
                        id: errorBanner
                        visible: Services.GitHubService.authState === "error"
                        Layout.fillWidth: true
                        height: errorBannerContent.height + 16
                        radius: 8
                        color: Qt.alpha(internal.errorColor, 0.15)
                        border.color: Qt.alpha(internal.errorColor, 0.3)
                        border.width: 1

                        RowLayout {
                            id: errorBannerContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                text: "\uf071"  // Warning icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: internal.errorColor
                            }

                            Text {
                                Layout.fillWidth: true
                                text: internal.getAuthErrorMessage(Services.GitHubService.error)
                                font.pixelSize: 13
                                color: internal.errorColor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Idle/Initial state - instructions
                    ColumnLayout {
                        visible: Services.GitHubService.authState === "idle" ||
                                 Services.GitHubService.authState === "error"
                        Layout.fillWidth: true
                        spacing: 16

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Connect your GitHub account to access issues, create pull requests, and more.")
                            font.pixelSize: 14
                            color: internal.subtextColor
                            wrapMode: Text.WordWrap
                            lineHeight: 1.4
                        }

                        // Start auth button
                        Rectangle {
                            id: startAuthButton
                            Layout.fillWidth: true
                            height: 44
                            radius: 8
                            color: startAuthMouseArea.containsMouse ?
                                Qt.lighter(internal.accentColor, 1.1) : internal.accentColor

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "\uf09b"  // GitHub icon
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 16
                                    color: internal.backgroundColor
                                }

                                Text {
                                    text: Services.GitHubService.authState === "error" ?
                                        qsTr("Try Again") : qsTr("Connect with GitHub")
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: internal.backgroundColor
                                }
                            }

                            MouseArea {
                                id: startAuthMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    Services.GitHubService.startAuth()
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Awaiting code / Polling state - show device code (T046)
                    ColumnLayout {
                        visible: Services.GitHubService.authState === "awaiting_code" ||
                                 Services.GitHubService.authState === "polling"
                        Layout.fillWidth: true
                        spacing: 16

                        // Step 1: Visit URL
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Step 1: Visit")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.subtextColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 8
                                color: internal.overlayColor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: "\uf0c1"  // Link icon
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: internal.accentColor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: Services.GitHubService.verificationUrl ||
                                              "github.com/login/device"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: internal.accentColor
                                        elide: Text.ElideMiddle
                                    }

                                    // Copy button
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 6
                                        color: copyUrlMouseArea.containsMouse ?
                                            internal.surfaceColor : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf0c5"  // Copy icon
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 12
                                            color: internal.subtextColor
                                        }

                                        MouseArea {
                                            id: copyUrlMouseArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true

                                            onClicked: {
                                                // Copy URL to clipboard
                                                // Note: Requires clipboard integration
                                                console.log("[Panel] Copy URL to clipboard:",
                                                    Services.GitHubService.verificationUrl)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Step 2: Enter code (PROMINENT DISPLAY)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Step 2: Enter this code")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.subtextColor
                            }

                            // Large user code display
                            Rectangle {
                                Layout.fillWidth: true
                                height: 72
                                radius: 12
                                color: internal.backgroundColor
                                border.color: internal.accentColor
                                border.width: 2

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    // User code - large and prominent
                                    Text {
                                        Layout.fillWidth: true
                                        text: Services.GitHubService.userCode || "----"
                                        font.pixelSize: 32
                                        font.weight: Font.Bold
                                        font.family: "monospace"
                                        font.letterSpacing: 4
                                        horizontalAlignment: Text.AlignHCenter
                                        color: internal.textColor
                                    }

                                    // Copy code button
                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 8
                                        color: copyCodeMouseArea.containsMouse ?
                                            internal.overlayColor : internal.surfaceColor

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf0c5"  // Copy icon
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 16
                                            color: internal.textColor
                                        }

                                        MouseArea {
                                            id: copyCodeMouseArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true

                                            onClicked: {
                                                // Copy code to clipboard
                                                console.log("[Panel] Copy code to clipboard:",
                                                    Services.GitHubService.userCode)
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }

                        // Waiting status with spinner
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            // Spinner animation
                            Item {
                                width: 20
                                height: 20

                                Text {
                                    id: spinnerIcon
                                    anchors.centerIn: parent
                                    text: "\uf110"  // Spinner icon
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 16
                                    color: internal.accentColor

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: Services.GitHubService.authState === "polling"
                                    }
                                }
                            }

                            Text {
                                text: Services.GitHubService.authState === "awaiting_code" ?
                                    qsTr("Generating code...") :
                                    qsTr("Waiting for authorization...")
                                font.pixelSize: 13
                                color: internal.subtextColor
                            }
                        }

                        // Cancel button
                        Rectangle {
                            id: cancelAuthButton
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: cancelAuthMouseArea.containsMouse ?
                                internal.overlayColor : "transparent"
                            border.color: internal.borderColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Cancel")
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: internal.subtextColor
                            }

                            MouseArea {
                                id: cancelAuthMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    Services.GitHubService.cancelAuth()
                                    authOverlay.visible = false
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Success state (brief flash before overlay closes)
                    ColumnLayout {
                        visible: Services.GitHubService.authState === "authenticated" &&
                                 authOverlay.visible
                        Layout.fillWidth: true
                        spacing: 16

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "\uf058"  // Checkmark circle icon
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 36
                                    color: internal.githubIconAuthenticated
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: qsTr("Connected as @%1").arg(
                                        Services.GitHubService.username)
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }
                            }
                        }
                    }
                }
            }

            // Auto-close overlay on successful authentication
            Connections {
                target: Services.GitHubService

                function onAuthenticated(username) {
                    console.log("[Panel] Auth success, closing overlay in 1.5s")
                    authSuccessCloseTimer.start()
                }

                function onAuthFailed(error) {
                    console.log("[Panel] Auth failed:", error)
                    // Keep overlay open to show error
                }
            }

            Timer {
                id: authSuccessCloseTimer
                interval: 1500
                repeat: false
                onTriggered: {
                    authOverlay.visible = false
                }
            }

            // Fade in/out animation
            Behavior on visible {
                PropertyAnimation {
                    property: "opacity"
                    from: authOverlay.visible ? 0 : 1
                    to: authOverlay.visible ? 1 : 0
                    duration: 200
                }
            }
        }

        // =====================================================================
        // SETTINGS OVERLAY (T082 - Settings Panel)
        // =====================================================================

        Rectangle {
            id: settingsOverlay
            visible: false
            anchors.fill: parent
            color: Qt.alpha(internal.backgroundColor, 0.85)
            z: 150

            // Close on escape
            Keys.onEscapePressed: {
                settingsOverlay.visible = false
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    settingsOverlay.visible = false
                }
            }

            // Settings panel container
            Rectangle {
                id: settingsPanel
                width: Math.min(450, parent.width - 48)
                height: Math.min(550, parent.height - 48)
                anchors.centerIn: parent
                color: "transparent"

                // Prevent clicks on the panel from closing overlay
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Consume the click - don't close
                    }
                }

                // Settings component
                Settings {
                    id: settingsContent
                    anchors.fill: parent
                    isOpen: settingsOverlay.visible

                    onCloseRequested: {
                        settingsOverlay.visible = false
                    }
                }

                // Drop shadow effect
                layer.enabled: true
                layer.effect: Item {
                    // Placeholder for DropShadow if available
                }
            }

            // Fade in/out animation
            Behavior on visible {
                PropertyAnimation {
                    property: "opacity"
                    from: settingsOverlay.visible ? 0 : 1
                    to: settingsOverlay.visible ? 1 : 0
                    duration: 200
                }
            }
        }
    }

    // =========================================================================
    // CLICK-OUTSIDE HANDLER
    // =========================================================================

    // Note: This requires the panel to span full screen width
    // A proper implementation would use a separate overlay window
    // For now, close button and escape key are the primary close methods

    // =========================================================================
    // VIEW CHANGE EFFECTS
    // =========================================================================

    Behavior on currentView {
        enabled: false  // Instant switch, loaders handle transitions
    }

    onCurrentViewChanged: {
        console.log("[Panel] View changed to:", currentView)
        // Clear search when switching views (optional UX choice)
        // searchInput.text = ""
    }

    // =========================================================================
    // SERVICE BINDINGS
    // =========================================================================

    // Refresh on panel open if repo is valid
    onIsOpenChanged: {
        if (isOpen && Services.GitService.isRepo) {
            Services.GitService.refresh()
        }
    }

    // =========================================================================
    // REMOTE URL FETCHING (T064)
    // =========================================================================

    /**
     * Process: Get GitHub remote URL for issues
     * Uses: git remote get-url origin
     */
    Process {
        id: remoteUrlProcess
        running: false

        property string stdoutText: ""
        property string stderrText: ""

        command: ["git", "-C", Services.GitService.repoPath, "remote", "get-url", "origin"]

        stdout: StdioCollector {
            onCollected: text => {
                remoteUrlProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                remoteUrlProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const url = stdoutText.trim()
                console.log("[Panel] Remote URL:", url)
                internal.remoteUrl = url
                internal.parseGitHubRemote(url)
            } else {
                console.log("[Panel] No remote configured or error fetching remote")
                internal.remoteUrl = ""
                internal.gitHubOwner = ""
                internal.gitHubRepo = ""
            }
            stdoutText = ""
            stderrText = ""
        }
    }

    // Track last repo path to detect changes
    property string _lastRepoPath: ""

    /**
     * Fetch remote URL when repository is valid and manage recent repos
     */
    Connections {
        target: Services.GitService

        function onStatusChanged() {
            if (Services.GitService.isRepo && !remoteUrlProcess.running) {
                // Only fetch if we haven't already
                if (internal.remoteUrl === "") {
                    remoteUrlProcess.command = ["git", "-C", Services.GitService.repoPath, "remote", "get-url", "origin"]
                    remoteUrlProcess.running = true
                }
            }

            // Add newly validated repos to recent list (T071 integration)
            if (Services.GitService.isRepo && Services.GitService.repoPath) {
                const newPath = Services.GitService.repoPath
                if (newPath !== panel._lastRepoPath) {
                    console.log("[Panel] New valid repo detected, adding to recent:", newPath)
                    Services.SettingsService.addRecentRepo(newPath)
                    panel._lastRepoPath = newPath
                    // Also reset remote URL so we fetch for the new repo
                    internal.remoteUrl = ""
                    internal.gitHubOwner = ""
                    internal.gitHubRepo = ""
                }
            }
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[Panel] Initialized")
        console.log("[Panel] Default view:", internal.initialView)

        // Start with panel closed (slide position)
        slideY = -internal.panelHeight

        // Fetch remote URL if repo is already valid
        if (Services.GitService.isRepo) {
            remoteUrlProcess.command = ["git", "-C", Services.GitService.repoPath, "remote", "get-url", "origin"]
            remoteUrlProcess.running = true
        }
    }

    Component.onDestruction: {
        console.log("[Panel] Destroyed")
    }
}
