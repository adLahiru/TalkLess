import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property int currentIndex: 0  // Soundboard selected by default
    
    width: 250
    color: "#0a0a0f"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        
        // Logo
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            spacing: 10
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: "#06B6D4"
                
                Text {
                    anchors.centerIn: parent
                    text: "◎"
                    font.pixelSize: 20
                    color: "white"
                }
            }
            
            Text {
                text: "Talkless"
                font.pixelSize: 20
                font.weight: Font.Bold
                color: "#06B6D4"
            }
        }
        
        // Menu Items
        SidebarItem {
            icon: "🎛️"
            text: "Soundboard"
            isActive: currentIndex === 0
            onClicked: currentIndex = 0
        }
        
        SidebarItem {
            icon: "🔊"
            text: "Audio Playback Engine"
            isActive: currentIndex === 1
            onClicked: currentIndex = 1
        }
        
        SidebarItem {
            icon: "⚡"
            text: "Macros & Automation"
            isActive: currentIndex === 2
            onClicked: currentIndex = 2
        }
        
        SidebarItem {
            icon: "⚙️"
            text: "Application Settings"
            isActive: currentIndex === 3
            onClicked: currentIndex = 3
        }
        
        SidebarItem {
            icon: "📊"
            text: "Statistics & Reporting"
            isActive: currentIndex === 4
            onClicked: currentIndex = 4
        }
        
        Item { Layout.fillHeight: true }
        
        // Soundboard List
        Text {
            text: "Soundboards"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: "#6B7280"
            Layout.leftMargin: 8
        }
        
        // Soundboard thumbnails
        Repeater {
            model: 4
            
            SoundboardListItem {
                Layout.fillWidth: true
                title: "Greeting"
            }
        }
        
        // Add Soundboard Button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "transparent"
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 12
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: "#7C3AED"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "white"
                    }
                }
                
                Text {
                    text: "Add Soundboard"
                    font.pixelSize: 14
                    color: "white"
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
