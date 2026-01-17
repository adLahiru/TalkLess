// HeaderBar.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../styles"

Rectangle {
    id: root
    height: 60
    color: "transparent"

    // Load Orelega One font from Google Fonts
    FontLoader {
        id: orelegaOneFont
        source: "https://fonts.gstatic.com/s/orelegaone/v12/3qTpojOggD2XtAdFb-QXZGt61EcYaQ7F.ttf"
    }
    
    // Load Outfit font for UI elements
    FontLoader {
        id: outfitFont
        source: "https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4TC1C4G-EiAou6Y.ttf"
    }

    // Content container with max-width constraint
    Item {
        id: contentContainer
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 1400) // Max width of 1400px with 20px margins
        height: parent.height

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16

            // Spacer to push content to the right
            Item {
                Layout.fillWidth: true
            }

            // Search Bar
            Rectangle {
                id: searchBar
                Layout.preferredWidth: 320
                Layout.preferredHeight: 40
                radius: 20
                color: Colors.surfaceDark
                border.width: 1
                border.color: searchInput.activeFocus ? Colors.accent : Colors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    // Search Icon
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "🔍"
                            font.pixelSize: 14
                            opacity: 0.6
                        }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Search..."
                        placeholderTextColor: Colors.textSecondary
                        color: Colors.textPrimary
                        font.pixelSize: 14
                        background: Rectangle {
                            color: "transparent"
                        }
                        verticalAlignment: TextInput.AlignVCenter
                    }

                    // Clear button (visible when there's text)
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: searchInput.text.length > 0 ? Colors.surfaceLight : "transparent"
                        visible: searchInput.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Colors.textTertiary
                            font.pixelSize: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // Profile Button
            Rectangle {
                id: profileButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: profileMouseArea.containsMouse ? "#2A2C33" : "#1F1F1F"
                border.width: 1
                border.color: "#2A2C33"

                // Gradient overlay for selected/hover state
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: profileMouseArea.containsPress
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.gradientPrimaryStart
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.gradientPrimaryEnd
                        }
                    }
                    opacity: 0.3
                }

                // Profile Initials
                Text {
                    anchors.centerIn: parent
                    text: {
                        if (apiClient && apiClient.isGuest) return "G"
                        if (apiClient && apiClient.currentUserFirstName) {
                            var first = apiClient.currentUserFirstName.charAt(0).toUpperCase()
                            var last = apiClient.currentUserLastName ? apiClient.currentUserLastName.charAt(0).toUpperCase() : ""
                            return first + last
                        }
                        return "U"
                    }
                    color: Colors.textPrimary
                    font.family: orelegaOneFont.status === FontLoader.Ready ? orelegaOneFont.name : "Arial"
                    font.weight: Font.Normal // 400
                    font.pixelSize: 18 // rounded from 18.4
                    // font.styleName: "Regular" // Removed to avoid conflict
                    lineHeight: 1.0
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: profileMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("Profile clicked");
                        logoutPopup.open();
                    }
                }

                // Logout Popup
                Popup {
                    id: logoutPopup
                    y: parent.height + 8
                    x: -width + parent.width // Align right edge
                    width: 160
                    height: 50
                    padding: 0
                    margins: 0

                    background: Rectangle {
                        color: Colors.surface
                        radius: 12
                        border.color: Colors.border
                        border.width: 1

                        // Shadow effect
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#80000000"
                            shadowBlur: 1.0
                            shadowVerticalOffset: 4
                            shadowHorizontalOffset: 0
                        }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Rectangle {
                            id: logoutBtn
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 8

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                
                                Text {
                                    text: (apiClient && apiClient.isGuest) ? "Log in" : "Log out"
                                    color: Colors.textPrimary
                                    font.family: outfitFont.status === FontLoader.Ready ? outfitFont.name : "Arial"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: logoutMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log(apiClient && apiClient.isGuest ? "Login clicked" : "Logout clicked");
                                    logoutPopup.close();
                                    apiClient.logout();
                                }
                            }
                            
                            color: logoutMouse.containsPress ? Colors.surfaceLight : (logoutMouse.containsMouse ? Qt.lighter(Colors.surface, 1.2) : "transparent")
                            
                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // User Name - shows "Guest" for guest users, first name otherwise
            Text {
                text: {
                    if (apiClient && apiClient.isGuest) return "Guest"
                    return apiClient && apiClient.isLoggedIn ? apiClient.displayName : ""
                }
                color: Colors.textPrimary
                font.family: "Orelega One"
                font.pixelSize: 20
                font.weight: Font.Normal
                font.styleName: "Regular"
                lineHeight: 1.0
                lineHeightMode: Text.ProportionalHeight
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter
                visible: apiClient && (apiClient.isLoggedIn || apiClient.isGuest)
            }
        }
    }
}
