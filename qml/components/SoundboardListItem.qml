import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string title: "Greeting"
    property string imagePath: ""
    property bool isSelected: false
    
    signal clicked()
    
    Layout.preferredHeight: 48
    color: isSelected ? "#1a1a2e" : "transparent"
    radius: 8
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 12
        
        // Thumbnail
        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "#2a2a3e"
            clip: true
            
            Image {
                anchors.fill: parent
                source: imagePath
                fillMode: Image.PreserveAspectCrop
                visible: imagePath !== ""
            }
            
            // Fallback gradient
            Rectangle {
                anchors.fill: parent
                radius: 6
                visible: imagePath === ""
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#EC4899" }
                    GradientStop { position: 1.0; color: "#F97316" }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 16
                }
            }
        }
        
        Text {
            text: title
            font.pixelSize: 14
            color: "white"
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
        
        onEntered: {
            if (!isSelected) root.color = "#1a1a2e"
        }
        
        onExited: {
            if (!isSelected) root.color = "transparent"
        }
    }
}
