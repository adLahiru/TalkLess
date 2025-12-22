import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // Section Title
        Text {
            text: "Auto-Update Settings"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "white"
        }
        
        // Auto-update toggle
        RowLayout {
            spacing: 16
            
            Text {
                text: "Auto-update:"
                font.pixelSize: 14
                color: "white"
            }
            
            ToggleSwitch {
                checked: true
            }
        }
        
        // Current Version
        RowLayout {
            spacing: 16
            
            Text {
                text: "Current Version:"
                font.pixelSize: 14
                color: "white"
            }
            
            Text {
                text: "v3.5.2"
                font.pixelSize: 14
                color: "#9CA3AF"
            }
        }
        
        // Last Updated
        RowLayout {
            spacing: 16
            
            Text {
                text: "Last Updated:"
                font.pixelSize: 14
                color: "white"
            }
            
            Text {
                text: "22 Jul 2025"
                font.pixelSize: 14
                color: "#9CA3AF"
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Check for Updates Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Check for Updates"
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
