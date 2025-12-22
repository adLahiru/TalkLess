import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string icon: ""
    property string text: ""
    property bool isActive: false
    
    signal clicked()
    
    width: parent ? parent.width : 220
    height: 48
    radius: 12
    color: isActive ? "#9333EA" : "transparent"
    
    // Gradient overlay for active state
    Rectangle {
        anchors.fill: parent
        radius: 12
        visible: isActive
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#9333EA" }
            GradientStop { position: 1.0; color: "#EC4899" }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        
        Text {
            text: root.icon
            font.pixelSize: 18
            color: "white"
        }
        
        Text {
            text: root.text
            font.pixelSize: 14
            font.weight: Font.Medium
            color: "white"
            Layout.fillWidth: true
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
        
        onEntered: {
            if (!isActive) {
                root.color = "#1a1a2e"
            }
        }
        
        onExited: {
            if (!isActive) {
                root.color = "transparent"
            }
        }
    }
}
