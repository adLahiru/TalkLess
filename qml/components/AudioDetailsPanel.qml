import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string title: "Introducing"
    property string imagePath: ""
    property real voiceVolume: 45
    property real speed: 1.0
    
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
        
        // Image preview
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 8
            color: "#1a1a2e"
            clip: true
            
            Image {
                anchors.fill: parent
                source: imagePath
                fillMode: Image.PreserveAspectCrop
            }
            
            // Fallback
            Rectangle {
                anchors.fill: parent
                radius: 8
                visible: imagePath === ""
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#1a1a2e" }
                    GradientStop { position: 1.0; color: "#2a2a3e" }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 48
                }
            }
            
            // Edit button
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                width: 24
                height: 24
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.5)
                
                Text {
                    anchors.centerIn: parent
                    text: "✏"
                    font.pixelSize: 12
                    color: "white"
                }
            }
        }
        
        // Title
        Text {
            text: title
            font.pixelSize: 18
            font.weight: Font.Bold
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Playback controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            Repeater {
                model: ["◀◀", "◀", "⏸", "▶▶", "▶", "↻"]
                
                Rectangle {
                    width: index === 2 ? 36 : 28
                    height: index === 2 ? 36 : 28
                    radius: width / 2
                    color: index === 2 ? "#7C3AED" : "#2a2a3e"
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: index === 2 ? 14 : 10
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
        
        // Volume slider (inline)
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "Voice Volume"
                font.pixelSize: 13
                color: "#9CA3AF"
                Layout.preferredWidth: 100
            }
            
            Slider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: voiceVolume
                
                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#374151"
                    
                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: "#7C3AED"
                    }
                }
                
                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "white"
                }
            }
            
            Text {
                text: Math.round(volumeSlider.value)
                font.pixelSize: 12
                color: "#9CA3AF"
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }
        
        // Speed slider (inline)
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Text {
                text: "Speed"
                font.pixelSize: 13
                color: "#9CA3AF"
                Layout.preferredWidth: 100
            }
            
            Slider {
                id: speedSlider
                Layout.fillWidth: true
                from: 0
                to: 200
                value: speed * 100
                
                background: Rectangle {
                    x: speedSlider.leftPadding
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    width: speedSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#374151"
                    
                    Rectangle {
                        width: speedSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: "#7C3AED"
                    }
                }
                
                handle: Rectangle {
                    x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "white"
                }
            }
            
            Text {
                text: (speedSlider.value / 100).toFixed(1) + "x"
                font.pixelSize: 12
                color: "#9CA3AF"
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }
        
        // Trim Audio (placeholder)
        RowLayout {
            spacing: 8
            
            Text {
                text: "Trim Audio"
                font.pixelSize: 13
                color: "white"
            }
        }
        
        WaveformDisplay {
            Layout.fillWidth: true
            startTime: 1.30
            endTime: 3.30
        }
        
        // Playback Behavior
        Text {
            text: "Playback Behavior"
            font.pixelSize: 13
            font.weight: Font.Medium
            color: "white"
        }
        
        ColumnLayout {
            spacing: 8
            
            Repeater {
                model: ["Stop other sounds on play", "Mute other sounds", "Mute mic during playback", "Persistent settings"]
                
                RowLayout {
                    spacing: 8
                    
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 3
                        color: "#7C3AED"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 10
                            color: "white"
                        }
                    }
                    
                    Text {
                        text: modelData
                        font.pixelSize: 12
                        color: "#9CA3AF"
                    }
                }
            }
        }
        
        // Add Tag
        Text {
            text: "Add Tag"
            font.pixelSize: 13
            font.weight: Font.Medium
            color: "white"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 6
            color: "#1a1a2e"
            border.color: "#2a2a3e"
            
            TextInput {
                anchors.fill: parent
                anchors.margins: 10
                color: "white"
                font.pixelSize: 12
                
                Text {
                    anchors.fill: parent
                    text: "Add tag and press enter"
                    color: "#6B7280"
                    font.pixelSize: 12
                    visible: parent.text.length === 0
                }
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Action buttons
        RowLayout {
            Layout.fillWidth: true
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
        
        Item { Layout.fillHeight: true }
    }
}
