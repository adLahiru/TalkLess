// TrimWaveform.qml - Waveform visualization with trim handles and playhead
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Item {
    id: root

    // Properties
    property real currentTime: 0         // Current position in seconds
    property real totalDuration: 0       // Total duration in seconds
    property real trimStart: 0.0         // Trim start position (0-1)
    property real trimEnd: 1.0           // Trim end position (0-1)

    // Waveform data (mock data - array of amplitudes 0-1)
    property var waveformData: root.generateMockWaveform()

    // Signals
    signal trimStartMoved(real position)
    signal trimEndMoved(real position)
    signal seekRequested(real position)

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
        if (seconds < 0)
            seconds = 0;
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // Start time label
        ColumnLayout {
            spacing: 2
            Layout.preferredWidth: 45

            Text {
                text: root.formatTime(root.currentTime)
                color: Colors.textPrimary
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: "Arial"
                Layout.alignment: Qt.AlignRight
            }
            Text {
                text: root.formatTime(root.trimStart * root.totalDuration)
                color: Colors.accent
                font.pixelSize: 10
                font.family: "Arial"
                Layout.alignment: Qt.AlignRight
            }
        }

        // Waveform area
        Rectangle {
            id: waveformView
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.surface
            radius: 8
            clip: true

            // Click to seek
            MouseArea {
                anchors.fill: parent
                onClicked: function (mouse) {
                    var pos = mouse.x / width;
                    root.seekRequested(pos);
                }
            }

            // Trim region background
            Rectangle {
                x: parent.width * root.trimStart
                width: parent.width * (root.trimEnd - root.trimStart)
                height: parent.height
                color: Qt.darker(Colors.accent, 1.5) // Dark blue
                opacity: 0.3
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
                        property real playProgress: root.totalDuration > 0 ? root.currentTime / root.totalDuration : 0
                        property bool isPlayed: normalizedPosition < playProgress
                        property bool isInTrimRegion: normalizedPosition >= root.trimStart && normalizedPosition <= root.trimEnd

                        width: 2
                        height: amplitude * (parent.height - 8)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 1
                        color: {
                            if (isPlayed)
                                return Colors.textPrimary;
                            if (isInTrimRegion)
                                return Colors.accent;
                            return Colors.textSecondary;
                        }
                    }
                }
            }

            // Playhead indicator
            Rectangle {
                id: playhead
                x: parent.width * (root.totalDuration > 0 ? root.currentTime / root.totalDuration : 0) - 1
                width: 2
                height: parent.height
                color: Colors.textPrimary
                visible: root.totalDuration > 0
                z: 5
            }

            // Left trim handle (blue vertical line)
            Rectangle {
                id: leftHandle
                x: parent.width * root.trimStart - 2
                width: 4
                height: parent.height
                color: Colors.accent
                radius: 2
                z: 10

                // Top handle knob
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: 8
                    height: 8
                    radius: 4
                    color: Colors.accent
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.SizeHorCursor
                    drag.target: leftHandle
                    drag.axis: Drag.XAxis
                    drag.minimumX: -2
                    drag.maximumX: Math.max(-2, rightHandle.x - 10)

                    onPositionChanged: {
                        if (drag.active) {
                            var pos = (leftHandle.x + 2) / waveformView.width;
                            root.trimStartMoved(Math.max(0, Math.min(pos, root.trimEnd - 0.01)));
                        }
                    }
                }
            }

            // Right trim handle (blue vertical line)
            Rectangle {
                id: rightHandle
                x: parent.width * root.trimEnd - 2
                width: 4
                height: parent.height
                color: Colors.accent
                radius: 2
                z: 10

                // Bottom handle knob
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 8
                    width: 8
                    height: 8
                    radius: 4
                    color: Colors.accent
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.SizeHorCursor
                    drag.target: rightHandle
                    drag.axis: Drag.XAxis
                    drag.minimumX: leftHandle.x + 10
                    drag.maximumX: waveformView.width - 2

                    onPositionChanged: {
                        if (drag.active) {
                            var pos = (rightHandle.x + 2) / waveformView.width;
                            root.trimEndMoved(Math.min(1.0, Math.max(pos, root.trimStart + 0.01)));
                        }
                    }
                }
            }
        }

        // End time label
        ColumnLayout {
            spacing: 2
            Layout.preferredWidth: 45

            Text {
                text: root.formatTime(root.totalDuration)
                color: Colors.textSecondary
                font.pixelSize: 11
                font.family: "Arial"
                Layout.alignment: Qt.AlignLeft
            }
            Text {
                text: root.formatTime(root.trimEnd * root.totalDuration)
                color: Colors.accent
                font.pixelSize: 10
                font.family: "Arial"
                Layout.alignment: Qt.AlignLeft
            }
        }
    }
}
