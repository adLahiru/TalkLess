import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 180  // Match ClipTile size - reduced from 222
    height: 128  // Match ClipTile size - reduced from 158

    property bool enabled: true
    property string text: enabled ? "Add Audio" : "Limit Reached"
    property url backgroundImage: "qrc:/qt/qml/TalkLess/resources/images/addAudioBackground.png"

    signal clicked()

    // Outer frame with light border
    Rectangle {
        id: outerFrame
        anchors.fill: parent
        radius: 16
        color: Colors.border
        opacity: root.enabled ? 1.0 : 0.6

        // Inner card with background image
        Rectangle {
            id: innerCard
            anchors.fill: parent
            anchors.margins: 6
            radius: 12
            color: "transparent"
            clip: true

            // Background image
            Image {
                id: bgImage
                anchors.fill: parent
                source: root.backgroundImage
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            // Translucent dark overlay
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Colors.surface
                opacity: 0.55
            }

            // Content: + symbol and text
            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "+"
                    color: Colors.textPrimary
                    font.pixelSize: 48
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.text
                    color: Colors.textPrimary
                    font.pixelSize: Typography.fontSizeMedium
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()

        onEntered: {
            if (root.enabled) {
                outerFrame.scale = 1.02
            }
        }
        onExited: {
            outerFrame.scale = 1.0
        }
    }

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }
}
