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
    property int boardId: -1
    property var appliedEffects: []  // List of applied effects/normalization

    // State
    property bool expanded: false
    property bool isSelected: false
    property bool isPlaying: false

    // Dimensions
    implicitWidth: parent ? parent.width : 400
    implicitHeight: expanded ? (appliedEffects.length > 0 ? 270 : 220) : 56  // Extra height for effect tags

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Signals
    signal loopClicked
    signal shuffleClicked
    signal settingsClicked
    signal testVolumeMatchClicked
    signal rmsVolumeAdjusted(double value)
    signal micVolumeAdjusted(double value)
    signal muteMicToggled(bool muted)
    signal expansionRequested(int clipId, bool isExpanded)  // For accordion behavior
    signal selectionToggled(int clipId, bool selected)  // For multi-select
    signal playClicked(int clipId)  // For playing audio
    signal stopClicked(int clipId)  // For stopping audio

    Rectangle {
        id: card
        anchors.fill: parent
        color: root.isSelected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1) : Colors.cardBg
        radius: 12
        border.width: root.isSelected ? 2 : 1
        border.color: root.isSelected ? Colors.accent : Colors.border

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on border.width {
            NumberAnimation {
                duration: 150
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        // Collapsed header row (always visible)
        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            height: 36
            spacing: 12

            // Audio icon (Image) - FIRST
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 8
                color: Colors.surfaceLight

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: root.iconSource || ""
                    fillMode: Image.PreserveAspectFit
                    visible: root.iconSource && root.iconSource.length > 0
                }

                // Fallback emoji if no icon
                Text {
                    anchors.centerIn: parent
                    text: "🎵"
                    font.pixelSize: 18
                    visible: !root.iconSource || root.iconSource.length === 0
                }
            }

            // Title - SECOND
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 100
                text: (root.clipTitle && root.clipTitle.length > 0) ? root.clipTitle : "Untitled"
                color: Colors.textPrimary
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Hotkey badge - THIRD (after name, read-only look)
            Rectangle {
                Layout.preferredWidth: hotkeyText.implicitWidth + 16
                Layout.preferredHeight: 24
                Layout.minimumWidth: 32
                radius: 6
                color: Colors.surfaceDark
                border.width: 1
                border.color: Colors.border
                visible: root.hotkeyLabel && root.hotkeyLabel.length > 0

                Text {
                    id: hotkeyText
                    anchors.centerIn: parent
                    text: root.hotkeyLabel
                    color: Colors.textSecondary
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                // Tooltip-style indicator that it's read-only
                ToolTip {
                    id: hotkeyTooltip
                    text: "Hotkey (edit in Soundboard)"
                    delay: 500
                    visible: hotkeyMa.containsMouse
                }

                MouseArea {
                    id: hotkeyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor // Not editable
                }
            }

            // Action buttons
            RowLayout {
                spacing: 8

                // Play/Stop button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 28
                    radius: 6
                    color: root.isPlaying ? Colors.accent : (playMa.containsMouse ? Colors.surfaceLight : "transparent")
                    border.width: 1
                    border.color: root.isPlaying ? Colors.accent : Colors.border

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏹" : "▶"
                        color: root.isPlaying ? Colors.textOnAccent : Colors.textPrimary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: playMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isPlaying) {
                                root.stopClicked(root.clipId);
                            } else {
                                root.playClicked(root.clipId);
                            }
                        }
                    }
                }

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

        // Click to expand/collapse OR select (Ctrl+Click)
        MouseArea {
            anchors.fill: headerRow
            onClicked: function (mouse) {
                if (mouse.modifiers & Qt.ControlModifier) {
                    // Ctrl+Click toggles selection
                    root.selectionToggled(root.clipId, !root.isSelected);
                } else {
                    // Normal click expands/collapses
                    root.expanded = !root.expanded;
                }
            }
            z: -1
        }

        // Selection checkbox (visible when any clip is selected)
        Rectangle {
            id: selectionCheckbox
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: -4
            anchors.topMargin: -4
            width: 20
            height: 20
            radius: 10
            color: root.isSelected ? Colors.accent : Colors.surfaceDark
            border.width: 1
            border.color: root.isSelected ? Colors.accent : Colors.border
            visible: root.isSelected || selectionCheckboxMa.containsMouse
            z: 10

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: Colors.textOnAccent
                font.pixelSize: 12
                font.weight: Font.Bold
                visible: root.isSelected
            }

            MouseArea {
                id: selectionCheckboxMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectionToggled(root.clipId, !root.isSelected)
            }
        }

        // Expanded content
        Item {
            id: expandedContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: root.appliedEffects.length > 0 ? 200 : 150  // Extra height for effect tags
            visible: root.expanded
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // Applied Effects Tags
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.appliedEffects && root.appliedEffects.length > 0

                    Repeater {
                        model: root.appliedEffects || []

                        Rectangle {
                            id: effectTagDelegate
                            required property string modelData

                            width: effectTagText.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: {
                                var effectName = effectTagDelegate.modelData.toLowerCase();
                                if (effectName.indexOf("normalized") !== -1)
                                    return "#059669";  // Green for normalization
                                if (effectName.indexOf("bass") !== -1)
                                    return "#DC2626";  // Red for bass
                                if (effectName.indexOf("treble") !== -1)
                                    return "#2563EB";  // Blue for treble
                                if (effectName.indexOf("voice") !== -1)
                                    return "#7C3AED";  // Purple for voice
                                if (effectName.indexOf("warm") !== -1)
                                    return "#EA580C";  // Orange for warmth
                                if (effectName.indexOf("low cut") !== -1)
                                    return "#0891B2";  // Cyan for low cut
                                if (effectName.indexOf("high cut") !== -1)
                                    return "#DB2777";  // Pink for high cut
                                return Colors.accent;  // Default
                            }

                            Text {
                                id: effectTagText
                                anchors.centerIn: parent
                                text: effectTagDelegate.modelData
                                color: "white"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // RMS Volume slider row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "RMS Volume"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                        Layout.preferredWidth: 80
                    }

                    // Red-to-gray gradient slider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        Layout.minimumWidth: 200
                        radius: 6
                        color: Colors.surfaceDark // Fallback background

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "#EF4444"
                            }
                            GradientStop {
                                position: 0.7
                                color: "#F87171"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#4B5563"
                            }
                        }

                        // Thumb
                        Rectangle {
                            id: rmsThumb
                            // Map -60..20 to 0..width
                            // Range = 80
                            x: Math.max(0, Math.min(parent.width - width, (root.rmsVolume + 60) / 80 * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 20
                            radius: 10
                            color: Colors.accent // Use theme accent

                            Text {
                                anchors.centerIn: parent
                                text: root.rmsVolume.toFixed(0) + "dB"
                                color: Colors.textOnAccent
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: function (mouse) {
                                if (pressed) {
                                    var fraction = mouse.x / width;
                                    var val = fraction * 80 - 60;
                                    root.rmsVolume = Math.max(-60, Math.min(20, val));
                                    root.rmsVolumeAdjusted(root.rmsVolume);
                                }
                            }
                            onClicked: function (mouse) {
                                var fraction = mouse.x / width;
                                var val = fraction * 80 - 60;
                                root.rmsVolume = Math.max(-60, Math.min(20, val));
                                root.rmsVolumeAdjusted(root.rmsVolume);
                            }
                        }
                    }

                    // Removed spacer to let slider fill more space
                }

                // Mic Volume slider row + Mute Mic toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "Mic Volume"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                        Layout.preferredWidth: 80
                    }

                    // Green-to-gray gradient slider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        Layout.minimumWidth: 200
                        radius: 6
                        color: Colors.surfaceDark

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "#22C55E"
                            }
                            GradientStop {
                                position: 0.5
                                color: "#4ADE80"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#4B5563"
                            }
                        }

                        // Thumb
                        Rectangle {
                            // Map -60..20 to 0..width
                            x: Math.max(0, Math.min(parent.width - width, (root.micVolume + 60) / 80 * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 20
                            radius: 10
                            color: Colors.accent

                            Text {
                                anchors.centerIn: parent
                                text: root.micVolume.toFixed(0) + "dB"
                                color: Colors.textOnAccent
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: function (mouse) {
                                if (pressed) {
                                    var fraction = mouse.x / width;
                                    var val = fraction * 80 - 60;
                                    root.micVolume = Math.max(-60, Math.min(20, val));
                                    root.micVolumeAdjusted(root.micVolume);
                                }
                            }
                            onClicked: function (mouse) {
                                var fraction = mouse.x / width;
                                var val = fraction * 80 - 60;
                                root.micVolume = Math.max(-60, Math.min(20, val));
                                root.micVolumeAdjusted(root.micVolume);
                            }
                        }
                    }

                    // Mute Mic label and toggle
                    RowLayout {
                        spacing: 8

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
                            color: root.muteMic ? Colors.error : Colors.surfaceDark // Red when muted

                            Rectangle {
                                x: root.muteMic ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: 10
                                color: "white"

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.muteMic = !root.muteMic;
                                    root.muteMicToggled(root.muteMic);
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    } // Spacer
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
