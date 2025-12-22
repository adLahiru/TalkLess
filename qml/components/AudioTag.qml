import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property string text: "Professional"
    property color tagColor: "#374151"
    property bool isActive: false
    
    signal clicked()
    
    height: 24
    width: tagText.width + 20
    radius: 12
    color: tagColor
    border.color: isActive ? "#7C3AED" : "transparent"
    border.width: isActive ? 1 : 0
    
    Text {
        id: tagText
        anchors.centerIn: parent
        text: "○ " + root.text
        font.pixelSize: 11
        color: "white"
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
