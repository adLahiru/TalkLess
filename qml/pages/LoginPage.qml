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

                        Item {
                            Layout.fillWidth: true
                            height: 64 // Increased height to accommodate label on top

                            TextField {
                                id: emailInput
                                anchors.fill: parent
                                anchors.topMargin: 8
                                placeholderText: "john.doe@gmail.com"
                                placeholderTextColor: "#555555"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                                topPadding: 16
                                leftPadding: 16
                                rightPadding: 16
                                background: Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: emailInput.activeFocus ? Colors.accent : "#333333"
                                    border.width: 1
                                    radius: 4
                                }

                                onTextChanged: {
                                    if (emailError.visible) {
                                        if (isValidEmail(text.trim())) {
                                            emailError.visible = false;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                x: 12
                                y: 0
                                width: emailLabel.width + 10
                                height: 16
                                color: "#0D0D0D"

                                Text {
                                    id: emailLabel
                                    anchors.centerIn: parent
                                    text: "Email"
                                    font.pixelSize: 12
                                    color: "#888888"
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

                        Item {
                            Layout.fillWidth: true
                            height: 64

                            TextField {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.topMargin: 8
                                echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                                placeholderText: "••••••••••••"
                                placeholderTextColor: "#555555"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                                topPadding: 16
                                leftPadding: 16
                                rightPadding: 40 // Space for eye icon
                                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                background: Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: passwordInput.activeFocus ? Colors.accent : "#333333"
                                    border.width: 1
                                    radius: 4
                                }

                                onTextChanged: {
                                    if (passwordError.visible && text.length >= 6) {
                                        passwordError.visible = false;
                                    }
                                }
                            }

                            // Eye Icon inside the field
                            CheckBox {
                                id: showPassword
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: passwordInput.verticalCenter
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

                            Rectangle {
                                x: 12
                                y: 0
                                width: passwordLabel.width + 10
                                height: 16
                                color: "#0D0D0D"

                                Text {
                                    id: passwordLabel
                                    anchors.centerIn: parent
                                    text: "Password"
                                    font.pixelSize: 12
                                    color: "#888888"
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
                            Layout.alignment: Qt.AlignVCenter
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
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Forgot Password"
                            font.pixelSize: 13
                            color: "#CCCCCC"
                            Layout.alignment: Qt.AlignVCenter

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
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                text: "Don't Have an account?"
                                font.pixelSize: 13
                                color: "#888888"
                            }

                            Text {
                                text: "Sign Up"
                                font.pixelSize: 13
                                font.bold: true
                                color: Colors.gradientPrimaryEnd

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.signupRequested()
                                }
                            }
                        }

                        Text {
                            text: "Try as guest"
                            font.pixelSize: 13
                            color: Colors.textSecondary
                            Layout.alignment: Qt.AlignHCenter

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
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Rectangle {
                            width: 100
                            height: 50
                            color: "transparent"
                            border.color: "#333333"
                            border.width: 1
                            radius: 8

                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/qt/qml/TalkLess/resources/icons/facebook.svg"
                                width: 24
                                height: 24
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Facebook login")
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 50
                            color: "transparent"
                            border.color: "#333333"
                            border.width: 1
                            radius: 8

                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/qt/qml/TalkLess/resources/icons/google.svg"
                                width: 24
                                height: 24
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Google login")
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 50
                            color: "transparent"
                            border.color: "#333333"
                            border.width: 1
                            radius: 8

                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/qt/qml/TalkLess/resources/icons/apple.svg"
                                width: 24
                                height: 24
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 24
                                sourceSize.height: 24
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
                        anchors.fill: parent
                        source: "qrc:/qt/qml/TalkLess/resources/images/login_page.png"
                        fillMode: Image.PreserveAspectCrop
                    }

                }
            }
        }
    }
}
