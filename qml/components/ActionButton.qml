import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property string text: "Button"
    property bool isPrimary: false
    
    signal clicked()
    
    width: textContent.width + 32
    height: 36
    radius: 4
    color: "transparent"
    border.color: "#4B5563"
    border.width: 1
    
    Text {
        id: textContent
        anchors.centerIn: parent
        text: "[ " + root.text + " ]"
        font.pixelSize: 13
        color: "#9CA3AF"
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
        
        onEntered: {
            root.border.color = "#7C3AED"
            textContent.color = "#A78BFA"
        }
        
        onExited: {
            root.border.color = "#4B5563"
            textContent.color = "#9CA3AF"
        }
    }
}
