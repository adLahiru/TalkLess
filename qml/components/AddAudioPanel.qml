import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    width: 280
    color: "#12121a"
    radius: 12
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // Header with icons
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "F1"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: "white"
            }
            
            Item { Layout.fillWidth: true }
            
            // Icon buttons
            Repeater {
                model: ["⚙", "+", "●", "◫", "🔊"]
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: "#2a2a3e"
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 12
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
        
        // Name Audio File
        Text {
            text: "Name Audio File"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            
            TextInput {
                anchors.fill: parent
                anchors.margins: 12
                color: "white"
                font.pixelSize: 13
                
                Text {
                    anchors.fill: parent
                    text: "Enter Name Here..."
                    color: "#6B7280"
                    font.pixelSize: 13
                    visible: parent.text.length === 0
                }
            }
        }
        
        // Assign to Slot
        Text {
            text: "Assign to Slot"
            font.pixelSize: 13
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                
                Text {
                    text: "Select Available Slot"
                    font.pixelSize: 13
                    color: "#6B7280"
                    Layout.fillWidth: true
                }
                
                Text {
                    text: "▼"
                    font.pixelSize: 10
                    color: "#6B7280"
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }
        
        // Upload area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 8
            color: "transparent"
            border.color: "#4B5563"
            border.width: 1
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "⬆"
                    font.pixelSize: 24
                    color: "#6B7280"
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Drop audio files here or click to browse"
                    font.pixelSize: 12
                    color: "#6B7280"
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }
        
        // Trim Audio
        Text {
            text: "Trim Audio"
            font.pixelSize: 13
            font.weight: Font.Medium
            color: "white"
        }
        
        WaveformDisplay {
            Layout.fillWidth: true
            startTime: 1.30
            endTime: 3.30
        }
        
        Item { Layout.fillHeight: true }
        
        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 12
            
            Rectangle {
                Layout.preferredWidth: 80
                height: 36
                radius: 6
                color: "transparent"
                border.color: "#4B5563"
                
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 13
                    color: "#9CA3AF"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 80
                height: 36
                radius: 6
                color: "#7C3AED"
                
                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 13
                    color: "white"
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
