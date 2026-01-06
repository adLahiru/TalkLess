// ToggleSwitch.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property bool isOn: false
    property color onColor: "#22C55E"
    property color offColor: "#3A3A3A"
    
    signal toggled(bool value)
    
    width: 52
    height: 28
    radius: 14
    color: root.isOn ? root.onColor : root.offColor

    Rectangle {
        id: handle
        width: 22
        height: 22
        radius: 11
        color: "#FFFFFF"
        x: root.isOn ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            NumberAnimation { duration: 150 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.isOn = !root.isOn
            root.toggled(root.isOn)
        }
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
}
