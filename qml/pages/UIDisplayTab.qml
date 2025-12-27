import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Bind to settingsManager properties for persistence
    property string currentTheme: settingsManager.theme
    property real interfaceScale: settingsManager.interfaceScale
    property bool uiAnimationsEnabled: settingsManager.uiAnimationsEnabled
    property bool systemThemeEnabled: settingsManager.systemThemeEnabled
    
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
                    checked: settingsManager.systemThemeEnabled
                    onCheckedChanged: {
                        settingsManager.systemThemeEnabled = checked
                        if (checked) {
                            settingsManager.theme = Qt.platform.os === "windows" ? "dark" : "light"
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
                currentValue: (settingsManager.interfaceScale * 100).toFixed(0) + "%"
                model: ["75%", "100%", "125%", "150%", "175%", "200%"]
                width: 150
                onValueChanged: {
                    settingsManager.interfaceScale = parseFloat(value.replace("%", "")) / 100
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
                currentValue: settingsManager.theme === "light" ? "Light" : settingsManager.theme === "dark" ? "Dark" : "Auto (System)"
                model: ["Light", "Dark", "Auto (System)"]
                onValueChanged: {
                    if (value === "Light") {
                        settingsManager.theme = "light"
                        Colors.setTheme("light")
                    } else if (value === "Dark") {
                        settingsManager.theme = "dark"
                        Colors.setTheme("dark")
                    } else if (value === "Auto (System)") {
                        settingsManager.theme = "auto"
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
                checked: settingsManager.uiAnimationsEnabled
                onCheckedChanged: settingsManager.uiAnimationsEnabled = checked
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
                checked: settingsManager.compactMode
                onCheckedChanged: settingsManager.compactMode = checked
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
                checked: settingsManager.showTooltips
                onCheckedChanged: settingsManager.showTooltips = checked
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
                checked: settingsManager.hardwareAcceleration
                onCheckedChanged: settingsManager.hardwareAcceleration = checked
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
                    settingsManager.saveAllSettings()
                    console.log("Settings saved - Theme:", settingsManager.theme, "Scale:", settingsManager.interfaceScale)
                }
            }
            
            ActionButton {
                text: "Reset to Defaults"
                onClicked: {
                    settingsManager.theme = "dark"
                    settingsManager.interfaceScale = 1.0
                    settingsManager.uiAnimationsEnabled = true
                    settingsManager.systemThemeEnabled = false
                    settingsManager.compactMode = false
                    settingsManager.showTooltips = true
                    settingsManager.hardwareAcceleration = true
                    Colors.setTheme("dark")
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
