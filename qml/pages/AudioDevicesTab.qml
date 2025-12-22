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
                id: inputDeviceDropdown
                currentValue: audioManager.currentInputDevice || "Default"
                model: audioManager.inputDevices || ["Default"]
                onValueChanged: {
                    audioManager.setCurrentInputDevice(value)
                }
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
                id: outputDeviceDropdown
                currentValue: audioManager.currentOutputDevice || "Default"
                model: audioManager.outputDevices || ["Default"]
                onValueChanged: {
                    audioManager.setCurrentOutputDevice(value)
                }
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
                onClicked: {
                    audioManager.testPlayback()
                }
            }
            
            ActionButton {
                text: "Refresh Devices"
                onClicked: {
                    audioManager.refreshAudioDevices()
                }
            }
            
            ActionButton {
                text: "Reset to Default"
                onClicked: {
                    audioManager.refreshAudioDevices()
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
