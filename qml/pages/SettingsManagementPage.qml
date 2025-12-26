import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TalkLess 1.0

Rectangle {
    id: root
    color: "#26293a"
    radius: 12
    border.color: "#3f3f46"
    border.width: 1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        Text {
            text: "Settings Management"
            font.pixelSize: 20
            font.bold: true
            color: "white"
        }
        
        // Import/Export Component
        SettingsImportExport {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            
            onSettingsExported: function(filePath) {
                console.log("Settings exported to:", filePath)
                // Show success message
                successMessage.text = "Settings successfully exported!"
                successMessage.visible = true
                successTimer.restart()
            }
            
            onSettingsImported: function(filePath) {
                console.log("Settings imported from:", filePath)
                // Show success message
                successMessage.text = "Settings successfully imported!"
                successMessage.visible = true
                successTimer.restart()
            }
            
            onErrorOccurred: function(error) {
                console.log("Settings error:", error)
                // Show error message
                errorMessage.text = "Error: " + error
                errorMessage.visible = true
                errorTimer.restart()
            }
        }
        
        // Success Message
        Text {
            id: successMessage
            text: ""
            color: "#10B981"
            font.pixelSize: 14
            visible: false
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Error Message
        Text {
            id: errorMessage
            text: ""
            color: "#EF4444"
            font.pixelSize: 14
            visible: false
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Additional Settings Info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#1a1a2e"
            radius: 8
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                
                Text {
                    text: "About JSON Settings"
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                }
                
                Text {
                    text: "• Export: Saves all settings, audio clips, hotkeys, and sections to a JSON file\n• Import: Loads settings from a JSON file, replacing current settings\n• Backup: Export settings before making major changes\n• Share: Import settings from other users or backup files"
                    font.pixelSize: 12
                    color: "#9CA3AF"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Item {
            Layout.fillHeight: true
        }
    }
    
    // Timers to hide messages
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: successMessage.visible = false
    }
    
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: errorMessage.visible = false
    }
}
