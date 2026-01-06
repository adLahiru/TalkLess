import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 280
    height: 220

    // data
    property string title: "Morning"
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"
    property string hotkeyText: "Alt+F2+Shift"
    property var tags: []               // ["Professional", "warm"]
    property bool selected: false

    // actions
    signal playClicked()
    signal copyClicked()
    signal clicked()
    signal tagClicked(string tag)

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: "#101010"
        border.width: selected ? 3 : 2
        border.color: selected ? "#FFFFFF" : "#EDEDED"
        antialiasing: true

        // background image
        Image {
            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: source && source !== ""
            clip: true
            layer.enabled: true
        }

        // dark overlay for readability
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "#000000"
            opacity: 0.18
        }

        // Tag pill (top-left)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.topMargin: 14
            height: 38
            radius: 18
            color: "#3C7BFF"
            opacity: 0.95

            Text {
                anchors.centerIn: parent
                text: root.title
                color: "white"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                leftPadding: 14
                rightPadding: 14
            }
        }

        // Bottom hotkey bar
        Rectangle {
            id: hotkeyBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 14
            height: 56
            radius: 18
            color: "#121212"
            opacity: 0.92

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                // Play button
                Button {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    padding: 0
                    onClicked: root.playClicked()

                    background: Rectangle {
                        radius: 10
                        color: "transparent"
                    }

                    contentItem: Text {
                        text: "▶"
                        color: "white"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Hotkey text
                Text {
                    Layout.fillWidth: true
                    text: root.hotkeyText
                    color: "#EDEDED"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Copy button
                Button {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    padding: 0
                    onClicked: root.copyClicked()

                    background: Rectangle {
                        radius: 10
                        color: "transparent"
                    }

                    // simple copy glyph; replace with svg if you want
                    contentItem: Text {
                        text: "⧉"
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Whole card click (for selecting/opening)
        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
            cursorShape: Qt.PointingHandCursor
        }
    }

    // Optional tag chips under the card (like "Professional", "warm")
    Flow {
        id: chipRow
        width: parent.width
        anchors.top: card.bottom
        anchors.topMargin: 12
        spacing: 12
        visible: root.tags && root.tags.length > 0

        Repeater {
            model: root.tags

            Button {
                text: modelData
                padding: 0

                contentItem: Row {
                    spacing: 8
                    anchors.centerIn: parent
                    Text { text: "🏷"; color: "#BDBDBD"; font.pixelSize: 14 } // simple icon
                    Text { text: modelData; color: "#EDEDED"; font.pixelSize: 14 }
                }

                background: Rectangle {
                    radius: 8
                    color: "#111111"
                    border.color: "#3A3A3A"
                    border.width: 1
                }

                width: implicitWidth + 22
                height: 44

                onClicked: root.tagClicked(modelData)
            }
        }
    }

    // Increase overall height if chips are visible
    implicitHeight: card.height + (chipRow.visible ? (chipRow.implicitHeight + 12) : 0)
}
