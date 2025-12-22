import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Function to show hotkey assignment dialog
    function showHotkeyDialog(clipId, actionName) {
        hotkeyDialog.clipId = clipId
        hotkeyDialog.actionName = actionName
        hotkeyDialog.open()
    }
    
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
                    onClicked: {
                        // Show dialog to add hotkey for first available clip
                        if (audioManager.audioClips.length > 0) {
                            showHotkeyDialog(audioManager.audioClips[0].id, audioManager.audioClips[0].title)
                        }
                    }
                }
            }
        }
        
        // Hotkey List - Dynamically populated from audio clips
        Repeater {
            model: audioManager.audioClips
            delegate: HotkeyItem {
                actionName: modelData.title || "Audio Clip " + (index + 1)
                hotkey: hotkeyManager.getHotkeyForClip(modelData.id) || "Not set"
                Layout.fillWidth: true
                
                // Make the edit button functional
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        showHotkeyDialog(modelData.id, modelData.title || "Audio Clip " + (index + 1))
                    }
                }
            }
        }
        
        // Default system hotkeys (read-only)
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#2a2a3e"
            Layout.topMargin: 10
            Layout.bottomMargin: 10
        }
        
        Text {
            text: "System Hotkeys:"
            font.pixelSize: 14
            font.weight: Font.Medium
            color: "#9CA3AF"
        }
        
        HotkeyItem {
            actionName: "Play/Pause"
            hotkey: "Space"
            Layout.fillWidth: true
        }
        
        HotkeyItem {
            actionName: "Stop All"
            hotkey: "Ctrl+S"
            Layout.fillWidth: true
        }
        
        Item { Layout.fillHeight: true }
        
        // Reset Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Clear All Hotkeys"
                onClicked: {
                    // Clear all hotkeys
                    for (var i = 0; i < audioManager.audioClips.length; i++) {
                        hotkeyManager.unregisterHotkey(audioManager.audioClips[i].id)
                    }
                }
            }
            
            ActionButton {
                text: "Reset to Defaults"
                onClicked: {
                    // Reset to default hotkeys
                    hotkeyManager.unregisterHotkey("all")
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
    
    // Hotkey Assignment Dialog
    Popup {
        id: hotkeyDialog
        width: 400
        height: 200
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string clipId: ""
        property string actionName: ""
        
        background: Rectangle {
            color: "#1a1a2e"
            radius: 8
            border.color: "#2a2a3e"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            
            Text {
                text: "Assign Hotkey for: " + hotkeyDialog.actionName
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "white"
            }
            
            Text {
                text: "Press a key combination..."
                font.pixelSize: 14
                color: "#9CA3AF"
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#2a2a3e"
                radius: 6
                border.color: "#4f46e5"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: hotkeyCapture.currentKey || "Press keys now"
                    color: "#E5E7EB"
                    font.pixelSize: 14
                }
                
                Keys.enabled: true
                Keys.onPressed: {
                    var keyString = event.text
                    if (event.modifiers & Qt.ControlModifier) keyString = "Ctrl+" + keyString
                    if (event.modifiers & Qt.AltModifier) keyString = "Alt+" + keyString
                    if (event.modifiers & Qt.ShiftModifier) keyString = "Shift+" + keyString
                    
                    hotkeyCapture.currentKey = keyString
                    event.accepted = true
                }
                
                property alias currentKey: hotkeyCapture.keyText
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                
                ActionButton {
                    text: "Cancel"
                    onClicked: hotkeyDialog.close()
                }
                
                ActionButton {
                    text: "Assign"
                    enabled: hotkeyCapture.currentKey !== ""
                    onClicked: {
                        if (hotkeyManager.isHotkeyAvailable(hotkeyCapture.currentKey)) {
                            hotkeyManager.registerHotkey(hotkeyDialog.clipId, hotkeyCapture.currentKey)
                            hotkeyDialog.close()
                            hotkeyCapture.currentKey = ""
                        }
                    }
                }
            }
        }
    }
    
    // Key capture helper
    QtObject {
        id: hotkeyCapture
        property string keyText: ""
    }
}
