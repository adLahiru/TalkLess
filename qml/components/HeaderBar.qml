import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string userName: "Johnson"
    property string userInitials: "JD"
    property string currentPageTitle: ""
    
    height: 60
    color: "transparent"
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        
        Item { Layout.fillWidth: true }
        
        // Search Bar
        Rectangle {
            Layout.preferredWidth: 280
            Layout.preferredHeight: 40
            radius: 20
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8
                
                Text {
                    text: "🔍"
                    font.pixelSize: 14
                    opacity: 0.6
                }
                
                TextInput {
                    Layout.fillWidth: true
                    color: "white"
                    font.pixelSize: 14
                    
                    Text {
                        anchors.fill: parent
                        text: "Search here..."
                        color: "#666"
                        font.pixelSize: 14
                        visible: parent.text.length === 0
                    }
                }
            }
        }
        
        Item { Layout.preferredWidth: 24 }
        
        // User Profile
        RowLayout {
            spacing: 12
            
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: "#3B82F6"
                
                Text {
                    anchors.centerIn: parent
                    text: userInitials
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "white"
                }
            }
            
            Text {
                text: userName
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "white"
            }
        }
    }
}
