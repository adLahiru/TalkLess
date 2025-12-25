import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    
    width: 1400
    height: 900
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: qsTr("TalkLess")
    color: Colors.background
    
    // Window flags to respect work area when maximized
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint | Qt.WindowMaximizeUsingGeometryHint
    
    // Global hotkey handler - captures key presses when app has focus
    Item {
        id: globalKeyHandler
        focus: true
        anchors.fill: parent
        
        Keys.onPressed: function(event) {
            // Build hotkey string from pressed keys
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
                    // Skip modifier-only keys
                    if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || 
                        event.key === Qt.Key_Shift || event.key === Qt.Key_Meta) {
                        return
                    }
                    keyName = event.text.toUpperCase()
            }
            
            if (keyName) {
                parts.push(keyName)
                var hotkeyString = parts.join("+")
                
                // Check if this hotkey is registered and trigger it
                hotkeyManager.handleKeyPress(event.key, event.modifiers)
            }
        }
    }
        
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            currentIndex: 0
        }
        
        // Main Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // Header Bar
            HeaderBar {
                id: headerBar
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.minimumHeight: 50
                Layout.maximumHeight: 80
                currentPageTitle: "Soundboard"
            }
            
            // Content placeholder
            StackLayout {
                id: contentStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: sidebar.currentIndex === 0 ? 0 : 1
                
                // Soundboard Page
                SoundboardPage {
                    id: soundboardPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                
                // System Settings Page
                SystemSettingsPage {
                    id: settingsPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
