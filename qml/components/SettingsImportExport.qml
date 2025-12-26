import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import TalkLess 1.0

Rectangle {
    id: root
    color: "#26293a"
    radius: 12
    border.color: "#3f3f46"
    border.width: 1
    
    property alias title: titleText.text
    
    signal settingsExported(string filePath)
    signal settingsImported(string filePath)
    signal errorOccurred(string error)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        Text {
            id: titleText
            text: "Import/Export Settings"
            font.pixelSize: 18
            font.bold: true
            color: "white"
        }
        
        // Export Section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1a1a2e"
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: "Export Settings"
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                    }
                    
                    Text {
                        text: "Save all application settings to a JSON file"
                        font.pixelSize: 12
                        color: "#9CA3AF"
                        Layout.fillWidth: true
                    }
                }
                
                Button {
                    text: "Export"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: parent.hovered ? "#7C3AED" : "#6B21A8"
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        exportFileDialog.open()
                    }
                }
            }
        }
        
        // Import Section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#1a1a2e"
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: "Import Settings"
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                    }
                    
                    Text {
                        text: "Load settings from a JSON file"
                        font.pixelSize: 12
                        color: "#9CA3AF"
                        Layout.fillWidth: true
                    }
                }
                
                Button {
                    text: "Import"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: parent.hovered ? "#059669" : "#047857"
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        importFileDialog.open()
                    }
                }
            }
        }
        
        // Status Messages
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1a1a2e"
            radius: 8
            visible: statusText.text !== ""
            
            Text {
                id: statusText
                anchors.centerIn: parent
                text: ""
                font.pixelSize: 14
                color: "#10B981"
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        Item {
            Layout.fillHeight: true
        }
    }
    
    // File Dialogs
    FileDialog {
        id: exportFileDialog
        title: "Export Settings"
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        defaultSuffix: "json"
        fileMode: FileDialog.SaveFile
        onAccepted: {
            console.log("Exporting to:", selectedFile)
            statusText.text = "Exporting settings..."
            statusText.color = "#FCD34D"
            
            settingsManager.exportSettingsToJson(selectedFile)
        }
    }
    
    FileDialog {
        id: importFileDialog
        title: "Import Settings"
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            console.log("Importing from:", selectedFile)
            statusText.text = "Importing settings..."
            statusText.color = "#FCD34D"
            
            settingsManager.importSettingsFromJson(selectedFile)
        }
    }
    
    // Connections to SettingsManager
    Connections {
        target: settingsManager
        
        function onSettingsExported(filePath) {
            statusText.text = "Settings exported successfully to: " + filePath
            statusText.color = "#10B981"
            root.settingsExported(filePath)
        }
        
        function onSettingsImported(filePath) {
            statusText.text = "Settings imported successfully from: " + filePath
            statusText.color = "#10B981"
            root.settingsImported(filePath)
        }
        
        function onExportError(error) {
            statusText.text = "Export failed: " + error
            statusText.color = "#EF4444"
            root.errorOccurred(error)
        }
        
        function onImportError(error) {
            statusText.text = "Import failed: " + error
            statusText.color = "#EF4444"
            root.errorOccurred(error)
        }
    }
}
