pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../styles"

Rectangle {
    id: root
    color: "#1F1F1F"
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
    property int selectedBoardId: -1  // Track which board is selected (for viewing)
    signal selected(string route)
    signal soundboardSelected(int boardId)  // Emitted when a soundboard is selected

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
            title: "Macros & Automation"
            route: "macros"
            iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_macros.svg"
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
                color: toggleMouse.containsMouse ? "#2A2A2A" : "transparent"
                Layout.alignment: Qt.AlignRight

                Text {
                    anchors.centerIn: parent
                    text: root.isCollapsed ? "☰" : "‹"
                    color: "#FFFFFF"
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isCollapsed = !root.isCollapsed
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
                    color: "#1B1D24"
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
                        color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"
                        border.width: 1
                        border.color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"
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
                            colorizationColor: rowItem.isSelected ? "#3B82F6" : "#DBFFFFFF"
                        }
                    }

                    Text {
                        text: rowItem.title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: "#FFFFFF"
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
            }
        }

        // 2px dividing line before soundboards - full width
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            Layout.leftMargin: -18  // Extend to edge
            Layout.rightMargin: -18  // Extend to edge
            color: "#2D2D2D"
        }

        // ==========================
        // Soundboards bottom section
        // ==========================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            // Always visible - adapts layout based on collapsed state

            // Soundboards list - shows full layout when expanded, just images with checkbox when collapsed
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isCollapsed ? 300 : 240

                ListView {
                    id: boardsList
                    anchors.fill: parent
                    clip: true
                    spacing: root.isCollapsed ? 8 : 10

                    model: soundboardsModel

                    delegate: Item {
                        id: boardRow
                        width: boardsList.width
                        height: root.isCollapsed ? 52 : 56

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

                        // Mouse area for the whole row (placed first = underneath)
                        MouseArea {
                            id: mouse2
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton

                            onClicked: () => {
                                if (root.isCollapsed) {
                                    // In collapsed mode, clicking the image area toggles active state
                                    // But we handle that in the checkbox overlay below
                                    root.selectedBoardId = boardRow.boardId;
                                    root.soundboardSelected(boardRow.boardId);
                                } else if (root.editingBoardId === -1) {
                                    // Select this soundboard (for viewing)
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
                            radius: root.isCollapsed ? 10 : 14
                            // Show selection highlight (blue border) or active state (filled) or hover
                            color: {
                                if (root.selectedBoardId === boardRow.boardId) {
                                    return "#1A3B82F6";  // Light blue for selected
                                } else if (mouse2.containsMouse) {
                                    return "#232323";
                                } else {
                                    return "transparent";
                                }
                            }
                            border.width: root.selectedBoardId === boardRow.boardId ? 1 : 0
                            border.color: "#3B82F6"
                        }

                        // Collapsed mode layout - just image with checkbox overlay
                        Item {
                            width: parent.height - 8  // Square, based on row height
                            height: parent.height - 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.isCollapsed

                            // Soundboard image with rounded corners
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "#141414"

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: boardRow.boardImage || "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg"
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: 48
                                                height: 48
                                                radius: 10
                                            }
                                        }
                                    }
                                }

                                // Checkbox overlay in top-right corner
                                Rectangle {
                                    id: collapsedCheckbox
                                    width: 14
                                    height: 14
                                    radius: 3
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 3
                                    anchors.rightMargin: 3
                                    color: boardRow.active ? "#D214FD" : "#80000000"
                                    border.width: 1.5
                                    border.color: boardRow.active ? "#D214FD" : "#FFFFFF"

                                    // Checkmark when active
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#FFFFFF"
                                        visible: boardRow.active
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            soundboardsModel.toggleActiveById(boardRow.boardId);
                                        }
                                    }
                                }
                            }
                        }

                        // Expanded mode layout - full row with checkbox, image, name
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            z: 1  // Above the background
                            visible: !root.isCollapsed

                            // checkbox indicator - clicking this toggles the soundboard active state
                            Rectangle {
                                id: checkboxIndicator
                                width: 22
                                height: 22
                                radius: 4  // Square with rounded corners for checkbox
                                border.width: 2
                                border.color: boardRow.active ? "#D214FD" : "#5AFFFFFF"
                                color: checkboxMouse.containsMouse ? "#333333" : "transparent"

                                // Checkmark icon when active
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#D214FD"
                                    visible: boardRow.active
                                }

                                MouseArea {
                                    id: checkboxMouse
                                    anchors.fill: parent
                                    anchors.margins: -4  // Make clickable area slightly larger
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: () => {
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

                                // Use ShaderEffectSource and OpacityMask via layer
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: "#141414"

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: boardRow.boardImage || "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg"
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: ShaderEffectSource {
                                                sourceItem: Rectangle {
                                                    width: 44
                                                    height: 44
                                                    radius: 12
                                                }
                                            }
                                        }
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
                                    color: "#FFFFFF"
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
                                        color: "#1A1A1A"
                                        radius: 6
                                        border.color: "#D214FD"
                                        border.width: 1
                                    }

                                    color: "#FFFFFF"
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
                                            soundboardsModel.reload();
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
                                        color: deleteBtnMouse.containsMouse ? "#FF3B30" : "#3A3A3A"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: deleteBtnMouse.containsMouse ? "#FF6B60" : "#2A2A2A"
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
                    }
                }
            }

            // Add Soundboard button - matches design (hidden in collapsed mode)
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                text: "Add Soundboard"
                visible: !root.isCollapsed

                background: Rectangle {
                    radius: 12
                    color: "#3D2F2F"  // Brown/maroon background
                }

                contentItem: RowLayout {
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

                onClicked: {
                    // Create immediately with a placeholder name
                    const newId = soundboardService.createBoard("New Soundboard");
                    root.editingBoardId = newId;

                    // Refresh model (usually boardsChanged triggers reload automatically,
                    // but calling reload makes it immediate)
                    soundboardsModel.reload();

                    // Scroll to the new one and start editing
                    const row = soundboardsModel.rowForId(newId);
                    if (row >= 0) {
                        boardsList.positionViewAtIndex(row, ListView.End);
                        // Focus happens automatically when the TextField becomes visible
                    }
                }
            }

            // Collapsed mode: Add button as just a plus icon
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 10
                color: addBtnMouse.containsMouse ? "#4D3F3F" : "#3D2F2F"
                visible: root.isCollapsed

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#FFFFFF"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: addBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const newId = soundboardService.createBoard("New Soundboard");
                        soundboardsModel.reload();
                        // Expand sidebar to allow editing
                        root.isCollapsed = false;
                        root.editingBoardId = newId;
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
            color: "#2A2A2A"
            radius: 12
            border.color: "#3A3A3A"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: "Are you sure you want to delete \"" + deleteConfirmDialog.boardNameToDelete + "\"?"
                color: "#FFFFFF"
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
                        color: parent.hovered ? "#444444" : "#333333"
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
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
                        soundboardsModel.reload();
                        deleteConfirmDialog.close();
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#FF3333" : "#FF4444"
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
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
