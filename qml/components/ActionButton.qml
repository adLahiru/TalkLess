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
    color: isPrimary ? Colors.primary : "transparent"
    border.color: isPrimary ? Colors.primary : Colors.border
    border.width: 1
    
    Text {
        id: textContent
        anchors.centerIn: parent
        text: "[ " + root.text + " ]"
        font.pixelSize: 13
        color: isPrimary ? "white" : Colors.textSecondary
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
        
        onEntered: {
            root.color = isPrimary ? Colors.primaryLight : Colors.surfaceLight
            root.border.color = Colors.primary
            textContent.color = isPrimary ? "white" : Colors.primary
        }
        
        onExited: {
            root.color = isPrimary ? Colors.primary : "transparent"
            root.border.color = isPrimary ? Colors.primary : Colors.border
            textContent.color = isPrimary ? "white" : Colors.textSecondary
        }
    }
}
