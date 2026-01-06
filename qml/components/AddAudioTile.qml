import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 280
    height: 220

    property bool enabled: true
    property string text: enabled ? "Add Audio" : "Limit Reached"
    property url backgroundImage: "qrc:/qt/qml/TalkLess/resources/images/addAudioBackground.png"

    signal clicked()

    // Outer frame
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "#E7E2DF"
        opacity: root.enabled ? 1.0 : 0.6
        Image {
            anchors.fill: parent
            source: root.backgroundImage
            visible: source && source !== ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
            opacity: 0.35
        }
    }

    // Inner card
    Rectangle {
        anchors.fill: parent
        anchors.margins: 14
        radius: 18
        color: "#514443"
        opacity: root.enabled ? 1.0 : 0.6

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "+"
                color: "white"
                font.pixelSize: 72
                font.weight: Font.Light
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Text {
                text: root.text
                color: "white"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
