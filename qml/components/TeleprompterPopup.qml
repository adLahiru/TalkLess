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

    // Transcription service connections
    Connections {
        target: transcriptionService

        function onTranscriptDelta(itemId, delta) {
            // Append delta text to the text edit in real-time
            console.log("[QML] Received transcript delta:", delta);
            teleprompterTextEdit.insert(teleprompterTextEdit.length, delta);
        }

        function onTranscriptFinal(itemId, text) {
            // Add a space or newline after final segment
            console.log("[QML] Received transcript final:", text);
            teleprompterTextEdit.insert(teleprompterTextEdit.length, " ");
        }

        function onSttError(message) {
            console.log("[QML] Received STT error:", message);
            errorLabel.text = message;
            errorLabel.visible = true;
            errorTimer.restart();
        }
    }

    // Timer to hide error message
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: errorLabel.visible = false
    }

    onOpened: {
        teleprompterTextEdit.text = root.teleprompterText;
        errorLabel.visible = false;
    }

    onClosed: {
        // Auto-save the current content when dialog is closed
        root.saved(root.clipId, teleprompterTextEdit.text);
        // Stop listening if still active
        if (transcriptionService.isListening) {
            transcriptionService.stopListening();
        }
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
                    Layout.preferredHeight: 44
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
                    id: transcribeButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    color: transcriptionService.isListening ? Colors.accent : Colors.surfaceDark
                    radius: 8
                    border.color: transcriptionService.isListening ? Colors.accent : Colors.border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 200 } }

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
                            colorizationColor: transcriptionService.isListening ? Colors.textOnPrimary : Colors.textSecondary
                        }

                        Text {
                            text: transcriptionService.isListening ? "Stop Listening" : "Speak to Transcribe"
                            font.pixelSize: 13
                            color: transcriptionService.isListening ? Colors.textOnPrimary : Colors.textPrimary
                        }
                    }

                    // Pulsing animation when listening
                    SequentialAnimation on opacity {
                        running: transcriptionService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.7; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (transcriptionService.isListening) {
                                transcriptionService.stopListening();
                            } else if (!transcriptionService.hasApiKey) {
                                // Show API key input dialog
                                apiKeyDialog.open();
                            } else {
                                transcriptionService.startListening();
                            }
                        }
                    }
                }
            }

            // Error message label
            Text {
                id: errorLabel
                Layout.fillWidth: true
                visible: false
                text: ""
                color: "#FF6B6B"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
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

    // API Key input dialog
    Dialog {
        id: apiKeyDialog
        title: "OpenAI API Key Required"
        modal: true
        parent: Overlay.overlay
        x: Math.round((parent ? parent.width : 800) / 2 - width / 2)
        y: Math.round((parent ? parent.height : 600) / 2 - height / 2)
        width: 420
        standardButtons: Dialog.Cancel

        background: Rectangle {
            color: Colors.panelBg
            radius: 12
            border.width: 1
            border.color: Colors.border
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: "Enter your OpenAI API key to enable speech-to-text transcription."
                font.pixelSize: 13
                color: Colors.textSecondary
                wrapMode: Text.Wrap
            }

            TextField {
                id: apiKeyInput
                Layout.fillWidth: true
                placeholderText: "sk-proj-..."
                echoMode: TextInput.Password
                color: Colors.textPrimary
                font.pixelSize: 14

                background: Rectangle {
                    color: Colors.surfaceDark
                    radius: 8
                    border.color: apiKeyInput.focus ? Colors.accent : Colors.border
                    border.width: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Your key is stored locally and never sent anywhere except OpenAI."
                font.pixelSize: 11
                color: Colors.textSecondary
                opacity: 0.7
            }

            Button {
                Layout.alignment: Qt.AlignRight
                text: "Save & Start Listening"
                enabled: apiKeyInput.text.length > 10

                background: Rectangle {
                    color: parent.enabled ? Colors.accent : Colors.surfaceDark
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: parent.enabled ? Colors.textOnPrimary : Colors.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    transcriptionService.setApiToken(apiKeyInput.text);
                    apiKeyInput.text = "";
                    apiKeyDialog.close();
                    transcriptionService.startListening();
                }
            }
        }
    }
}

