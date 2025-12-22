import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        
        // Section Header
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Global Hotkey Map:"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "white"
            }
            
            Item { Layout.fillWidth: true }
            
            // Add Hotkey Button
            Rectangle {
                width: 110
                height: 36
                radius: 18
                color: "#22C55E"
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: "+"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "white"
                    }
                    
                    Text {
                        text: "Add Hotkey"
                        font.pixelSize: 12
                        color: "white"
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
        
        // Hotkey List
        HotkeyItem {
            actionName: "Play/Pause"
            hotkey: "Ctrl + P"
            Layout.fillWidth: true
        }
        
        HotkeyItem {
            actionName: "Stop"
            hotkey: "Ctrl + S"
            Layout.fillWidth: true
        }
        
        HotkeyItem {
            actionName: "Next Audio"
            hotkey: "Ctrl + N"
            Layout.fillWidth: true
        }
        
        Item { Layout.fillHeight: true }
        
        // Reset Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Reset to Defaults"
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
