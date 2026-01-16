/**
 * DiffViewer.qml - Unified Diff Display Component
 *
 * Displays git diff output with syntax highlighting and line numbers.
 * Features:
 * - ListView with custom delegate for each diff line
 * - Line numbers (old and new) in margin
 * - Type indicator (+/-/space) in left margin
 * - Color-coded add (green), remove (red), context (default) lines
 * - Hunk headers (@@) with context information
 * - Truncation for large diffs (>500 lines) with "Show full diff" option
 * - Binary file detection with placeholder message
 *
 * Tasks Implemented:
 * - T032: Create Components/DiffViewer.qml with ListView for diff lines
 * - T033: Implement diff parsing (uses GitService.getDiff)
 * - T034: Implement diff parser in JavaScript (unified diff format)
 * - T035: Style with add (green), remove (red), context colors
 * - T038: Handle large diffs (>500 lines) with truncation
 * - T039: Handle binary files with placeholder
 *
 * @see specs/001-quick-git-plugin/spec.md (US2)
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
     * File path to show diff for (relative to repo root)
     */
    property string filePath: ""

    /**
     * Whether to show staged diff (--cached) or working tree diff
     */
    property bool isStaged: false

    /**
     * Maximum number of lines before truncation kicks in
     */
    property int maxLines: 500

    /**
     * Override truncation to show full diff
     */
    property bool showFullDiff: false

    /**
     * True while loading diff from git
     */
    property bool isLoading: false

    /**
     * Raw diff text (can be set externally or loaded via loadDiff())
     */
    property string diffText: ""

    /**
     * Preferred height based on content (for parent layout)
     */
    readonly property int contentHeight: {
        if (internal.isBinary) return 60
        if (internal.isEmpty) return 60
        if (internal.isLoading) return 60

        const lineHeight = 22
        const headerHeight = 28
        const hunkCount = internal.parsedHunks.length
        const lineCount = internal.displayLines.length
        const baseHeight = hunkCount * headerHeight + lineCount * lineHeight + 16

        // Add space for truncation banner if needed
        const truncationHeight = internal.isTruncated && !root.showFullDiff ? 40 : 0

        return Math.min(Math.max(baseHeight + truncationHeight, 80), 400)
    }

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when diff loading completes
     */
    signal diffLoaded()

    /**
     * Emitted when an error occurs
     */
    signal errorOccurred(string message)

    // =========================================================================
    // PUBLIC METHODS
    // =========================================================================

    /**
     * Load diff from GitService for the configured file (T087: added file size check)
     */
    function loadDiff() {
        if (!root.filePath) {
            console.warn("[DiffViewer] Cannot load diff: no file path")
            return
        }

        console.log("[DiffViewer] Loading diff for:", root.filePath, "staged:", root.isStaged)
        internal.isLoading = true
        internal.error = ""
        internal.isFileTooLarge = false

        // T087: Check file size before loading diff
        // Build full path to file (using GitService.repoPath)
        const fullPath = Services.GitService.repoPath + "/" + root.filePath
        fileSizeProcess.filePath = fullPath
        fileSizeProcess.running = true
    }

    /**
     * Clear the current diff (T087: added file size reset)
     */
    function clear() {
        root.diffText = ""
        internal.parsedHunks = []
        internal.displayLines = []
        internal.isBinary = false
        internal.isEmpty = false
        internal.error = ""
        internal.isFileTooLarge = false
        internal.fileSizeBytes = 0
        internal.hasConflictMarkers = false
    }

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
        readonly property color borderColor: "#45475a"

        // =====================================================================
        // COLORBLIND-ACCESSIBLE DIFF COLORS (T080)
        // =====================================================================

        // Get current palette from SettingsService
        readonly property string currentPalette: Services.SettingsService.colorblindPalette

        // Palette definitions for add colors (Catppuccin Mocha based)
        readonly property var addColors: ({
            "shapes":       "#a6e3a1",  // Green (default)
            "highcontrast": "#ffffff",  // White text on dark green
            "deuteranopia": "#89b4fa",  // Blue (avoid red/green)
            "protanopia":   "#a6e3a1"   // Green (safe for protanopia)
        })

        // Palette definitions for add background colors
        readonly property var addBgColors: ({
            "shapes":       "#1a3d1a",  // Dark green
            "highcontrast": "#006400",  // Dark green bg for high contrast
            "deuteranopia": "#1e3a5f",  // Dark blue
            "protanopia":   "#1a3d1a"   // Dark green
        })

        // Palette definitions for remove colors
        readonly property var removeColors: ({
            "shapes":       "#f38ba8",  // Red (default)
            "highcontrast": "#ffffff",  // White text on dark red
            "deuteranopia": "#fab387",  // Orange (avoid red/green)
            "protanopia":   "#f9e2af"   // Yellow (avoid red)
        })

        // Palette definitions for remove background colors
        readonly property var removeBgColors: ({
            "shapes":       "#3d1a1a",  // Dark red
            "highcontrast": "#8b0000",  // Dark red bg for high contrast
            "deuteranopia": "#3d2a1a",  // Dark orange
            "protanopia":   "#3d3a1a"   // Dark yellow
        })

        // Dynamic colors based on current palette
        readonly property color addColor: addColors[currentPalette] || addColors["shapes"]
        readonly property color addBackgroundColor: addBgColors[currentPalette] || addBgColors["shapes"]
        readonly property color removeColor: removeColors[currentPalette] || removeColors["shapes"]
        readonly property color removeBackgroundColor: removeBgColors[currentPalette] || removeBgColors["shapes"]

        // Static colors (not affected by palette)
        readonly property color contextColor: "#cdd6f4"       // Normal text
        readonly property color hunkHeaderColor: "#89b4fa"    // Blue
        readonly property color hunkHeaderBgColor: "#1e3a5f"  // Dark blue bg
        readonly property color lineNumberColor: "#6c7086"    // Overlay0

        // Conflict marker colors (T086)
        readonly property color conflictMarkerColor: "#f38ba8"  // Red - warning
        readonly property color conflictMarkerBgColor: "#3d1a2a"  // Dark red/purple bg

        // State
        property bool isLoading: false
        property string error: ""
        property var parsedHunks: []
        property var displayLines: []
        property bool isBinary: false
        property bool isEmpty: false
        property int totalLineCount: 0
        property bool isTruncated: false
        property bool hasConflictMarkers: false  // T086: Track if diff contains conflict markers
        property bool isFileTooLarge: false  // T087: Track if file exceeds size limit
        property int fileSizeBytes: 0  // T087: Actual file size

        // T087: Size limit for file display (1MB = 1,048,576 bytes)
        readonly property int maxFileSizeBytes: 1048576

        /**
         * Parse unified diff format into structured hunks and lines
         *
         * Input format:
         *   diff --git a/file.txt b/file.txt
         *   index abc123..def456 100644
         *   --- a/file.txt
         *   +++ b/file.txt
         *   @@ -1,3 +1,4 @@ optional context
         *    unchanged line
         *   -removed line
         *   +added line
         *
         * Output structure:
         *   hunks: [{ header, oldStart, oldCount, newStart, newCount, lines: [...] }]
         *   Each line: { type: "add"|"remove"|"context"|"header", content, oldLineNum, newLineNum }
         */
        function parseDiff(diffText) {
            if (!diffText || diffText.trim().length === 0) {
                isEmpty = true
                isBinary = false
                parsedHunks = []
                displayLines = []
                totalLineCount = 0
                isTruncated = false
                return
            }

            // Check for binary file
            if (diffText.includes("Binary files") ||
                diffText.includes("binary file") ||
                diffText.includes("GIT binary patch")) {
                isBinary = true
                isEmpty = false
                parsedHunks = []
                displayLines = []
                totalLineCount = 0
                isTruncated = false
                return
            }

            isEmpty = false
            isBinary = false
            hasConflictMarkers = false  // T086: Reset conflict marker flag

            const lines = diffText.split('\n')
            const hunks = []
            let currentHunk = null
            let oldLineNum = 0
            let newLineNum = 0
            let flatLines = []

            for (let i = 0; i < lines.length; i++) {
                const line = lines[i]

                // Skip diff header lines (diff --git, index, ---, +++)
                if (line.startsWith('diff --git') ||
                    line.startsWith('index ') ||
                    line.startsWith('--- ') ||
                    line.startsWith('+++ ') ||
                    line.startsWith('old mode') ||
                    line.startsWith('new mode') ||
                    line.startsWith('deleted file') ||
                    line.startsWith('new file') ||
                    line.startsWith('similarity index') ||
                    line.startsWith('rename from') ||
                    line.startsWith('rename to') ||
                    line.startsWith('copy from') ||
                    line.startsWith('copy to')) {
                    continue
                }

                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@ context
                if (line.startsWith('@@')) {
                    const match = line.match(/@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)/)
                    if (match) {
                        oldLineNum = parseInt(match[1], 10)
                        newLineNum = parseInt(match[3], 10)
                        const oldCount = match[2] ? parseInt(match[2], 10) : 1
                        const newCount = match[4] ? parseInt(match[4], 10) : 1
                        const context = match[5] ? match[5].trim() : ""

                        currentHunk = {
                            header: line,
                            oldStart: oldLineNum,
                            oldCount: oldCount,
                            newStart: newLineNum,
                            newCount: newCount,
                            context: context,
                            lines: []
                        }
                        hunks.push(currentHunk)

                        // Add header as a display line
                        flatLines.push({
                            type: "header",
                            content: line,
                            oldLineNum: null,
                            newLineNum: null,
                            hunkIndex: hunks.length - 1
                        })
                    }
                    continue
                }

                // Parse content lines (only if we have a current hunk)
                if (currentHunk && line.length > 0) {
                    const firstChar = line.charAt(0)
                    let lineType = "context"
                    let displayOldNum = null
                    let displayNewNum = null
                    let content = line.substring(1)
                    let isConflictMarker = false  // T086: Track conflict markers

                    if (firstChar === '+') {
                        lineType = "add"
                        displayNewNum = newLineNum
                        newLineNum++

                        // T086: Check for conflict markers in added lines
                        if (content.startsWith("<<<<<<<") ||
                            content.startsWith("=======") ||
                            content.startsWith(">>>>>>>")) {
                            lineType = "conflict"
                            isConflictMarker = true
                            hasConflictMarkers = true
                        }
                    } else if (firstChar === '-') {
                        lineType = "remove"
                        displayOldNum = oldLineNum
                        oldLineNum++
                    } else if (firstChar === ' ') {
                        lineType = "context"
                        displayOldNum = oldLineNum
                        displayNewNum = newLineNum
                        oldLineNum++
                        newLineNum++

                        // T086: Check for conflict markers in context lines
                        if (content.startsWith("<<<<<<<") ||
                            content.startsWith("=======") ||
                            content.startsWith(">>>>>>>")) {
                            lineType = "conflict"
                            isConflictMarker = true
                            hasConflictMarkers = true
                        }
                    } else if (firstChar === '\\') {
                        // "\ No newline at end of file"
                        lineType = "meta"
                        content = line
                    } else {
                        // Unknown line format, treat as context
                        content = line
                    }

                    const lineObj = {
                        type: lineType,
                        content: content,
                        oldLineNum: displayOldNum,
                        newLineNum: displayNewNum,
                        isConflict: isConflictMarker  // T086: Flag conflict marker lines
                    }

                    currentHunk.lines.push(lineObj)
                    flatLines.push(lineObj)
                }
            }

            parsedHunks = hunks
            totalLineCount = flatLines.length

            // Handle truncation
            if (totalLineCount > root.maxLines && !root.showFullDiff) {
                isTruncated = true
                displayLines = flatLines.slice(0, root.maxLines)
            } else {
                isTruncated = false
                displayLines = flatLines
            }

            console.log("[DiffViewer] Parsed", hunks.length, "hunks,",
                        totalLineCount, "total lines, truncated:", isTruncated)
        }

        /**
         * Get background color for line type (T086: added conflict support)
         */
        function getLineBackground(type) {
            switch (type) {
                case "add": return addBackgroundColor
                case "remove": return removeBackgroundColor
                case "header": return hunkHeaderBgColor
                case "conflict": return conflictMarkerBgColor
                default: return "transparent"
            }
        }

        /**
         * Get text color for line type (T086: added conflict support)
         */
        function getLineTextColor(type) {
            switch (type) {
                case "add": return addColor
                case "remove": return removeColor
                case "header": return hunkHeaderColor
                case "meta": return subtextColor
                case "conflict": return conflictMarkerColor
                default: return contextColor
            }
        }

        /**
         * Get type indicator character (T086: added conflict support)
         */
        function getTypeIndicator(type) {
            switch (type) {
                case "add": return "+"
                case "remove": return "-"
                case "header": return ""
                case "meta": return ""
                case "conflict": return "!"  // Warning indicator for conflict markers
                default: return " "
            }
        }

        /**
         * Format line number with padding
         */
        function formatLineNum(num) {
            if (num === null || num === undefined) return "    "
            const str = num.toString()
            return str.length >= 4 ? str : ("    " + str).slice(-4)
        }

        /**
         * Format file size for display (T087)
         */
        function formatFileSize(bytes) {
            if (bytes < 1024) return bytes + " B"
            if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " KB"
            return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        }

        /**
         * Open file in external editor (T087)
         * Uses xdg-open on Linux
         */
        function openInExternalEditor(filePath) {
            console.log("[DiffViewer] Opening in external editor:", filePath)
            externalEditorProcess.filePath = filePath
            externalEditorProcess.running = true
        }
    }

    // =========================================================================
    // SERVICE CONNECTIONS
    // =========================================================================

    Connections {
        target: Services.GitService

        function onDiffReady(filePath, staged, diffText) {
            // Only handle our request
            if (filePath !== root.filePath || staged !== root.isStaged) {
                return
            }

            console.log("[DiffViewer] Received diff for:", filePath, "length:", diffText.length)
            internal.isLoading = false
            root.diffText = diffText
            internal.parseDiff(diffText)
            root.diffLoaded()
        }

        function onErrorOccurred(message) {
            if (internal.isLoading) {
                internal.isLoading = false
                internal.error = message
                root.errorOccurred(message)
            }
        }
    }

    // =========================================================================
    // WATCH FOR PROPERTY CHANGES
    // =========================================================================

    onDiffTextChanged: {
        if (diffText && !internal.isLoading) {
            internal.parseDiff(diffText)
        }
    }

    onShowFullDiffChanged: {
        // Re-parse to update display lines
        if (diffText) {
            internal.parseDiff(diffText)
        }
    }

    // =========================================================================
    // UI LAYOUT
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: internal.backgroundColor
        radius: 4
        border.color: internal.borderColor
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Loading state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: internal.isLoading

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

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
                        text: qsTr("Loading diff...")
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }
                }
            }

            // Error state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: internal.error.length > 0 && !internal.isLoading

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf071"  // Warning
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.removeColor
                    }

                    Text {
                        text: internal.error
                        font.pixelSize: 12
                        color: internal.removeColor
                    }
                }
            }

            // Binary file placeholder (T039)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: internal.isBinary && !internal.isLoading

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf1c0"  // Binary/database icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        color: internal.subtextColor
                    }

                    Text {
                        text: qsTr("Binary file - cannot display diff")
                        font.pixelSize: 13
                        color: internal.subtextColor
                        font.italic: true
                    }
                }
            }

            // File too large placeholder (T087)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: internal.isFileTooLarge && !internal.isLoading

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\uf15b"  // Large file icon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 32
                        color: internal.subtextColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("File too large to display")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: internal.textColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("File size: %1 (max: %2)")
                            .arg(internal.formatFileSize(internal.fileSizeBytes))
                            .arg(internal.formatFileSize(internal.maxFileSizeBytes))
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }

                    // Open in external editor button
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: openExternalContent.width + 24
                        height: 36
                        radius: 6
                        color: openExternalMouseArea.containsMouse ?
                               internal.overlayColor : internal.surfaceColor
                        border.color: internal.hunkHeaderColor
                        border.width: 1

                        RowLayout {
                            id: openExternalContent
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "\uf08e"  // External link icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: internal.hunkHeaderColor
                            }

                            Text {
                                text: qsTr("Open in External Editor")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: internal.hunkHeaderColor
                            }
                        }

                        MouseArea {
                            id: openExternalMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                const fullPath = Services.GitService.repoPath + "/" + root.filePath
                                internal.openInExternalEditor(fullPath)
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }

            // Empty/no changes state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: internal.isEmpty && !internal.isLoading && !internal.isBinary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf00c"  // Checkmark
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.addColor
                    }

                    Text {
                        text: qsTr("No changes")
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }
                }
            }

            // Conflict warning banner (T086)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                visible: internal.hasConflictMarkers && !internal.isLoading && !internal.isBinary
                color: internal.conflictMarkerBgColor
                border.color: internal.conflictMarkerColor
                border.width: 1
                radius: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf071"  // Warning triangle
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.conflictMarkerColor
                    }

                    Text {
                        text: qsTr("This file contains merge conflict markers that need to be resolved")
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: internal.conflictMarkerColor
                    }
                }
            }

            // Diff content (T032, T087: added isFileTooLarge check)
            ListView {
                id: diffListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !internal.isLoading && !internal.isBinary &&
                         !internal.isEmpty && !internal.isFileTooLarge &&
                         internal.error.length === 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // T093: Performance optimization for large diffs
                cacheBuffer: 400

                model: internal.displayLines

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 8
                }

                delegate: Rectangle {
                    id: lineDelegate
                    width: diffListView.width
                    height: modelData.type === "header" ? 28 : 22
                    color: internal.getLineBackground(modelData.type)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 0

                        // Hunk header - full width
                        Text {
                            visible: modelData.type === "header"
                            Layout.fillWidth: true
                            text: modelData.content
                            font.pixelSize: 12
                            font.family: "monospace"
                            font.weight: Font.Medium
                            color: internal.hunkHeaderColor
                            elide: Text.ElideRight
                            leftPadding: 8
                        }

                        // Line numbers (for non-header lines)
                        Text {
                            visible: modelData.type !== "header"
                            Layout.preferredWidth: 40
                            text: internal.formatLineNum(modelData.oldLineNum)
                            font.pixelSize: 11
                            font.family: "monospace"
                            color: internal.lineNumberColor
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            visible: modelData.type !== "header"
                            Layout.preferredWidth: 40
                            text: internal.formatLineNum(modelData.newLineNum)
                            font.pixelSize: 11
                            font.family: "monospace"
                            color: internal.lineNumberColor
                            horizontalAlignment: Text.AlignRight
                        }

                        // Separator
                        Rectangle {
                            visible: modelData.type !== "header"
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                            color: internal.borderColor
                        }

                        // Type indicator (+/-/space)
                        Text {
                            visible: modelData.type !== "header"
                            Layout.preferredWidth: 16
                            text: internal.getTypeIndicator(modelData.type)
                            font.pixelSize: 12
                            font.family: "monospace"
                            font.weight: Font.Bold
                            color: internal.getLineTextColor(modelData.type)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Line content
                        Text {
                            visible: modelData.type !== "header"
                            Layout.fillWidth: true
                            text: modelData.content || ""
                            font.pixelSize: 12
                            font.family: "monospace"
                            color: internal.getLineTextColor(modelData.type)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Truncation banner (T038)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: internal.isTruncated && !root.showFullDiff &&
                         !internal.isLoading && !internal.isBinary
                color: internal.surfaceColor
                border.color: internal.borderColor
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "\uf06a"  // Info circle
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: internal.hunkHeaderColor
                    }

                    Text {
                        text: qsTr("Diff truncated (%1 of %2 lines shown)")
                            .arg(internal.displayLines.length)
                            .arg(internal.totalLineCount)
                        font.pixelSize: 12
                        color: internal.subtextColor
                    }

                    Rectangle {
                        width: showFullButton.width + 16
                        height: 26
                        radius: 4
                        color: showFullMouseArea.containsMouse ?
                               internal.overlayColor : internal.surfaceColor
                        border.color: internal.hunkHeaderColor
                        border.width: 1

                        Text {
                            id: showFullButton
                            anchors.centerIn: parent
                            text: qsTr("Show full diff")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: internal.hunkHeaderColor
                        }

                        MouseArea {
                            id: showFullMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                console.log("[DiffViewer] Show full diff clicked")
                                root.showFullDiff = true
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // PROCESSES (T087)
    // =========================================================================

    /**
     * Process: Check file size before loading diff (T087)
     * Uses stat command to get file size
     */
    Process {
        id: fileSizeProcess
        running: false

        property string filePath: ""
        property string stdoutText: ""

        command: ["stat", "-c", "%s", filePath]

        stdout: StdioCollector {
            onCollected: text => {
                fileSizeProcess.stdoutText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const sizeBytes = parseInt(stdoutText.trim(), 10)
                internal.fileSizeBytes = sizeBytes

                if (sizeBytes > internal.maxFileSizeBytes) {
                    console.log("[DiffViewer] File too large:", internal.formatFileSize(sizeBytes))
                    internal.isFileTooLarge = true
                    internal.isLoading = false
                } else {
                    // File size is OK, proceed to load diff
                    internal.isFileTooLarge = false
                    Services.GitService.getDiff(root.filePath, root.isStaged)
                }
            } else {
                // Couldn't check size (file might be new/deleted), proceed with diff
                console.log("[DiffViewer] Could not check file size, proceeding with diff")
                internal.isFileTooLarge = false
                Services.GitService.getDiff(root.filePath, root.isStaged)
            }

            stdoutText = ""
        }
    }

    /**
     * Process: Open file in external editor (T087)
     * Uses xdg-open on Linux
     */
    Process {
        id: externalEditorProcess
        running: false

        property string filePath: ""

        command: ["xdg-open", filePath]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[DiffViewer] Failed to open external editor")
            }
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[DiffViewer] Initialized for:", root.filePath)
        // Auto-load if filePath is set
        if (root.filePath) {
            loadDiff()
        }
    }

    Component.onDestruction: {
        console.log("[DiffViewer] Destroyed")
    }
}
