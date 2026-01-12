pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects

Item {
    id: root

    // Base dimensions matching SoundboardView calculation
    property real baseWidth: 180
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

    // hover state
    property bool tileHover: false
    property bool actionHover: false

    // actions
    signal playClicked
    signal stopClicked
    signal copyClicked
    signal pasteClicked
    signal clicked
    signal editBackgroundClicked
    signal hotkeyClicked
    signal deleteClicked
    signal editClicked
    signal webClicked

    // =========================
    // Auto close (2 seconds)
    // =========================
    Timer {
        id: autoCloseTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.actionHover) {
                root.showActions = false
            }
        }
    }

    // =========================
    // Position popup above tile
    // =========================
    function openActionsAboveTile() {
        // Prevent repositioning while already visible (avoids following mouse)
        if (root.showActions)
            return

        actionPopup.parent = Overlay.overlay

        // Ensure popup has size before positioning
        actionPopup.width = actionBarWidth
        actionPopup.height = actionBarHeight

        var overlay = actionPopup.parent

        // tile top-left in overlay coords
        var tilePos = root.mapToItem(overlay, 0, 0)

        // center above tile
        var x = tilePos.x + (root.width - actionPopup.width) / 2
        var yAbove = tilePos.y - actionPopup.height - popupMargin
        var yInside = tilePos.y + popupMargin

        // clamp X inside overlay
        var minX = 8
        var maxX = overlay.width - actionPopup.width - 8
        x = Math.max(minX, Math.min(x, maxX))

        // choose Y: above if possible, otherwise inside top
        var y = (yAbove >= 8) ? yAbove : yInside

        // clamp Y too
        var minY = 8
        var maxY = overlay.height - actionPopup.height - 8
        y = Math.max(minY, Math.min(y, maxY))

        // set position ONCE (no bindings)
        actionPopup.x = x
        actionPopup.y = y

        root.showActions = true
        autoCloseTimer.restart()
    }

    // Action bar sizing
    readonly property int actionBarHeight: 40
    readonly property int actionBarWidth: 240
    readonly property int popupMargin: 8

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16 * root.scaleFactor
        color: "#101010"
        border.width: Math.max(1, 2 * root.scaleFactor)
        border.color: "#EDEDED"
        clip: true

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
                maskSource: ShaderEffectSource { sourceItem: imageMask; live: false }
                visible: backgroundImage.status === Image.Ready
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
                color: "#D9D9D938"
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
                color: "#3B82F6"
            }

            Text {
                id: tagText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 4 * root.scaleFactor
                width: parent.width - 16 * root.scaleFactor
                text: root.title
                color: "#FFFFFF"
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
            color: "#000000"
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

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8 * root.scaleFactor
                anchors.rightMargin: 8 * root.scaleFactor
                spacing: 6 * root.scaleFactor

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20 * root.scaleFactor
                    color: root.hotkeyText !== "" ? "rgba(0, 0, 0, 0.4)" : "rgba(60, 123, 255, 0.15)"
                    radius: 4 * root.scaleFactor
                    border.color: root.hotkeyText !== "" ? "transparent" : "rgba(60, 123, 255, 0.3)"
                    border.width: root.hotkeyText !== "" ? 0 : 1

                    Text {
                        anchors.fill: parent
                        text: root.hotkeyText !== "" ? root.hotkeyText : "Assign"
                        color: root.hotkeyText !== "" ? "#FFFFFF" : "#3C7BFF"
                        font.pixelSize: Math.max(8, 12 * root.scaleFactor)
                        font.weight: root.hotkeyText !== "" ? Font.Medium : Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                root.hotkeyClicked()
                                mouse.accepted = true
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
                color: "#E61A1A1A"
                border.color: "#3B82F6"
                border.width: 1
            }

            contentItem: Item {
                width: actionBarWidth
                height: actionBarHeight

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: { root.actionHover = true; autoCloseTimer.stop() }
                    onExited:  {
                        root.actionHover = false;
                        autoCloseTimer.start()
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2 * root.scaleFactor

                    // Play/Stop
                    Rectangle {
                        width: 30 ; height: 30 * root; radius: 15
                        color: playMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: root.isPlaying ? "⏹️" : "▶️"; font.pixelSize: 14  }
                        MouseArea { id: playMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.playClicked(); root.showActions = false } }
                    }

                    // Copy
                    Rectangle {
                        width: 30 ; height: 30 ; radius: 15
                        color: copyMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: "📋"; font.pixelSize: 14 }
                        MouseArea { id: copyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.copyClicked(); root.showActions = false } }
                    }

                    // Edit bg
                    Rectangle {
                        width: 30 ; height: 30 ; radius: 15
                        color: bgMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: "🖼️"; font.pixelSize: Math.max(10, 14 ) }
                        MouseArea { id: bgMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.editBackgroundClicked(); root.showActions = false } }
                    }

                    // Web
                    Rectangle {
                        width: 30 ; height: 30 ; radius: 15
                        color: webMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: "🌐"; font.pixelSize: Math.max(10, 14 ) }
                        MouseArea { id: webMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.webClicked(); root.showActions = false } }
                    }

                    // Edit
                    Rectangle {
                        width: 30 ; height: 30 ; radius: 15
                        color: editMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: Math.max(10, 14 ) }
                        MouseArea { id: editMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.editClicked(); root.showActions = false } }
                    }

                    // Delete
                    Rectangle {
                        width: 30 ; height: 30 ; radius: 15
                        color: delMA.containsMouse ? "#444444" : "transparent"
                        Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: Math.max(10, 14 ) }
                        MouseArea { id: delMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.deleteClicked(); root.showActions = false } }
                    }
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    root.actionHover = false
                    autoCloseTimer.stop()
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: { root.tileHover = true;
                        baseWidth * 1.01
            }
            onExited:  {
                root.tileHover = false
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    // open above clip (top-center)
                    root.openActionsAboveTile()
                    mouse.accepted = true
                } else if (mouse.button === Qt.LeftButton) {
                    root.clicked()
                    root.playClicked()
                    // optional: hide actions on left click
                    root.showActions = false
                }
            }
        }
    }
}
