pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

Item {
    id: root

    // Signal emitted when authentication is complete (login, signup, or guest)
    signal authComplete

    // Current page: 0 = login, 1 = signup
    property int currentPage: 0

    // Loading overlay
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        z: 100
        visible: apiClient.isLoading

        Column {
            anchors.centerIn: parent
            spacing: 16

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.visible
            }

            Text {
                text: "Please wait..."
                color: "#FFFFFF"
                font.pixelSize: 16
            }
        }
    }

    // Error message popup
    Rectangle {
        id: errorPopup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        width: errorText.implicitWidth + 40
        height: 48
        radius: 8
        color: "#ff4444"
        z: 99
        opacity: apiClient.errorMessage !== "" ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Text {
            id: errorText
            anchors.centerIn: parent
            text: apiClient.errorMessage
            color: "#FFFFFF"
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Clear error on click (this would need a method in ApiClient)
            }
        }
    }

    // Connect to ApiClient signals
    Connections {
        target: apiClient

        function onLoginSuccess() {
            console.log("[AuthView] Login success!");
            root.authComplete();
        }

        function onSignupSuccess() {
            console.log("[AuthView] Signup success! Redirecting to login...");
            // After signup, guide user to login page
            root.currentPage = 0;
        }

        function onLoginError(message) {
            console.log("[AuthView] Login error:", message);
        }

        function onSignupError(message) {
            console.log("[AuthView] Signup error:", message);
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.currentPage

        LoginPage {
            onLoginRequested: function(email, password, rememberMe) {
                console.log("[AuthView] Login requested:", email, "remember:", rememberMe);
                apiClient.login(email, password, rememberMe);
            }

            onSignupRequested: {
                root.currentPage = 1;
            }

            onGuestRequested: {
                console.log("[AuthView] Guest mode requested");
                apiClient.loginAsGuest();
            }

            onForgotPasswordRequested: {
                console.log("[AuthView] Forgot password requested");
                // TODO: Implement forgot password flow
            }
        }

        SignupPage {
            onSignupRequested: function(firstName, lastName, email, phone, password) {
                console.log("[AuthView] Signup requested:", firstName, lastName, email, phone);
                apiClient.signup(email, password, firstName, lastName, phone);
            }

            onLoginRequested: {
                root.currentPage = 0;
            }

            onGuestRequested: {
                console.log("[AuthView] Guest mode requested");
                apiClient.loginAsGuest();
            }
        }
    }
}
