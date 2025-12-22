import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property string title: audioPlayerView.currentTitle
    property string subtitle: "Press F1 to play"
    property real currentTime: audioPlayerView.currentPosition
    property real totalTime: audioPlayerView.currentDuration
    property bool isPlaying: audioPlayerView.isPlaying
    property string imagePath: audioManager.currentClip ? audioManager.currentClip.imagePath : ""
    
    signal playPauseClicked()
    signal previousClicked()
    signal nextClicked()
    
    height: 100
    color: "#1a1a2e"
    radius: 16
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // Album art
        Rectangle {
            width: 48
            height: 48
            radius: 8
            color: "#2a2a3e"
            clip: true
            
            Image {
                anchors.fill: parent
                source: imagePath
                fillMode: Image.PreserveAspectCrop
            }
            
            Rectangle {
                anchors.fill: parent
                radius: 8
                visible: imagePath === ""
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#EC4899" }
                    GradientStop { position: 1.0; color: "#F97316" }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 20
                }
            }
        }
        
        // Info and controls
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            // Waveform and time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Text {
                    text: formatTime(currentTime)
                    font.pixelSize: 11
                    color: "#9CA3AF"
                }
                
                // Mini waveform
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    color: "transparent"
                    
                    Row {
                        id: miniWaveformRow
                        anchors.centerIn: parent
                        spacing: 2
                        
                        // Pre-generated heights to avoid Math.random() in binding
                        property var barHeights: [8, 14, 6, 16, 10, 12, 5, 15, 9, 13, 7, 11, 14, 8, 16, 10, 6, 12, 15, 9]
                        
                        Repeater {
                            model: 20
                            
                            Rectangle {
                                width: 2
                                height: miniWaveformRow.barHeights[index]
                                radius: 1
                                color: "#7C3AED"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
                
                Text {
                    text: formatTime(totalTime)
                    font.pixelSize: 11
                    color: "#9CA3AF"
                }
            }
            
            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                
                // Previous
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        font.pixelSize: 14
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            previousClicked()
                            // Stop current playback
                            audioManager.stopAll()
                        }
                    }
                }
                
                // Play/Pause
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: "#7C3AED"
                    
                    Text {
                        anchors.centerIn: parent
                        text: isPlaying ? "⏸" : "▶"
                        font.pixelSize: 16
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playPauseClicked()
                            audioPlayerView.togglePlayPause()
                        }
                    }
                }
                
                // Next
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        font.pixelSize: 14
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            nextClicked()
                            // Stop current playback
                            audioManager.stopAll()
                        }
                    }
                }
                
                // Mute
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: audioManager.volume > 0 ? "🔊" : "🔇"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            audioPlayerView.toggleMute()
                        }
                    }
                }
            }
            
            // Title info
            RowLayout {
                spacing: 8
                
                Text {
                    text: title
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: "white"
                }
                
                Text {
                    text: subtitle
                    font.pixelSize: 11
                    color: "#6B7280"
                }
            }
        }
    }
    
    function formatTime(time) {
        var mins = Math.floor(time)
        var secs = Math.round((time - mins) * 100)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}
