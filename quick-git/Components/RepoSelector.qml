/**
 * RepoSelector.qml - Repository Selector Dropdown Component
 *
 * This component provides:
 * - Dropdown button showing current repository name and branch
 * - Dropdown menu with recently accessed repositories
 * - Text input to add new repository paths
 * - Path validation (must contain .git/)
 * - Repository switching via GitService.setRepository()
 *
 * Tasks Implemented:
 * - T066: Create Components/RepoSelector.qml dropdown component
 * - T067: Implement recent repos list from SettingsService.recentRepos
 * - T068: Add repo selection handler that calls GitService.setRepository()
 * - T069: Implement path input for adding new repos to recent list
 * - T070: Validate repo path (must contain .git/) before adding
 *
 * @see specs/001-quick-git-plugin/spec.md (US6)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../Services" as Services

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    /**
     * Button width - can be set by parent
     */
    property real buttonWidth: 180

    /**
     * Button height - can be set by parent
     */
    property real buttonHeight: 56

    /**
     * Whether the dropdown is currently open
     */
    property bool dropdownOpen: false

    // =========================================================================
    // COMPUTED PROPERTIES
    // =========================================================================

    /**
     * Extract repository name from path (last component)
     */
    readonly property string repoName: {
        if (!Services.GitService.repoPath) return ""
        const parts = Services.GitService.repoPath.split("/")
        // Filter empty parts and get last non-empty component
        for (let i = parts.length - 1; i >= 0; i--) {
            if (parts[i] && parts[i].length > 0) {
                return parts[i]
            }
        }
        return ""
    }

    /**
     * Display text for button - repo name or "No repo"
     */
    readonly property string displayText: {
        if (Services.GitService.isRepo && repoName) {
            return repoName
        }
        return qsTr("Select Repository")
    }

    // =========================================================================
    // SIGNALS
    // =========================================================================

    /**
     * Emitted when a repository is selected
     * @param path - Absolute path to the repository
     */
    signal repoSelected(string path)

    /**
     * Emitted when dropdown opens or closes
     * @param isOpen - New open state
     */
    signal dropdownToggled(bool isOpen)

    // =========================================================================
    // LAYOUT
    // =========================================================================

    implicitWidth: buttonWidth
    implicitHeight: buttonHeight

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
        readonly property color errorColor: "#f38ba8"
        readonly property color successColor: "#a6e3a1"
        readonly property color warningColor: "#fab387"

        // Dropdown dimensions
        readonly property int dropdownWidth: 320
        readonly property int maxDropdownHeight: 400
        readonly property int repoItemHeight: 44
        readonly property int inputHeight: 44

        // Error state
        property string errorMessage: ""
        property bool showError: false

        // Input state
        property string inputPath: ""
        property bool isValidating: false

        /**
         * Extract repo name from a path
         */
        function getRepoName(path) {
            if (!path) return ""
            const parts = path.split("/")
            for (let i = parts.length - 1; i >= 0; i--) {
                if (parts[i] && parts[i].length > 0) {
                    return parts[i]
                }
            }
            return path
        }

        /**
         * Clear error state
         */
        function clearError() {
            errorMessage = ""
            showError = false
        }

        /**
         * Show error message
         */
        function setError(msg) {
            errorMessage = msg
            showError = true
            errorClearTimer.restart()
        }

        /**
         * Validate and add repository path
         * First validates that the path contains .git/
         */
        function validateAndAddRepo(path) {
            if (!path || path.trim().length === 0) {
                setError(qsTr("Please enter a path"))
                return
            }

            const trimmedPath = path.trim()
            // Remove trailing slashes
            const normalizedPath = trimmedPath.replace(/\/+$/, "")

            console.log("[RepoSelector] Validating path:", normalizedPath)
            isValidating = true
            clearError()

            // Start validation process
            validateProcess.pathToValidate = normalizedPath
            validateProcess.command = ["git", "-C", normalizedPath, "rev-parse", "--git-dir"]
            validateProcess.running = true
        }

        /**
         * Select a repository
         */
        function selectRepo(path) {
            console.log("[RepoSelector] Selecting repository:", path)
            clearError()

            // Call GitService to switch repository
            if (Services.GitService.setRepository(path)) {
                // Add to recent repos on successful switch
                Services.SettingsService.addRecentRepo(path)
                root.repoSelected(path)
                root.dropdownOpen = false
            }
        }

        /**
         * Remove repository from recent list
         */
        function removeRepo(path) {
            console.log("[RepoSelector] Removing from recent:", path)
            Services.SettingsService.removeRecentRepo(path)
        }
    }

    // Timer to clear error after a few seconds
    Timer {
        id: errorClearTimer
        interval: 5000
        repeat: false
        onTriggered: internal.clearError()
    }

    // =========================================================================
    // VALIDATION PROCESS (T070)
    // =========================================================================

    /**
     * Process: Validate repository path
     * Uses: git rev-parse --git-dir
     */
    Process {
        id: validateProcess
        running: false

        property string pathToValidate: ""
        property string stderrText: ""

        stderr: StdioCollector {
            onCollected: text => {
                validateProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            internal.isValidating = false

            if (exitCode === 0) {
                console.log("[RepoSelector] Valid git repository:", pathToValidate)
                // Path is valid - select it
                internal.selectRepo(pathToValidate)
                internal.inputPath = ""
            } else {
                console.log("[RepoSelector] Invalid path:", pathToValidate)
                internal.setError(qsTr("Not a valid git repository"))
            }

            stderrText = ""
        }
    }

    // =========================================================================
    // DROPDOWN BUTTON (T066)
    // =========================================================================

    Rectangle {
        id: dropdownButton
        anchors.fill: parent
        color: buttonMouseArea.containsMouse ? internal.overlayColor : internal.surfaceColor
        radius: 8
        border.color: root.dropdownOpen ? internal.accentColor : internal.borderColor
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            // Git branch icon
            Text {
                text: "\ue725"  // Git branch icon (Nerd Font)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: internal.accentColor
            }

            // Repository and branch info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                // Repo name
                Text {
                    Layout.fillWidth: true
                    text: root.displayText
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Services.GitService.isRepo ? internal.textColor : internal.subtextColor
                    elide: Text.ElideMiddle
                }

                // Branch name (when repo is valid)
                Text {
                    Layout.fillWidth: true
                    visible: Services.GitService.isRepo && Services.GitService.branch
                    text: Services.GitService.branch
                    font.pixelSize: 11
                    color: internal.subtextColor
                    elide: Text.ElideMiddle
                }
            }

            // Dropdown arrow
            Text {
                text: root.dropdownOpen ? "\ue5ce" : "\ue5cf"  // Chevron up/down
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: internal.subtextColor

                Behavior on text {
                    PropertyAnimation { duration: 0 }
                }
            }
        }

        MouseArea {
            id: buttonMouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                root.dropdownOpen = !root.dropdownOpen
                root.dropdownToggled(root.dropdownOpen)
                if (root.dropdownOpen) {
                    internal.clearError()
                }
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
    // DROPDOWN MENU (T067, T068, T069)
    // =========================================================================

    Rectangle {
        id: dropdownMenu
        visible: root.dropdownOpen
        width: internal.dropdownWidth
        height: Math.min(dropdownContent.height + 16, internal.maxDropdownHeight)

        // Position below the button
        anchors.top: dropdownButton.bottom
        anchors.topMargin: 4
        anchors.left: dropdownButton.left

        color: internal.surfaceColor
        radius: 12
        border.color: internal.borderColor
        border.width: 1

        // Drop shadow effect
        layer.enabled: true
        layer.effect: Item {
            // Note: Add DropShadow when available
        }

        // Click outside to close
        Connections {
            target: root
            function onDropdownOpenChanged() {
                if (!root.dropdownOpen) {
                    internal.inputPath = ""
                    internal.clearError()
                }
            }
        }

        ColumnLayout {
            id: dropdownContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 4

            // -----------------------------------------------------------------
            // HEADER: Current Repository Info
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 48 : 0
                visible: Services.GitService.isRepo
                color: internal.overlayColor
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Current repo icon
                    Text {
                        text: "\uf07c"  // Folder open icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.successColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: root.repoName
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: internal.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 6

                            Text {
                                text: "\ue725"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: internal.accentColor
                            }

                            Text {
                                text: Services.GitService.branch
                                font.pixelSize: 11
                                color: internal.subtextColor
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Status indicator
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: {
                            if (Services.GitService.hasChanges) {
                                return internal.warningColor
                            }
                            return internal.successColor
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // SEPARATOR
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                visible: Services.GitService.isRepo && recentReposList.count > 0
                color: internal.borderColor
            }

            // -----------------------------------------------------------------
            // SECTION HEADER: Recent Repositories
            // -----------------------------------------------------------------

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                visible: recentReposList.count > 0
                text: qsTr("Recent Repositories")
                font.pixelSize: 11
                font.weight: Font.Medium
                color: internal.subtextColor
            }

            // -----------------------------------------------------------------
            // RECENT REPOS LIST (T067)
            // -----------------------------------------------------------------

            ListView {
                id: recentReposList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count * internal.repoItemHeight, 220)
                clip: true
                interactive: count * internal.repoItemHeight > 220

                // T093: Performance optimization for smooth scrolling
                cacheBuffer: 200

                model: Services.SettingsService.recentRepos

                delegate: Rectangle {
                    id: repoDelegate
                    width: recentReposList.width
                    height: internal.repoItemHeight
                    radius: 6
                    color: {
                        if (modelData === Services.GitService.repoPath) {
                            return Qt.alpha(internal.accentColor, 0.15)
                        }
                        if (repoMouseArea.containsMouse) {
                            return internal.overlayColor
                        }
                        return "transparent"
                    }

                    property string repoPath: modelData
                    property string repoDisplayName: internal.getRepoName(modelData)
                    property bool isCurrentRepo: modelData === Services.GitService.repoPath

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        // Repo icon
                        Text {
                            text: repoDelegate.isCurrentRepo ? "\uf00c" : "\uf07b"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: repoDelegate.isCurrentRepo ? internal.accentColor : internal.subtextColor
                        }

                        // Repo info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: repoDelegate.repoDisplayName
                                font.pixelSize: 13
                                font.weight: repoDelegate.isCurrentRepo ? Font.Medium : Font.Normal
                                color: internal.textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: repoDelegate.repoPath
                                font.pixelSize: 10
                                color: internal.subtextColor
                                elide: Text.ElideMiddle
                            }
                        }

                        // Remove button
                        Rectangle {
                            id: removeButton
                            width: 24
                            height: 24
                            radius: 4
                            visible: removeMouseArea.containsMouse || repoMouseArea.containsMouse
                            color: removeMouseArea.containsMouse ? Qt.alpha(internal.errorColor, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: removeMouseArea.containsMouse ? internal.errorColor : internal.subtextColor
                            }

                            MouseArea {
                                id: removeMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    internal.removeRepo(repoDelegate.repoPath)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: repoMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 32  // Leave space for remove button
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            if (!repoDelegate.isCurrentRepo) {
                                internal.selectRepo(repoDelegate.repoPath)
                            }
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }

                // Empty state
                Rectangle {
                    anchors.fill: parent
                    visible: recentReposList.count === 0
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("No recent repositories")
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }
                }
            }

            // -----------------------------------------------------------------
            // SEPARATOR
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: internal.borderColor
            }

            // -----------------------------------------------------------------
            // ADD REPOSITORY INPUT (T069, T070)
            // -----------------------------------------------------------------

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                text: qsTr("Add Repository")
                font.pixelSize: 11
                font.weight: Font.Medium
                color: internal.subtextColor
            }

            // Path input row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: internal.inputHeight
                    radius: 8
                    color: internal.overlayColor
                    border.color: {
                        if (internal.showError) return internal.errorColor
                        if (pathInput.activeFocus) return internal.accentColor
                        return "transparent"
                    }
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        // Folder icon
                        Text {
                            text: "\uf07b"  // Folder icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: internal.subtextColor
                        }

                        // Path input field
                        TextInput {
                            id: pathInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 12
                            color: internal.textColor
                            clip: true
                            selectByMouse: true

                            text: internal.inputPath

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: qsTr("/path/to/repository")
                                font.pixelSize: 12
                                color: Qt.alpha(internal.subtextColor, 0.6)
                                visible: !pathInput.text && !pathInput.activeFocus
                            }

                            onTextChanged: {
                                internal.inputPath = text
                                internal.clearError()
                            }

                            onAccepted: {
                                internal.validateAndAddRepo(text)
                            }

                            // Keyboard focus when dropdown opens
                            Component.onCompleted: {
                                if (root.dropdownOpen) {
                                    forceActiveFocus()
                                }
                            }
                        }

                        // Loading indicator
                        Text {
                            visible: internal.isValidating
                            text: "\uf110"  // Spinner
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: internal.accentColor

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: internal.isValidating
                            }
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }

                // Add button
                Rectangle {
                    id: addButton
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: internal.inputHeight
                    radius: 8
                    color: {
                        if (internal.isValidating) return internal.surfaceColor
                        if (addButtonMouseArea.containsMouse) return internal.accentColor
                        return internal.overlayColor
                    }
                    opacity: internal.isValidating ? 0.5 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "\uf067"  // Plus icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: addButtonMouseArea.containsMouse && !internal.isValidating ?
                            internal.backgroundColor : internal.textColor
                    }

                    MouseArea {
                        id: addButtonMouseArea
                        anchors.fill: parent
                        cursorShape: internal.isValidating ? Qt.BusyCursor : Qt.PointingHandCursor
                        hoverEnabled: true
                        enabled: !internal.isValidating

                        onClicked: {
                            internal.validateAndAddRepo(internal.inputPath)
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            // Error message
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: internal.showError ? errorText.height + 12 : 0
                visible: internal.showError
                radius: 6
                color: Qt.alpha(internal.errorColor, 0.15)

                Text {
                    id: errorText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    text: internal.errorMessage
                    font.pixelSize: 11
                    color: internal.errorColor
                    wrapMode: Text.WordWrap
                }

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // -----------------------------------------------------------------
            // BROWSE BUTTON (Optional - filesystem picker)
            // -----------------------------------------------------------------

            Rectangle {
                id: browseButton
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.topMargin: 4
                radius: 6
                color: browseMouseArea.containsMouse ? internal.overlayColor : "transparent"
                border.color: internal.borderColor
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf07c"  // Folder open icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: internal.textColor
                    }

                    Text {
                        text: qsTr("Browse...")
                        font.pixelSize: 12
                        color: internal.textColor
                    }
                }

                MouseArea {
                    id: browseMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        // Note: File dialog integration would require platform support
                        // For now, log that this feature would need additional implementation
                        console.log("[RepoSelector] Browse clicked - file dialog not yet implemented")
                        // Focus the path input as fallback
                        pathInput.forceActiveFocus()
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    // =========================================================================
    // CLICK-AWAY HANDLER
    // =========================================================================

    // This component doesn't implement click-away directly
    // The parent Panel should handle global click-away for dropdowns
    // Alternatively, use a modal overlay approach

    // =========================================================================
    // PUBLIC METHODS
    // =========================================================================

    /**
     * Open the dropdown
     */
    function open() {
        dropdownOpen = true
        dropdownToggled(true)
    }

    /**
     * Close the dropdown
     */
    function close() {
        dropdownOpen = false
        dropdownToggled(false)
    }

    /**
     * Toggle dropdown state
     */
    function toggle() {
        dropdownOpen = !dropdownOpen
        dropdownToggled(dropdownOpen)
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[RepoSelector] Initialized")
        console.log("[RepoSelector] Recent repos:", Services.SettingsService.recentRepos.length)
    }
}
