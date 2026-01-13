// HeaderBar.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
                    ColorAnimation { duration: 150 }
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
                        GradientStop { position: 0.0; color: "#3E66FF" }
                        GradientStop { position: 1.0; color: "#B44CFF" }
                    }
                    opacity: 0.3
                }

                // Profile Icon (placeholder - user silhouette)
                Text {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: profileMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("Profile clicked")
                        // TODO: Open profile menu/dialog
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // User Name - shows "Guest" for guest users, first name otherwise
            Text {
                text: apiClient && apiClient.isLoggedIn ? apiClient.displayName : ""
                color: Colors.textPrimary
                font.family: "Orelega One"
                font.pixelSize: 20
                font.weight: Font.Normal
                font.styleName: "Regular"
                lineHeight: 1.0
                lineHeightMode: Text.ProportionalHeight
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter
                visible: apiClient && apiClient.isLoggedIn
            }
        }
    }
}
