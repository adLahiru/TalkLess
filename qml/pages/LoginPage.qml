pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Item {
    id: root

    signal loginRequested(string email, string password, bool rememberMe)
    signal signupRequested
    signal guestRequested
    signal forgotPasswordRequested

    // Validation functions
    function isValidEmail(email) {
        var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    function validateForm() {
        var isValid = true;

        // Validate email
        if (emailInput.text.trim() === "") {
            emailError.text = "Email is required";
            emailError.visible = true;
            isValid = false;
        } else if (!isValidEmail(emailInput.text.trim())) {
            emailError.text = "Please enter a valid email address";
            emailError.visible = true;
            isValid = false;
        } else {
            emailError.visible = false;
        }

        // Validate password
        if (passwordInput.text === "") {
            passwordError.text = "Password is required";
            passwordError.visible = true;
            isValid = false;
        } else if (passwordInput.text.length < 6) {
            passwordError.text = "Password must be at least 6 characters";
            passwordError.visible = true;
            isValid = false;
        } else {
            passwordError.visible = false;
        }

        return isValid;
    }

    Rectangle {
        anchors.fill: parent
        color: "#0D0D0D"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left side - Form
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.45

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(380, parent.width - 80)
                    spacing: 20

                    // Welcome text
                    Text {
                        text: "Welcome!"
                        font.pixelSize: 42
                        font.weight: Font.Bold
                        font.italic: true
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "Login to access your account"
                        font.pixelSize: 14
                        color: "#888888"
                        Layout.bottomMargin: 10
                    }

                    // Email field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            color: "transparent"
                            border.color: emailInput.activeFocus ? Colors.accent : "#333333"
                            border.width: 1
                            radius: 4

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text {
                                    text: "Email"
                                    font.pixelSize: 11
                                    color: "#888888"
                                }

                                TextField {
                                    id: emailInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    placeholderText: "john.doe@gmail.com"
                                    placeholderTextColor: "#555555"
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    background: Rectangle { color: "transparent" }
                                    leftPadding: 0

                                    onTextChanged: {
                                        if (emailError.visible) {
                                            if (isValidEmail(text.trim())) {
                                                emailError.visible = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: emailError
                            visible: false
                            text: ""
                            font.pixelSize: 11
                            color: "#FF6B6B"
                        }
                    }

                    // Password field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            color: "transparent"
                            border.color: passwordInput.activeFocus ? Colors.accent : "#333333"
                            border.width: 1
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2

                                    Text {
                                        text: "Password"
                                        font.pixelSize: 11
                                        color: "#888888"
                                    }

                                    TextField {
                                        id: passwordInput
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                                        placeholderText: "••••••••••••"
                                        placeholderTextColor: "#555555"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        background: Rectangle { color: "transparent" }
                                        leftPadding: 0

                                        onTextChanged: {
                                            if (passwordError.visible && text.length >= 6) {
                                                passwordError.visible = false;
                                            }
                                        }
                                    }
                                }

                                CheckBox {
                                    id: showPassword
                                    Layout.alignment: Qt.AlignVCenter
                                    indicator: Rectangle {
                                        width: 24
                                        height: 24
                                        color: "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: showPassword.checked ? "👁" : "👁‍🗨"
                                            font.pixelSize: 16
                                            color: "#888888"
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: passwordError
                            visible: false
                            text: ""
                            font.pixelSize: 11
                            color: "#FF6B6B"
                        }
                    }

                    // Remember me row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CheckBox {
                            id: rememberMeCheck
                            indicator: Rectangle {
                                width: 18
                                height: 18
                                radius: 3
                                border.color: "#555555"
                                border.width: 1
                                color: rememberMeCheck.checked ? Colors.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#FFFFFF"
                                    font.pixelSize: 12
                                    visible: rememberMeCheck.checked
                                }
                            }
                        }

                        Text {
                            text: "Remember me"
                            font.pixelSize: 13
                            color: "#CCCCCC"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Forgot Password"
                            font.pixelSize: 13
                            color: "#CCCCCC"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.forgotPasswordRequested()
                            }
                        }
                    }

                    // Login button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        radius: 6

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#00D9FF" }
                            GradientStop { position: 1.0; color: "#FF00FF" }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Login"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.validateForm()) {
                                    root.loginRequested(emailInput.text.trim(), passwordInput.text, rememberMeCheck.checked);
                                }
                            }
                        }
                    }

                    // Don't have account link
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            text: "Don't Have an account?"
                            font.pixelSize: 13
                            color: "#888888"
                        }

                        Text {
                            text: "Try as guest"
                            font.pixelSize: 13
                            color: Colors.accent

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.guestRequested()
                            }
                        }
                    }

                    // Divider
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#333333"
                        }

                        Text {
                            text: "Or login with"
                            font.pixelSize: 12
                            color: "#666666"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#333333"
                        }
                    }

                    // Social login buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Facebook
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            color: "#1877F2"
                            radius: 6

                            Text {
                                anchors.centerIn: parent
                                text: "f"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Facebook login")
                            }
                        }

                        // Google
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            color: "#FFFFFF"
                            radius: 6

                            Text {
                                anchors.centerIn: parent
                                text: "G"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#4285F4"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Google login")
                            }
                        }

                        // Apple
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            color: "#000000"
                            border.color: "#333333"
                            border.width: 1
                            radius: 6

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.pixelSize: 20
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Apple login")
                            }
                        }
                    }
                }
            }

            // Right side - Image
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 20
                    color: "#F5F5F5"
                    radius: 20

                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.85
                        height: parent.height * 0.85
                        source: "qrc:/qt/qml/TalkLess/resources/images/login_page.png"
                        fillMode: Image.PreserveAspectFit
                    }

                    // Page indicators
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 25
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 8
                            radius: 4
                            color: "#00D9FF"
                        }
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#333333"
                        }
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#333333"
                        }
                    }
                }
            }
        }
    }
}
