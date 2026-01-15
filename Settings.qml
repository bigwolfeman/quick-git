/**
 * Settings.qml - Settings Panel for Quick-Git
 *
 * This component provides a settings interface with:
 * - Accessibility section: Colorblind mode toggle, palette selector
 * - General section: Refresh interval slider, default view dropdown
 * - Reset to defaults button
 *
 * Tasks Implemented:
 * - T075: Create Settings.qml panel component with preferences UI
 * - T076: Add colorblind mode toggle binding to SettingsService.colorblindMode
 * - T077: Add palette selector dropdown (Shapes+Labels, High Contrast, Deuteranopia, Protanopia)
 * - T083: Add refreshInterval setting control in Settings.qml
 * - T084: Add defaultView setting control in Settings.qml
 *
 * @see specs/001-quick-git-plugin/spec.md (US7)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Services" as Services

Rectangle {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    /**
     * Whether the settings panel is visible
     */
    property bool isOpen: false

    // =========================================================================
    // PUBLIC SIGNALS
    // =========================================================================

    /**
     * Emitted when close button is clicked
     */
    signal closeRequested()

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

        // Palette display names mapped to values
        readonly property var paletteOptions: [
            { name: qsTr("Shapes + Labels"), value: "shapes" },
            { name: qsTr("High Contrast"), value: "highcontrast" },
            { name: qsTr("Deuteranopia (Red-Green)"), value: "deuteranopia" },
            { name: qsTr("Protanopia (Red)"), value: "protanopia" }
        ]

        // View display names mapped to values
        readonly property var viewOptions: [
            { name: qsTr("Commits"), value: "commits" },
            { name: qsTr("Issues"), value: "issues" }
        ]

        /**
         * Get current palette index for combo box
         */
        function getCurrentPaletteIndex() {
            const currentPalette = Services.SettingsService.colorblindPalette
            for (let i = 0; i < paletteOptions.length; i++) {
                if (paletteOptions[i].value === currentPalette) {
                    return i
                }
            }
            return 0
        }

        /**
         * Get current view index for combo box
         */
        function getCurrentViewIndex() {
            const currentView = Services.SettingsService.defaultView
            for (let i = 0; i < viewOptions.length; i++) {
                if (viewOptions[i].value === currentView) {
                    return i
                }
            }
            return 0
        }

        /**
         * Reset all settings to defaults
         */
        function resetToDefaults() {
            Services.SettingsService.setColorblindMode(false)
            Services.SettingsService.setColorblindPalette("shapes")
            Services.SettingsService.setRefreshInterval(30)
            Services.SettingsService.setDefaultView("commits")
            console.log("[Settings] Reset to defaults")
        }

        /**
         * Format interval for display
         */
        function formatInterval(seconds) {
            if (seconds < 60) {
                return qsTr("%1 seconds").arg(seconds)
            } else {
                const minutes = Math.floor(seconds / 60)
                const remainingSeconds = seconds % 60
                if (remainingSeconds === 0) {
                    return minutes === 1 ? qsTr("1 minute") : qsTr("%1 minutes").arg(minutes)
                }
                return qsTr("%1m %2s").arg(minutes).arg(remainingSeconds)
            }
        }
    }

    // =========================================================================
    // APPEARANCE
    // =========================================================================

    color: internal.backgroundColor
    radius: 12
    border.color: internal.borderColor
    border.width: 1

    // =========================================================================
    // LAYOUT
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // =====================================================================
        // HEADER
        // =====================================================================

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Gear icon
            Text {
                text: "\uf013"  // Gear icon
                font.family: "Symbols Nerd Font"
                font.pixelSize: 20
                color: internal.accentColor
            }

            // Title
            Text {
                Layout.fillWidth: true
                text: qsTr("Settings")
                font.pixelSize: 18
                font.weight: Font.Bold
                color: internal.textColor
            }

            // Close button
            Rectangle {
                id: closeButton
                width: 32
                height: 32
                radius: 16
                color: closeMouseArea.containsMouse ? internal.overlayColor : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"  // X icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: internal.subtextColor
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: internal.borderColor
        }

        // =====================================================================
        // SCROLLABLE CONTENT
        // =====================================================================

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 24

                // =============================================================
                // ACCESSIBILITY SECTION
                // =============================================================

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Section header
                    RowLayout {
                        spacing: 8

                        Text {
                            text: "\uf06e"  // Eye icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: internal.accentColor
                        }

                        Text {
                            text: qsTr("Accessibility")
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: internal.textColor
                        }
                    }

                    // Colorblind Mode Toggle (T076)
                    Rectangle {
                        Layout.fillWidth: true
                        height: colorblindModeContent.height + 24
                        color: internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1

                        RowLayout {
                            id: colorblindModeContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: qsTr("Colorblind Mode")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }

                                Text {
                                    text: qsTr("Show shape-based indicators with text labels")
                                    font.pixelSize: 11
                                    color: internal.subtextColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            // Toggle Switch
                            Rectangle {
                                id: colorblindToggle
                                width: 48
                                height: 26
                                radius: 13
                                color: Services.SettingsService.colorblindMode ?
                                    internal.accentColor : internal.overlayColor

                                Rectangle {
                                    id: toggleKnob
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Services.SettingsService.colorblindMode ? parent.width - width - 3 : 3
                                    color: internal.textColor

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsService.setColorblindMode(
                                            !Services.SettingsService.colorblindMode
                                        )
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    // Palette Selector (T077)
                    Rectangle {
                        Layout.fillWidth: true
                        height: paletteContent.height + 24
                        color: internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1
                        opacity: Services.SettingsService.colorblindMode ? 1.0 : 0.5

                        ColumnLayout {
                            id: paletteContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 10

                            ColumnLayout {
                                spacing: 4

                                Text {
                                    text: qsTr("Color Palette")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }

                                Text {
                                    text: qsTr("Choose colors optimized for your vision")
                                    font.pixelSize: 11
                                    color: internal.subtextColor
                                }
                            }

                            // Custom dropdown
                            Rectangle {
                                id: paletteDropdown
                                Layout.fillWidth: true
                                height: 40
                                radius: 6
                                color: paletteDropdownMouse.containsMouse ?
                                    internal.overlayColor : internal.backgroundColor
                                border.color: palettePopup.visible ?
                                    internal.accentColor : internal.borderColor
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: internal.paletteOptions[internal.getCurrentPaletteIndex()].name
                                        font.pixelSize: 13
                                        color: internal.textColor
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: palettePopup.visible ? "\ue5ce" : "\ue5cf"  // Chevron up/down
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                    }
                                }

                                MouseArea {
                                    id: paletteDropdownMouse
                                    anchors.fill: parent
                                    cursorShape: Services.SettingsService.colorblindMode ?
                                        Qt.PointingHandCursor : Qt.ArrowCursor
                                    hoverEnabled: true
                                    enabled: Services.SettingsService.colorblindMode

                                    onClicked: {
                                        palettePopup.visible = !palettePopup.visible
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Palette dropdown popup
                            Rectangle {
                                id: palettePopup
                                visible: false
                                Layout.fillWidth: true
                                height: palettePopupColumn.height + 8
                                color: internal.surfaceColor
                                radius: 6
                                border.color: internal.borderColor
                                border.width: 1

                                ColumnLayout {
                                    id: palettePopupColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    spacing: 2

                                    Repeater {
                                        model: internal.paletteOptions

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 36
                                            radius: 4
                                            color: {
                                                if (Services.SettingsService.colorblindPalette === modelData.value) {
                                                    return Qt.alpha(internal.accentColor, 0.2)
                                                }
                                                return paletteItemMouse.containsMouse ?
                                                    internal.overlayColor : "transparent"
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    font.pixelSize: 13
                                                    color: internal.textColor
                                                }

                                                Text {
                                                    visible: Services.SettingsService.colorblindPalette === modelData.value
                                                    text: "\uf00c"  // Checkmark
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: 12
                                                    color: internal.accentColor
                                                }
                                            }

                                            MouseArea {
                                                id: paletteItemMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: {
                                                    Services.SettingsService.setColorblindPalette(modelData.value)
                                                    palettePopup.visible = false
                                                }
                                            }

                                            Behavior on color {
                                                ColorAnimation { duration: 100 }
                                            }
                                        }
                                    }
                                }
                            }

                            // Color preview swatches
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: qsTr("Preview:")
                                    font.pixelSize: 11
                                    color: internal.subtextColor
                                }

                                // Add color swatch
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 3
                                    color: {
                                        switch (Services.SettingsService.colorblindPalette) {
                                            case "shapes": return "#a6e3a1"
                                            case "highcontrast": return "#00ff00"
                                            case "deuteranopia": return "#89b4fa"
                                            case "protanopia": return "#a6e3a1"
                                            default: return "#a6e3a1"
                                        }
                                    }

                                    ToolTip {
                                        visible: addSwatchMouse.containsMouse
                                        text: qsTr("Add/Open")
                                        delay: 500
                                    }

                                    MouseArea {
                                        id: addSwatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }

                                // Remove color swatch
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 3
                                    color: {
                                        switch (Services.SettingsService.colorblindPalette) {
                                            case "shapes": return "#f38ba8"
                                            case "highcontrast": return "#ff0000"
                                            case "deuteranopia": return "#fab387"
                                            case "protanopia": return "#f9e2af"
                                            default: return "#f38ba8"
                                        }
                                    }

                                    ToolTip {
                                        visible: removeSwatchMouse.containsMouse
                                        text: qsTr("Remove/Closed")
                                        delay: 500
                                    }

                                    MouseArea {
                                        id: removeSwatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }

                // =============================================================
                // GENERAL SECTION
                // =============================================================

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Section header
                    RowLayout {
                        spacing: 8

                        Text {
                            text: "\uf013"  // Gear icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: internal.accentColor
                        }

                        Text {
                            text: qsTr("General")
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: internal.textColor
                        }
                    }

                    // Refresh Interval (T083)
                    Rectangle {
                        Layout.fillWidth: true
                        height: refreshContent.height + 24
                        color: internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1

                        ColumnLayout {
                            id: refreshContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: qsTr("Auto-Refresh Interval")
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: internal.textColor
                                    }

                                    Text {
                                        text: qsTr("How often to check for repository changes")
                                        font.pixelSize: 11
                                        color: internal.subtextColor
                                    }
                                }

                                // Current value badge
                                Rectangle {
                                    width: intervalValueText.width + 16
                                    height: 24
                                    radius: 12
                                    color: internal.overlayColor

                                    Text {
                                        id: intervalValueText
                                        anchors.centerIn: parent
                                        text: internal.formatInterval(Services.SettingsService.refreshInterval)
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: internal.accentColor
                                    }
                                }
                            }

                            // Slider
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "5s"
                                    font.pixelSize: 10
                                    color: internal.subtextColor
                                }

                                Slider {
                                    id: refreshSlider
                                    Layout.fillWidth: true
                                    from: Services.SettingsService.minRefreshInterval
                                    to: Services.SettingsService.maxRefreshInterval
                                    stepSize: 5
                                    value: Services.SettingsService.refreshInterval

                                    onMoved: {
                                        Services.SettingsService.setRefreshInterval(value)
                                    }

                                    background: Rectangle {
                                        x: refreshSlider.leftPadding
                                        y: refreshSlider.topPadding + refreshSlider.availableHeight / 2 - height / 2
                                        width: refreshSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: internal.overlayColor

                                        Rectangle {
                                            width: refreshSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: internal.accentColor
                                            radius: 2
                                        }
                                    }

                                    handle: Rectangle {
                                        x: refreshSlider.leftPadding + refreshSlider.visualPosition * (refreshSlider.availableWidth - width)
                                        y: refreshSlider.topPadding + refreshSlider.availableHeight / 2 - height / 2
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: refreshSlider.pressed ? Qt.lighter(internal.accentColor, 1.2) : internal.accentColor
                                        border.color: internal.backgroundColor
                                        border.width: 2

                                        Behavior on color {
                                            ColorAnimation { duration: 100 }
                                        }
                                    }
                                }

                                Text {
                                    text: "5m"
                                    font.pixelSize: 10
                                    color: internal.subtextColor
                                }
                            }
                        }
                    }

                    // Default View (T084)
                    Rectangle {
                        Layout.fillWidth: true
                        height: viewContent.height + 24
                        color: internal.surfaceColor
                        radius: 8
                        border.color: internal.borderColor
                        border.width: 1

                        ColumnLayout {
                            id: viewContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12
                            spacing: 10

                            ColumnLayout {
                                spacing: 4

                                Text {
                                    text: qsTr("Default View")
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: internal.textColor
                                }

                                Text {
                                    text: qsTr("View shown when opening the panel")
                                    font.pixelSize: 11
                                    color: internal.subtextColor
                                }
                            }

                            // View dropdown
                            Rectangle {
                                id: viewDropdown
                                Layout.fillWidth: true
                                height: 40
                                radius: 6
                                color: viewDropdownMouse.containsMouse ?
                                    internal.overlayColor : internal.backgroundColor
                                border.color: viewPopup.visible ?
                                    internal.accentColor : internal.borderColor
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    // View icon
                                    Text {
                                        text: Services.SettingsService.defaultView === "commits" ?
                                            "\uf417" : "\uf41b"  // Git commit or issue icon
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 14
                                        color: internal.accentColor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: internal.viewOptions[internal.getCurrentViewIndex()].name
                                        font.pixelSize: 13
                                        color: internal.textColor
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: viewPopup.visible ? "\ue5ce" : "\ue5cf"  // Chevron up/down
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: internal.subtextColor
                                    }
                                }

                                MouseArea {
                                    id: viewDropdownMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        viewPopup.visible = !viewPopup.visible
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // View dropdown popup
                            Rectangle {
                                id: viewPopup
                                visible: false
                                Layout.fillWidth: true
                                height: viewPopupColumn.height + 8
                                color: internal.surfaceColor
                                radius: 6
                                border.color: internal.borderColor
                                border.width: 1

                                ColumnLayout {
                                    id: viewPopupColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    spacing: 2

                                    Repeater {
                                        model: internal.viewOptions

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 36
                                            radius: 4
                                            color: {
                                                if (Services.SettingsService.defaultView === modelData.value) {
                                                    return Qt.alpha(internal.accentColor, 0.2)
                                                }
                                                return viewItemMouse.containsMouse ?
                                                    internal.overlayColor : "transparent"
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                Text {
                                                    text: modelData.value === "commits" ?
                                                        "\uf417" : "\uf41b"
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: 14
                                                    color: internal.subtextColor
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    font.pixelSize: 13
                                                    color: internal.textColor
                                                }

                                                Text {
                                                    visible: Services.SettingsService.defaultView === modelData.value
                                                    text: "\uf00c"  // Checkmark
                                                    font.family: "Symbols Nerd Font"
                                                    font.pixelSize: 12
                                                    color: internal.accentColor
                                                }
                                            }

                                            MouseArea {
                                                id: viewItemMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: {
                                                    Services.SettingsService.setDefaultView(modelData.value)
                                                    viewPopup.visible = false
                                                }
                                            }

                                            Behavior on color {
                                                ColorAnimation { duration: 100 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // RESET TO DEFAULTS
                // =============================================================

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    height: resetContent.height + 16
                    color: resetMouseArea.containsMouse ?
                        Qt.alpha(internal.errorColor, 0.1) : "transparent"
                    radius: 8
                    border.color: resetMouseArea.containsMouse ?
                        internal.errorColor : internal.borderColor
                    border.width: 1

                    RowLayout {
                        id: resetContent
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "\uf021"  // Reset icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: resetMouseArea.containsMouse ?
                                internal.errorColor : internal.subtextColor
                        }

                        Text {
                            text: qsTr("Reset to Defaults")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: resetMouseArea.containsMouse ?
                                internal.errorColor : internal.textColor
                        }
                    }

                    MouseArea {
                        id: resetMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            internal.resetToDefaults()
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }

                // Spacer at bottom
                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 20
                }
            }
        }
    }

    // =========================================================================
    // CLICK-AWAY HANDLER FOR DROPDOWNS
    // =========================================================================

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            palettePopup.visible = false
            viewPopup.visible = false
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[Settings] Panel initialized")
    }

    Component.onDestruction: {
        console.log("[Settings] Panel destroyed")
    }
}
