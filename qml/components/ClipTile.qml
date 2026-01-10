pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects

Item {
    id: root
    width: 222  // 111:79 aspect ratio (landscape)
    height: 158

    // data
    property string title: ""  // Optional - only shows if not empty (e.g., "Morning")
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"
    property string hotkeyText: "Alt+F2+Shift"
    property bool selected: false
    property bool showActions: false
    property bool isPlaying: false  // Track playback state

    // actions
    signal playClicked
    signal stopClicked
    signal copyClicked
    signal pasteClicked
    signal clicked
    signal editBackgroundClicked
    signal hotkeyClicked
    signal deleteClicked
    signal editClicked
    signal webClicked

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: "#101010"
        border.width: 2
        border.color: "#EDEDED"
        clip: true

        // Background image with rounded corners
        Item {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: 2  // Account for border

            // The actual image (hidden, used as source for masking)
            Image {
                id: backgroundImage
                anchors.fill: parent
                source: root.imageSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false  // Hidden, used as source for MultiEffect
            }

            // Mask shape
            Rectangle {
                id: imageMask
                anchors.fill: parent
                radius: 14  // Slightly less than card radius to account for border
                visible: false
            }

            // Apply the mask using MultiEffect
            MultiEffect {
                anchors.fill: backgroundImage
                source: backgroundImage
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: imageMask
                    live: false
                }
                visible: backgroundImage.status === Image.Ready
            }
        }

        // Yellowish translucent overlay on left half of tile
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.5  // Left half of tile
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: -16  // Extend right to hide right-side corners
                radius: 16  // Match card radius
                color: "#D9D9D938"  // Yellowish/golden color
                opacity: 0.2  // Transparent so background shows through
            }
        }

        // Tag pill (top-left) - starts from left edge, only right corners rounded
        Item {
            id: tagPill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 10
            height: 28
            // Width is content-based but limited to 60% of tile width
            width: Math.min(tagText.implicitWidth + 20, parent.width * 0.6)
            visible: root.title !== ""
            clip: true

            // Background with right-side rounded corners only
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -16  // Extend left to hide left corners
                radius: 14
                color: "#3B82F6"
            }

            Text {
                id: tagText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 4  // Slight offset for padding
                width: parent.width - 16  // Leave padding on both sides
                text: root.title
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight  // Truncate with ellipsis if text is too long
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Bottom hotkey bar - thin translucent black bar at bottom only
        Rectangle {
            id: hotkeyBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 6
            height: 28
            radius: 10
            color: "#000000"
            opacity: 0.7
        }

        // Hotkey bar content (on top of the translucent background)
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 6
            height: 28

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                // Hotkey container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    color: root.hotkeyText !== "" ? "rgba(0, 0, 0, 0.4)" : "rgba(60, 123, 255, 0.15)"
                    radius: 4
                    border.color: root.hotkeyText !== "" ? "transparent" : "rgba(60, 123, 255, 0.3)"
                    border.width: root.hotkeyText !== "" ? 0 : 1

                    Text {
                        id: hotkeyDisplayText
                        anchors.fill: parent
                        text: root.hotkeyText !== "" ? root.hotkeyText : "Assign"
                        color: root.hotkeyText !== "" ? "#FFFFFF" : "#3C7BFF"
                        font.pixelSize: 12
                        font.weight: root.hotkeyText !== "" ? Font.Medium : Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                root.hotkeyClicked();
                                mouse.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        // Action Bar - toggled by right click
        Rectangle {
            id: actionPopupBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 8
            width: 240 // Widened for Copy and Paste buttons
            height: 40
            radius: 20
            color: "#E61A1A1A" // More solid than hover version
            border.color: "#3B82F6" // Blue border when open
            border.width: 1
            opacity: root.showActions ? 1.0 : 0.0
            visible: opacity > 0
            z: 20 // Above everything

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 2

                // Play/Stop Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: playActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏹️" : "▶️"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: playActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isPlaying)
                                root.stopClicked();
                            else
                                root.playClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Copy Button (Clipboard)
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: copyActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "📋"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: copyActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.copyClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Paste Button (Clipboard Paste)
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: pasteActionMouseArea.containsMouse ? "#444444" : "transparent"
                    opacity: soundboardService.canPaste() ? 1.0 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: "📥"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: pasteActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: soundboardService.canPaste()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.pasteClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Edit Background Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: editBgActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "🖼️"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: editBgActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editBackgroundClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Web/Globe Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: webActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "🌐"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: webActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.webClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Edit Settings Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: editActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✏️"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: editActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editClicked();
                            root.showActions = false;
                        }
                    }
                }

                // Delete Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: deleteActionMouseArea.containsMouse ? "#444444" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "🗑️"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: deleteActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.deleteClicked();
                            root.showActions = false;
                        }
                    }
                }
            }
        }

        // Whole card click (for selecting/opening/playing) - BELOW the buttons in z-order
        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            z: -1  // Lower z so buttons get clicks first
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.showActions = !root.showActions;
                } else {
                    // Left click: Play the clip and select it
                    root.clicked(); // Updates selection sidebar
                    if (!root.isPlaying) {
                        root.playClicked();
                    } else {
                        root.stopClicked();
                    }
                    root.showActions = false; // Hide bar on play
                }
            }
            cursorShape: Qt.PointingHandCursor
        }

        Menu {
            id: clipContextMenu
            MenuItem {
                text: "Copy Clip"
                onTriggered: root.copyClicked()
            }
            MenuItem {
                text: "Paste Clip"
                enabled: soundboardService.canPaste
                onTriggered: {
                    const bId = clipsModel.boardId;
                    if (bId !== -1 && soundboardService.pasteClip(bId)) {
                        clipsModel.reload();
                    }
                }
            }
        }
    }
}
