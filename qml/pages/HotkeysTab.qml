import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Model for hotkeys list - refreshed when hotkeys change
    property var hotkeysModel: hotkeyManager.getClipsWithHotkeys()
    
    // Model for system hotkeys list - refreshed when system hotkeys change
    property var systemHotkeysModel: hotkeyManager.getSystemHotkeys()
    
    // Refresh hotkeys model when hotkeys change
    Connections {
        target: hotkeyManager
        function onHotkeysChanged() {
            root.hotkeysModel = hotkeyManager.getClipsWithHotkeys()
        }
        function onSystemHotkeysChanged() {
            root.systemHotkeysModel = hotkeyManager.getSystemHotkeys()
        }
    }
    
    // Get unique clips by file path (avoid duplicates across dashboards)
    property var uniqueClips: {
        var clips = audioManager.audioClips
        var seen = {}
        var unique = []
        for (var i = 0; i < clips.length; i++) {
            var clip = clips[i]
            var filePath = clip.filePath ? clip.filePath.toString() : ""
            if (filePath && !seen[filePath]) {
                seen[filePath] = true
                unique.push(clip)
            } else if (!filePath && !seen[clip.id]) {
                // If no filePath, use id as fallback
                seen[clip.id] = true
                unique.push(clip)
            }
        }
        return unique
    }
    
    // Function to show hotkey assignment dialog
    function showHotkeyDialog(clipId, actionName) {
        hotkeyDialog.clipId = clipId
        hotkeyDialog.actionName = actionName
        hotkeyCapture.currentKey = ""
        hotkeyDialog.open()
        keyCaptureArea.forceActiveFocus()
    }
    
    // Function to show system hotkey assignment dialog
    function showSystemHotkeyDialog(action, displayName) {
        systemHotkeyDialog.action = action
        systemHotkeyDialog.displayName = displayName
        systemHotkeyDialog.currentHotkey = hotkeyManager.getSystemHotkey(action)
        systemHotkeyCapture.currentKey = systemHotkeyDialog.currentHotkey
        systemHotkeyDialog.open()
        systemKeyCaptureArea.forceActiveFocus()
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
                        // Show add hotkey dialog with song selection
                        if (root.uniqueClips.length > 0) {
                            addHotkeyDialog.open()
                        }
                    }
                }
            }
        }
        
        // Hotkey List - Only show clips that have hotkeys assigned
        Repeater {
            id: hotkeyListRepeater
            model: hotkeysModel
            
            delegate: HotkeyItem {
                required property var modelData
                required property int index
                
                // Find the clip info from audioManager
                property var clipInfo: {
                    var clips = audioManager.audioClips
                    for (var i = 0; i < clips.length; i++) {
                        if (clips[i].id === modelData.clipId) {
                            return clips[i]
                        }
                    }
                    return null
                }
                
                actionName: clipInfo ? clipInfo.title : "Unknown Clip"
                hotkey: modelData.hotkey
                Layout.fillWidth: true
                visible: clipInfo !== null
                
                // Make the edit button functional
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (clipInfo) {
                            showHotkeyDialog(modelData.clipId, clipInfo.title || "Audio Clip")
                        }
                    }
                }
            }
        }
        
        // Show message when no hotkeys are assigned
        Text {
            visible: root.hotkeysModel.length === 0
            text: "No hotkeys assigned yet. Click 'Add Hotkey' to assign hotkeys to audio clips."
            font.pixelSize: 14
            color: "#6B7280"
            Layout.fillWidth: true
            Layout.topMargin: 20
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Default system hotkeys (editable)
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
        
        Repeater {
            model: root.systemHotkeysModel
            
            delegate: HotkeyItem {
                required property var modelData
                
                actionName: modelData.displayName
                hotkey: modelData.hotkey
                Layout.fillWidth: true
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        showSystemHotkeyDialog(modelData.action, modelData.displayName)
                    }
                }
            }
        }
        
        // System Hotkey Control Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            
            ActionButton {
                text: "Clear System Hotkeys"
                onClicked: {
                    // Clear all system hotkeys
                    hotkeyManager.clearAllSystemHotkeys()
                }
            }
            
            ActionButton {
                text: "Reset System Hotkeys"
                onClicked: {
                    // Reset system hotkeys to defaults
                    hotkeyManager.resetSystemHotkeys()
                }
            }
            
            Item { Layout.fillWidth: true }
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
                    // Reset clip hotkeys
                    for (var i = 0; i < audioManager.audioClips.length; i++) {
                        hotkeyManager.unregisterHotkey(audioManager.audioClips[i].id)
                    }
                    // Reset system hotkeys
                    hotkeyManager.resetSystemHotkeys()
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
                id: keyCaptureRect
                Layout.fillWidth: true
                height: 40
                color: keyCaptureArea.activeFocus ? "#3a3a4e" : "#2a2a3e"
                radius: 6
                border.color: keyCaptureArea.activeFocus ? "#7C3AED" : "#4f46e5"
                border.width: keyCaptureArea.activeFocus ? 2 : 1
                
                Text {
                    anchors.centerIn: parent
                    text: hotkeyCapture.currentKey || (keyCaptureArea.activeFocus ? "Listening for keys..." : "Click here and press keys")
                    color: "#E5E7EB"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: keyCaptureArea.forceActiveFocus()
                }
                
                Item {
                    id: keyCaptureArea
                    anchors.fill: parent
                    focus: true
                    
                    Keys.onPressed: function(event) {
                        var parts = []
                        
                        // Build modifier string
                        if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl")
                        if (event.modifiers & Qt.AltModifier) parts.push("Alt")
                        if (event.modifiers & Qt.ShiftModifier) parts.push("Shift")
                        if (event.modifiers & Qt.MetaModifier) parts.push("Meta")
                        
                        // Get key name
                        var keyName = ""
                        switch(event.key) {
                            case Qt.Key_A: keyName = "A"; break
                            case Qt.Key_B: keyName = "B"; break
                            case Qt.Key_C: keyName = "C"; break
                            case Qt.Key_D: keyName = "D"; break
                            case Qt.Key_E: keyName = "E"; break
                            case Qt.Key_F: keyName = "F"; break
                            case Qt.Key_G: keyName = "G"; break
                            case Qt.Key_H: keyName = "H"; break
                            case Qt.Key_I: keyName = "I"; break
                            case Qt.Key_J: keyName = "J"; break
                            case Qt.Key_K: keyName = "K"; break
                            case Qt.Key_L: keyName = "L"; break
                            case Qt.Key_M: keyName = "M"; break
                            case Qt.Key_N: keyName = "N"; break
                            case Qt.Key_O: keyName = "O"; break
                            case Qt.Key_P: keyName = "P"; break
                            case Qt.Key_Q: keyName = "Q"; break
                            case Qt.Key_R: keyName = "R"; break
                            case Qt.Key_S: keyName = "S"; break
                            case Qt.Key_T: keyName = "T"; break
                            case Qt.Key_U: keyName = "U"; break
                            case Qt.Key_V: keyName = "V"; break
                            case Qt.Key_W: keyName = "W"; break
                            case Qt.Key_X: keyName = "X"; break
                            case Qt.Key_Y: keyName = "Y"; break
                            case Qt.Key_Z: keyName = "Z"; break
                            case Qt.Key_0: keyName = "0"; break
                            case Qt.Key_1: keyName = "1"; break
                            case Qt.Key_2: keyName = "2"; break
                            case Qt.Key_3: keyName = "3"; break
                            case Qt.Key_4: keyName = "4"; break
                            case Qt.Key_5: keyName = "5"; break
                            case Qt.Key_6: keyName = "6"; break
                            case Qt.Key_7: keyName = "7"; break
                            case Qt.Key_8: keyName = "8"; break
                            case Qt.Key_9: keyName = "9"; break
                            case Qt.Key_F1: keyName = "F1"; break
                            case Qt.Key_F2: keyName = "F2"; break
                            case Qt.Key_F3: keyName = "F3"; break
                            case Qt.Key_F4: keyName = "F4"; break
                            case Qt.Key_F5: keyName = "F5"; break
                            case Qt.Key_F6: keyName = "F6"; break
                            case Qt.Key_F7: keyName = "F7"; break
                            case Qt.Key_F8: keyName = "F8"; break
                            case Qt.Key_F9: keyName = "F9"; break
                            case Qt.Key_F10: keyName = "F10"; break
                            case Qt.Key_F11: keyName = "F11"; break
                            case Qt.Key_F12: keyName = "F12"; break
                            case Qt.Key_Space: keyName = "Space"; break
                            case Qt.Key_Return: keyName = "Enter"; break
                            case Qt.Key_Enter: keyName = "Enter"; break
                            case Qt.Key_Tab: keyName = "Tab"; break
                            case Qt.Key_Backspace: keyName = "Backspace"; break
                            case Qt.Key_Delete: keyName = "Delete"; break
                            case Qt.Key_Insert: keyName = "Insert"; break
                            case Qt.Key_Home: keyName = "Home"; break
                            case Qt.Key_End: keyName = "End"; break
                            case Qt.Key_PageUp: keyName = "PageUp"; break
                            case Qt.Key_PageDown: keyName = "PageDown"; break
                            case Qt.Key_Up: keyName = "Up"; break
                            case Qt.Key_Down: keyName = "Down"; break
                            case Qt.Key_Left: keyName = "Left"; break
                            case Qt.Key_Right: keyName = "Right"; break
                            default:
                                // Skip modifier-only keys
                                if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || 
                                    event.key === Qt.Key_Shift || event.key === Qt.Key_Meta) {
                                    return
                                }
                                keyName = event.text.toUpperCase()
                        }
                        
                        if (keyName) {
                            parts.push(keyName)
                            hotkeyCapture.currentKey = parts.join("+")
                        }
                        
                        event.accepted = true
                    }
                }
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
                        if (hotkeyCapture.currentKey && hotkeyCapture.currentKey !== "") {
                            var success = hotkeyManager.registerHotkey(hotkeyDialog.clipId, hotkeyCapture.currentKey)
                            if (success) {
                                console.log("Hotkey assigned:", hotkeyCapture.currentKey, "for clip:", hotkeyDialog.clipId)
                            } else {
                                console.log("Failed to assign hotkey - may already be in use")
                            }
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
        property string currentKey: ""
    }
    
    // Add Hotkey Dialog with song selection
    Popup {
        id: addHotkeyDialog
        width: 450
        height: 320
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: parent
        
        property int selectedClipIndex: 0
        
        onOpened: {
            selectedClipIndex = 0
            addHotkeyCapture.currentKey = ""
            addKeyCaptureArea.forceActiveFocus()
        }
        
        background: Rectangle {
            color: "#1a1a2e"
            radius: 12
            border.color: "#2a2a3e"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20
            
            Text {
                text: "Add New Hotkey"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "white"
            }
            
            // Song Selection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Text {
                    text: "Select Audio Clip:"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    color: "#2a2a3e"
                    radius: 8
                    border.color: songDropdownPopup.visible ? "#7C3AED" : "#4B5563"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        
                        Text {
                            Layout.fillWidth: true
                            text: root.uniqueClips.length > 0 ? root.uniqueClips[addHotkeyDialog.selectedClipIndex].title : "No clips"
                            font.pixelSize: 14
                            color: "white"
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            text: songDropdownPopup.visible ? "▲" : "▼"
                            font.pixelSize: 10
                            color: "#9CA3AF"
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: songDropdownPopup.visible ? songDropdownPopup.close() : songDropdownPopup.open()
                    }
                    
                    Popup {
                        id: songDropdownPopup
                        y: parent.height + 4
                        width: parent.width
                        height: Math.min(200, root.uniqueClips.length * 40 + 8)
                        padding: 4
                        
                        background: Rectangle {
                            color: "#2a2a3e"
                            radius: 8
                            border.color: "#4B5563"
                        }
                        
                        contentItem: ListView {
                            clip: true
                            model: root.uniqueClips
                            boundsBehavior: Flickable.StopAtBounds
                            
                            delegate: Rectangle {
                                width: songDropdownPopup.width - 8
                                height: 36
                                color: mouseArea.containsMouse ? "#3a3a4e" : "transparent"
                                radius: 4
                                
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title || "Untitled"
                                    font.pixelSize: 13
                                    color: "white"
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        addHotkeyDialog.selectedClipIndex = index
                                        songDropdownPopup.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Hotkey Capture
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Text {
                    text: "Press Hotkey Combination:"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                }
                
                Rectangle {
                    id: addKeyCaptureRect
                    Layout.fillWidth: true
                    height: 44
                    color: addKeyCaptureArea.activeFocus ? "#3a3a4e" : "#2a2a3e"
                    radius: 8
                    border.color: addKeyCaptureArea.activeFocus ? "#7C3AED" : "#4B5563"
                    border.width: addKeyCaptureArea.activeFocus ? 2 : 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: addHotkeyCapture.currentKey || (addKeyCaptureArea.activeFocus ? "Listening..." : "Click and press keys")
                        font.pixelSize: 14
                        color: addHotkeyCapture.currentKey ? "#22C55E" : "#E5E7EB"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: addKeyCaptureArea.forceActiveFocus()
                    }
                    
                    Item {
                        id: addKeyCaptureArea
                        anchors.fill: parent
                        focus: true
                        
                        Keys.onPressed: function(event) {
                            var parts = []
                            
                            if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl")
                            if (event.modifiers & Qt.AltModifier) parts.push("Alt")
                            if (event.modifiers & Qt.ShiftModifier) parts.push("Shift")
                            if (event.modifiers & Qt.MetaModifier) parts.push("Cmd")
                            
                            var keyName = ""
                            switch(event.key) {
                                case Qt.Key_A: keyName = "A"; break
                                case Qt.Key_B: keyName = "B"; break
                                case Qt.Key_C: keyName = "C"; break
                                case Qt.Key_D: keyName = "D"; break
                                case Qt.Key_E: keyName = "E"; break
                                case Qt.Key_F: keyName = "F"; break
                                case Qt.Key_G: keyName = "G"; break
                                case Qt.Key_H: keyName = "H"; break
                                case Qt.Key_I: keyName = "I"; break
                                case Qt.Key_J: keyName = "J"; break
                                case Qt.Key_K: keyName = "K"; break
                                case Qt.Key_L: keyName = "L"; break
                                case Qt.Key_M: keyName = "M"; break
                                case Qt.Key_N: keyName = "N"; break
                                case Qt.Key_O: keyName = "O"; break
                                case Qt.Key_P: keyName = "P"; break
                                case Qt.Key_Q: keyName = "Q"; break
                                case Qt.Key_R: keyName = "R"; break
                                case Qt.Key_S: keyName = "S"; break
                                case Qt.Key_T: keyName = "T"; break
                                case Qt.Key_U: keyName = "U"; break
                                case Qt.Key_V: keyName = "V"; break
                                case Qt.Key_W: keyName = "W"; break
                                case Qt.Key_X: keyName = "X"; break
                                case Qt.Key_Y: keyName = "Y"; break
                                case Qt.Key_Z: keyName = "Z"; break
                                case Qt.Key_0: keyName = "0"; break
                                case Qt.Key_1: keyName = "1"; break
                                case Qt.Key_2: keyName = "2"; break
                                case Qt.Key_3: keyName = "3"; break
                                case Qt.Key_4: keyName = "4"; break
                                case Qt.Key_5: keyName = "5"; break
                                case Qt.Key_6: keyName = "6"; break
                                case Qt.Key_7: keyName = "7"; break
                                case Qt.Key_8: keyName = "8"; break
                                case Qt.Key_9: keyName = "9"; break
                                case Qt.Key_F1: keyName = "F1"; break
                                case Qt.Key_F2: keyName = "F2"; break
                                case Qt.Key_F3: keyName = "F3"; break
                                case Qt.Key_F4: keyName = "F4"; break
                                case Qt.Key_F5: keyName = "F5"; break
                                case Qt.Key_F6: keyName = "F6"; break
                                case Qt.Key_F7: keyName = "F7"; break
                                case Qt.Key_F8: keyName = "F8"; break
                                case Qt.Key_F9: keyName = "F9"; break
                                case Qt.Key_F10: keyName = "F10"; break
                                case Qt.Key_F11: keyName = "F11"; break
                                case Qt.Key_F12: keyName = "F12"; break
                                case Qt.Key_Space: keyName = "Space"; break
                                case Qt.Key_Return: keyName = "Enter"; break
                                case Qt.Key_Enter: keyName = "Enter"; break
                                default:
                                    if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || 
                                        event.key === Qt.Key_Shift || event.key === Qt.Key_Meta) {
                                        return
                                    }
                                    keyName = event.text.toUpperCase()
                            }
                            
                            if (keyName) {
                                parts.push(keyName)
                                addHotkeyCapture.currentKey = parts.join("+")
                            }
                            event.accepted = true
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    width: 100
                    height: 40
                    radius: 8
                    color: "#4B5563"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: 14
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addHotkeyDialog.close()
                    }
                }
                
                Rectangle {
                    width: 120
                    height: 40
                    radius: 8
                    color: addHotkeyCapture.currentKey ? "#7C3AED" : "#4B5563"
                    opacity: addHotkeyCapture.currentKey ? 1.0 : 0.5
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Assign Hotkey"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (addHotkeyCapture.currentKey === "" || root.uniqueClips.length === 0) {
                                return
                            }
                            
                            var clip = root.uniqueClips[addHotkeyDialog.selectedClipIndex]
                            if (clip) {
                                hotkeyManager.registerHotkey(clip.id, addHotkeyCapture.currentKey)
                                addHotkeyCapture.currentKey = ""
                                addHotkeyDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Key capture helper for add dialog
    QtObject {
        id: addHotkeyCapture
        property string currentKey: ""
    }
    
    // System Hotkey Assignment Dialog
    Popup {
        id: systemHotkeyDialog
        width: 400
        height: 200
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string action: ""
        property string displayName: ""
        property string currentHotkey: ""
        
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
                text: "Edit System Hotkey: " + systemHotkeyDialog.displayName
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "white"
            }
            
            Text {
                text: "Current: " + (systemHotkeyDialog.currentHotkey || "None")
                font.pixelSize: 12
                color: "#9CA3AF"
            }
            
            Text {
                text: "Press new key combination..."
                font.pixelSize: 14
                color: "#9CA3AF"
            }
            
            Rectangle {
                id: systemKeyCaptureRect
                Layout.fillWidth: true
                height: 40
                color: systemKeyCaptureArea.activeFocus ? "#3a3a4e" : "#2a2a3e"
                radius: 6
                border.color: systemKeyCaptureArea.activeFocus ? "#7C3AED" : "#4f46e5"
                border.width: systemKeyCaptureArea.activeFocus ? 2 : 1
                
                Text {
                    anchors.centerIn: parent
                    text: systemHotkeyCapture.currentKey || (systemKeyCaptureArea.activeFocus ? "Listening for keys..." : "Click here and press keys")
                    color: "#E5E7EB"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: systemKeyCaptureArea.forceActiveFocus()
                }
                
                Item {
                    id: systemKeyCaptureArea
                    anchors.fill: parent
                    focus: true
                    
                    Keys.onPressed: function(event) {
                        var parts = []
                        
                        // Build modifier string
                        if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl")
                        if (event.modifiers & Qt.AltModifier) parts.push("Alt")
                        if (event.modifiers & Qt.ShiftModifier) parts.push("Shift")
                        if (event.modifiers & Qt.MetaModifier) parts.push("Cmd")
                        
                        // Get key name
                        var keyName = ""
                        switch(event.key) {
                            case Qt.Key_A: keyName = "A"; break
                            case Qt.Key_B: keyName = "B"; break
                            case Qt.Key_C: keyName = "C"; break
                            case Qt.Key_D: keyName = "D"; break
                            case Qt.Key_E: keyName = "E"; break
                            case Qt.Key_F: keyName = "F"; break
                            case Qt.Key_G: keyName = "G"; break
                            case Qt.Key_H: keyName = "H"; break
                            case Qt.Key_I: keyName = "I"; break
                            case Qt.Key_J: keyName = "J"; break
                            case Qt.Key_K: keyName = "K"; break
                            case Qt.Key_L: keyName = "L"; break
                            case Qt.Key_M: keyName = "M"; break
                            case Qt.Key_N: keyName = "N"; break
                            case Qt.Key_O: keyName = "O"; break
                            case Qt.Key_P: keyName = "P"; break
                            case Qt.Key_Q: keyName = "Q"; break
                            case Qt.Key_R: keyName = "R"; break
                            case Qt.Key_S: keyName = "S"; break
                            case Qt.Key_T: keyName = "T"; break
                            case Qt.Key_U: keyName = "U"; break
                            case Qt.Key_V: keyName = "V"; break
                            case Qt.Key_W: keyName = "W"; break
                            case Qt.Key_X: keyName = "X"; break
                            case Qt.Key_Y: keyName = "Y"; break
                            case Qt.Key_Z: keyName = "Z"; break
                            case Qt.Key_0: keyName = "0"; break
                            case Qt.Key_1: keyName = "1"; break
                            case Qt.Key_2: keyName = "2"; break
                            case Qt.Key_3: keyName = "3"; break
                            case Qt.Key_4: keyName = "4"; break
                            case Qt.Key_5: keyName = "5"; break
                            case Qt.Key_6: keyName = "6"; break
                            case Qt.Key_7: keyName = "7"; break
                            case Qt.Key_8: keyName = "8"; break
                            case Qt.Key_9: keyName = "9"; break
                            case Qt.Key_F1: keyName = "F1"; break
                            case Qt.Key_F2: keyName = "F2"; break
                            case Qt.Key_F3: keyName = "F3"; break
                            case Qt.Key_F4: keyName = "F4"; break
                            case Qt.Key_F5: keyName = "F5"; break
                            case Qt.Key_F6: keyName = "F6"; break
                            case Qt.Key_F7: keyName = "F7"; break
                            case Qt.Key_F8: keyName = "F8"; break
                            case Qt.Key_F9: keyName = "F9"; break
                            case Qt.Key_F10: keyName = "F10"; break
                            case Qt.Key_F11: keyName = "F11"; break
                            case Qt.Key_F12: keyName = "F12"; break
                            case Qt.Key_Space: keyName = "Space"; break
                            case Qt.Key_Return: keyName = "Enter"; break
                            case Qt.Key_Enter: keyName = "Enter"; break
                            case Qt.Key_Tab: keyName = "Tab"; break
                            case Qt.Key_Backspace: keyName = "Backspace"; break
                            case Qt.Key_Delete: keyName = "Delete"; break
                            case Qt.Key_Insert: keyName = "Insert"; break
                            case Qt.Key_Home: keyName = "Home"; break
                            case Qt.Key_End: keyName = "End"; break
                            case Qt.Key_PageUp: keyName = "PageUp"; break
                            case Qt.Key_PageDown: keyName = "PageDown"; break
                            case Qt.Key_Up: keyName = "Up"; break
                            case Qt.Key_Down: keyName = "Down"; break
                            case Qt.Key_Left: keyName = "Left"; break
                            case Qt.Key_Right: keyName = "Right"; break
                            default:
                                // Skip modifier-only keys
                                if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || 
                                    event.key === Qt.Key_Shift || event.key === Qt.Key_Meta) {
                                    return
                                }
                                keyName = event.text.toUpperCase()
                        }
                        
                        if (keyName) {
                            parts.push(keyName)
                            systemHotkeyCapture.currentKey = parts.join("+")
                        }
                        
                        event.accepted = true
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                
                ActionButton {
                    text: "Cancel"
                    onClicked: systemHotkeyDialog.close()
                }
                
                ActionButton {
                    text: "Clear"
                    onClicked: {
                        hotkeyManager.setSystemHotkey(systemHotkeyDialog.action, "")
                        systemHotkeyDialog.close()
                        systemHotkeyCapture.currentKey = ""
                    }
                }
                
                ActionButton {
                    text: "Save"
                    enabled: systemHotkeyCapture.currentKey !== ""
                    onClicked: {
                        if (systemHotkeyCapture.currentKey && systemHotkeyCapture.currentKey !== "") {
                            hotkeyManager.setSystemHotkey(systemHotkeyDialog.action, systemHotkeyCapture.currentKey)
                            console.log("System hotkey assigned:", systemHotkeyCapture.currentKey, "for action:", systemHotkeyDialog.action)
                            systemHotkeyDialog.close()
                            systemHotkeyCapture.currentKey = ""
                        }
                    }
                }
            }
        }
    }
    
    // Key capture helper for system dialog
    QtObject {
        id: systemHotkeyCapture
        property string currentKey: ""
    }
}
