// ToggleSwitch.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../styles"

Rectangle {
    id: root
    
    property bool isOn: false
    property color onColor: Colors.success
    property color offColor: Colors.surfaceLight
    
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
        color: Colors.white
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
