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

    StackLayout {
        anchors.fill: parent
        currentIndex: root.currentPage

        LoginPage {
            onLoginRequested: function(email, password, rememberMe) {
                console.log("Login requested:", email, "remember:", rememberMe);
                // TODO: Implement actual login logic
                root.authComplete();
            }

            onSignupRequested: {
                root.currentPage = 1;
            }

            onGuestRequested: {
                console.log("Guest mode requested");
                root.authComplete();
            }

            onForgotPasswordRequested: {
                console.log("Forgot password requested");
                // TODO: Implement forgot password flow
            }
        }

        SignupPage {
            onSignupRequested: function(firstName, lastName, email, phone, password) {
                console.log("Signup requested:", firstName, lastName, email, phone);
                // TODO: Implement actual signup logic
                root.authComplete();
            }

            onLoginRequested: {
                root.currentPage = 0;
            }

            onGuestRequested: {
                console.log("Guest mode requested");
                root.authComplete();
            }
        }
    }
}
