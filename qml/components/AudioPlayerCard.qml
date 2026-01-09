// AudioPlayerCard.qml - Custom audio player card with SVG background
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    
    // Dimensions scaled to 85% of original SVG size (268x149 -> 228x127)
    implicitWidth: 228
    implicitHeight: 140  // Extra height for play button extending above
    
    // Properties
    property string songName: "Greetings"
    property string hotkeyText: "Press F1 to play"
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/sondboard.jpg"
    property bool isPlaying: false
    property bool isMuted: false
    
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
        
        // SVG Background shape - positioned at bottom to leave room for play button
        Image {
            id: backgroundSvg
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 268 * root.scaleFactor  // 228
            height: 141 * root.scaleFactor  // ~120
            source: "qrc:/qt/qml/TalkLess/resources/images/Subtract.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        
        // Play button - smaller, positioned in the center notch
        Rectangle {
            id: playButton
            width: 48
            height: 48
            radius: 24
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
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
                    if (root.isPlaying) {
                        root.isPlaying = false
                        root.pauseClicked()
                    } else {
                        root.isPlaying = true
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
