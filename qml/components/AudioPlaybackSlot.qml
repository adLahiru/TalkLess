// AudioPlaybackSlot.qml
// Expandable audio clip component for Playback Dashboard
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Item {
    id: root

    // Clip data properties
    property int clipId: -1
    property string clipTitle: ""
    property string hotkeyLabel: "F1"
    property string iconSource: ""
    property double rmsVolume: -5.0  // dB value
    property double micVolume: -3.0  // dB value
    property bool muteMic: false

    // State
    property bool expanded: false

    // Dimensions
    implicitWidth: parent ? parent.width : 400
    implicitHeight: expanded ? 180 : 52

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Signals
    signal loopClicked()
    signal shuffleClicked()
    signal settingsClicked()
    signal testVolumeMatchClicked()
    signal rmsVolumeAdjusted(double value)
    signal micVolumeAdjusted(double value)
    signal muteMicToggled(bool muted)

    Rectangle {
        id: card
        anchors.fill: parent
        color: Colors.cardBg
        radius: 12
        border.width: 1
        border.color: Colors.border

        // Collapsed header row (always visible)
        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            height: 32
            spacing: 12

            // F-key badge
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 20
                radius: 4
                color: Colors.surfaceDark

                Text {
                    anchors.centerIn: parent
                    text: root.hotkeyLabel
                    color: Colors.textSecondary
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            // Audio icon
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 8
                color: "#F5F5F5"

                Text {
                    anchors.centerIn: parent
                    text: "🎵"
                    font.pixelSize: 18
                }
            }

            // Title
            Text {
                Layout.fillWidth: true
                text: root.clipTitle || "Untitled"
                color: Colors.textPrimary
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            // Action buttons
            RowLayout {
                spacing: 8

                // Loop button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 6
                    color: loopMa.containsMouse ? Colors.surfaceLight : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: Colors.textSecondary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: loopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.loopClicked()
                    }
                }

                // Shuffle button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 6
                    color: shuffleMa.containsMouse ? Colors.surfaceLight : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "⇌"
                        color: Colors.textSecondary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: shuffleMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shuffleClicked()
                    }
                }

                // Settings gear
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: "#2D1F4E"

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: "#A855F7"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: settingsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.settingsClicked()
                    }
                }
            }
        }

        // Click to expand/collapse
        MouseArea {
            anchors.fill: headerRow
            onClicked: root.expanded = !root.expanded
            z: -1
        }

        // Expanded content
        Item {
            id: expandedContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.topMargin: 16
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 110
            visible: root.expanded
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // RMS Volume slider row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "RMS Volume"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                        Layout.preferredWidth: 80
                    }

                    // Red-to-gray gradient slider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#EF4444" }
                            GradientStop { position: 0.7; color: "#F87171" }
                            GradientStop { position: 1.0; color: "#4B5563" }
                        }

                        // Thumb
                        Rectangle {
                            id: rmsThumb
                            x: Math.max(0, Math.min(parent.width - width, (root.rmsVolume + 20) / 20 * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 20
                            radius: 10
                            color: "#8B5CF6"

                            Text {
                                anchors.centerIn: parent
                                text: root.rmsVolume.toFixed(0) + "dB"
                                color: "white"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var val = (mouse.x / width) * 20 - 20
                                    root.rmsVolume = Math.max(-20, Math.min(0, val))
                                    root.rmsVolumeAdjusted(root.rmsVolume)
                                }
                            }
                            onClicked: function(mouse) {
                                var val = (mouse.x / width) * 20 - 20
                                root.rmsVolume = Math.max(-20, Math.min(0, val))
                                root.rmsVolumeAdjusted(root.rmsVolume)
                            }
                        }
                    }
                }

                // Mic Volume slider row + Mute Mic toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Mic Volume"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                        Layout.preferredWidth: 80
                    }

                    // Green-to-gray gradient slider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 200
                        Layout.preferredHeight: 8
                        radius: 4

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#22C55E" }
                            GradientStop { position: 0.5; color: "#4ADE80" }
                            GradientStop { position: 1.0; color: "#4B5563" }
                        }

                        // Thumb
                        Rectangle {
                            x: Math.max(0, Math.min(parent.width - width, (root.micVolume + 20) / 20 * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 20
                            radius: 10
                            color: "#8B5CF6"

                            Text {
                                anchors.centerIn: parent
                                text: root.micVolume.toFixed(0) + "db"
                                color: "white"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var val = (mouse.x / width) * 20 - 20
                                    root.micVolume = Math.max(-20, Math.min(0, val))
                                    root.micVolumeAdjusted(root.micVolume)
                                }
                            }
                            onClicked: function(mouse) {
                                var val = (mouse.x / width) * 20 - 20
                                root.micVolume = Math.max(-20, Math.min(0, val))
                                root.micVolumeAdjusted(root.micVolume)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Mute Mic label and toggle
                    Text {
                        text: "Mute Mic"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                    }

                    Rectangle {
                        id: muteMicToggle
                        width: 44
                        height: 24
                        radius: 12
                        color: root.muteMic ? "#22C55E" : Colors.surfaceDark

                        Rectangle {
                            x: root.muteMic ? parent.width - width - 2 : 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: "white"

                            Behavior on x {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.muteMic = !root.muteMic
                                root.muteMicToggled(root.muteMic)
                            }
                        }
                    }
                }

                // Test button
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 36
                    radius: 8
                    color: testBtnMa.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                    border.width: 1
                    border.color: Colors.border

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "📊"
                            font.pixelSize: 14
                        }

                        Text {
                            text: "Test Speak Volume Match"
                            color: Colors.textPrimary
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: testBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.testVolumeMatchClicked()
                    }
                }
            }
        }
    }
}
