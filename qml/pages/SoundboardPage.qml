import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property int selectedSlots: 0
    property int rightPanelIndex: 0  // 0: Details, 1: Add Audio, 2: Meters, 3: Teleprompter
    property var audioClips: []
    
    Component.onCompleted: {
        // Add sample audio clips
        audioClips = [
            audioManager.addClip("Greeting", "", "Alt+F1"),
            audioManager.addClip("Welcome", "", "Alt+F2"),
            audioManager.addClip("Intro", "", "Alt+F3")
        ]
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Main Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // Page Header with background
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                color: "transparent"
                clip: true
                
                // Background Image
                Image {
                    anchors.fill: parent
                    source: "qrc:/TalkLess/resources/images/background-52.png"
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.8
                }
                
                // Gradient Overlay
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#1a0a2e" }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: "#2a1040" }
                    }
                }
                
                // Content
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    
                    ColumnLayout {
                        spacing: 8
                        
                        Text {
                            text: "Soundboard Test"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            color: "white"
                        }
                        
                        Text {
                            text: "Manage and trigger your audio clips"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Menu button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 6
                        color: Qt.rgba(255, 255, 255, 0.1)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "⋮"
                            font.pixelSize: 16
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    // Add Soundboard button
                    Rectangle {
                        width: 140
                        height: 40
                        radius: 8
                        color: "#7C3AED"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Add Soundboard"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
            
            // Filter toolbar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "transparent"
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    // Filter icons
                    Repeater {
                        model: ["▶", "🌐", "✏", "🗑"]
                        
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: "#1a1a2e"
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 14
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
            
            // Audio Grid
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                GridLayout {
                    width: parent.width
                    columns: 4
                    columnSpacing: 16
                    rowSpacing: 16
                    
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    
                    // Add Audio Card
                    AddAudioCard {
                        onClicked: rightPanelIndex = 1
                    }
                    
                    // Audio Cards
                    Repeater {
                        model: audioManager.audioClips.length
                        
                        ColumnLayout {
                            spacing: 8
                            
                            AudioCard {
                                title: audioManager.audioClips[index] ? audioManager.audioClips[index].title : ""
                                hotkey: audioManager.audioClips[index] ? audioManager.audioClips[index].hotkey : ""
                                tagLabel: index < 3 ? "Morning" : ""
                                tagColor: "#EAB308"
                                isSelected: index === 0
                                isPlaying: audioManager.audioClips[index] ? audioManager.audioClips[index].isPlaying : false
                                audioClipId: audioManager.audioClips[index] ? audioManager.audioClips[index].id : ""
                                imagePath: audioManager.audioClips[index] ? audioManager.audioClips[index].imagePath : ""
                                onClicked: rightPanelIndex = 0
                                onDeleteClicked: {
                                    if (audioManager.audioClips[index]) {
                                        audioManager.removeClip(audioManager.audioClips[index].id)
                                    }
                                }
                            }
                            
                            // Tags below card
                            RowLayout {
                                spacing: 6
                                visible: index < 3
                                
                                AudioTag {
                                    text: "Professional"
                                    tagColor: "#374151"
                                }
                                
                                AudioTag {
                                    text: "warm"
                                    tagColor: "#374151"
                                }
                            }
                        }
                    }
                }
            }
            
            // Selection bar (when slots selected)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: selectedSlots > 0 ? 50 : 0
                color: "#1a1a2e"
                visible: selectedSlots > 0
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    
                    Text {
                        text: selectedSlots + " Slots Selected"
                        font.pixelSize: 13
                        color: "white"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 80
                        height: 32
                        radius: 6
                        color: "#EF4444"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: 12
                            color: "white"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    Rectangle {
                        width: 140
                        height: 32
                        radius: 6
                        color: "#2a2a3e"
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "Move to Soundboard"
                                font.pixelSize: 12
                                color: "#9CA3AF"
                            }
                            
                            Text {
                                text: "▼"
                                font.pixelSize: 8
                                color: "#9CA3AF"
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
            
            // Bottom Audio Player
            AudioPlayer {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 16
                title: "Greetings"
                subtitle: "Press F1 to play"
            }
        }
        
        // Right Panel
        StackLayout {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            currentIndex: rightPanelIndex
            
            AudioDetailsPanel {
                title: "Introducing"
            }
            
            AddAudioPanel {
                onAudioAdded: function(name, filePath) {
                    var clip = audioManager.addClip(name, filePath, "")
                    if (clip) {
                        audioClips.push(clip)
                        audioClipsChanged()
                    }
                    rightPanelIndex = 0
                }
                onCancelled: {
                    rightPanelIndex = 0
                }
            }
            
            MetersPanel {}
            
            TeleprompterPanel {}
        }
    }
}
