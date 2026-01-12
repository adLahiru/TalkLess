// AudioPlayerCard.qml - Custom audio player card with waveform progress strip
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    
    // Dimensions adjusted for waveform strip above the card
    implicitWidth: 228
    implicitHeight: 175  // Height for waveform strip + gap + player card
    
    // Properties
    property string songName: "Greetings"
    property string hotkeyText: "Press F1 to play"
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg"
    property bool isPlaying: false
    property bool isMuted: false
    
    // Time properties for waveform progress
    property real currentTime: 90   // Current position in seconds (1:30)
    property real totalTime: 210    // Total duration in seconds (3:30)
    
    // Helper function to format time as m:ss
    function formatTime(seconds: real): string {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    // Signals
    signal playClicked()
    signal pauseClicked()
    signal previousClicked()
    signal nextClicked()
    signal muteClicked()
    
    // Scale factor (85% of original)
    readonly property real scaleFactor: 0.85
    
    // Main container
    Item {
        anchors.fill: parent
        
        // Waveform progress strip - positioned at the top
        Rectangle {
            id: waveformStrip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 191  // Narrower strip to reduce gap between timestamps and waveform
            height: 28
            radius: 14  // Pill shape
            color: "#3D3D3D"
            
            // Left timestamp
            Text {
                id: currentTimeText
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatTime(root.currentTime)
                color: "#9CA3AF"
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            
            // Right timestamp
            Text {
                id: totalTimeText
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatTime(root.totalTime)
                color: "#9CA3AF"
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            
            // Waveform visualization (centered)
            Row {
                id: waveformBars
                anchors.centerIn: parent
                spacing: 2
                
                // Generate waveform bars with varying heights
                Repeater {
                    model: 32
                    
                    Rectangle {
                        required property int index
                        width: 2
                        // Create varied heights for waveform effect
                        height: {
                            var heights = [6, 10, 14, 8, 16, 12, 10, 18, 14, 8, 12, 16, 
                                          14, 10, 18, 12, 8, 14, 16, 10, 12, 8, 14, 10,
                                          8, 12, 16, 10, 14, 8, 12, 10]
                            return heights[index] || 10
                        }
                        radius: 1
                        // Live progress: white for played portion, gray for remaining
                        color: {
                            var progress = root.totalTime > 0 ? root.currentTime / root.totalTime : 0
                            var barProgress = (index + 1) / 32
                            return barProgress <= progress ? "#FFFFFF" : "#6B7280"
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
        
        // SVG Background shape - positioned at bottom to leave room for play button and waveform
        Image {
            id: backgroundSvg
            anchors.top: waveformStrip.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 268 * root.scaleFactor  // 228
            height: 141 * root.scaleFactor  // ~120
            source: "qrc:/qt/qml/TalkLess/resources/images/Subtract.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        
        // Play button - positioned in the center notch of the player card
        Rectangle {
            id: playButton
            width: 48
            height: 48
            radius: 24
            anchors.horizontalCenter: backgroundSvg.horizontalCenter
            anchors.top: backgroundSvg.top
            anchors.topMargin: -20  // Overlap into the notch
            color: playButtonArea.containsMouse ? "#4A9AF7" : "#3B82F6"
            
            // Play icon (triangle pointing right)
            Canvas {
                id: playIcon
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: root.isPlaying ? 0 : 2
                width: 16
                height: 18
                visible: !root.isPlaying
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#FFFFFF"
                    ctx.beginPath()
                    ctx.moveTo(2, 0)
                    ctx.lineTo(16, 9)
                    ctx.lineTo(2, 18)
                    ctx.closePath()
                    ctx.fill()
                }
            }
            
            // Pause icon (two vertical bars)
            Row {
                anchors.centerIn: parent
                spacing: 3
                visible: root.isPlaying
                
                Rectangle {
                    width: 4
                    height: 14
                    radius: 1
                    color: "#FFFFFF"
                }
                Rectangle {
                    width: 4
                    height: 14
                    radius: 1
                    color: "#FFFFFF"
                }
            }
            
            MouseArea {
                id: playButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Don't toggle isPlaying locally - let the backend update the state
                    // and propagate it back through the binding
                    if (root.isPlaying) {
                        root.pauseClicked()
                    } else {
                        root.playClicked()
                    }
                }
            }
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
        
        // Previous button - positioned at top left, beside the notch curve
        Rectangle {
            id: prevButton
            anchors.top: backgroundSvg.top
            anchors.topMargin: 8
            anchors.right: playButton.left
            anchors.rightMargin: 12
            width: 28
            height: 28
            color: "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "⏮"
                color: prevButtonArea.containsMouse ? "#FFFFFF" : "#AAAAAA"
                font.pixelSize: 16
            }
            
            MouseArea {
                id: prevButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previousClicked()
            }
        }
        
        // Next button - positioned at top right, beside the notch curve
        Rectangle {
            id: nextButton
            anchors.top: backgroundSvg.top
            anchors.topMargin: 8
            anchors.left: playButton.right
            anchors.leftMargin: 12
            width: 28
            height: 28
            color: "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "⏭"
                color: nextButtonArea.containsMouse ? "#FFFFFF" : "#AAAAAA"
                font.pixelSize: 16
            }
            
            MouseArea {
                id: nextButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextClicked()
            }
        }
        
        // Mute button - far right at the same level as prev/next
        Rectangle {
            id: muteButton
            anchors.top: backgroundSvg.top
            anchors.topMargin: 8
            anchors.right: backgroundSvg.right
            anchors.rightMargin: 15
            width: 28
            height: 28
            color: "transparent"
            
            // Microphone icon
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                
                Text {
                    anchors.centerIn: parent
                    text: "🎤"
                    font.pixelSize: 16
                    opacity: root.isMuted ? 0.4 : 1.0
                    color: muteButtonArea.containsMouse ? "#FFFFFF" : "#888888"
                }
                
                // Diagonal slash when muted
                Rectangle {
                    visible: root.isMuted
                    anchors.centerIn: parent
                    width: 22
                    height: 2
                    color: "#FF5555"
                    rotation: -45
                }
            }
            
            MouseArea {
                id: muteButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.isMuted = !root.isMuted
                    root.muteClicked()
                }
            }
        }
        
        // Audio info section (bottom part of the card)
        Row {
            id: audioInfoRow
            anchors.bottom: backgroundSvg.bottom
            anchors.bottomMargin: 12
            anchors.left: backgroundSvg.left
            anchors.leftMargin: 20
            anchors.right: backgroundSvg.right
            anchors.rightMargin: 15
            height: 60
            spacing: 12
            
            // Thumbnail image with rounded corners using OpacityMask
            Item {
                id: thumbnailContainer
                width: 60
                height: 60
                
                // The actual image (hidden, used as source)
                Image {
                    id: thumbnailImage
                    anchors.fill: parent
                    source: root.imageSource
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: false
                }
                
                // Mask shape
                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: 10
                    visible: false
                }
                
                // Apply the mask using MultiEffect
                MultiEffect {
                    anchors.fill: thumbnailImage
                    source: thumbnailImage
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: maskRect
                        live: false
                    }
                }
            }
            
            // Song info column
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - thumbnailContainer.width - parent.spacing
                
                // Song name
                Text {
                    text: root.songName
                    color: "#FFFFFF"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                }
                
                // Hotkey text
                Text {
                    text: root.hotkeyText
                    color: "#3B82F6"
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }
}
