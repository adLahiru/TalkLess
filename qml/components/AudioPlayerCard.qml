// AudioPlayerCard.qml - Custom audio player card with waveform progress strip
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../styles"

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
    
    // Waveform data - array of normalized peak values (0.1-1.0)
    // When empty, uses placeholder heights for fallback display
    property var waveformData: []
    
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
    signal seekRequested(real positionMs)  // Request seek to position in milliseconds
    
    // Scrubbing state
    property bool isScrubbing: false
    property real scrubPosition: 0  // 0-1 progress during scrub
    
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
            
            // Left timestamp - shows scrub time while dragging, otherwise current time
            Text {
                id: currentTimeText
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.isScrubbing) {
                        // Show scrub position time
                        return root.formatTime(root.scrubPosition * root.totalTime);
                    } else {
                        return root.formatTime(root.currentTime);
                    }
                }
                color: root.isScrubbing ? "#3B82F6" : "#9CA3AF"  // Blue while scrubbing
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
                spacing: 1  // Tighter spacing for smoother look
                
                // Fixed bar count - 42 bars fills the space between timestamps
                readonly property int barCount: 42
                
                // Calculate min/max from actual waveform data for dynamic scaling
                readonly property real dataMin: {
                    if (root.waveformData.length === 0) return 0.1;
                    var min = 1.0;
                    for (var i = 0; i < root.waveformData.length; i++) {
                        var val = root.waveformData[i] || 0.1;
                        if (val < min) min = val;
                    }
                    return min;
                }
                readonly property real dataMax: {
                    if (root.waveformData.length === 0) return 1.0;
                    var max = 0.0;
                    for (var i = 0; i < root.waveformData.length; i++) {
                        var val = root.waveformData[i] || 0.1;
                        if (val > max) max = val;
                    }
                    return Math.max(max, 0.1);  // Avoid division by zero
                }
                
                // Generate waveform bars - always fixed count
                Repeater {
                    model: waveformBars.barCount
                    
                    Rectangle {
                        required property int index
                        width: 2  // Narrow bars for smooth waveform look
                        
                        // Sample waveform data proportionally and scale dynamically
                        height: {
                            var maxHeight = 18;
                            var minHeight = 4;
                            
                            if (root.waveformData.length > 0) {
                                // Map bar index to waveform data index (proportional sampling)
                                var dataIndex = Math.floor(index * root.waveformData.length / waveformBars.barCount);
                                dataIndex = Math.min(dataIndex, root.waveformData.length - 1);
                                
                                var amplitude = root.waveformData[dataIndex] || 0.1;
                                
                                // Normalize amplitude based on song's actual range
                                var range = waveformBars.dataMax - waveformBars.dataMin;
                                var normalized = range > 0.01 
                                    ? (amplitude - waveformBars.dataMin) / range 
                                    : 0.5;
                                
                                // Scale to height range
                                return minHeight + normalized * (maxHeight - minHeight);
                            } else {
                                // Fallback placeholder heights when no data
                                var heights = [6, 10, 14, 8, 16, 12, 10, 18, 14, 8, 12, 16, 
                                              14, 10, 18, 12, 8, 14, 16, 10, 12, 8, 14, 10,
                                              8, 12, 16, 10, 14, 8, 12, 10];
                                return heights[index % heights.length] || 10;
                            }
                        }
                        radius: 1
                        // Live progress: white for played portion, gray for remaining
                        // When scrubbing, show scrub position instead of current time
                        color: {
                            var displayProgress = root.isScrubbing ? root.scrubPosition : 
                                (root.totalTime > 0 ? root.currentTime / root.totalTime : 0);
                            var barProgress = (index + 1) / waveformBars.barCount;
                            return barProgress <= displayProgress ? "#FFFFFF" : "#6B7280";
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            
            // Scrub position indicator line (shown while dragging)
            Rectangle {
                id: scrubIndicator
                visible: root.isScrubbing
                width: 2
                height: parent.height - 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 1
                color: "#3B82F6"  // Blue accent
                x: {
                    // Calculate position within the waveform area
                    var waveformLeft = waveformBars.x;
                    var waveformWidth = waveformBars.width;
                    return waveformLeft + (root.scrubPosition * waveformWidth) - 1;
                }
            }
            
            // MouseArea for scrubbing - covers the entire waveform strip
            MouseArea {
                id: scrubArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                // Calculate seek position from mouse X coordinate
                function calculateSeekPosition(mouseX: real): real {
                    // Get waveform bounds
                    var waveformLeft = waveformBars.x;
                    var waveformWidth = waveformBars.width;
                    var waveformRight = waveformLeft + waveformWidth;
                    
                    // Clamp to waveform area
                    var clampedX = Math.max(waveformLeft, Math.min(waveformRight, mouseX));
                    
                    // Convert to 0-1 progress
                    var progress = (clampedX - waveformLeft) / waveformWidth;
                    return Math.max(0, Math.min(1, progress));
                }
                
                onPressed: function(mouse) {
                    root.isScrubbing = true;
                    root.scrubPosition = calculateSeekPosition(mouse.x);
                }
                
                onPositionChanged: function(mouse) {
                    if (root.isScrubbing) {
                        root.scrubPosition = calculateSeekPosition(mouse.x);
                    }
                }
                
                onReleased: function(mouse) {
                    if (root.isScrubbing) {
                        var position = calculateSeekPosition(mouse.x);
                        var positionMs = position * root.totalTime * 1000;
                        root.seekRequested(positionMs);
                        root.isScrubbing = false;
                    }
                }
                
                onCanceled: {
                    root.isScrubbing = false;
                }
            }
        }
        
        // SVG Background shape - positioned at bottom to leave room for play button and waveform
        Rectangle {
            id: backgroundSvg
            anchors.top: waveformStrip.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 268 * root.scaleFactor  // 228
            height: 141 * root.scaleFactor  // ~120
            color: Colors.surface
            radius: 24
            border.color: Colors.border
            border.width: 1

            // Optional: Add a shadow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colors.shadow
                shadowBlur: 16
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 0
            }
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
                    ctx.fillStyle = Colors.textOnPrimary
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
                    color: Colors.textOnPrimary
                }
                Rectangle {
                    width: 4
                    height: 14
                    radius: 1
                    color: Colors.textOnPrimary
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
            
            Image {
                id: prevIcon
                anchors.centerIn: parent
                width: 14
                height: 14
                source: "qrc:/qt/qml/TalkLess/resources/icons/previous.svg"
                sourceSize: Qt.size(14, 14)
                visible: false
            }
            MultiEffect {
                anchors.fill: prevIcon
                source: prevIcon
                colorization: 1.0
                colorizationColor: prevButtonArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
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
            
            Image {
                id: nextIcon
                anchors.centerIn: parent
                width: 14
                height: 14
                source: "qrc:/qt/qml/TalkLess/resources/icons/next.svg"
                sourceSize: Qt.size(14, 14)
                visible: false
            }
            MultiEffect {
                anchors.fill: nextIcon
                source: nextIcon
                colorization: 1.0
                colorizationColor: nextButtonArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
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
                
                Image {
                    id: micIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: root.isMuted ? "qrc:/qt/qml/TalkLess/resources/icons/microphone_muted.svg" : "qrc:/qt/qml/TalkLess/resources/icons/microphone.svg"
                    sourceSize: Qt.size(16, 16)
                    visible: false
                }
                MultiEffect {
                    anchors.fill: micIcon
                    source: micIcon
                    colorization: 1.0
                    colorizationColor: muteButtonArea.containsMouse ? Colors.textPrimary : Colors.textSecondary
                    opacity: root.isMuted ? 0.6 : 1.0
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
