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
            text: "Interface Preference"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "white"
        }
        
        // Interface Scale
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Interface Scale:"
                font.pixelSize: 14
                color: "white"
            }
            
            DropdownSelect {
                currentValue: "100%"
                model: ["75%", "100%", "125%", "150%"]
                width: 150
            }
        }
        
        // Theme Mode
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Theme Mode"
                font.pixelSize: 14
                color: "white"
            }
            
            ColumnLayout {
                spacing: 8
                
                RowLayout {
                    spacing: 8
                    
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#4B5563"
                        border.color: "#9CA3AF"
                        border.width: 1
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: "#9CA3AF"
                            visible: true
                        }
                    }
                    
                    Text {
                        text: "Light"
                        font.pixelSize: 13
                        color: "#9CA3AF"
                    }
                }
                
                RowLayout {
                    spacing: 8
                    
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#7C3AED"
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: "white"
                        }
                    }
                    
                    Text {
                        text: "Dark"
                        font.pixelSize: 13
                        color: "white"
                    }
                }
            }
        }
        
        // UI Animations
        RowLayout {
            spacing: 16
            
            Text {
                text: "UI Animations:"
                font.pixelSize: 14
                color: "white"
            }
            
            ToggleSwitch {
                checked: true
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Save Button
        RowLayout {
            Layout.fillWidth: true
            
            ActionButton {
                text: "Save Changes"
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
