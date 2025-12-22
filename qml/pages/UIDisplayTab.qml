import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Theme properties
    property string currentTheme: "dark"
    property real interfaceScale: 1.0
    property bool uiAnimationsEnabled: true
    property bool systemThemeEnabled: false
    
    // Theme settings object
    QtObject {
        id: themeSettings
        
        property string theme: currentTheme
        property real scale: interfaceScale
        property bool animations: uiAnimationsEnabled
        property bool systemTheme: systemThemeEnabled
        
        function saveSettings() {
            // Save settings to storage (would need backend integration)
            console.log("Saving theme settings:", theme, scale, animations, systemTheme)
        }
        
        function resetToDefaults() {
            currentTheme = "dark"
            interfaceScale = 1.0
            uiAnimationsEnabled = true
            systemThemeEnabled = false
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // Section Title
        Text {
            text: "Interface Preference"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: Colors.textPrimary
        }
        
        // System Theme Detection
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "System Theme:"
                font.pixelSize: 14
                color: Colors.textPrimary
            }
            
            RowLayout {
                spacing: 16
                
                Text {
                    text: "Follow system theme"
                    font.pixelSize: 13
                    color: Colors.textSecondary
                    Layout.preferredWidth: 200
                }
                
                ToggleSwitch {
                    id: systemThemeSwitch
                    checked: systemThemeEnabled
                    onCheckedChanged: {
                        systemThemeEnabled = checked
                        if (checked) {
                            // Auto-detect system theme (would need backend integration)
                            currentTheme = Qt.platform.os === "windows" ? "dark" : "light"
                        }
                    }
                }
            }
        }
        
        // Interface Scale
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Interface Scale:"
                font.pixelSize: 14
                color: Colors.textPrimary
            }
            
            DropdownSelect {
                id: scaleDropdown
                currentValue: (interfaceScale * 100).toFixed(0) + "%"
                model: ["75%", "100%", "125%", "150%", "175%", "200%"]
                width: 150
                onValueChanged: {
                    interfaceScale = parseFloat(value.replace("%", "")) / 100
                }
            }
        }
        
        // Theme Mode
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            enabled: !systemThemeEnabled
            opacity: systemThemeEnabled ? 0.5 : 1.0
            
            Text {
                text: "Theme Mode"
                font.pixelSize: 14
                color: Colors.textPrimary
            }
            
            DropdownSelect {
                id: themeDropdown
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                currentValue: currentTheme === "light" ? "Light" : currentTheme === "dark" ? "Dark" : "Auto (System)"
                model: ["Light", "Dark", "Auto (System)"]
                onValueChanged: {
                    if (value === "Light") {
                        currentTheme = "light"
                        Colors.setTheme("light")
                    } else if (value === "Dark") {
                        currentTheme = "dark"
                        Colors.setTheme("dark")
                    } else if (value === "Auto (System)") {
                        currentTheme = "auto"
                        Colors.setTheme("auto")
                    }
                }
            }
        }
        
        // UI Animations
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "UI Animations:"
                font.pixelSize: 14
                color: Colors.textPrimary
                Layout.preferredWidth: 200
            }
            
            ToggleSwitch {
                id: animationsSwitch
                checked: uiAnimationsEnabled
                onCheckedChanged: uiAnimationsEnabled = checked
            }
        }
        
        // Additional Display Options
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.border
            Layout.topMargin: 10
            Layout.bottomMargin: 10
        }
        
        Text {
            text: "Display Options"
            font.pixelSize: 14
            font.weight: Font.Medium
            color: Colors.textPrimary
        }
        
        // Compact Mode
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "Compact Mode:"
                font.pixelSize: 13
                color: Colors.textSecondary
                Layout.preferredWidth: 200
            }
            
            ToggleSwitch {
                id: compactModeSwitch
                checked: false
            }
        }
        
        // Show Tooltips
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "Show Tooltips:"
                font.pixelSize: 13
                color: Colors.textSecondary
                Layout.preferredWidth: 200
            }
            
            ToggleSwitch {
                id: tooltipsSwitch
                checked: true
            }
        }
        
        // Hardware Acceleration
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "Hardware Acceleration:"
                font.pixelSize: 13
                color: Colors.textSecondary
                Layout.preferredWidth: 200
            }
            
            ToggleSwitch {
                id: hardwareAccelSwitch
                checked: true
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            ActionButton {
                text: "Apply Changes"
                onClicked: {
                    themeSettings.saveSettings()
                    // Apply theme changes to the application
                    console.log("Theme applied:", currentTheme, "Scale:", interfaceScale)
                }
            }
            
            ActionButton {
                text: "Reset to Defaults"
                onClicked: {
                    themeSettings.resetToDefaults()
                    scaleDropdown.currentValue = "100%"
                    themeDropdown.currentValue = "Dark"
                    systemThemeSwitch.checked = false
                    animationsSwitch.checked = true
                    compactModeSwitch.checked = false
                    tooltipsSwitch.checked = true
                    hardwareAccelSwitch.checked = true
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
