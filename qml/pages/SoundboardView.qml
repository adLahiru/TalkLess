// SoundboardView.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Row for banner (left) and other panels (right)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 145
            Layout.maximumHeight: 145
            spacing: 15

            // Background Banner - takes left portion
            Rectangle {
                id: bannerContainer
                Layout.preferredWidth: parent.width * 0.7
                Layout.preferredHeight: 145
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

            // Spacer for right side (where meters panel would go)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // Action Buttons Bar - centered below banner
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.topMargin: -10

            Rectangle {
                id: actionButtonsBar
                // Center under the banner (which is 70% of parent width)
                x: (parent.width * 0.7 - width) / 2
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
            // Width calculation: (banner_width - padding*2 - spacing*3) / 4
            // Banner is 70% of parent, so tile width = (parent.width * 0.7 - 40 - 45) / 4
            readonly property real tileWidth: (width * 0.7 - tilePadding * 2 - tileSpacing * 3) / 4
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

            // Flickable area for scrolling - constrained to banner width
            Flickable {
                id: clipsFlickable
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: contentArea.tilePadding
                // Constrain width to match banner (70% of parent)
                width: parent.width * 0.7 - contentArea.tilePadding * 2
                contentWidth: width
                contentHeight: clipsGrid.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick

                // Grid layout for tiles - constrained to banner width
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
}
