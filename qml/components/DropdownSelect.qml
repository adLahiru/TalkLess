import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property string currentValue: ""
    property var model: []
    property int currentIndex: 0
    
    width: 240
    height: 40
    radius: 8
    color: "#1a1a2e"
    border.color: "#2a2a3e"
    border.width: 1
    
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: currentValue || (model.length > 0 ? model[currentIndex] : "")
        font.pixelSize: 14
        color: "#9CA3AF"
    }
    
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "▼"
        font.pixelSize: 10
        color: "#9CA3AF"
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Dropdown functionality would go here
    }
}
