import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property var scriptLines: [
        "Thank you for calling our support...",
        "Let me transfer you to the right department...",
        "Thank you for calling our support...",
        "Let me transfer you to the right department...",
        "Thank you for calling our support...",
        "Let me transfer you to the right department...",
        "Thank you for calling our support...",
        "Let me transfer you to the right department..."
    ]
    
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
                    color: index === 3 ? "#7C3AED" : "#2a2a3e"
                    
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
        
        // Title
        Text {
            text: "Teleprompter"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "white"
        }
        
        // Script content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a2e"
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                // Upload icon
                Text {
                    text: "⬆"
                    font.pixelSize: 14
                    color: "#6B7280"
                    Layout.alignment: Qt.AlignTop
                }
                
                // Script text
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 8
                        
                        Repeater {
                            model: scriptLines
                            
                            Text {
                                text: modelData
                                font.pixelSize: 11
                                color: "#9CA3AF"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                
                // Microphone icon
                Text {
                    text: "🎤"
                    font.pixelSize: 14
                    color: "#6B7280"
                    Layout.alignment: Qt.AlignTop
                }
            }
        }
        
        // Download button
        Rectangle {
            Layout.preferredWidth: 100
            height: 36
            radius: 6
            color: "#2a2a3e"
            
            Text {
                anchors.centerIn: parent
                text: "Download"
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
