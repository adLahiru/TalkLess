import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    
    width: 1400
    height: 900
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: qsTr("TalkLess")
    color: Colors.background
    
    // Window flags to respect work area when maximized
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint | Qt.WindowMaximizeUsingGeometryHint
    
        
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
                Layout.preferredHeight: 60
                Layout.minimumHeight: 50
                Layout.maximumHeight: 80
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
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                
                // System Settings Page
                SystemSettingsPage {
                    id: settingsPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
