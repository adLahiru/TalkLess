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
                color: Colors.surface

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
                        placeholderTextColor: Colors.textTertiary
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
                        color: searchInput.text.length > 0 ? Colors.surfaceDark : "transparent"

                        visible: searchInput.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#888888"
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
                color: profileMouseArea.containsMouse ? Colors.surfaceLight : Colors.surface

                border.width: 1
                border.color: Colors.border

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
                        console.log("Profile clicked");
                        // TODO: Open profile menu/dialog
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // User Name
            Text {
                text: "Johnson"
                color: Colors.textPrimary

                font.family: orelegaOneFont.status === FontLoader.Ready ? orelegaOneFont.name : "Arial"
                font.pixelSize: 18
                font.weight: Font.Normal
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
