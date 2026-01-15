/**
 * IssueEditor.qml - GitHub Issue Editor/Viewer Component
 *
 * Displays a full issue with markdown body, comment thread, and actions.
 * Also serves as the create issue form when in creation mode.
 *
 * Features:
 * - Issue title display (editable for new issues)
 * - Markdown body rendering using TextEdit.MarkdownText
 * - Comment thread with author avatars
 * - Comment input with markdown preview toggle
 * - Close/Reopen buttons for existing issues
 * - Submit button for new issues
 * - State indicator and labels display
 *
 * Tasks Implemented:
 * - T053: Create Components/IssueEditor.qml for expanded issue view with markdown body
 * - T054: Implement markdown rendering using TextEdit.MarkdownText for issue body
 * - T056: Display comment thread in IssueEditor with author avatars
 * - T058: Add comment input TextArea with markdown preview toggle
 * - T062: Add close/reopen buttons to expanded issue view
 *
 * @see specs/001-quick-git-plugin/spec.md (US3)
 * @see specs/001-quick-git-plugin/data-model.md (Issue, Comment entities)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Services" as Services

Rectangle {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    /**
     * The issue to display (null for create mode)
     */
    property var issue: null

    /**
     * Whether we're creating a new issue
     */
    property bool isCreating: false

    /**
     * Repository owner
     */
    property string owner: ""

    /**
     * Repository name
     */
    property string repo: ""

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when close button is clicked
     */
    signal close()

    /**
     * Emitted when a new issue is successfully created
     * @param newIssue - The created issue object
     */
    signal issueCreated(var newIssue)

    /**
     * Emitted when an issue is updated (closed/reopened/comment added)
     * @param updatedIssue - The updated issue object
     */
    signal issueUpdated(var updatedIssue)

    // =========================================================================
    // VISUAL PROPERTIES
    // =========================================================================

    color: internal.backgroundColor
    radius: 8
    border.color: internal.borderColor
    border.width: 1

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

        // Issue state colors
        readonly property color openColor: "#a6e3a1"       // Green
        readonly property color closedColor: "#cba6f7"     // Purple/Mauve
        readonly property color closedNotPlannedColor: "#6c7086"  // Gray
        readonly property color errorColor: "#f38ba8"      // Red

        // State
        property bool isLoadingComments: false
        property bool isSubmitting: false
        property bool isClosing: false
        property bool isReopening: false
        property bool isAddingComment: false
        property var comments: []
        property string error: ""

        // Create mode inputs
        property string newTitle: ""
        property string newBody: ""

        // Comment input
        property string commentText: ""
        property bool showCommentPreview: false

        /**
         * Get state icon for issue
         */
        function getStateIcon(issue) {
            if (!issue) return ""
            if (issue.state === "open") {
                return "\uf41b"  // Issue open icon
            } else {
                if (issue.state_reason === "not_planned") {
                    return "\uf52a"  // X circle
                }
                return "\uf058"  // Check circle
            }
        }

        /**
         * Get state color
         */
        function getStateColor(issue) {
            if (!issue) return subtextColor
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
         * Get state label
         */
        function getStateLabel(issue) {
            if (!issue) return ""
            if (issue.state === "open") {
                return qsTr("Open")
            } else {
                if (issue.state_reason === "not_planned") {
                    return qsTr("Closed as not planned")
                }
                return qsTr("Closed")
            }
        }

        /**
         * Format date for display
         */
        function formatDate(dateString) {
            if (!dateString) return ""
            const date = new Date(dateString)
            return date.toLocaleDateString(Qt.locale(), "MMM d, yyyy") + " at " +
                   date.toLocaleTimeString(Qt.locale(), "h:mm AP")
        }

        /**
         * Format relative time
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
            if (diffMins < 60) return qsTr("%1 minutes ago").arg(diffMins)
            if (diffHours < 24) return qsTr("%1 hours ago").arg(diffHours)
            if (diffDays < 7) return qsTr("%1 days ago").arg(diffDays)

            return formatDate(dateString)
        }

        /**
         * Get label text color for contrast
         */
        function getLabelTextColor(hexColor) {
            if (!hexColor) return textColor
            const hex = hexColor.replace("#", "")
            const r = parseInt(hex.substring(0, 2), 16)
            const g = parseInt(hex.substring(2, 4), 16)
            const b = parseInt(hex.substring(4, 6), 16)
            const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            return luminance > 0.5 ? "#1e1e2e" : "#ffffff"
        }

        /**
         * Load issue details including comments
         */
        function loadIssueDetails() {
            if (!root.issue || !root.owner || !root.repo) return

            console.log("[IssueEditor] Loading issue details:", root.issue.number)
            isLoadingComments = true
            error = ""

            Services.GitHubService.getIssue(root.owner, root.repo, root.issue.number)
        }

        /**
         * Submit new issue
         */
        function submitNewIssue() {
            if (!newTitle.trim()) {
                error = qsTr("Title is required")
                return
            }

            if (!root.owner || !root.repo) {
                error = qsTr("No repository configured")
                return
            }

            console.log("[IssueEditor] Creating issue:", newTitle)
            isSubmitting = true
            error = ""

            Services.GitHubService.createIssue(
                root.owner,
                root.repo,
                newTitle.trim(),
                newBody.trim(),
                []  // No labels for now
            )
        }

        /**
         * Close the current issue
         */
        function closeIssue(reason) {
            if (!root.issue || !root.owner || !root.repo) return

            console.log("[IssueEditor] Closing issue:", root.issue.number, "reason:", reason)
            isClosing = true
            error = ""

            Services.GitHubService.closeIssue(
                root.owner,
                root.repo,
                root.issue.number,
                reason || "completed"
            )
        }

        /**
         * Reopen the current issue
         */
        function reopenIssue() {
            if (!root.issue || !root.owner || !root.repo) return

            console.log("[IssueEditor] Reopening issue:", root.issue.number)
            isReopening = true
            error = ""

            Services.GitHubService.reopenIssue(
                root.owner,
                root.repo,
                root.issue.number
            )
        }

        /**
         * Add a comment to the issue
         */
        function addComment() {
            if (!commentText.trim()) return
            if (!root.issue || !root.owner || !root.repo) return

            console.log("[IssueEditor] Adding comment to issue:", root.issue.number)
            isAddingComment = true
            error = ""

            Services.GitHubService.addComment(
                root.owner,
                root.repo,
                root.issue.number,
                commentText.trim()
            )
        }

        /**
         * Reset state when issue changes
         */
        function resetState() {
            comments = []
            error = ""
            commentText = ""
            showCommentPreview = false
            newTitle = ""
            newBody = ""
            isLoadingComments = false
            isSubmitting = false
            isClosing = false
            isReopening = false
            isAddingComment = false
        }
    }

    // =========================================================================
    // SERVICE CONNECTIONS
    // =========================================================================

    Connections {
        target: Services.GitHubService

        function onIssueLoaded(loadedIssue) {
            if (!root.issue || loadedIssue.number !== root.issue.number) return

            console.log("[IssueEditor] Issue loaded with",
                       loadedIssue.comments_data ? loadedIssue.comments_data.length : 0, "comments")
            internal.isLoadingComments = false
            internal.comments = loadedIssue.comments_data || []

            // Update the issue with full data
            root.issueUpdated(loadedIssue)
        }

        function onIssueUpdated(updatedIssue) {
            if (!root.issue || updatedIssue.number !== root.issue.number) return

            console.log("[IssueEditor] Issue updated, state:", updatedIssue.state)
            internal.isClosing = false
            internal.isReopening = false

            root.issueUpdated(updatedIssue)
        }

        function onCommentAdded(comment) {
            console.log("[IssueEditor] Comment added")
            internal.isAddingComment = false
            internal.commentText = ""

            // Add comment to local list
            internal.comments = internal.comments.concat([comment])
        }

        function onErrorOccurred(message) {
            console.error("[IssueEditor] Error:", message)
            internal.error = message
            internal.isSubmitting = false
            internal.isClosing = false
            internal.isReopening = false
            internal.isAddingComment = false
            internal.isLoadingComments = false
        }
    }

    // =========================================================================
    // PROPERTY WATCHERS
    // =========================================================================

    onIssueChanged: {
        internal.resetState()
        if (issue && !isCreating) {
            internal.loadIssueDetails()
        }
    }

    onIsCreatingChanged: {
        internal.resetState()
    }

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // =====================================================================
        // HEADER: Title, Close button, State badge
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // State badge (for existing issues)
            Rectangle {
                visible: !root.isCreating && root.issue
                width: stateContent.width + 16
                height: 26
                radius: 13
                color: Qt.alpha(internal.getStateColor(root.issue), 0.2)
                border.color: internal.getStateColor(root.issue)
                border.width: 1

                RowLayout {
                    id: stateContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: internal.getStateIcon(root.issue)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: internal.getStateColor(root.issue)
                    }

                    Text {
                        text: internal.getStateLabel(root.issue)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: internal.getStateColor(root.issue)
                    }
                }
            }

            // Issue number
            Text {
                visible: !root.isCreating && root.issue
                text: "#" + (root.issue ? root.issue.number : "")
                font.pixelSize: 18
                font.weight: Font.Bold
                color: internal.subtextColor
            }

            // Title for existing issue
            Text {
                visible: !root.isCreating && root.issue
                Layout.fillWidth: true
                text: root.issue ? root.issue.title : ""
                font.pixelSize: 18
                font.weight: Font.Bold
                color: internal.textColor
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            // Title for new issue - header label
            Text {
                visible: root.isCreating
                Layout.fillWidth: true
                text: qsTr("New Issue")
                font.pixelSize: 18
                font.weight: Font.Bold
                color: internal.textColor
            }

            // Close panel button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closePanelMouse.containsMouse ? internal.overlayColor : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"  // X icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: internal.subtextColor
                }

                MouseArea {
                    id: closePanelMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.close()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // =====================================================================
        // CREATE ISSUE FORM
        // =====================================================================

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            visible: root.isCreating

            // Title input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: internal.surfaceColor
                radius: 6
                border.color: titleInput.activeFocus ? internal.accentColor : internal.borderColor
                border.width: 1

                TextInput {
                    id: titleInput
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 14
                    color: internal.textColor
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("Issue title...")
                        font.pixelSize: 14
                        color: internal.subtextColor
                        visible: !titleInput.text && !titleInput.activeFocus
                    }

                    onTextChanged: internal.newTitle = text
                }

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Body input with markdown preview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: internal.surfaceColor
                radius: 6
                border.color: bodyInput.activeFocus ? internal.accentColor : internal.borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Tab bar for Write/Preview
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: internal.overlayColor
                        radius: 6

                        // Mask bottom corners
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 6
                            color: internal.overlayColor
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 4

                            // Write tab
                            Rectangle {
                                width: writeTabText.width + 16
                                height: 28
                                radius: 4
                                color: !internal.showCommentPreview ? internal.surfaceColor : "transparent"

                                Text {
                                    id: writeTabText
                                    anchors.centerIn: parent
                                    text: qsTr("Write")
                                    font.pixelSize: 12
                                    color: !internal.showCommentPreview ? internal.textColor : internal.subtextColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: internal.showCommentPreview = false
                                }
                            }

                            // Preview tab
                            Rectangle {
                                width: previewTabText.width + 16
                                height: 28
                                radius: 4
                                color: internal.showCommentPreview ? internal.surfaceColor : "transparent"

                                Text {
                                    id: previewTabText
                                    anchors.centerIn: parent
                                    text: qsTr("Preview")
                                    font.pixelSize: 12
                                    color: internal.showCommentPreview ? internal.textColor : internal.subtextColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: internal.showCommentPreview = true
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Markdown hint
                            RowLayout {
                                spacing: 4

                                Text {
                                    text: "\ue73e"  // Markdown icon
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 12
                                    color: internal.subtextColor
                                }

                                Text {
                                    text: qsTr("Markdown supported")
                                    font.pixelSize: 11
                                    color: internal.subtextColor
                                }
                            }
                        }
                    }

                    // Content area
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Write mode - TextArea
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: !internal.showCommentPreview
                            clip: true

                            TextArea {
                                id: bodyInput
                                width: parent.width
                                placeholderText: qsTr("Describe your issue (markdown supported)...")
                                placeholderTextColor: internal.subtextColor
                                font.pixelSize: 13
                                font.family: "monospace"
                                color: internal.textColor
                                wrapMode: TextArea.Wrap
                                selectByMouse: true

                                background: Rectangle {
                                    color: "transparent"
                                }

                                onTextChanged: internal.newBody = text
                            }
                        }

                        // Preview mode - Markdown rendered (T054)
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: internal.showCommentPreview
                            clip: true

                            TextEdit {
                                width: parent.width
                                textFormat: TextEdit.MarkdownText
                                text: internal.newBody || qsTr("_Nothing to preview_")
                                font.pixelSize: 13
                                color: internal.textColor
                                wrapMode: Text.Wrap
                                readOnly: true
                                selectByMouse: true
                            }
                        }
                    }
                }

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Error message
            Text {
                Layout.fillWidth: true
                visible: internal.error.length > 0
                text: internal.error
                font.pixelSize: 12
                color: internal.errorColor
                wrapMode: Text.Wrap
            }

            // Submit button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: submitMouse.containsMouse ?
                    Qt.lighter(internal.accentColor, 1.1) : internal.accentColor
                opacity: internal.newTitle.trim().length > 0 && !internal.isSubmitting ? 1.0 : 0.5

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        visible: internal.isSubmitting
                        text: "\uf110"  // Spinner
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.backgroundColor

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: internal.isSubmitting
                        }
                    }

                    Text {
                        text: internal.isSubmitting ? qsTr("Creating...") : qsTr("Create Issue")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: internal.backgroundColor
                    }
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    cursorShape: internal.newTitle.trim().length > 0 && !internal.isSubmitting ?
                        Qt.PointingHandCursor : Qt.ForbiddenCursor
                    hoverEnabled: true
                    enabled: internal.newTitle.trim().length > 0 && !internal.isSubmitting

                    onClicked: internal.submitNewIssue()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // =====================================================================
        // EXISTING ISSUE VIEW
        // =====================================================================

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.isCreating && root.issue
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 16

                // ---------------------------------------------------------
                // Issue metadata: Author, Date, Labels
                // ---------------------------------------------------------

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Author
                    RowLayout {
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: internal.overlayColor
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.issue && root.issue.user ? root.issue.user.avatar_url : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: parent.children[0].status !== Image.Ready
                                text: "\uf007"  // User icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: internal.subtextColor
                            }
                        }

                        Text {
                            text: root.issue && root.issue.user ? root.issue.user.login : ""
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: internal.textColor
                        }
                    }

                    Text {
                        text: qsTr("opened this issue")
                        font.pixelSize: 13
                        color: internal.subtextColor
                    }

                    Text {
                        text: internal.formatRelativeTime(root.issue ? root.issue.created_at : "")
                        font.pixelSize: 13
                        color: internal.subtextColor
                    }

                    Item { Layout.fillWidth: true }

                    // Labels
                    Flow {
                        Layout.preferredWidth: implicitWidth
                        Layout.maximumWidth: 200
                        spacing: 4

                        Repeater {
                            model: root.issue ? root.issue.labels : []

                            Rectangle {
                                width: labelText.width + 12
                                height: 22
                                radius: 11
                                color: "#" + (modelData.color || "6c7086")

                                Text {
                                    id: labelText
                                    anchors.centerIn: parent
                                    text: modelData.name || ""
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: internal.getLabelTextColor(modelData.color)
                                }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // Issue body rendered as markdown (T053, T054)
                // ---------------------------------------------------------

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: bodyContent.height + 24
                    color: internal.surfaceColor
                    radius: 8
                    border.color: internal.borderColor
                    border.width: 1

                    TextEdit {
                        id: bodyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12

                        textFormat: TextEdit.MarkdownText
                        text: root.issue && root.issue.body ?
                            root.issue.body : "_No description provided._"
                        font.pixelSize: 13
                        color: internal.textColor
                        wrapMode: Text.Wrap
                        readOnly: true
                        selectByMouse: true

                        // Handle link clicks
                        onLinkActivated: link => {
                            console.log("[IssueEditor] Link clicked:", link)
                            Qt.openUrlExternally(link)
                        }
                    }
                }

                // ---------------------------------------------------------
                // ACTION BUTTONS: Close/Reopen (T062)
                // ---------------------------------------------------------

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.issue

                    Item { Layout.fillWidth: true }

                    // Close button (for open issues)
                    Rectangle {
                        visible: root.issue && root.issue.state === "open"
                        width: closeIssueContent.width + 24
                        height: 36
                        radius: 6
                        color: closeIssueMouse.containsMouse ?
                            Qt.alpha(internal.closedColor, 0.3) : internal.surfaceColor
                        border.color: internal.closedColor
                        border.width: 1

                        RowLayout {
                            id: closeIssueContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                visible: internal.isClosing
                                text: "\uf110"  // Spinner
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.closedColor

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: internal.isClosing
                                }
                            }

                            Text {
                                visible: !internal.isClosing
                                text: "\uf058"  // Check circle
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.closedColor
                            }

                            Text {
                                text: internal.isClosing ? qsTr("Closing...") : qsTr("Close Issue")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.closedColor
                            }
                        }

                        MouseArea {
                            id: closeIssueMouse
                            anchors.fill: parent
                            cursorShape: internal.isClosing ? Qt.BusyCursor : Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: !internal.isClosing

                            onClicked: internal.closeIssue("completed")
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Close as not planned button
                    Rectangle {
                        visible: root.issue && root.issue.state === "open"
                        width: closeNotPlannedContent.width + 24
                        height: 36
                        radius: 6
                        color: closeNotPlannedMouse.containsMouse ?
                            internal.overlayColor : internal.surfaceColor
                        border.color: internal.borderColor
                        border.width: 1

                        RowLayout {
                            id: closeNotPlannedContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "\uf52a"  // X circle
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.subtextColor
                            }

                            Text {
                                text: qsTr("Close as not planned")
                                font.pixelSize: 12
                                color: internal.subtextColor
                            }
                        }

                        MouseArea {
                            id: closeNotPlannedMouse
                            anchors.fill: parent
                            cursorShape: internal.isClosing ? Qt.BusyCursor : Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: !internal.isClosing

                            onClicked: internal.closeIssue("not_planned")
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Reopen button (for closed issues)
                    Rectangle {
                        visible: root.issue && root.issue.state === "closed"
                        width: reopenContent.width + 24
                        height: 36
                        radius: 6
                        color: reopenMouse.containsMouse ?
                            Qt.alpha(internal.openColor, 0.3) : internal.surfaceColor
                        border.color: internal.openColor
                        border.width: 1

                        RowLayout {
                            id: reopenContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                visible: internal.isReopening
                                text: "\uf110"  // Spinner
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.openColor

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: internal.isReopening
                                }
                            }

                            Text {
                                visible: !internal.isReopening
                                text: "\uf41b"  // Issue open icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.openColor
                            }

                            Text {
                                text: internal.isReopening ? qsTr("Reopening...") : qsTr("Reopen Issue")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.openColor
                            }
                        }

                        MouseArea {
                            id: reopenMouse
                            anchors.fill: parent
                            cursorShape: internal.isReopening ? Qt.BusyCursor : Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: !internal.isReopening

                            onClicked: internal.reopenIssue()
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                // ---------------------------------------------------------
                // COMMENTS SECTION (T056)
                // ---------------------------------------------------------

                // Comments header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 2
                        height: 20
                        radius: 1
                        color: internal.accentColor
                    }

                    Text {
                        text: qsTr("Comments")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: internal.textColor
                    }

                    Rectangle {
                        width: commentCountText.width + 12
                        height: 20
                        radius: 10
                        color: internal.overlayColor

                        Text {
                            id: commentCountText
                            anchors.centerIn: parent
                            text: internal.comments.length.toString()
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: internal.subtextColor
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Loading indicator
                    RowLayout {
                        visible: internal.isLoadingComments
                        spacing: 6

                        Text {
                            text: "\uf110"  // Spinner
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: internal.subtextColor

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: internal.isLoadingComments
                            }
                        }

                        Text {
                            text: qsTr("Loading...")
                            font.pixelSize: 12
                            color: internal.subtextColor
                        }
                    }
                }

                // Comments list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Empty state
                    Text {
                        visible: !internal.isLoadingComments && internal.comments.length === 0
                        text: qsTr("No comments yet")
                        font.pixelSize: 13
                        font.italic: true
                        color: internal.subtextColor
                    }

                    // Comment items
                    Repeater {
                        model: internal.comments

                        CommentDelegate {
                            Layout.fillWidth: true
                            comment: modelData
                        }
                    }
                }

                // ---------------------------------------------------------
                // ADD COMMENT INPUT (T058)
                // ---------------------------------------------------------

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: commentInputArea.height + 24
                    color: internal.surfaceColor
                    radius: 8
                    border.color: commentTextArea.activeFocus ? internal.accentColor : internal.borderColor
                    border.width: 1

                    ColumnLayout {
                        id: commentInputArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        // Author indicator
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: internal.overlayColor
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: Services.GitHubService.avatarUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.children[0].status !== Image.Ready
                                    text: "\uf007"
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 8
                                    color: internal.subtextColor
                                }
                            }

                            Text {
                                text: qsTr("Add a comment as @%1").arg(Services.GitHubService.username)
                                font.pixelSize: 12
                                color: internal.subtextColor
                            }

                            Item { Layout.fillWidth: true }

                            // Preview toggle
                            Rectangle {
                                width: previewToggleContent.width + 12
                                height: 24
                                radius: 4
                                color: internal.showCommentPreview ? internal.accentColor : internal.overlayColor

                                RowLayout {
                                    id: previewToggleContent
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "\ue73e"  // Markdown
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 10
                                        color: internal.showCommentPreview ? internal.backgroundColor : internal.subtextColor
                                    }

                                    Text {
                                        text: qsTr("Preview")
                                        font.pixelSize: 10
                                        color: internal.showCommentPreview ? internal.backgroundColor : internal.subtextColor
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: internal.showCommentPreview = !internal.showCommentPreview
                                }
                            }
                        }

                        // Comment input area
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100

                            // Write mode
                            TextArea {
                                id: commentTextArea
                                anchors.fill: parent
                                visible: !internal.showCommentPreview
                                placeholderText: qsTr("Leave a comment...")
                                placeholderTextColor: internal.subtextColor
                                font.pixelSize: 13
                                color: internal.textColor
                                wrapMode: TextArea.Wrap
                                selectByMouse: true

                                background: Rectangle {
                                    color: "transparent"
                                }

                                onTextChanged: internal.commentText = text

                                // Ctrl+Enter to submit
                                Keys.onPressed: event => {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                                        (event.modifiers & Qt.ControlModifier)) {
                                        if (internal.commentText.trim()) {
                                            internal.addComment()
                                        }
                                        event.accepted = true
                                    }
                                }
                            }

                            // Preview mode
                            ScrollView {
                                anchors.fill: parent
                                visible: internal.showCommentPreview
                                clip: true

                                TextEdit {
                                    width: parent.width
                                    textFormat: TextEdit.MarkdownText
                                    text: internal.commentText || qsTr("_Nothing to preview_")
                                    font.pixelSize: 13
                                    color: internal.textColor
                                    wrapMode: Text.Wrap
                                    readOnly: true
                                }
                            }
                        }

                        // Submit row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("Ctrl+Enter to submit")
                                font.pixelSize: 11
                                color: internal.subtextColor
                                visible: internal.commentText.trim().length > 0
                            }

                            Item { Layout.fillWidth: true }

                            // Submit button
                            Rectangle {
                                width: submitCommentContent.width + 20
                                height: 32
                                radius: 6
                                color: submitCommentMouse.containsMouse && internal.commentText.trim() ?
                                    Qt.lighter(internal.accentColor, 1.1) : internal.accentColor
                                opacity: internal.commentText.trim().length > 0 && !internal.isAddingComment ? 1.0 : 0.5

                                RowLayout {
                                    id: submitCommentContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        visible: internal.isAddingComment
                                        text: "\uf110"  // Spinner
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: internal.backgroundColor

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: internal.isAddingComment
                                        }
                                    }

                                    Text {
                                        text: internal.isAddingComment ? qsTr("Posting...") : qsTr("Comment")
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: internal.backgroundColor
                                    }
                                }

                                MouseArea {
                                    id: submitCommentMouse
                                    anchors.fill: parent
                                    cursorShape: internal.commentText.trim() && !internal.isAddingComment ?
                                        Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    hoverEnabled: true
                                    enabled: internal.commentText.trim().length > 0 && !internal.isAddingComment

                                    onClicked: internal.addComment()
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }

                // Bottom spacer
                Item {
                    Layout.preferredHeight: 20
                }
            }
        }
    }

    // =========================================================================
    // COMMENT DELEGATE COMPONENT (T056)
    // =========================================================================

    component CommentDelegate: Rectangle {
        id: commentRoot

        property var comment: ({})

        implicitHeight: commentContent.height + 24
        color: internal.surfaceColor
        radius: 8
        border.color: internal.borderColor
        border.width: 1

        ColumnLayout {
            id: commentContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // Header: Avatar, Author, Time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Author avatar
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: internal.overlayColor
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: commentRoot.comment && commentRoot.comment.user ?
                            commentRoot.comment.user.avatar_url : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.children[0].status !== Image.Ready
                        text: "\uf007"  // User icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 11
                        color: internal.subtextColor
                    }
                }

                // Author name
                Text {
                    text: commentRoot.comment && commentRoot.comment.user ?
                        commentRoot.comment.user.login : ""
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: internal.textColor
                }

                // Author association badge
                Rectangle {
                    visible: commentRoot.comment && commentRoot.comment.author_association &&
                            commentRoot.comment.author_association !== "NONE"
                    width: assocText.width + 10
                    height: 18
                    radius: 9
                    color: internal.overlayColor

                    Text {
                        id: assocText
                        anchors.centerIn: parent
                        text: {
                            const assoc = commentRoot.comment ? commentRoot.comment.author_association : ""
                            switch (assoc) {
                                case "OWNER": return qsTr("Owner")
                                case "COLLABORATOR": return qsTr("Collaborator")
                                case "CONTRIBUTOR": return qsTr("Contributor")
                                case "MEMBER": return qsTr("Member")
                                default: return ""
                            }
                        }
                        font.pixelSize: 10
                        color: internal.subtextColor
                    }
                }

                Text {
                    text: qsTr("commented")
                    font.pixelSize: 12
                    color: internal.subtextColor
                }

                Text {
                    text: internal.formatRelativeTime(commentRoot.comment ? commentRoot.comment.created_at : "")
                    font.pixelSize: 12
                    color: internal.subtextColor
                }

                Item { Layout.fillWidth: true }

                // Edited indicator
                Text {
                    visible: commentRoot.comment &&
                            commentRoot.comment.updated_at !== commentRoot.comment.created_at
                    text: qsTr("edited")
                    font.pixelSize: 11
                    font.italic: true
                    color: internal.subtextColor
                }
            }

            // Comment body rendered as markdown (T054)
            TextEdit {
                Layout.fillWidth: true

                textFormat: TextEdit.MarkdownText
                text: commentRoot.comment && commentRoot.comment.body ?
                    commentRoot.comment.body : ""
                font.pixelSize: 13
                color: internal.textColor
                wrapMode: Text.Wrap
                readOnly: true
                selectByMouse: true

                onLinkActivated: link => {
                    Qt.openUrlExternally(link)
                }
            }
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[IssueEditor] Initialized, isCreating:", isCreating,
                   "issue:", issue ? issue.number : "null")
    }

    Component.onDestruction: {
        console.log("[IssueEditor] Destroyed")
    }
}
