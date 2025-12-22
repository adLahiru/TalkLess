import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // Default Input Device
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Default Input Device:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                currentValue: "Microphone 1"
                model: ["Microphone 1", "Microphone 2", "USB Mic"]
            }
        }
        
        // Default Output Device
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Default Output Device:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                currentValue: "Headset A"
                model: ["Headset A", "Speakers", "USB Audio"]
            }
        }
        
        // Audio Driver
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Audio Driver:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                currentValue: "WASAPI"
                model: ["WASAPI", "DirectSound", "ASIO"]
            }
        }
        
        // Sample Rate
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Sample Rate:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                currentValue: "44.1 kHz"
                model: ["44.1 kHz", "48 kHz", "96 kHz"]
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            ActionButton {
                text: "Test Playback"
            }
            
            ActionButton {
                text: "Reset to Default"
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
