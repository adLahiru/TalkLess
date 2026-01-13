pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Item {
    id: root

    signal signupRequested(string firstName, string lastName, string email, string phone, string password)
    signal loginRequested
    signal guestRequested

    // Validation functions
    function isValidEmail(email) {
        var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    function isValidPhone(phone) {
        var phoneRegex = /^\d{10,}$/;
        return phoneRegex.test(phone.replace(/[\s\-\(\)]/g, ''));
    }

    function validateForm() {
        var isValid = true;

        // Validate first name
        if (firstNameInput.text.trim() === "") {
            firstNameError.text = "First name is required";
            firstNameError.visible = true;
            isValid = false;
        } else {
            firstNameError.visible = false;
        }

        // Validate last name
        if (lastNameInput.text.trim() === "") {
            lastNameError.text = "Last name is required";
            lastNameError.visible = true;
            isValid = false;
        } else {
            lastNameError.visible = false;
        }

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

        // Validate phone
        if (phoneInput.text.trim() === "") {
            phoneError.text = "Phone number is required";
            phoneError.visible = true;
            isValid = false;
        } else if (!isValidPhone(phoneInput.text.trim())) {
            phoneError.text = "Please enter a valid phone number (10+ digits)";
            phoneError.visible = true;
            isValid = false;
        } else {
            phoneError.visible = false;
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

        // Validate confirm password
        if (confirmPasswordInput.text === "") {
            confirmPasswordError.text = "Please confirm your password";
            confirmPasswordError.visible = true;
            isValid = false;
        } else if (confirmPasswordInput.text !== passwordInput.text) {
            confirmPasswordError.text = "Passwords do not match";
            confirmPasswordError.visible = true;
            isValid = false;
        } else {
            confirmPasswordError.visible = false;
        }

        // Validate terms
        if (!termsCheck.checked) {
            termsError.visible = true;
            isValid = false;
        } else {
            termsError.visible = false;
        }

        return isValid;
    }

    Rectangle {
        anchors.fill: parent
        color: "#0D0D0D"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left side - Image
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.4

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 20
                    color: "#F5F5F5"
                    radius: 20

                    Image {
                        anchors.fill: parent
                        source: "qrc:/qt/qml/TalkLess/resources/images/signup_page.png"
                        fillMode: Image.PreserveAspectCrop
                    }

                }
            }

            // Right side - Form
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 20
                    contentHeight: formColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: formColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(500, parent.width - 40)
                        spacing: 16

                        // Title
                        Text {
                            text: "Sign up"
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                        }

                        Text {
                            text: "Let's get you all set up so you can access your personal account."
                            font.pixelSize: 14
                            color: "#888888"
                            Layout.bottomMargin: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // First Name / Last Name row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // First Name
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    height: 64

                                    TextField {
                                        id: firstNameInput
                                        anchors.fill: parent
                                        anchors.topMargin: 8
                                        placeholderText: "John"
                                        placeholderTextColor: "#555555"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        topPadding: 16
                                        leftPadding: 16
                                        rightPadding: 16
                                        background: Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: firstNameInput.activeFocus ? Colors.accent : "#333333"
                                            border.width: 1
                                            radius: 4
                                        }
                                    }

                                    Rectangle {
                                        x: 12
                                        y: 0
                                        width: firstNameLabel.width + 10
                                        height: 16
                                        color: "#0D0D0D"

                                        Text {
                                            id: firstNameLabel
                                            anchors.centerIn: parent
                                            text: "First Name"
                                            font.pixelSize: 12
                                            color: "#888888"
                                        }
                                    }
                                }

                                Text {
                                    id: firstNameError
                                    visible: false
                                    text: ""
                                    font.pixelSize: 11
                                    color: "#FF6B6B"
                                }
                            }

                            // Last Name
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    height: 64

                                    TextField {
                                        id: lastNameInput
                                        anchors.fill: parent
                                        anchors.topMargin: 8
                                        placeholderText: "Doe"
                                        placeholderTextColor: "#555555"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        topPadding: 16
                                        leftPadding: 16
                                        rightPadding: 16
                                        background: Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: lastNameInput.activeFocus ? Colors.accent : "#333333"
                                            border.width: 1
                                            radius: 4
                                        }
                                    }

                                    Rectangle {
                                        x: 12
                                        y: 0
                                        width: lastNameLabel.width + 10
                                        height: 16
                                        color: "#0D0D0D"

                                        Text {
                                            id: lastNameLabel
                                            anchors.centerIn: parent
                                            text: "Last Name"
                                            font.pixelSize: 12
                                            color: "#888888"
                                        }
                                    }
                                }

                                Text {
                                    id: lastNameError
                                    visible: false
                                    text: ""
                                    font.pixelSize: 11
                                    color: "#FF6B6B"
                                }
                            }
                        }

                        // Email / Phone row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Email
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    height: 64

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
                                            if (emailError.visible && isValidEmail(text.trim())) {
                                                emailError.visible = false;
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

                            // Phone
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    height: 64

                                    TextField {
                                        id: phoneInput
                                        anchors.fill: parent
                                        anchors.topMargin: 8
                                        placeholderText: "0322890302"
                                        placeholderTextColor: "#555555"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        topPadding: 16
                                        leftPadding: 16
                                        rightPadding: 16
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        background: Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: phoneInput.activeFocus ? Colors.accent : "#333333"
                                            border.width: 1
                                            radius: 4
                                        }

                                        onTextChanged: {
                                            if (phoneError.visible && isValidPhone(text.trim())) {
                                                phoneError.visible = false;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        x: 12
                                        y: 0
                                        width: phoneLabel.width + 10
                                        height: 16
                                        color: "#0D0D0D"

                                        Text {
                                            id: phoneLabel
                                            anchors.centerIn: parent
                                            text: "Phone Number"
                                            font.pixelSize: 12
                                            color: "#888888"
                                        }
                                    }
                                }

                                Text {
                                    id: phoneError
                                    visible: false
                                    text: ""
                                    font.pixelSize: 11
                                    color: "#FF6B6B"
                                }
                            }
                        }

                        // Confirm Password field
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                    Layout.fillWidth: true
                                    height: 64

                                    TextField {
                                        id: confirmPasswordInput
                                        anchors.fill: parent
                                        anchors.topMargin: 8
                                        echoMode: showConfirmPassword.checked ? TextInput.Normal : TextInput.Password
                                        placeholderText: "••••••••••••"
                                        placeholderTextColor: "#555555"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        topPadding: 16
                                        leftPadding: 16
                                        rightPadding: 40
                                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                        background: Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: confirmPasswordInput.activeFocus ? Colors.accent : "#333333"
                                            border.width: 1
                                            radius: 4
                                        }
                                    }

                                    CheckBox {
                                        id: showConfirmPassword
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: confirmPasswordInput.verticalCenter
                                        indicator: Rectangle {
                                            width: 24
                                            height: 24
                                            color: "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: showConfirmPassword.checked ? "👁" : "👁‍🗨"
                                                font.pixelSize: 16
                                                color: "#888888"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        x: 12
                                        y: 0
                                        width: confirmPasswordLabel.width + 10
                                        height: 16
                                        color: "#0D0D0D"

                                        Text {
                                            id: confirmPasswordLabel
                                            anchors.centerIn: parent
                                            text: "Confirm Password"
                                            font.pixelSize: 12
                                            color: "#888888"
                                        }
                                    }
                                }

                            Text {
                                id: confirmPasswordError
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
                                        rightPadding: 40
                                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                        background: Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.color: passwordInput.activeFocus ? Colors.accent : "#333333"
                                            border.width: 1
                                            radius: 4
                                        }
                                    }

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

                            RowLayout {
                                spacing: 12
                                width: parent.width

                                CheckBox {
                                    id: termsCheck
                                    Layout.alignment: Qt.AlignVCenter
                                    indicator: Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 3
                                        border.color: "#555555"
                                        border.width: 1
                                        color: termsCheck.checked ? Colors.accent : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: "#FFFFFF"
                                            font.pixelSize: 12
                                            visible: termsCheck.checked
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "I agree to all the <a href='terms' style='color: #FF6B6B; text-decoration: none'>Terms</a> and <a href='privacy' style='color: #FF6B6B; text-decoration: none'>Privacy Policies</a>"
                                    color: "#CCCCCC"
                                    font.pixelSize: 13
                                    textFormat: Text.RichText
                                    wrapMode: Text.WordWrap
                                    linkColor: "#FF6B6B"

                                    onLinkActivated: function(link) {
                                        if (link === 'terms') console.log("Terms clicked");
                                        if (link === 'privacy') console.log("Privacy clicked");
                                    }
                                }
                            }

                            Text {
                                id: termsError
                                visible: false
                                text: "You must agree to the terms and privacy policies"
                                font.pixelSize: 11
                                color: "#FF6B6B"
                            }

                        // Create account button
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
                                text: "Create account"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.validateForm()) {
                                        root.signupRequested(
                                            firstNameInput.text.trim(),
                                            lastNameInput.text.trim(),
                                            emailInput.text.trim(),
                                            phoneInput.text.trim(),
                                            passwordInput.text
                                        );
                                    }
                                }
                            }
                        }

                        // Already have account link
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: "Already have an account?"
                                    font.pixelSize: 13
                                    color: "#888888"
                                }

                                Text {
                                    text: "Login"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Colors.gradientPrimaryEnd

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.loginRequested()
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
                                text: "Or Sign up with"
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
                                     onClicked: console.log("Facebook signup")
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
                                     onClicked: console.log("Google signup")
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
                                     onClicked: console.log("Apple signup")
                                 }
                             }
                        }

                        // Bottom spacing
                        Item { height: 20 }
                    }
                }
            }
        }
    }
}
