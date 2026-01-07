// SoundboardView.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import "../components"

Rectangle {
    id: root
    color: "#0d0d0d"
    radius: 10

    // Load fonts at root level
    FontLoader {
        id: poppinsFont
        source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLEj6Z1JlFc-K.ttf"
    }

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // Main 3-column layout
    RowLayout {
        anchors.fill: parent
        spacing: 15

        // LEFT COLUMN: Banner and Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 900
            spacing: 20

            // Background Banner
            Rectangle {
                id: bannerContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 145
                Layout.maximumHeight: 145
                radius: 16
                clip: true
                color: "transparent"

                // Background image
                Image {
                    id: backgroundImage
                    anchors.fill: parent
                    source: "qrc:/qt/qml/TalkLess/resources/images/background.png"
                    fillMode: Image.PreserveAspectCrop
                }

                // Dark overlay for text readability
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.3
                }

                // Three dots menu button - top right corner
                Rectangle {
                    id: moreButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.rightMargin: 10
                    width: 28
                    height: 28
                    radius: 6
                    color: moreMouseArea.containsMouse || moreOptionsMenu.visible ? "#33FFFFFF" : "#22FFFFFF"

                    // Three vertical dots
                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: "#FFFFFF"
                            }
                        }
                    }

                    MouseArea {
                        id: moreMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            moreOptionsMenu.open()
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    // Popup menu
                    Popup {
                        id: moreOptionsMenu
                        x: (parent.width - width) / 2  // Center horizontally under the dots
                        y: parent.height + 5
                        width: 160
                        padding: 8

                        background: Rectangle {
                            color: "#1F1F1F"
                            radius: 8
                            border.color: "#333333"
                            border.width: 1
                        }

                        contentItem: Column {
                            spacing: 4

                            Repeater {
                                model: ["Select Slots", "Detach Window", "Edit Cover", "Delete"]

                                delegate: Rectangle {
                                    id: menuItem
                                    width: 144
                                    height: 36
                                    radius: 6
                                    color: menuItemMouse.containsMouse ? "#333333" : "transparent"
                                    
                                    required property string modelData

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: menuItem.modelData
                                        color: menuItem.modelData === "Delete" ? "#FF6B6B" : "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        font.weight: Font.Normal
                                    }

                                    MouseArea {
                                        id: menuItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            console.log("Menu item clicked:", menuItem.modelData)
                                            moreOptionsMenu.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Content row - text left, button right
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 25
                    anchors.rightMargin: 20
                    anchors.topMargin: 15
                    anchors.bottomMargin: 15
                    spacing: 15

                    // Text column (left side)
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        // Main text
                        Text {
                            text: "Soundboard Test"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        // Secondary text
                        Text {
                            text: "Manage and trigger your audio clips"
                            color: "#FFFFFF"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 15
                            font.weight: Font.Normal
                            opacity: 0.9
                        }
                    }

                    // Spacer
                    Item { Layout.fillWidth: true }

                    // Add Soundboard button
                    Rectangle {
                        id: addButton
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        radius: 5

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#3B82F6" }
                            GradientStop { position: 1.0; color: "#D214FD" }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Add Soundboard"
                            color: "#FFFFFF"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("Add Soundboard clicked")
                            }
                        }
                    }
                }
            }

            // Action Buttons Bar - centered below banner
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.topMargin: -10

                Rectangle {
                    id: actionButtonsBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 160
                    height: 36
                    radius: 8
                    color: "#1A1A1A"
                    border.color: "#2A2A2A"
                    border.width: 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        // Play Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: playMouseArea.containsMouse ? "#333333" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "▶️"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: playMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Play all clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Globe/Web Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: globeMouseArea.containsMouse ? "#333333" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "🌐"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: globeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Web/Share clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Edit/Pencil Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: editMouseArea.containsMouse ? "#333333" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✏️"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: editMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Edit clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Delete/Trash Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: deleteMouseArea.containsMouse ? "#333333" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "🗑️"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Delete clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }

            // Soundboard content area
            Rectangle {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0d0d0d"
                radius: 12

                // Tile sizing properties
                readonly property real tileSpacing: 15
                readonly property real tilePadding: 20
                // Width calculation: (available_width - padding*2 - spacing*3) / 4
                readonly property real tileWidth: (width - tilePadding * 2 - tileSpacing * 3) / 4
                readonly property real tileHeight: tileWidth * 79 / 111  // 111:79 aspect ratio

                // Dummy clips data
                ListModel {
                    id: dummyClipsModel
                    ListElement { modelTitle: "Morning"; modelHotkeyText: "Alt+F2+Shift"; hasTag: true }
                    ListElement { modelTitle: "Morning"; modelHotkeyText: "Alt+F2+Shift"; hasTag: true }
                    ListElement { modelTitle: "Morning"; modelHotkeyText: "Alt+F2+Shift"; hasTag: true }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: "Morning"; modelHotkeyText: "Alt+F2+Shift"; hasTag: true }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: ""; modelHotkeyText: "Alt+F2+Shift"; hasTag: false }
                    ListElement { modelTitle: "Morning"; modelHotkeyText: "Alt+F2+Shift"; hasTag: true }
                }

                // Flickable area for scrolling
                Flickable {
                    id: clipsFlickable
                    anchors.fill: parent
                    anchors.margins: contentArea.tilePadding
                    contentWidth: width
                    contentHeight: clipsGrid.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    // Grid layout for tiles
                    Flow {
                        id: clipsGrid
                        width: parent.width
                        spacing: contentArea.tileSpacing

                        // Add Audio Tile (first item)
                        AddAudioTile {
                            id: addAudioTile
                            width: contentArea.tileWidth
                            height: contentArea.tileHeight
                            enabled: true
                            onClicked: {
                                console.log("Add Audio clicked")
                            }
                        }

                        // Dummy Clip Tiles
                        Repeater {
                            model: dummyClipsModel

                            ClipTile {
                                required property string modelTitle
                                required property string modelHotkeyText
                                required property bool hasTag

                                width: contentArea.tileWidth
                                height: contentArea.tileHeight
                                title: hasTag ? modelTitle : ""
                                hotkeyText: modelHotkeyText
                                imageSource: "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"

                                onClicked: console.log("Clip clicked:", modelTitle)
                                onPlayClicked: console.log("Play clicked:", modelTitle)
                                onCopyClicked: console.log("Copy clicked:", modelTitle)
                            }
                        }
                    }

                    // Scrollbar
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }

        // RIGHT COLUMN: Sidebar (gray placeholder)
        Rectangle {
            id: rightSidebar
            Layout.preferredWidth: 250
            Layout.preferredHeight: 600
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 20
            Layout.rightMargin: 10
            color: "#2A2A2A"
            radius: 10

            // Tab state: 0=Settings, 1=Plus, 2=Record, 3=Teleprompter, 4=Speaker
            property int currentTabIndex: 2  // Default to Record tab

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 8

                // Top section with F1 label and icons
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#2A2A2A"
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        // F1 Label
                        Text {
                            text: "F1"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Icon buttons row
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            // Settings button (Tab 0)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 5
                                color: rightSidebar.currentTabIndex === 0 ? "#3B82F6" : (settingsMouseArea.containsMouse ? "#333333" : "#2A2A2A")
                                border.color: rightSidebar.currentTabIndex === 0 ? "#3B82F6" : "#3A3A3A"
                                border.width: 1

                                Image {
                                    id: settingsIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_settings.svg"
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: settingsIcon
                                    anchors.fill: settingsIcon
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }

                                MouseArea {
                                    id: settingsMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightSidebar.currentTabIndex = 0
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Plus button (Tab 1)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 5
                                color: rightSidebar.currentTabIndex === 1 ? "#3B82F6" : (plusMouseArea.containsMouse ? "#333333" : "#2A2A2A")
                                border.color: rightSidebar.currentTabIndex === 1 ? "#3B82F6" : "#3A3A3A"
                                border.width: 1

                                Image {
                                    id: plusIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_add.svg"
                                    width: 14
                                    height: 14
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: plusIcon
                                    anchors.centerIn: parent
                                    width: plusIcon.width
                                    height: plusIcon.height
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }

                                MouseArea {
                                    id: plusMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightSidebar.currentTabIndex = 1
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Record button (Tab 2)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 5
                                color: rightSidebar.currentTabIndex === 2 ? "#3B82F6" : (recordMouseArea.containsMouse ? "#333333" : "#2A2A2A")
                                border.color: rightSidebar.currentTabIndex === 2 ? "#3B82F6" : "#3A3A3A"
                                border.width: 1

                                Image {
                                    id: recordIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_record.svg"
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: recordIcon
                                    anchors.centerIn: parent
                                    width: recordIcon.width
                                    height: recordIcon.height
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }

                                MouseArea {
                                    id: recordMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightSidebar.currentTabIndex = 2
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Teleprompter button (Tab 3)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 5
                                color: rightSidebar.currentTabIndex === 3 ? "#3B82F6" : (teleprompterMouseArea.containsMouse ? "#333333" : "#2A2A2A")
                                border.color: rightSidebar.currentTabIndex === 3 ? "#3B82F6" : "#3A3A3A"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "📄"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: teleprompterMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightSidebar.currentTabIndex = 3
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            // Speaker button (Tab 4)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 5
                                color: rightSidebar.currentTabIndex === 4 ? "#3B82F6" : (speakerMouseArea.containsMouse ? "#333333" : "#2A2A2A")
                                border.color: rightSidebar.currentTabIndex === 4 ? "#3B82F6" : "#3A3A3A"
                                border.width: 1

                                Image {
                                    id: speakerIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_speaker.svg"
                                    width: 14
                                    height: 13
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: speakerIcon
                                    anchors.centerIn: parent
                                    width: speakerIcon.width
                                    height: speakerIcon.height
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }

                                MouseArea {
                                    id: speakerMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightSidebar.currentTabIndex = 4
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                }

                // Separator line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    color: "#3A3A3A"
                }

                // Recording Tab Content (Tab 2)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    visible: rightSidebar.currentTabIndex === 2

                    // Name Audio File Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Header with title and icon
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Name Audio File"
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            // Clipboard/paste icon
                            Rectangle {
                                width: 24
                                height: 24
                                color: "transparent"

                                Image {
                                    id: clipboardIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_clipboard.svg"
                                    width: 16
                                    height: 16
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: clipboardIcon
                                    anchors.fill: clipboardIcon
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Clipboard clicked")
                                }
                            }
                        }

                        // Text Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 4

                                Text {
                                    text: "Enter Name Here:"
                                    color: "#808080"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    visible: audioNameInput.text === ""
                                }

                                TextInput {
                                    id: audioNameInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    clip: true
                                    
                                    Text {
                                        anchors.fill: parent
                                        text: "_ _ _ _ _ _ _ _ _ _ _ _ _ _"
                                        color: "#666666"
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    // Input Source Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5 
                        spacing: 3

                        Text {
                            text: "Input Source"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Dropdown selector
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15

                                Text {
                                    text: "Select Mic Device"
                                    color: "#666666"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                // Dropdown arrow
                                Text {
                                    text: "▼"
                                    color: "#808080"
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Mic dropdown clicked")
                            }
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 4 }

                    // Start Recording Button Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        // Recording state
                        property bool isRecording: false

                        // Microphone button with gray background
                        Rectangle {
                            id: micButton
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignHCenter
                            radius: 15
                            color: micButtonArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                            border.color: "#4A4A4A"
                            border.width: 1

                            Image {
                                id: micIcon
                                anchors.centerIn: parent
                                source: "qrc:/qt/qml/TalkLess/resources/icons/actions/ic_mic.svg"
                                width: 18
                                height: 18
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            MultiEffect {
                                source: micIcon
                                anchors.fill: micIcon
                                colorization: 1.0
                                colorizationColor: parent.parent.isRecording ? "#3B82F6" : "#FFFFFF"
                            }

                            MouseArea {
                                id: micButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    parent.parent.isRecording = !parent.parent.isRecording
                                    console.log("Recording:", parent.parent.isRecording)
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Start Recording text
                        Text {
                            text: parent.isRecording ? "Stop Recording" : "Start Recording"
                            color: "#888888"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 9
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 8 }

                    // Trim Audio Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Header with scissors icon and title
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Scissors icon
                            Rectangle {
                                width: 16
                                height: 16
                                color: "transparent"

                                Image {
                                    id: scissorsIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_scissors.svg"
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: scissorsIcon
                                    anchors.fill: scissorsIcon
                                    colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }
                            }

                            Text {
                                text: "Trim Audio"
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        // Waveform Display
                        WaveformDisplay {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            currentTime: 90
                            totalDuration: 210
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 4 }

                    // Name Audio File Section (for saving)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 4

                        Text {
                            text: "Name Audio File"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        // Text Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: "#1A1A1A"
                            radius: 6
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 4

                                Text {
                                    text: "Enter Name Here:"
                                    color: "#808080"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 11
                                    visible: saveNameInput.text === ""
                                }

                                TextInput {
                                    id: saveNameInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 11
                                    clip: true
                                    
                                    Text {
                                        anchors.fill: parent
                                        text: "_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _"
                                        color: "#666666"
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 6 }

                    // Cancel and Save buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Spacer to push buttons to right
                        Item { Layout.fillWidth: true }

                        // Cancel button
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            color: cancelBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                            radius: 8

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: cancelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Cancel clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Save button (gradient)
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            radius: 8
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: saveBtnArea.containsMouse ? "#4A9AF7" : "#3B82F6" }
                                GradientStop { position: 1.0; color: saveBtnArea.containsMouse ? "#E040FB" : "#D214FD" }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: saveBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Save clicked")
                            }
                        }
                    }

                    // Fill remaining space
                    Item { Layout.fillHeight: true }
                }

                // Settings Tab Content (Tab 0)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 0

                    Text {
                        text: "Settings"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Panel settings will appear here"
                        color: "#666666"
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillHeight: true }
                }

                // Add Tab Content (Tab 1)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    visible: rightSidebar.currentTabIndex === 1

                    // Name Audio File Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Text {
                            text: "Name Audio File"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Text Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 4

                                Text {
                                    text: "Enter Name Here:"
                                    color: "#808080"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    visible: uploadAudioNameInput.text === ""
                                }

                                TextInput {
                                    id: uploadAudioNameInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    clip: true
                                    
                                    Text {
                                        anchors.fill: parent
                                        text: "_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _"
                                        color: "#666666"
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    // Assign to Slot Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5 
                        spacing: 8

                        Text {
                            text: "Assign to Slot"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Dropdown selector
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15

                                Text {
                                    text: "Select Available Slot"
                                    color: "#AAAAAA"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                // Dropdown arrow
                                Text {
                                    text: "▼"
                                    color: "#808080"
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Slot dropdown clicked")
                            }
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 4 }

                    // File Upload Drop Area
                    FileDropArea {
                        id: fileDropArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        
                        onFileDropped: function(filePath, fileName) {
                            console.log("File dropped:", fileName, filePath)
                            // Auto-fill the name input if empty
                            if (uploadAudioNameInput.text === "") {
                                // Remove extension from filename
                                var nameWithoutExt = fileName.replace(/\.[^/.]+$/, "")
                                uploadAudioNameInput.text = nameWithoutExt
                            }
                        }
                        
                        onFileCleared: {
                            console.log("File cleared")
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 4 }

                    // Trim Audio Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Text {
                            text: "Trim Audio"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Waveform Display (without playback controls)
                        TrimWaveform {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            currentTime: 90
                            totalDuration: 210
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 6 }

                    // Cancel and Save buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Cancel button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: uploadCancelBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                            radius: 8

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: uploadCancelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Upload Cancel clicked")
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Save button (gradient)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 8
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: uploadSaveBtnArea.containsMouse ? "#4A9AF7" : "#3B82F6" }
                                GradientStop { position: 1.0; color: uploadSaveBtnArea.containsMouse ? "#E040FB" : "#D214FD" }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: uploadSaveBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Upload Save clicked")
                            }
                        }
                    }

                    // Fill remaining space
                    Item { Layout.fillHeight: true }
                }

                // Teleprompter Tab Content (Tab 3)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 3

                    Text {
                        text: "Teleprompter"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Teleprompter content will appear here"
                        color: "#666666"
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillHeight: true }
                }

                // Speaker Tab Content (Tab 4)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 4

                    Text {
                        text: "Audio Output"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Speaker and output settings here"
                        color: "#666666"
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
