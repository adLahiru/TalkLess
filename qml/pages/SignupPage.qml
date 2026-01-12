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
                        anchors.centerIn: parent
                        width: parent.width * 0.85
                        height: parent.height * 0.85
                        source: "qrc:/qt/qml/TalkLess/resources/images/signup_page.png"
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

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 56
                                    color: "transparent"
                                    border.color: firstNameInput.activeFocus ? Colors.accent : "#333333"
                                    border.width: 1
                                    radius: 4

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 2

                                        Text {
                                            text: "First Name"
                                            font.pixelSize: 11
                                            color: "#888888"
                                        }

                                        TextField {
                                            id: firstNameInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            placeholderText: "John"
                                            placeholderTextColor: "#555555"
                                            color: "#FFFFFF"
                                            font.pixelSize: 14
                                            background: Rectangle { color: "transparent" }
                                            leftPadding: 0
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

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 56
                                    color: "transparent"
                                    border.color: lastNameInput.activeFocus ? Colors.accent : "#333333"
                                    border.width: 1
                                    radius: 4

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 2

                                        Text {
                                            text: "Last Name"
                                            font.pixelSize: 11
                                            color: "#888888"
                                        }

                                        TextField {
                                            id: lastNameInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            placeholderText: "Doe"
                                            placeholderTextColor: "#555555"
                                            color: "#FFFFFF"
                                            font.pixelSize: 14
                                            background: Rectangle { color: "transparent" }
                                            leftPadding: 0
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
                                                if (emailError.visible && isValidEmail(text.trim())) {
                                                    emailError.visible = false;
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

                            // Phone
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 56
                                    color: "transparent"
                                    border.color: phoneInput.activeFocus ? Colors.accent : "#333333"
                                    border.width: 1
                                    radius: 4

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 2

                                        Text {
                                            text: "Phone Number"
                                            font.pixelSize: 11
                                            color: "#888888"
                                        }

                                        TextField {
                                            id: phoneInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            placeholderText: "0322890302"
                                            placeholderTextColor: "#555555"
                                            color: "#FFFFFF"
                                            font.pixelSize: 14
                                            background: Rectangle { color: "transparent" }
                                            leftPadding: 0
                                            inputMethodHints: Qt.ImhDigitsOnly

                                            onTextChanged: {
                                                if (phoneError.visible && isValidPhone(text.trim())) {
                                                    phoneError.visible = false;
                                                }
                                            }
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

                            Rectangle {
                                Layout.fillWidth: true
                                height: 56
                                color: "transparent"
                                border.color: confirmPasswordInput.activeFocus ? Colors.accent : "#333333"
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
                                            text: "Confirm Password"
                                            font.pixelSize: 11
                                            color: "#888888"
                                        }

                                        TextField {
                                            id: confirmPasswordInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            echoMode: showConfirmPassword.checked ? TextInput.Normal : TextInput.Password
                                            placeholderText: "••••••••••••"
                                            placeholderTextColor: "#555555"
                                            color: "#FFFFFF"
                                            font.pixelSize: 14
                                            background: Rectangle { color: "transparent" }
                                            leftPadding: 0
                                        }
                                    }

                                    CheckBox {
                                        id: showConfirmPassword
                                        Layout.alignment: Qt.AlignVCenter
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

                        // Terms checkbox
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                spacing: 8

                                CheckBox {
                                    id: termsCheck
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
                                    text: "I agree to all the "
                                    font.pixelSize: 13
                                    color: "#CCCCCC"
                                }
                                Text {
                                    text: "Terms"
                                    font.pixelSize: 13
                                    color: "#FF6B6B"
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: console.log("Terms clicked")
                                    }
                                }
                                Text {
                                    text: " and "
                                    font.pixelSize: 13
                                    color: "#CCCCCC"
                                }
                                Text {
                                    text: "Privacy Policies"
                                    font.pixelSize: 13
                                    color: "#FF6B6B"
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: console.log("Privacy clicked")
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
                                    onClicked: console.log("Facebook signup")
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
                                    onClicked: console.log("Google signup")
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
