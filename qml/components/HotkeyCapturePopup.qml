import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A sleek, modern popup for capturing keyboard hotkeys
Popup {
    id: root

    property string title: "Assign Hotkey"
    property string capturedHotkey: ""

    signal hotkeyConfirmed(string hotkeyText)
    signal cancelled

    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    width: 420
    height: 280
    padding: 0
    focus: true  // Popup needs focus

    background: Rectangle {
        color: "#1A1A1A"
        radius: 16
        border.width: 1
        border.color: "#2A2A2A"

        // Subtle glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: 18
            color: "transparent"
            border.width: 2
            border.color: "#3C7BFF"
            opacity: 0.3
            z: -1
        }
    }

    // Dim overlay
    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    // Focus handler
    onOpened: {
        capturedHotkey = "";
        keyCapture.forceActiveFocus();
    }

    // Main content item that captures keys
    contentItem: FocusScope {
        id: keyCapture
        focus: true

        // This is the key handler - must be on a FocusScope or Item with focus
        Keys.onPressed: function (event) {
            console.log("Key pressed:", event.key, "Modifiers:", event.modifiers, "Text:", event.text);

            // Build hotkey string from modifiers + key
            var parts = [];

            if (event.modifiers & Qt.ControlModifier)
                parts.push("Ctrl");
            if (event.modifiers & Qt.AltModifier)
                parts.push("Alt");
            if (event.modifiers & Qt.ShiftModifier)
                parts.push("Shift");
            if (event.modifiers & Qt.MetaModifier)
                parts.push("Meta");

            // Get the key name
            var keyName = "";
            var key = event.key;

            // Handle special keys first
            switch (key) {
            case Qt.Key_Escape:
                // Escape cancels without clearing
                root.cancelled();
                root.close();
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                // Enter confirms the current hotkey
                if (root.capturedHotkey !== "") {
                    root.hotkeyConfirmed(root.capturedHotkey);
                    root.close();
                }
                event.accepted = true;
                return;
            case Qt.Key_Control:
            case Qt.Key_Alt:
            case Qt.Key_Shift:
            case Qt.Key_Meta:
                // Modifiers alone - just show them but don't confirm
                root.capturedHotkey = parts.join("+");
                event.accepted = true;
                return;

            // Named special keys
            case Qt.Key_Space:
                keyName = "Space";
                break;
            case Qt.Key_Tab:
                keyName = "Tab";
                break;
            case Qt.Key_Backspace:
                keyName = "Backspace";
                break;
            case Qt.Key_Delete:
                keyName = "Delete";
                break;
            case Qt.Key_Insert:
                keyName = "Insert";
                break;
            case Qt.Key_Home:
                keyName = "Home";
                break;
            case Qt.Key_End:
                keyName = "End";
                break;
            case Qt.Key_PageUp:
                keyName = "PgUp";
                break;
            case Qt.Key_PageDown:
                keyName = "PgDown";
                break;
            case Qt.Key_Up:
                keyName = "Up";
                break;
            case Qt.Key_Down:
                keyName = "Down";
                break;
            case Qt.Key_Left:
                keyName = "Left";
                break;
            case Qt.Key_Right:
                keyName = "Right";
                break;
            case Qt.Key_CapsLock:
                keyName = "CapsLock";
                break;
            case Qt.Key_NumLock:
                keyName = "NumLock";
                break;
            case Qt.Key_ScrollLock:
                keyName = "ScrollLock";
                break;
            case Qt.Key_Pause:
                keyName = "Pause";
                break;
            case Qt.Key_Print:
                keyName = "Print";
                break;

            // Function keys
            case Qt.Key_F1:
                keyName = "F1";
                break;
            case Qt.Key_F2:
                keyName = "F2";
                break;
            case Qt.Key_F3:
                keyName = "F3";
                break;
            case Qt.Key_F4:
                keyName = "F4";
                break;
            case Qt.Key_F5:
                keyName = "F5";
                break;
            case Qt.Key_F6:
                keyName = "F6";
                break;
            case Qt.Key_F7:
                keyName = "F7";
                break;
            case Qt.Key_F8:
                keyName = "F8";
                break;
            case Qt.Key_F9:
                keyName = "F9";
                break;
            case Qt.Key_F10:
                keyName = "F10";
                break;
            case Qt.Key_F11:
                keyName = "F11";
                break;
            case Qt.Key_F12:
                keyName = "F12";
                break;

            // Letter keys A-Z (Qt.Key_A = 65, Qt.Key_Z = 90)
            case Qt.Key_A:
                keyName = "A";
                break;
            case Qt.Key_B:
                keyName = "B";
                break;
            case Qt.Key_C:
                keyName = "C";
                break;
            case Qt.Key_D:
                keyName = "D";
                break;
            case Qt.Key_E:
                keyName = "E";
                break;
            case Qt.Key_F:
                keyName = "F";
                break;
            case Qt.Key_G:
                keyName = "G";
                break;
            case Qt.Key_H:
                keyName = "H";
                break;
            case Qt.Key_I:
                keyName = "I";
                break;
            case Qt.Key_J:
                keyName = "J";
                break;
            case Qt.Key_K:
                keyName = "K";
                break;
            case Qt.Key_L:
                keyName = "L";
                break;
            case Qt.Key_M:
                keyName = "M";
                break;
            case Qt.Key_N:
                keyName = "N";
                break;
            case Qt.Key_O:
                keyName = "O";
                break;
            case Qt.Key_P:
                keyName = "P";
                break;
            case Qt.Key_Q:
                keyName = "Q";
                break;
            case Qt.Key_R:
                keyName = "R";
                break;
            case Qt.Key_S:
                keyName = "S";
                break;
            case Qt.Key_T:
                keyName = "T";
                break;
            case Qt.Key_U:
                keyName = "U";
                break;
            case Qt.Key_V:
                keyName = "V";
                break;
            case Qt.Key_W:
                keyName = "W";
                break;
            case Qt.Key_X:
                keyName = "X";
                break;
            case Qt.Key_Y:
                keyName = "Y";
                break;
            case Qt.Key_Z:
                keyName = "Z";
                break;

            // Number keys 0-9 (normalize symbols from Shift+Number to just the number)
            case Qt.Key_0:
            case Qt.Key_ParenRight:
                keyName = "0";
                break;
            case Qt.Key_1:
            case Qt.Key_Exclam:
                keyName = "1";
                break;
            case Qt.Key_2:
            case Qt.Key_At:
                keyName = "2";
                break;
            case Qt.Key_3:
            case Qt.Key_NumberSign:
                keyName = "3";
                break;
            case Qt.Key_4:
            case Qt.Key_Dollar:
                keyName = "4";
                break;
            case Qt.Key_5:
            case Qt.Key_Percent:
                keyName = "5";
                break;
            case Qt.Key_6:
            case Qt.Key_AsciiCircum:
                keyName = "6";
                break;
            case Qt.Key_7:
            case Qt.Key_Ampersand:
                keyName = "7";
                break;
            case Qt.Key_8:
            case Qt.Key_Asterisk:
                keyName = "8";
                break;
            case Qt.Key_9:
            case Qt.Key_ParenLeft:
                keyName = "9";
                break;

            // Punctuation and symbols
            case Qt.Key_Minus:
                keyName = "-";
                break;
            case Qt.Key_Plus:
                keyName = "+";
                break;
            case Qt.Key_Equal:
                keyName = "=";
                break;
            case Qt.Key_BracketLeft:
                keyName = "[";
                break;
            case Qt.Key_BracketRight:
                keyName = "]";
                break;
            case Qt.Key_Backslash:
                keyName = "\\";
                break;
            case Qt.Key_Semicolon:
                keyName = ";";
                break;
            case Qt.Key_Apostrophe:
                keyName = "'";
                break;
            case Qt.Key_Comma:
                keyName = ",";
                break;
            case Qt.Key_Period:
                keyName = ".";
                break;
            case Qt.Key_Slash:
                keyName = "/";
                break;
            case Qt.Key_QuoteLeft:
                keyName = "`";
                break;
            default:
                // For any other keys, try to use the text representation
                if (event.text !== "" && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
                    keyName = event.text.toUpperCase();
                } else {
                    console.log("Unhandled key:", key);
                }
            }

            if (keyName !== "") {
                parts.push(keyName);
                root.capturedHotkey = parts.join("+");
            }

            event.accepted = true;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.title
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Close button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouseArea.containsMouse ? "#333333" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#888888"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: closeMouseArea
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

            // Instructions
            Text {
                text: "Press any key combination to assign a hotkey"
                color: "#888888"
                font.pixelSize: 14
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // Capture display area
            Rectangle {
                id: captureArea
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                radius: 12
                color: "#0D0D0D"
                border.width: 2
                border.color: keyCapture.activeFocus ? "#3C7BFF" : "#2A2A2A"

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.capturedHotkey !== "" ? root.capturedHotkey : "Waiting for input..."
                    color: root.capturedHotkey !== "" ? "#FFFFFF" : "#555555"
                    font.pixelSize: root.capturedHotkey !== "" ? 20 : 16
                    font.weight: root.capturedHotkey !== "" ? Font.Medium : Font.Normal
                    font.family: "Consolas"

                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                // Pulsing border animation when focused
                SequentialAnimation on border.color {
                    id: pulseAnimation
                    running: keyCapture.activeFocus && root.capturedHotkey === ""
                    loops: Animation.Infinite
                    ColorAnimation {
                        to: "#3C7BFF"
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    ColorAnimation {
                        to: "#5A9AFF"
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }

                // Click to refocus
                MouseArea {
                    anchors.fill: parent
                    onClicked: keyCapture.forceActiveFocus()
                }
            }

            // Hint text
            Text {
                text: "Press Enter to confirm • Escape to cancel"
                color: "#555555"
                font.pixelSize: 12
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.fillWidth: true
                }

                // Cancel button
                Rectangle {
                    width: 100
                    height: 40
                    radius: 10
                    color: cancelMouseArea.containsMouse ? "#333333" : "#2A2A2A"
                    border.width: 1
                    border.color: "#3A3A3A"

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: "#CCCCCC"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cancelled();
                            root.close();
                        }
                    }
                }

                // Clear button
                Rectangle {
                    width: 100
                    height: 40
                    radius: 10
                    color: clearMouseArea.containsMouse ? "#333333" : "#2A2A2A"
                    border.width: 1
                    border.color: "#3A3A3A"

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: "#CCCCCC"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.capturedHotkey = "";
                            keyCapture.forceActiveFocus();
                        }
                    }
                }

                // Confirm button
                Rectangle {
                    width: 100
                    height: 40
                    radius: 10
                    opacity: root.capturedHotkey !== "" ? 1.0 : 0.5

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: "#3C7BFF"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#B400FF"
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Confirm"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: confirmMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.capturedHotkey !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.capturedHotkey !== ""
                        onClicked: {
                            if (root.capturedHotkey !== "") {
                                root.hotkeyConfirmed(root.capturedHotkey);
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
