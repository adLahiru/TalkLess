import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    
    width: 1400
    height: 900
    minimumWidth: 1200
    minimumHeight: 800
    visible: true
    title: qsTr("TalkLess")
    color: "#0f0f1a"
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            currentIndex: 0
        }
        
        // Main Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // Header Bar
            HeaderBar {
                id: headerBar
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                currentPageTitle: "Soundboard"
            }
            
            // Content placeholder
            StackLayout {
                id: contentStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: sidebar.currentIndex === 0 ? 0 : 1
                
                // Soundboard Page
                SoundboardPage {
                    id: soundboardPage
                }
                
                // System Settings Page
                SystemSettingsPage {
                    id: settingsPage
                }
            }
        }
    }
}
