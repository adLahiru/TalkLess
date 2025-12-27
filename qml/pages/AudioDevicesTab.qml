import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // Enable Input Device Checkbox
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Enable Microphone:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            Rectangle {
                width: 20
                height: 20
                radius: 4
                color: inputDeviceCheckbox.checked ? "#7C3AED" : "#2a2a3e"
                border.color: inputDeviceCheckbox.checked ? "#7C3AED" : "#4B5563"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 12
                    color: "white"
                    visible: inputDeviceCheckbox.checked
                }
                
                MouseArea {
                    id: inputDeviceCheckbox
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    property bool checked: audioManager.inputDeviceEnabled
                    onClicked: {
                        checked = !checked
                        audioManager.setInputDeviceEnabled(checked)
                    }
                }
            }
            
            Text {
                text: "Capture microphone input"
                font.pixelSize: 12
                color: "#9CA3AF"
            }
        }
        
        // Default Input Device
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            opacity: audioManager.inputDeviceEnabled ? 1.0 : 0.5
            
            Text {
                text: "Input Device:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                id: inputDeviceDropdown
                enabled: audioManager.inputDeviceEnabled
                currentValue: audioManager.currentInputDevice || "Default"
                model: audioManager.inputDevices || ["Default"]
                onValueChanged: {
                    if (audioManager.inputDeviceEnabled) {
                        audioManager.setCurrentInputDevice(value)
                    }
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            color: "#2a2a3e"
        }
        
        // Default Output Device (sends audio + mic)
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
        
        Text {
            text: "Default output sends both audio clips and microphone voice."
            font.pixelSize: 11
            color: "#6B7280"
            Layout.leftMargin: 200
        }
        
        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            color: "#2a2a3e"
        }
        
        // Secondary Output Enable Checkbox
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: "Enable Secondary Output:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            Rectangle {
                id: secondaryOutputCheckboxRect
                width: 20
                height: 20
                radius: 4
                color: audioManager.secondaryOutputEnabled ? "#7C3AED" : "#2a2a3e"
                border.color: audioManager.secondaryOutputEnabled ? "#7C3AED" : "#4B5563"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 12
                    color: "white"
                    visible: audioManager.secondaryOutputEnabled
                }
                
                MouseArea {
                    id: secondaryOutputCheckbox
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        audioManager.setSecondaryOutputEnabled(!audioManager.secondaryOutputEnabled)
                    }
                }
            }
            
            Text {
                text: "Audio only (no microphone)"
                font.pixelSize: 12
                color: "#9CA3AF"
            }
        }
        
        // Secondary Output Device
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            opacity: audioManager.secondaryOutputEnabled ? 1.0 : 0.5
            
            Text {
                text: "Secondary Output Device:"
                font.pixelSize: 14
                color: "white"
                Layout.preferredWidth: 180
            }
            
            DropdownSelect {
                id: secondaryOutputDeviceDropdown
                enabled: audioManager.secondaryOutputEnabled
                currentValue: audioManager.secondaryOutputDevice || "Select Device"
                model: audioManager.outputDevices || ["Default"]
                onValueChanged: function(value) {
                    audioManager.setSecondaryOutputDevice(value)
                }
            }
        }
        
        Text {
            text: "Secondary output sends only audio clips without microphone voice."
            font.pixelSize: 11
            color: "#6B7280"
            Layout.leftMargin: 200
            opacity: audioManager.secondaryOutputEnabled ? 1.0 : 0.5
        }
        
        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            color: "#2a2a3e"
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
                currentValue: settingsManager.audioDriver
                model: ["WASAPI", "DirectSound", "ASIO"]
                onValueChanged: settingsManager.audioDriver = value
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
                currentValue: settingsManager.sampleRate
                model: ["44.1 kHz", "48 kHz", "96 kHz"]
                onValueChanged: settingsManager.sampleRate = value
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
