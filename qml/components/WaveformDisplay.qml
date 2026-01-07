// WaveformDisplay.qml - Waveform visualization with trim functionality
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Properties
    property real currentTime: 90        // Current playback position in seconds (1:30)
    property real totalDuration: 210     // Total duration in seconds (3:30)
    property real trimStart: 0.15        // Trim start position (0-1)
    property real trimEnd: 0.85          // Trim end position (0-1)
    property bool isPlaying: false
    
    // Waveform data (temporary mock data - array of amplitudes 0-1)
    property var waveformData: root.generateMockWaveform()
    
    // Signals
    signal playClicked()
    signal previousClicked()
    signal nextClicked()
    signal repeatClicked()
    signal shuffleClicked()
    signal trimStartMoved(real position)
    signal trimEndMoved(real position)
    
    // Generate mock waveform data
    function generateMockWaveform() {
        var data = []
        for (var i = 0; i < 60; i++) {
            // Create varied wave pattern
            var amplitude = 0.2 + Math.random() * 0.6
            // Add some pattern variation
            if (i > 20 && i < 40) amplitude *= 1.3
            data.push(Math.min(1.0, amplitude))
        }
        return data
    }
    
    // Format time as M:SS
    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        
        // Waveform container with time labels
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 8
            
            // Current time label
            Text {
                text: root.formatTime(root.currentTime)
                color: "#FFFFFF"
                font.pixelSize: 11
                font.family: "Arial"
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
            
            // Waveform area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#2A2A2A"
                radius: 4
                clip: true
                
                // Trim region background
                Rectangle {
                    x: parent.width * root.trimStart
                    width: parent.width * (root.trimEnd - root.trimStart)
                    height: parent.height
                    color: "#1A3A5C"  // Dark blue shade
                }
                
                // Waveform bars
                Row {
                    anchors.centerIn: parent
                    height: parent.height - 16
                    spacing: 2
                    
                    Repeater {
                        model: root.waveformData.length
                        
                        Rectangle {
                            required property int index
                            property real amplitude: root.waveformData[index] || 0.3
                            property real normalizedPosition: index / root.waveformData.length
                            property real playProgress: root.currentTime / root.totalDuration
                            property bool isPlayed: normalizedPosition < playProgress
                            property bool isInTrimRegion: normalizedPosition >= root.trimStart && normalizedPosition <= root.trimEnd
                            
                            width: 2
                            height: amplitude * (parent.height - 8)
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 1
                            color: isPlayed ? "#FFFFFF" : (isInTrimRegion ? "#6B7280" : "#4B5563")
                        }
                    }
                }
                
                // Left trim handle (blue vertical line)
                Rectangle {
                    id: leftTrimHandle
                    x: parent.width * root.trimStart - 2
                    width: 3
                    height: parent.height
                    color: "#3B82F6"
                    radius: 1
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.SizeHorCursor
                        drag.target: parent
                        drag.axis: Drag.XAxis
                        drag.minimumX: 0
                        drag.maximumX: rightTrimHandle.x - 10
                        
                        onPositionChanged: {
                            if (drag.active) {
                                root.trimStart = Math.max(0, (leftTrimHandle.x + 2) / parent.parent.width)
                                root.trimStartMoved(root.trimStart)
                            }
                        }
                    }
                }
                
                // Right trim handle (blue vertical line)
                Rectangle {
                    id: rightTrimHandle
                    x: parent.width * root.trimEnd - 1
                    width: 3
                    height: parent.height
                    color: "#3B82F6"
                    radius: 1
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.SizeHorCursor
                        drag.target: parent
                        drag.axis: Drag.XAxis
                        drag.minimumX: leftTrimHandle.x + 10
                        drag.maximumX: parent.parent.width - 3
                        
                        onPositionChanged: {
                            if (drag.active) {
                                root.trimEnd = Math.min(1, (rightTrimHandle.x + 1) / parent.parent.width)
                                root.trimEndMoved(root.trimEnd)
                            }
                        }
                    }
                }
            }
            
            // Total duration label
            Text {
                text: root.formatTime(root.totalDuration)
                color: "#888888"
                font.pixelSize: 11
                font.family: "Arial"
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignLeft
            }
        }
        
        // Playback controls
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            
            // Repeat button
            Rectangle {
                width: 28
                height: 28
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: "#888888"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.repeatClicked()
                }
            }
            
            // Previous button
            Rectangle {
                width: 28
                height: 28
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "⏮"
                    color: "#888888"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previousClicked()
                }
            }
            
            // Play/Pause button (blue circle)
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: playButtonArea.containsMouse ? "#4A9AF7" : "#3B82F6"
                
                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "⏸" : "▶"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                }
                
                MouseArea {
                    id: playButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isPlaying = !root.isPlaying
                        root.playClicked()
                    }
                }
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            // Next button
            Rectangle {
                width: 28
                height: 28
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "⏭"
                    color: "#888888"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextClicked()
                }
            }
            
            // Shuffle button
            Rectangle {
                width: 28
                height: 28
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "⇌"
                    color: "#888888"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shuffleClicked()
                }
            }
        }
    }
}
