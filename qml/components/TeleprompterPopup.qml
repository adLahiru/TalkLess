// TeleprompterPopup.qml - Popup for clip-specific teleprompter text
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import "../styles"

Popup {
    id: root

    // Clip data
    property int clipId: -1
    property string clipTitle: ""
    property string teleprompterText: ""

    // Signals
    signal saved(int clipId, string text)
    signal cancelled

    parent: Overlay.overlay
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: Math.round((parent ? parent.width : 800) / 2 - width / 2)
    y: Math.round((parent ? parent.height : 600) / 2 - height / 2)
    width: 520
    height: 480

    padding: 0

    background: Rectangle {
        color: Colors.panelBg
        radius: 16
        border.width: 1
        border.color: Colors.border

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#60000000"
            shadowBlur: 30
            shadowVerticalOffset: 10
        }
    }

    onOpened: {
        teleprompterTextEdit.text = root.teleprompterText;
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: 24
            Layout.rightMargin: 16

            Text {
                text: "Teleprompter"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: Colors.textOnPrimary
            }

            Item { Layout.fillWidth: true }

            // Close button
            Rectangle {
                width: 40
                height: 40
                radius: 8
                color: closeMA.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                border.color: Colors.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 18
                    color: Colors.textSecondary
                }

                MouseArea {
                    id: closeMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cancelled();
                        root.close();
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            color: Colors.border
        }

        // Main content area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 16

            // Action buttons row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Upload Script button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: Colors.surfaceDark
                    radius: 8
                    border.color: Colors.border
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Image {
                            id: uploadScriptIcon
                            width: 20
                            height: 20
                            source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_upload.svg"
                            sourceSize: Qt.size(20, 20)
                            visible: false
                        }

                        MultiEffect {
                            width: 20
                            height: 20
                            source: uploadScriptIcon
                            colorization: 1.0
                            colorizationColor: Colors.textSecondary
                        }

                        Text {
                            text: "Upload Script"
                            font.pixelSize: 13
                            color: Colors.textPrimary
                        }
                    }

                    MouseArea {
                        id: uploadScriptMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            uploadFileDialog.open();
                        }
                    }
                }

                // Speak to Transcribe button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: Colors.surfaceDark
                    radius: 8
                    border.color: Colors.border
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Image {
                            id: micIcon
                            width: 20
                            height: 20
                            source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_mic_outline.svg"
                            sourceSize: Qt.size(20, 20)
                            visible: false
                        }

                        MultiEffect {
                            width: 20
                            height: 20
                            source: micIcon
                            colorization: 1.0
                            colorizationColor: Colors.textSecondary
                        }

                        Text {
                            text: "Speak to Transcribe"
                            font.pixelSize: 13
                            color: Colors.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("Speak to Transcribe clicked - placeholder");
                        }
                    }
                }
            }

            // Text area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                radius: 8
                border.color: Colors.border
                border.width: 1

                Flickable {
                    id: textFlickable
                    anchors.fill: parent
                    anchors.margins: 16
                    contentWidth: width
                    contentHeight: teleprompterTextEdit.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: teleprompterTextEdit
                        width: textFlickable.width
                        color: Colors.textPrimary
                        font.pixelSize: 13
                        font.family: "Arial"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        selectionColor: Colors.accent

                        Text {
                            anchors.fill: parent
                            text: "Enter your script here..."
                            color: Colors.textDisabled
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.border
        }

        // Footer with buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 12

            Item { Layout.fillWidth: true }

            // Cancel button
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 42
                color: cancelBtnMA.containsMouse ? "#4A4A4A" : "#3A3A3A"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Colors.textOnPrimary
                }

                MouseArea {
                    id: cancelBtnMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cancelled();
                        root.close();
                    }
                }

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Save button (gradient)
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 42
                radius: 8

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: saveBtnMA.containsMouse ? Colors.primaryLight : Colors.primary
                    }
                    GradientStop {
                        position: 1.0
                        color: saveBtnMA.containsMouse ? Colors.secondary : Colors.gradientPrimaryEnd
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Colors.textOnPrimary
                }

                MouseArea {
                    id: saveBtnMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.saved(root.clipId, teleprompterTextEdit.text);
                        root.close();
                    }
                }
            }
        }
    }

    // File dialog for uploading script
    FileDialog {
        id: uploadFileDialog
        title: "Import Script"
        nameFilters: ["Text files (*.txt)", "All files (*)"]
        fileMode: FileDialog.OpenFile

        onAccepted: {
            if (selectedFile) {
                console.log("Import from:", selectedFile.toString());
                // Placeholder - would need backend support to read file
            }
        }
    }
}
