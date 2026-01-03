import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import TalkLess 1.0

Rectangle {
    id: root
    color: "#0a0a0f"
    
    property int currentTab: 0  // 0=Export, 1=Backup, 2=Restore
    property string statusMessage: ""
    property string statusColor: "#10B981"
    property string pendingImportPath: ""
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Header Banner with Jellyfish Image
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            color: "#1a1a2e"
            clip: true
            
            // Gradient background
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#1a1a3e" }
                    GradientStop { position: 0.5; color: "#2a1a4e" }
                    GradientStop { position: 1.0; color: "#3a2a5e" }
                }
            }
            
            // Jellyfish decorative element (using gradient circles)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 150
                radius: 75
                color: "transparent"
                border.color: Qt.rgba(0.6, 0.4, 0.9, 0.3)
                border.width: 2
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 100
                    radius: 50
                    color: "transparent"
                    border.color: Qt.rgba(0.7, 0.5, 1.0, 0.4)
                    border.width: 2
                }
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 60
                    height: 60
                    radius: 30
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.5, 0.3, 0.8, 0.6) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.4, 0.2, 0.7, 0.3) }
                    }
                }
            }
            
            // Header Text
            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                
                Text {
                    text: "Export & Backup"
                    font.pixelSize: 32
                    font.bold: true
                    color: "white"
                }
                
                Text {
                    text: "Easily export configurations, create backups, and restore your soundboards and user profiles."
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    Layout.maximumWidth: 500
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0f"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 30
                
                // Tab Selector
                Rectangle {
                    Layout.preferredWidth: 340
                    Layout.preferredHeight: 50
                    color: "#1a1a2e"
                    radius: 25
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0
                        
                        // Export data tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 22
                            color: root.currentTab === 0 ? "#7C3AED" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Export data"
                                font.pixelSize: 14
                                font.weight: root.currentTab === 0 ? Font.Medium : Font.Normal
                                color: root.currentTab === 0 ? "white" : "#9CA3AF"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = 0
                            }
                        }
                        
                        // Backup tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 22
                            color: root.currentTab === 1 ? "#7C3AED" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Backup"
                                font.pixelSize: 14
                                font.weight: root.currentTab === 1 ? Font.Medium : Font.Normal
                                color: root.currentTab === 1 ? "white" : "#9CA3AF"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = 1
                            }
                        }
                        
                        // Restore tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 22
                            color: root.currentTab === 2 ? "#7C3AED" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Restore"
                                font.pixelSize: 14
                                font.weight: root.currentTab === 2 ? Font.Medium : Font.Normal
                                color: root.currentTab === 2 ? "white" : "#9CA3AF"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = 2
                            }
                        }
                    }
                }
                
                // Status message
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#1a1a2e"
                    radius: 8
                    visible: root.statusMessage !== ""
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.statusMessage
                        font.pixelSize: 14
                        color: root.statusColor
                    }
                }
                
                // Tab Content
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab
                    
                    // ===== EXPORT DATA TAB =====
                    ColumnLayout {
                        spacing: 30
                        
                        // Export Complete Configuration Section
                        ColumnLayout {
                            spacing: 16
                            
                            Text {
                                text: "Export Complete Configuration"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }
                            
                            Text {
                                text: "Export all settings, audio clips, hotkeys, and soundboard sections to a JSON file."
                                font.pixelSize: 13
                                color: "#9CA3AF"
                                Layout.leftMargin: 20
                            }
                            
                            // Export button
                            Rectangle {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 44
                                Layout.leftMargin: 20
                                color: exportBtnMa.containsMouse ? "#7C3AED" : "#6B21A8"
                                radius: 8
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "📤  Export JSON"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                                
                                MouseArea {
                                    id: exportBtnMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: exportFileDialog.open()
                                }
                            }
                        }
                        
                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#2a2a3e"
                        }
                        
                        // Import Configuration Section
                        ColumnLayout {
                            spacing: 16
                            
                            Text {
                                text: "Import Configuration"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }
                            
                            Text {
                                text: "Load settings from a JSON file. This will replace your current configuration."
                                font.pixelSize: 13
                                color: "#9CA3AF"
                                Layout.leftMargin: 20
                            }
                            
                            // Warning message
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: "#422006"
                                radius: 8
                                border.color: "#f59e0b"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10
                                    
                                    Text {
                                        text: "⚠️"
                                        font.pixelSize: 18
                                    }
                                    
                                    Text {
                                        text: "Warning: Importing will overwrite all current settings, audio clips, and hotkeys."
                                        font.pixelSize: 13
                                        color: "#fcd34d"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            // Import button
                            Rectangle {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 44
                                Layout.leftMargin: 20
                                color: importBtnMa.containsMouse ? "#059669" : "#047857"
                                radius: 8
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "📥  Import JSON"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                                
                                MouseArea {
                                    id: importBtnMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: importFileDialog.open()
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                    
                    // ===== BACKUP TAB =====
                    ColumnLayout {
                        spacing: 24
                        
                        // Backup section
                        ColumnLayout {
                            spacing: 16
                            
                            Text {
                                text: "Backup All Soundboards & User Profiles"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 44
                                color: backupBtnMa.containsMouse ? "#7C3AED" : "#6B21A8"
                                radius: 8
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "Create Backup Now"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                                
                                MouseArea {
                                    id: backupBtnMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: exportFileDialog.open()
                                }
                            }
                        }
                        
                        // Backup History Section
                        ColumnLayout {
                            spacing: 12
                            
                            Text {
                                text: "Backup History"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }
                            
                            // Table Header
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                color: "#1a1a2e"
                                radius: 6
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    
                                    Text {
                                        text: "Date/Time"
                                        font.pixelSize: 13
                                        color: "#9CA3AF"
                                        Layout.preferredWidth: 200
                                    }
                                    
                                    Text {
                                        text: "Type"
                                        font.pixelSize: 13
                                        color: "#9CA3AF"
                                        Layout.preferredWidth: 150
                                    }
                                    
                                    Text {
                                        text: "Actions"
                                        font.pixelSize: 13
                                        color: "#9CA3AF"
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                            
                            // Sample rows
                            Repeater {
                                model: [
                                    { date: "22 Jul 2025 2:45", type: "Full Backup" },
                                    { date: "22 Jul 2025 2:45", type: "Audio Only" }
                                ]
                                
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    color: index % 2 === 0 ? "#0f0f15" : "#1a1a2e"
                                    radius: 4
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 20
                                        anchors.rightMargin: 20
                                        
                                        Text {
                                            text: modelData.date
                                            font.pixelSize: 13
                                            color: "#D1D5DB"
                                            Layout.preferredWidth: 200
                                        }
                                        
                                        Text {
                                            text: modelData.type
                                            font.pixelSize: 13
                                            color: "#D1D5DB"
                                            Layout.preferredWidth: 150
                                        }
                                        
                                        Text {
                                            text: "[ Download ]"
                                            font.pixelSize: 13
                                            color: "#7C3AED"
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: exportFileDialog.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                    
                    // ===== RESTORE TAB =====
                    ColumnLayout {
                        spacing: 24
                        
                        // Restore section
                        ColumnLayout {
                            spacing: 16
                            
                            Text {
                                text: "Restore From Backup"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }
                            
                            Text {
                                text: "Select a backup file to restore your configuration."
                                font.pixelSize: 13
                                color: "#9CA3AF"
                            }
                            
                            // Warning message
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                Layout.rightMargin: 20
                                color: "#422006"
                                radius: 8
                                border.color: "#f59e0b"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10
                                    
                                    Text {
                                        text: "⚠️"
                                        font.pixelSize: 18
                                    }
                                    
                                    Text {
                                        text: "Warning: Restoring will overwrite all current settings and cannot be undone."
                                        font.pixelSize: 13
                                        color: "#fcd34d"
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            // Restore button
                            Rectangle {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 44
                                color: restoreBtnMa.containsMouse ? "#059669" : "#047857"
                                radius: 8
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "📂  Select Backup File"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                                
                                MouseArea {
                                    id: restoreBtnMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: importFileDialog.open()
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
    
    // File Dialogs
    FileDialog {
        id: exportFileDialog
        title: "Export Configuration"
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        defaultSuffix: "json"
        fileMode: FileDialog.SaveFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        
        onAccepted: {
            console.log("Exporting to:", selectedFile)
            root.statusMessage = "Exporting settings..."
            root.statusColor = "#FCD34D"
            
            if (settingsManager) {
                settingsManager.exportSettingsToJson(selectedFile)
            }
        }
    }
    
    FileDialog {
        id: importFileDialog
        title: "Import Configuration"
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        fileMode: FileDialog.OpenFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        
        onAccepted: {
            console.log("Selected file for import:", selectedFile)
            root.pendingImportPath = selectedFile.toString()
            importWarningDialog.open()
        }
    }
    
    // Import Warning Dialog
    Dialog {
        id: importWarningDialog
        title: "Confirm Import"
        modal: true
        anchors.centerIn: parent
        width: 450
        
        background: Rectangle {
            color: "#1a1a2e"
            radius: 12
            border.color: "#3a3a4e"
            border.width: 1
        }
        
        header: Rectangle {
            color: "transparent"
            height: 60
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                
                Text {
                    text: "⚠️"
                    font.pixelSize: 24
                }
                
                Text {
                    text: "Confirm Import"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }
            }
        }
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Text {
                text: "Are you sure you want to import this configuration?"
                font.pixelSize: 14
                color: "#D1D5DB"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#7f1d1d"
                radius: 8
                border.color: "#ef4444"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    
                    Text {
                        text: "⛔ This will permanently replace:"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#fca5a5"
                    }
                    
                    Text {
                        text: "• All audio clips and hotkeys\n• All soundboard sections\n• All application settings"
                        font.pixelSize: 12
                        color: "#fca5a5"
                    }
                }
            }
        }
        
        footer: Rectangle {
            color: "transparent"
            height: 60
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                // Cancel button
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    color: cancelBtnMa.containsMouse ? "#3a3a4e" : "#2a2a3e"
                    radius: 6
                    border.color: "#4a4a5e"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: 14
                        color: "white"
                    }
                    
                    MouseArea {
                        id: cancelBtnMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: importWarningDialog.close()
                    }
                }
                
                // Confirm button
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 40
                    color: confirmBtnMa.containsMouse ? "#dc2626" : "#b91c1c"
                    radius: 6
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Yes, Import"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }
                    
                    MouseArea {
                        id: confirmBtnMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            importWarningDialog.close()
                            root.statusMessage = "Importing settings..."
                            root.statusColor = "#FCD34D"
                            
                            if (settingsManager) {
                                settingsManager.importSettingsFromJson(root.pendingImportPath)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Connections to SettingsManager
    Connections {
        target: settingsManager
        
        function onSettingsExported(filePath) {
            root.statusMessage = "✅ Settings exported successfully!"
            root.statusColor = "#10B981"
            statusClearTimer.restart()
        }
        
        function onSettingsImported(filePath) {
            root.statusMessage = "✅ Settings imported successfully! Restart app to see all changes."
            root.statusColor = "#10B981"
            statusClearTimer.restart()
        }
        
        function onExportError(error) {
            root.statusMessage = "❌ Export failed: " + error
            root.statusColor = "#EF4444"
            statusClearTimer.restart()
        }
        
        function onImportError(error) {
            root.statusMessage = "❌ Import failed: " + error
            root.statusColor = "#EF4444"
            statusClearTimer.restart()
        }
    }
    
    Timer {
        id: statusClearTimer
        interval: 5000
        onTriggered: root.statusMessage = ""
    }
}
