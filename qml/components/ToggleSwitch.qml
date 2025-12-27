import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property bool checked: false
    
    width: 52
    height: 28
    radius: 14
    color: checked ? "#22C55E" : "#374151"
    
    Behavior on color {
        ColorAnimation { duration: 200 }
    }
    
    Rectangle {
        id: handle
        width: 22
        height: 22
        radius: 11
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        x: checked ? parent.width - width - 3 : 3
        
        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
        }
    }
}
