import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 222  // 111:79 aspect ratio (landscape)
    height: 158

    // data
    property string title: ""  // Optional - only shows if not empty (e.g., "Morning")
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"
    property string hotkeyText: "Alt+F2+Shift"
    property bool selected: false
    property bool isPlaying: false  // Track playback state

    // actions
    signal playClicked()
    signal stopClicked()
    signal copyClicked()
    signal clicked()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: "#101010"
        border.width: 2
        border.color: "#EDEDED"
        clip: true

        // Background image
        Image {
            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: source && source !== ""
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
                color: "#C4A84D"  // Yellowish/golden color
                opacity: 0.4  // Transparent so background shows through
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

                // Play/Stop button - toggles based on playing state
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "■" : "▶"  // Stop or Play icon
                        color: root.isPlaying ? "#FF6B6B" : "#FFFFFF"  // Red when playing
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (root.isPlaying) {
                                root.stopClicked()
                            } else {
                                root.playClicked()
                            }
                            mouse.accepted = true
                        }
                    }
                }

                // Hotkey text - centered
                Text {
                    Layout.fillWidth: true
                    text: root.hotkeyText
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // Copy/Menu button
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 4
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "☰"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            root.copyClicked()
                            mouse.accepted = true
                        }
                    }
                }
            }
        }

        // Whole card click (for selecting/opening) - BELOW the buttons in z-order
        MouseArea {
            anchors.fill: parent
            z: -1  // Lower z so buttons get clicks first
            onClicked: root.clicked()
            cursorShape: Qt.PointingHandCursor
        }
    }
}
