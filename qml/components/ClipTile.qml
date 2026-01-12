pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import "../styles"

Item {
    id: root

    // Base dimensions matching SoundboardView calculation
    readonly property real baseWidth: 180
    readonly property real baseHeight: baseWidth * 79 / 111
    readonly property real scaleFactor: width / baseWidth

    width: baseWidth
    height: baseHeight

    // data
    property string title: ""
    property url imageSource: "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png"
    property string hotkeyText: "Alt+F2+Shift"
    property bool selected: false
    property bool showActions: false
    property bool isPlaying: false
    property int clipId: -1  // The clip ID for fetching progress
    property real playbackProgress: 0.0  // 0.0 to 1.0 for progress display
    property string filePath: ""  // File path for cross-soundboard operations
    property int currentBoardId: -1  // Current board ID to identify source board

    // hover state
    property bool tileHover: false
    property bool actionHover: false

    // hover scale amount (change to 1.05 / 1.10 as you like)
    readonly property real hoverScale: 1.06

    // actions
    signal playClicked
    signal stopClicked
    signal sendToClicked
    signal pasteClicked
    signal clicked
    signal editBackgroundClicked
    signal hotkeyClicked
    signal deleteClicked
    signal editClicked
    signal webClicked

    // =========================
    // Auto close timer
    // =========================
    Timer {
        id: autoCloseTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!popupHover.hovered) {
                root.showActions = false;
            }
        }
    }

    // =========================
    // Hover delay timer (0.3s before showing action bar)
    // =========================
    Timer {
        id: hoverDelayTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.tileHover) {
                root.openActionsAboveTile();
            }
        }
    }

    // =========================
    // Position popup above tile
    // =========================
    function openActionsAboveTile() {
        // Prevent repositioning while already visible (avoids following mouse)
        if (root.showActions)
            return;
        actionPopup.parent = Overlay.overlay;

        // Ensure popup has size before positioning
        actionPopup.width = actionBarWidth;
        actionPopup.height = actionBarHeight;

        var overlay = actionPopup.parent;

        // tile top-left in overlay coords
        var tilePos = root.mapToItem(overlay, 0, 0);

        // center above tile
        var x = tilePos.x + (root.width - actionPopup.width) / 2;
        var yAbove = tilePos.y - actionPopup.height - popupMargin;
        var yInside = tilePos.y + popupMargin;

        // clamp X inside overlay
        var minX = 8;
        var maxX = overlay.width - actionPopup.width - 8;
        x = Math.max(minX, Math.min(x, maxX));

        // choose Y: above if possible, otherwise inside top
        var y = (yAbove >= 8) ? yAbove : yInside;

        // clamp Y too
        var minY = 8;
        var maxY = overlay.height - actionPopup.height - 8;
        y = Math.max(minY, Math.min(y, maxY));

        // set position ONCE (no bindings)
        actionPopup.x = x;
        actionPopup.y = y;

        root.showActions = true;
        autoCloseTimer.restart();
    }

    // Action bar sizing
    readonly property int actionBarHeight: 40
    readonly property int actionBarWidth: 150
    readonly property int popupMargin: 8

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16 * root.scaleFactor
        color: Colors.cardBg
        border.width: Math.max(1, 2 * root.scaleFactor)
        border.color: Colors.border
        clip: true

        // -------------------------
        // Hover animation (scale)
        // -------------------------
        transformOrigin: Item.Center
        scale: root.tileHover ? root.hoverScale : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        // Optional: subtle shadow-like effect using border color/opacity tweak
        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }
        border.color: root.tileHover ? Colors.accent : Colors.border

        // Background image with rounded corners
        Item {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: 2 * root.scaleFactor

            Image {
                id: backgroundImage
                anchors.fill: parent
                source: root.imageSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false
            }

            Rectangle {
                id: imageMask
                anchors.fill: parent
                radius: 14 * root.scaleFactor
                visible: false
            }

            MultiEffect {
                anchors.fill: backgroundImage
                source: backgroundImage
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: imageMask
                    live: false
                }
                visible: backgroundImage.status === Image.Ready
            }
        }

        // =========================
        // PLAYBACK PROGRESS OVERLAY
        // =========================
        // This overlay fills from left to right based on playback progress
        // Uses clip with rounded corners so the progress bar edges match the tile
        Item {
            id: progressOverlayContainer
            anchors.fill: parent
            anchors.margins: 2 * root.scaleFactor
            visible: root.isPlaying && root.playbackProgress > 0.001
            z: 5  // Above background, below UI elements
            clip: true

            // Rounded clip mask - applied to the entire container
            layer.enabled: visible && width > 0 && height > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: Math.max(1, progressOverlayContainer.width)
                        height: Math.max(1, progressOverlayContainer.height)
                        // Ensure radius doesn't exceed half dimensions
                        radius: Math.min(14 * root.scaleFactor, width / 2, height / 2)
                    }
                    live: true
                }
            }

            // Progress fill - simple rectangle that gets clipped by container
            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // Ensure minimum width of 1 to prevent invalid geometry, clamp progress
                readonly property real safeProgress: Math.max(0, Math.min(1, root.playbackProgress))
                width: Math.max(1, parent.width * safeProgress)
                // Ensure radius doesn't exceed half the width to prevent scene graph crashes
                radius: Math.min(14 * root.scaleFactor, width / 2, height / 2)
                clip: true
                // Only show when there's meaningful progress to display
                visible: root.isPlaying && safeProgress > 0.001

                // Gradient effect for the progress overlay
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45)
                    }
                    GradientStop {
                        position: 0.85
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                    }
                }

                // Smooth width animation
                Behavior on width {
                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.Linear
                    }
                }

                // Leading edge glow effect - now inside the fill to respect rounded corners
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    color: Colors.accent
                    opacity: 0.8

                    // Glow animation
                    SequentialAnimation on opacity {
                        running: root.isPlaying
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.8
                            to: 1.0
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            from: 1.0
                            to: 0.8
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        // Left overlay tint
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.5
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: -16 * root.scaleFactor
                radius: 16 * root.scaleFactor
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.22)
                opacity: 0.2
            }
        }

        // Tag pill
        Item {
            id: tagPill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 10 * root.scaleFactor
            height: 28 * root.scaleFactor
            width: Math.min(tagText.implicitWidth + 20 * root.scaleFactor, parent.width * 0.6)
            visible: root.title !== ""
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -16 * root.scaleFactor
                radius: 14 * root.scaleFactor
                color: Colors.accent
            }

            Text {
                id: tagText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 4 * root.scaleFactor
                width: parent.width - 16 * root.scaleFactor
                text: root.title
                color: Colors.textOnPrimary
                font.pixelSize: Math.max(10, 14 * root.scaleFactor)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Hotkey bar bg
        Rectangle {
            id: hotkeyBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8 * root.scaleFactor
            anchors.rightMargin: 8 * root.scaleFactor
            anchors.bottomMargin: 6 * root.scaleFactor
            height: 28 * root.scaleFactor
            radius: 10 * root.scaleFactor
            color: Colors.panelBg
            opacity: 0.7
        }

        // Hotkey bar content
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8 * root.scaleFactor
            anchors.rightMargin: 8 * root.scaleFactor
            anchors.bottomMargin: 6 * root.scaleFactor
            height: 28 * root.scaleFactor
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8 * root.scaleFactor
                anchors.rightMargin: 8 * root.scaleFactor
                spacing: 6 * root.scaleFactor

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20 * root.scaleFactor
                    color: root.hotkeyText !== "" ? "rgba(0, 0, 0, 0.4)" : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                    radius: 4 * root.scaleFactor
                    border.color: root.hotkeyText !== "" ? "transparent" : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.3)
                    border.width: root.hotkeyText !== "" ? 0 : 1

                    Text {
                        anchors.fill: parent
                        text: root.hotkeyText !== "" ? root.hotkeyText : "Assign"
                        color: root.hotkeyText !== "" ? "#FFFFFF" : Colors.accent
                        font.pixelSize: Math.max(8, 12 * root.scaleFactor)
                        font.weight: root.hotkeyText !== "" ? Font.Medium : Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                root.hotkeyClicked();
                                mouse.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        // =========================
        // ACTION POPUP (Top of tile)
        // =========================
        Popup {
            id: actionPopup
            parent: Overlay.overlay
            modal: false
            focus: false
            padding: 0
            closePolicy: Popup.NoAutoClose
            visible: root.showActions
            z: 999

            background: Rectangle {
                radius: 20
                color: Qt.rgba(Colors.panelBg.r, Colors.panelBg.g, Colors.panelBg.b, 0.9)
                border.color: Colors.accent
                border.width: 1
            }

            contentItem: Item {
                width: actionBarWidth
                height: actionBarHeight

                HoverHandler {
                    id: popupHover
                    onHoveredChanged: {
                        root.actionHover = hovered;
                        if (hovered)
                            autoCloseTimer.stop();
                        else
                            autoCloseTimer.start();
                    }
                }

                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        root.actionHover = true;
                        autoCloseTimer.stop();
                    }
                    onExited: {
                        root.actionHover = false;
                        autoCloseTimer.start();
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2 * root.scaleFactor

                    // Play/Stop
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: playMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "⏹️" : "▶️"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: playMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                // Prevent flicker when moving between buttons
                                autoCloseTimer.stop();
                            }
                            onClicked: {
                                root.playClicked();
                                root.showActions = false;
                            }
                        }
                    }

                    // Send to other soundboard (arrow icon)
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: sendToMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "➡️"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: sendToMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                // Prevent flicker when moving between buttons
                                autoCloseTimer.restart();
                                autoCloseTimer.stop();
                            }
                            onClicked: {
                                root.sendToClicked();
                                soundboardSelectionPopup.open();
                            }
                        }
                    }

                    // // Edit bg
                    // Rectangle {
                    //     width: 30
                    //     height: 30
                    //     radius: 15
                    //     color: bgMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                    //     Text { anchors.centerIn: parent; text: "🖼️"; font.pixelSize: 14 }
                    //     MouseArea { id: bgMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    //         onClicked: { root.editBackgroundClicked(); root.showActions = false } }
                    // }

                    // Web
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: webMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "🌐"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: webMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                autoCloseTimer.restart();
                                autoCloseTimer.stop();
                            }
                            onClicked: {
                                root.webClicked();
                                root.showActions = false;
                            }
                        }
                    }

                    // // Edit
                    // Rectangle {
                    //     width: 30
                    //     height: 30
                    //     radius: 15
                    //     color: editMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                    //     Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 14 }
                    //     MouseArea { id: editMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    //         onClicked: { root.editClicked(); root.showActions = false } }
                    // }

                    // Delete
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: delMA.containsMouse ? Colors.surfaceHighlight : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "🗑️"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: delMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                autoCloseTimer.restart();
                                autoCloseTimer.stop();
                            }
                            onClicked: {
                                root.deleteClicked();
                                root.showActions = false;
                            }
                        }
                    }
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    root.actionHover = false;
                    autoCloseTimer.stop();
                }
            }
        }

        // =========================
        // Main mouse handling
        // =========================
        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                root.tileHover = true;
                // Start the hover delay timer - action bar shows after 0.5s
                hoverDelayTimer.restart();
            }
            onExited: {
                root.tileHover = false;
                // Cancel the hover delay if mouse left before 0.5s
                hoverDelayTimer.stop();
                // Don't close immediately - let autoCloseTimer handle it
                if (!root.actionHover) {
                    autoCloseTimer.restart();
                }
            }

            onPositionChanged: {
                // Reset the hover delay timer when mouse moves
                if (root.tileHover && !root.showActions) {
                    hoverDelayTimer.restart();
                }
            }

            onClicked: function (mouse) {
                root.clicked();
                root.playClicked();
                root.showActions = false;
            }
        }
    }

    // =========================
    // Soundboard Selection Popup
    // =========================
    Popup {
        id: soundboardSelectionPopup

        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        x: Math.round((parent ? parent.width : 800) / 2 - width / 2)
        y: Math.round((parent ? parent.height : 600) / 2 - height / 2)
        width: 280
        height: Math.min(400, boardsListView.contentHeight + 80)

        padding: 0

        background: Rectangle {
            color: Colors.panelBg
            radius: 12
            border.width: 1
            border.color: Colors.border

            // Shadow effect
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#40000000"
                shadowBlur: 20
                shadowVerticalOffset: 8
            }
        }

        property var boardsList: []

        onOpened: {
            // Fetch boards with clip status when popup opens
            if (root.clipId >= 0) {
                boardsList = soundboardService.getBoardsWithClipStatus(root.clipId);
            }
        }

        contentItem: Column {
            spacing: 0

            // Header
            Rectangle {
                width: parent.width
                height: 48
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "Copy to Soundboard"
                    font.pixelSize: 14
                    font.bold: true
                    color: Colors.textPrimary
                }

                // Close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    width: 32
                    height: 32
                    radius: 16
                    color: closePopupMA.containsMouse ? Colors.surfaceLight : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 16
                        color: Colors.textSecondary
                    }

                    MouseArea {
                        id: closePopupMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: soundboardSelectionPopup.close()
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Colors.border
            }

            // Soundboards list
            ListView {
                id: boardsListView
                width: parent.width
                height: Math.min(300, contentHeight)
                clip: true

                model: soundboardSelectionPopup.boardsList

                delegate: Item {
                    width: boardsListView.width
                    height: 44

                    required property var modelData
                    required property int index

                    property bool isCurrentBoard: modelData.id === root.currentBoardId

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        radius: 8
                        color: boardRowMA.containsMouse ? Colors.surfaceLight : "transparent"
                        opacity: isCurrentBoard ? 0.5 : 1.0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Checkbox
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: modelData.hasClip ? Colors.accent : "transparent"
                                border.width: modelData.hasClip ? 0 : 2
                                border.color: Colors.textSecondary

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Colors.textOnPrimary
                                    visible: modelData.hasClip
                                }
                            }

                            // Board name
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name + (isCurrentBoard ? " (Current)" : "")
                                font.pixelSize: 13
                                color: isCurrentBoard ? Colors.textSecondary : Colors.textPrimary
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: boardRowMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: isCurrentBoard ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !isCurrentBoard

                            onClicked: {
                                if (modelData.hasClip) {
                                    // Remove clip from board
                                    soundboardService.removeClipByFilePath(modelData.id, root.filePath);
                                } else {
                                    // Copy clip to board
                                    soundboardService.copyClipToBoard(root.clipId, modelData.id);
                                }
                                // Refresh the list
                                soundboardSelectionPopup.boardsList = soundboardService.getBoardsWithClipStatus(root.clipId);
                            }
                        }
                    }
                }
            }

            // Bottom padding
            Item {
                width: parent.width
                height: 12
            }
        }
    }
}
