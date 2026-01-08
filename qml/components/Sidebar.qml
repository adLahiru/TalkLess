// SideBar.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    color: "#1F1F1F"
    radius: 10

    FontLoader {
        id: outfitFont
        source: "https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4TC1C4G-EiAou6Y.ttf"
    }

    property int currentIndex: 0
    property int editingBoardId: -1
    property int selectedBoardId: -1  // Track which board is selected (for viewing)
    signal selected(string route)
    signal soundboardSelected(int boardId)  // Emitted when a soundboard is selected

    ListModel {
        id: menuModel
        ListElement { title: "Soundboard";            route: "soundboard"; iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_soundboard.svg" }
        ListElement { title: "Audio Playback Engine"; route: "engine";     iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_play.svg"  }
        ListElement { title: "Macros & Automation";   route: "macros";     iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_macros.svg" }
        ListElement { title: "Application Settings";  route: "settings";   iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_settings.svg"  }
        ListElement { title: "Statistics & Reporting";route: "stats";      iconSource: "qrc:/qt/qml/TalkLess/resources/icons/sidebar/ic_nav_stats.svg" }
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
            }

            Item { Layout.fillWidth: true }
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
                height: 54

                required property int index
                required property string title
                required property string route
                required property string iconSource

                readonly property bool isSelected: (rowItem.index === root.currentIndex)

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: rowItem.isSelected
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#3B82F6" }
                        GradientStop { position: 1.0; color: "#D214FD" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: !rowItem.isSelected && mouse.containsMouse
                    color: "#1B1D24"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 34; height: 34
                        radius: 12
                        color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"
                        border.width: 1
                        border.color: rowItem.isSelected ? "#FFFFFF" : "#4F3B82F6"

                        Image {
                            id: iconImage
                            anchors.centerIn: parent
                            source: rowItem.iconSource
                            width: 18; height: 18
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
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.currentIndex = rowItem.index
                        root.selected(rowItem.route)
                    }
                }
            }
        }

        // Divider before soundboards
        Image {
            source: "qrc:/qt/qml/TalkLess/resources/icons/decorations/ic_sidebar_divider.svg"
            Layout.fillWidth: true
            fillMode: Image.Stretch
            Layout.preferredHeight: 2
        }

        // ==========================
        // Soundboards bottom section
        // ==========================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // title row
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Soundboards"
                    color: "#B3FFFFFF"
                    font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                // Optional: quick refresh
                ToolButton {
                    text: "⟳"
                    onClicked: soundboardsModel.reload()
                }
            }

            // Soundboards list
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 240

                ListView {
                    id: boardsList
                    anchors.fill: parent
                    clip: true
                    spacing: 10

                    model: soundboardsModel

                    delegate: Item {
                        id: boardRow
                        width: boardsList.width
                        height: 56

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
                            
                            onClicked: {
                                if (root.editingBoardId === -1) {
                                    // Select this soundboard (for viewing)
                                    root.selectedBoardId = boardRow.boardId
                                    root.soundboardSelected(boardRow.boardId)
                                }
                            }

                            onDoubleClicked: {
                                root.editingBoardId = boardRow.boardId
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            // Show selection highlight (blue border) or active state (filled) or hover
                            color: {
                                if (root.selectedBoardId === boardRow.boardId) {
                                    return "#1A3B82F6"  // Light blue for selected
                                } else if (mouse2.containsMouse) {
                                    return "#232323"
                                } else {
                                    return "transparent"
                                }
                            }
                            border.width: root.selectedBoardId === boardRow.boardId ? 1 : 0
                            border.color: "#3B82F6"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            z: 1  // Above the background

                            // radio indicator - clicking this activates the soundboard
                            Rectangle {
                                id: radioIndicator
                                width: 22; height: 22
                                radius: 11
                                border.width: 2
                                border.color: boardRow.active ? "#D214FD" : "#5AFFFFFF"
                                color: radioMouse.containsMouse ? "#333333" : "transparent"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12
                                    radius: 6
                                    visible: boardRow.active
                                    color: "#D214FD"
                                }

                                MouseArea {
                                    id: radioMouse
                                    anchors.fill: parent
                                    anchors.margins: -4  // Make clickable area slightly larger
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        console.log("Radio clicked - activating board:", boardRow.boardId)
                                        soundboardsModel.activateById(boardRow.boardId)
                                    }
                                }
                            }

                            // image (optional)
                            Rectangle {
                                width: 38; height: 38
                                radius: 10
                                color: "#141414"
                                border.width: 1
                                border.color: "#2D2D2D"

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectCrop
                                    source: (boardRow.boardImage && boardRow.boardImage.length > 0)
                                            ? boardRow.boardImage
                                            : "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                // Display mode (Text)
                                Text {
                                    id: nameLabel
                                    visible: root.editingBoardId !== boardRow.boardId
                                    text: boardRow.boardName
                                    elide: Text.ElideRight
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                                    Layout.fillWidth: true
                                    
                                    Component.onCompleted: {
                                        console.log("Name label created for board:", boardRow.boardId, "name:", boardRow.boardName)
                                    }
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
                                    font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                                    
                                    // Prevent clicks from propagating
                                    MouseArea {
                                        anchors.fill: parent
                                        propagateComposedEvents: false
                                        onPressed: (mouse) => { mouse.accepted = false }
                                    }

                                    // When this row becomes editable, focus + select all
                                    onVisibleChanged: {
                                        if (visible) {
                                            text = boardRow.boardName
                                            forceActiveFocus()
                                            selectAll()
                                        }
                                    }

                                    // Commit rename when user finishes
                                    onEditingFinished: {
                                        const newName = text.trim()
                                        if (newName.length > 0 && newName !== boardRow.boardName) {
                                            soundboardService.renameBoard(boardRow.boardId, newName)
                                            soundboardsModel.reload()
                                        }
                                        root.editingBoardId = -1
                                    }

                                    Keys.onReturnPressed: {
                                        focus = false
                                    }
                                    Keys.onEscapePressed: {
                                        text = boardRow.boardName
                                        root.editingBoardId = -1
                                    }
                                }

                                // Hotkey pill (optional)
                                Text {
                                    text: boardRow.boardHotkey && boardRow.boardHotkey.length > 0 ? ("Hotkey: " + boardRow.boardHotkey) : ""
                                    visible: text.length > 0 && root.editingBoardId !== boardRow.boardId
                                    elide: Text.ElideRight
                                    color: "#B3FFFFFF"
                                    font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                                    font.pixelSize: 11
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
                                    GradientStop { position: 0.0; color: deleteBtnMouse.containsMouse ? "#FF3B30" : "#3A3A3A" }
                                    GradientStop { position: 1.0; color: deleteBtnMouse.containsMouse ? "#FF6B60" : "#2A2A2A" }
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
                                    
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        console.log("Delete clicked for board:", boardRow.boardId, boardRow.boardName)
                                        deleteConfirmDialog.boardIdToDelete = boardRow.boardId
                                        deleteConfirmDialog.boardNameToDelete = boardRow.boardName
                                        deleteConfirmDialog.open()
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }

                    }
                }
            }

            // Add Soundboard
            Button {
                Layout.fillWidth: true
                text: "Add soundboard"

                background: Rectangle {
                    radius: 14
                    color: "#1B1D24"
                    border.width: 1
                    border.color: "#2D2D2D"
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28
                        radius: 10
                        color: "#262626"
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: "Add soundboard"
                        color: "#FFFFFF"
                        font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }
                }

                onClicked: {
                    // Create immediately with a placeholder name
                    const newId = soundboardService.createBoard("New Soundboard")
                    root.editingBoardId = newId

                    // Refresh model (usually boardsChanged triggers reload automatically,
                    // but calling reload makes it immediate)
                    soundboardsModel.reload()

                    // Scroll to the new one and start editing
                    const row = soundboardsModel.rowForId(newId)
                    if (row >= 0) {
                        boardsList.positionViewAtIndex(row, ListView.End)
                        // Focus happens automatically when the TextField becomes visible
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
        
        onOpened: {
            console.log("Dialog opened for deleting board:", boardIdToDelete, boardNameToDelete)
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
                    onClicked: {
                        console.log("Deleting board:", deleteConfirmDialog.boardIdToDelete)
                        const result = soundboardService.deleteBoard(deleteConfirmDialog.boardIdToDelete)
                        console.log("Delete result:", result)
                        soundboardsModel.reload()
                        deleteConfirmDialog.close()
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
