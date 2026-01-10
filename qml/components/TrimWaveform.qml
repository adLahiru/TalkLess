// TrimWaveform.qml - Waveform visualization with trim handles only (no playback controls)
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // Properties
    property real currentTime: 90        // Current position in seconds
    property real totalDuration: 210     // Total duration in seconds
    property real trimStart: 0.15        // Trim start position (0-1)
    property real trimEnd: 0.85          // Trim end position (0-1)

    // Waveform data (mock data - array of amplitudes 0-1)
    property var waveformData: root.generateMockWaveform()

    // Signals
    signal trimStartMoved(real position)
    signal trimEndMoved(real position)

    // Generate mock waveform data
    function generateMockWaveform() {
        var data = [];
        for (var i = 0; i < 60; i++) {
            var amplitude = 0.2 + Math.random() * 0.6;
            if (i > 20 && i < 40)
                amplitude *= 1.3;
            data.push(Math.min(1.0, amplitude));
        }
        return data;
    }

    // Format time as M:SS
    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // Waveform container with time labels
    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Start time label (Current or Trim Start)
        ColumnLayout {
            spacing: 2
            Layout.preferredWidth: 40

            Text {
                text: root.formatTime(root.currentTime)
                color: "#FFFFFF"
                font.pixelSize: 11
                font.family: "Arial"
                Layout.alignment: Qt.AlignRight
            }
            Text {
                text: root.formatTime(root.trimStart * root.totalDuration)
                color: "#3B82F6"
                font.pixelSize: 9
                font.family: "Arial"
                Layout.alignment: Qt.AlignRight
            }
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
                color: "#1A3A5C"
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
                id: leftHandle
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
                    drag.maximumX: rightHandle.x - 10

                    onPositionChanged: {
                        if (drag.active) {
                            root.trimStart = Math.max(0, (leftHandle.x + 2) / parent.parent.width);
                            root.trimStartMoved(root.trimStart);
                        }
                    }
                }
            }

            // Right trim handle (blue vertical line)
            Rectangle {
                id: rightHandle
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
                    drag.minimumX: leftHandle.x + 10
                    drag.maximumX: parent.parent.width - 3

                    onPositionChanged: {
                        if (drag.active) {
                            root.trimEnd = Math.min(1, (rightHandle.x + 1) / parent.parent.width);
                            root.trimEndMoved(root.trimEnd);
                        }
                    }
                }
            }
        }

        // End time label (Total or Trim End)
        ColumnLayout {
            spacing: 2
            Layout.preferredWidth: 40

            Text {
                text: root.formatTime(root.totalDuration)
                color: "#888888"
                font.pixelSize: 11
                font.family: "Arial"
                Layout.alignment: Qt.AlignLeft
            }
            Text {
                text: root.formatTime(root.trimEnd * root.totalDuration)
                color: "#3B82F6"
                font.pixelSize: 9
                font.family: "Arial"
                Layout.alignment: Qt.AlignLeft
            }
        }
    }
}
