pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../styles"

Rectangle {
    id: root
    color: Colors.surfaceDark
    radius: 10

    // Collapsible state
    property bool isCollapsed: false

    // Animated width based on collapsed state
    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    FontLoader {
        id: outfitFont
        source: "https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4TC1C4G-EiAou6Y.ttf"
    }

    FontLoader {
        id: poppinsFont
        source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLCz7Z1JlFc-K.ttf"  // Poppins SemiBold
    }

    property int currentIndex: 0
    property int editingBoardId: -1
    property int selectedBoardId: soundboardService?.activeBoardId ?? -1  // Track which board is selected (for viewing), initialize to first active board
    signal selected(string route)
    signal soundboardSelected(int boardId)
    signal addSoundboardClicked  // Emitted when a soundboard is selected

    ListModel {
        id: menuModel
        ListElement {
            title: "Soundboard"
            route: "soundboard"
            iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_soundboard.svg"
        }
        ListElement {
            title: "Audio Playback Engine"
            route: "engine"
            iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_play.svg"
        }

        ListElement {
            title: "Application Settings"
            route: "settings"
            iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_settings.svg"
        }
        ListElement {
            title: "Statistics & Reporting"
            route: "stats"
            iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_stats.svg"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // ----- Header -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Image {
                source: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_logo.png"
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                Layout.preferredHeight: 40
                Layout.preferredWidth: 120
                Layout.alignment: Qt.AlignLeft
                visible: !root.isCollapsed
            }

            Item {
                Layout.fillWidth: true
            }

            // Toggle button
            Rectangle {
                width: 36
                height: 36
                radius: 8
                color: toggleMouse.containsMouse ? Colors.surfaceLight : "transparent"
                Layout.alignment: Qt.AlignRight

                Text {
                    anchors.centerIn: parent
                    text: root.isCollapsed ? "☰" : "‹"
                    color: Colors.textPrimary
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isCollapsed = !root.isCollapsed;
                    }
                }
            }
        }

        // Divider
        Image {
            source: "qrc:/qt/qml/TalkLess/resources/icons/decorations/ic_sidebar_divider.svg"
            Layout.fillWidth: true
            fillMode: Image.Stretch
            Layout.preferredHeight: 2
            Layout.bottomMargin: 6
        }

        // ----- Menu list -----
        ListView {
            id: menuList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: menuModel

            delegate: Item {
                id: rowItem
                width: menuList.width
                height: root.isCollapsed ? 48 : 54

                required property int index
                required property string title
                required property string route
                required property string iconSource

                readonly property bool isSelected: (rowItem.index === root.currentIndex)

                // Selected background for collapsed state - gradient
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    visible: rowItem.isSelected && root.isCollapsed
                    layer.enabled: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.gradientPrimaryStart
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.gradientPrimaryEnd
                        }
                    }
                }

                // Selected background for expanded state - gradient
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: rowItem.isSelected && !root.isCollapsed
                    layer.enabled: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.gradientPrimaryStart
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.gradientPrimaryEnd
                        }
                    }
                }

                // Hover background
                Rectangle {
                    anchors.fill: parent
                    radius: root.isCollapsed ? 12 : 16
                    visible: !rowItem.isSelected && mouse.containsMouse
                    color: Colors.surfaceLight
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.isCollapsed ? 0 : 12
                    anchors.rightMargin: root.isCollapsed ? 0 : 12
                    spacing: root.isCollapsed ? 0 : 12
                    layoutDirection: root.isCollapsed ? Qt.LeftToRight : Qt.LeftToRight

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 12
                        color: rowItem.isSelected ? Colors.textOnPrimary : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                        border.width: 1
                        border.color: rowItem.isSelected ? Colors.textOnPrimary : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                        Layout.alignment: root.isCollapsed ? Qt.AlignHCenter : Qt.AlignVCenter

                        Image {
                            id: iconImage
                            anchors.centerIn: parent
                            source: rowItem.iconSource
                            width: 18
                            height: 18
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: iconImage
                            source: iconImage
                            colorization: 1.0
                            colorizationColor: rowItem.isSelected ? Colors.accent : Qt.rgba(Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.86)
                        }
                    }

                    Text {
                        text: rowItem.title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Colors.textPrimary
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        visible: !root.isCollapsed
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: () => {
                        root.currentIndex = rowItem.index;
                        root.selected(rowItem.route);
                    }
                }

                // Tooltip for collapsed sidebar
                ToolTip {
                    visible: root.isCollapsed && mouse.containsMouse
                    text: rowItem.title
                    delay: 300
                    timeout: 5000
                    x: parent.width + 10
                    y: (parent.height - height) / 2

                    background: Rectangle {
                        color: Colors.surface
                        border.color: Colors.border
                        border.width: 1
                        radius: 6
                    }

                    contentItem: Text {
                        text: rowItem.title
                        color: Colors.textPrimary
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 13
                    }
                }
            }
        }

        // 2px dividing line before soundboards - full width
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            Layout.leftMargin: -18  // Extend to edge
            Layout.rightMargin: -18  // Extend to edge
            color: Colors.surfaceLight
        }

        // ==========================
        // Soundboards bottom section
        // ==========================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            // Always visible - shows different layout based on collapsed state

            // Soundboards list
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isCollapsed ? 180 : 240

                ListView {
                    id: boardsList
                    anchors.fill: parent
                    clip: true
                    spacing: root.isCollapsed ? 8 : 10

                    model: soundboardsModel

                    delegate: Item {
                        id: boardRow
                        width: boardsList.width
                        height: root.isCollapsed ? 48 : 56

                        // from model roles - use required property for ComponentBehavior: Bound
                        required property int index
                        required property int id
                        required property string name
                        required property string hotkey
                        required property string imagePath
                        required property bool isActive

                        // Aliases for convenience
                        readonly property int boardId: id
                        readonly property string boardName: name
                        readonly property string boardHotkey: hotkey
                        readonly property string boardImage: imagePath
                        readonly property bool active: isActive

                        // Mouse area for the whole row - placed at the end to be on top
                        // This catches all clicks and handles row selection
                        MouseArea {
                            id: mouse2
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            // Lower z than interactive child elements
                            z: 0

                            onClicked: mouse => {
                                if (root.editingBoardId === -1) {
                                    // Select this soundboard (for viewing)
                                    console.log("Soundboard row clicked:", boardRow.boardId, boardRow.boardName);
                                    root.selectedBoardId = boardRow.boardId;
                                    root.soundboardSelected(boardRow.boardId);
                                }
                            }

                            onDoubleClicked: () => {
                                if (!root.isCollapsed) {
                                    root.editingBoardId = boardRow.boardId;
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root.isCollapsed ? 12 : 14
                            // Show selection highlight (blue border) or active state (filled) or hover
                            color: {
                                if (root.selectedBoardId === boardRow.boardId) {
                                    return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1);  // Light blue for selected
                                } else if (mouse2.containsMouse) {
                                    return Colors.surfaceLight;
                                } else {
                                    return "transparent";
                                }
                            }
                            border.width: root.selectedBoardId === boardRow.boardId ? 1 : 0
                            border.color: Colors.accent
                        }

                        // Collapsed mode layout - just image with checkbox overlay
                        Item {
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            visible: root.isCollapsed

                            // Soundboard image - simple clip for rounded corners (performant)
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "#141414"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    fillMode: Image.PreserveAspectCrop
                                    // Add file:// prefix for local paths
                                    source: {
                                        if (!boardRow.boardImage || boardRow.boardImage.length === 0) {
                                            return "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg";
                                        }
                                        if (boardRow.boardImage.startsWith("qrc:") || boardRow.boardImage.startsWith("file:")) {
                                            return boardRow.boardImage;
                                        }
                                        return "file:///" + boardRow.boardImage;
                                    }
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            // Checkbox overlay on top-right corner
                            Rectangle {
                                id: collapsedCheckbox
                                width: 18
                                height: 18
                                radius: 4
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: -4
                                anchors.topMargin: -4
                                z: 10
                                border.width: 2
                                border.color: boardRow.active ? Colors.gradientPrimaryEnd : "#AAFFFFFF"
                                color: collapsedCheckboxMouse.containsMouse ? "#333333" : (boardRow.active ? "#2A2A2A" : "#1A1A1A")

                                // Checkmark icon when active
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colors.gradientPrimaryEnd
                                    visible: boardRow.active
                                }

                                MouseArea {
                                    id: collapsedCheckboxMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: 20

                                    onClicked: mouse => {
                                        mouse.accepted = true;  // Stop propagation
                                        console.log("Collapsed checkbox clicked - toggling board:", boardRow.boardId);
                                        soundboardsModel.toggleActiveById(boardRow.boardId);
                                    }
                                }
                            }
                        }

                        // Expanded mode layout - full row with checkbox, image, name, delete
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            visible: !root.isCollapsed

                            // Allow mouse events to pass through to mouse2 below, except for interactive children
                            // This is handled by not setting z and letting child MouseAreas handle their own events

                            // checkbox indicator - clicking this toggles the soundboard active state
                            Rectangle {
                                id: checkboxIndicator
                                width: 22
                                height: 22
                                radius: 4  // Square with rounded corners for checkbox
                                border.width: boardRow.active ? 0 : 2
                                border.color: boardRow.active ? "transparent" : (checkboxMouse.containsMouse ? Colors.accent : Qt.alpha(Colors.white, 0.35))

                                color: boardRow.active ? Colors.accent : (checkboxMouse.containsMouse ? Colors.surfaceLight : "transparent")

                                // Checkmark icon when active
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Colors.borderLight
                                    opacity: root.enabled ? 1.0 : 0.6
                                    visible: boardRow.active
                                }

                                MouseArea {
                                    id: checkboxMouse
                                    anchors.fill: parent
                                    anchors.margins: -4  // Make clickable area slightly larger
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: 20

                                    onClicked: mouse => {
                                        mouse.accepted = true;  // Stop propagation
                                        console.log("Checkbox clicked - toggling board:", boardRow.boardId);
                                        soundboardsModel.toggleActiveById(boardRow.boardId);
                                    }
                                }
                            }

                            // Soundboard image - rounded corners with layer mask
                            Item {
                                width: 44
                                height: 44

                                Rectangle {
                                    id: imageMask
                                    anchors.fill: parent
                                    radius: 12
                                    visible: false
                                }

                                Image {
                                    id: soundboardImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: (boardRow.boardImage && boardRow.boardImage.length > 0) ? boardRow.boardImage : "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg"
                                    visible: false
                                }

                                // Simple clip for rounded corners (performant)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Colors.surface
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        fillMode: Image.PreserveAspectCrop
                                        // Add file:// prefix for local paths (paths not starting with qrc: or file:)
                                        source: {
                                            if (!boardRow.boardImage || boardRow.boardImage.length === 0) {
                                                return "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg";
                                            }
                                            if (boardRow.boardImage.startsWith("qrc:") || boardRow.boardImage.startsWith("file:")) {
                                                return boardRow.boardImage;
                                            }
                                            // Windows paths need file:/// (three slashes) for absolute paths
                                            return "file:///" + boardRow.boardImage;
                                        }
                                        asynchronous: true
                                        cache: true
                                    }
                                }
                            }

                            // Soundboard name with Poppins SemiBold 14px
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Display mode (Text) - Poppins SemiBold 14px
                                Text {
                                    id: nameLabel
                                    visible: root.editingBoardId !== boardRow.boardId
                                    text: boardRow.boardName
                                    elide: Text.ElideRight
                                    color: Colors.textPrimary
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Poppins"
                                    lineHeight: 1.0
                                    Layout.fillWidth: true
                                }

                                // Edit mode (TextField)
                                TextField {
                                    id: nameEditor
                                    visible: root.editingBoardId === boardRow.boardId
                                    text: boardRow.boardName
                                    selectByMouse: true
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28

                                    background: Rectangle {
                                        color: Colors.background
                                        radius: 6
                                        border.color: Colors.gradientPrimaryEnd
                                        border.width: 1
                                    }

                                    color: Colors.textPrimary
                                    font.pixelSize: 14
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Poppins"

                                    // Prevent clicks from propagating
                                    MouseArea {
                                        anchors.fill: parent
                                        propagateComposedEvents: false
                                        onPressed: mouse => {
                                            mouse.accepted = false;
                                        }
                                    }

                                    // When this row becomes editable, focus + select all
                                    onVisibleChanged: {
                                        if (visible) {
                                            text = boardRow.boardName;
                                            forceActiveFocus();
                                            selectAll();
                                        }
                                    }

                                    // Commit rename when user finishes
                                    onEditingFinished: {
                                        const newName = text.trim();
                                        if (newName.length > 0 && newName !== boardRow.boardName) {
                                            soundboardService.renameBoard(boardRow.boardId, newName);
                                            // Model automatically reloads via boardsChanged signal
                                        }
                                        root.editingBoardId = -1;
                                    }

                                    Keys.onReturnPressed: {
                                        focus = false;
                                    }
                                    Keys.onEscapePressed: {
                                        text = boardRow.boardName;
                                        root.editingBoardId = -1;
                                    }
                                }
                            }

                            // Delete button (visible on hover) - modern style
                            Rectangle {
                                id: deleteBtn
                                width: 28
                                height: 28
                                radius: 8
                                visible: mouse2.containsMouse && root.editingBoardId !== boardRow.boardId
                                z: 10  // Ensure it's on top

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: deleteBtnMouse.containsMouse ? Colors.error : Colors.surfaceLight
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: deleteBtnMouse.containsMouse ? Colors.errorLight : Colors.surface
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗑️"
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: deleteBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    propagateComposedEvents: false

                                    onClicked: mouse => {
                                        mouse.accepted = true;
                                        console.log("Delete clicked for board:", boardRow.boardId, boardRow.boardName);
                                        deleteConfirmDialog.boardIdToDelete = boardRow.boardId;
                                        deleteConfirmDialog.boardNameToDelete = boardRow.boardName;
                                        deleteConfirmDialog.open();
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                        // Tooltip for collapsed sidebar - soundboard name
                        ToolTip {
                            visible: root.isCollapsed && mouse2.containsMouse
                            text: boardRow.boardName
                            delay: 300
                            timeout: 5000
                            x: boardRow.width + 10
                            y: (boardRow.height - height) / 2

                            background: Rectangle {
                                color: Colors.surface
                                border.color: Colors.border
                                border.width: 1
                                radius: 6
                            }

                            contentItem: Text {
                                text: boardRow.boardName
                                color: Colors.textPrimary
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Poppins"
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            // Add Soundboard button - shows in both modes
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isCollapsed ? 44 : 48
                text: "Add Soundboard"

                background: Rectangle {
                    radius: 12
                    color: Colors.surfaceLight  // Brown/maroon background -> Surface Highlight
                }

                contentItem: Item {
                    anchors.fill: parent

                    // Collapsed mode - just centered plus icon
                    Rectangle {
                        visible: root.isCollapsed
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 8
                        color: "#4F3B3B"

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: "#FFFFFF"
                            font.pixelSize: 20
                            font.weight: Font.Normal
                        }
                    }

                    // Expanded mode - full row layout
                    RowLayout {
                        visible: !root.isCollapsed
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Plus icon in rounded square
                        Rectangle {
                            width: 52
                            height: 36
                            radius: 8
                            color: "#4F3B3B"

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: "#FFFFFF"
                                font.pixelSize: 20
                                font.weight: Font.Normal
                            }
                        }

                        Text {
                            text: "Add Soundboard"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Poppins"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }
                }

                onClicked: {
                    root.addSoundboardClicked();
                }

                // Tooltip for collapsed sidebar
                ToolTip {
                    visible: root.isCollapsed && parent.hovered
                    text: "Add Soundboard"
                    delay: 300
                    timeout: 5000
                    x: parent.width + 10
                    y: (parent.height - height) / 2

                    background: Rectangle {
                        color: Colors.surface
                        border.color: Colors.border
                        border.width: 1
                        radius: 6
                    }

                    contentItem: Text {
                        text: "Add Soundboard"
                        color: Colors.textPrimary
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Poppins"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    // Delete confirmation dialog - at root level for proper overlay
    Dialog {
        id: deleteConfirmDialog
        title: "Delete Soundboard"
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 300
        padding: 20

        property int boardIdToDelete: -1
        property string boardNameToDelete: ""

        onOpened: () => {
            console.log("Dialog opened for deleting board:", boardIdToDelete, boardNameToDelete);
        }

        background: Rectangle {
            color: Colors.surface
            radius: 12
            border.color: Colors.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: "Are you sure you want to delete \"" + deleteConfirmDialog.boardNameToDelete + "\"?"
                color: Colors.textPrimary
                font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Cancel"
                    onClicked: deleteConfirmDialog.close()

                    background: Rectangle {
                        color: parent.hovered ? Qt.lighter(Colors.surfaceLight, 1.2) : Colors.surfaceLight
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Colors.textPrimary
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Delete"
                    onClicked: () => {
                        console.log("Deleting board:", deleteConfirmDialog.boardIdToDelete);
                        const result = soundboardService.deleteBoard(deleteConfirmDialog.boardIdToDelete);
                        console.log("Delete result:", result);
                        // Model automatically reloads via boardsChanged signal
                        deleteConfirmDialog.close();
                    }

                    background: Rectangle {
                        color: parent.hovered ? Colors.error : Colors.error
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Colors.textOnPrimary
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
