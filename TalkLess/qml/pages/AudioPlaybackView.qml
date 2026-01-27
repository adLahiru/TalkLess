import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

Item {
    id: root

    // Banner Area
    BackgroundBanner {
        id: banner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        displayText: "Settings & Configuration, Manage and trigger your sound clips"
    }

    // Main Content Container
    ColumnLayout {
        anchors.top: banner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 20
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 20

        // Custom Tab Selector
        // We need a custom one that matches the specific visual style in the mockup
        // The existing SettingsTabSelector is a bit different, but let's try to adapt a similar structure manually for now to match the screenshot exactly
        // Tab Selector matching SettingsTabSelector style
        Rectangle {
            id: tabSelector
            Layout.fillWidth: true
            height: 56
            color: "transparent"

            // Current selected index
            property int currentIndex: 1 // Default to Test Call Simulation

            ListModel {
                id: tabModel
                ListElement { title: "Playback Dashboard" }
                ListElement { title: "Test Call Simulation" }
            }

            // Gray background rectangle container
            Rectangle {
                anchors.centerIn: tabRow
                width: tabRow.width + 20
                height: 48
                radius: 24
                color: Colors.surfaceDark
            }

            // Tab row
            RowLayout {
                id: tabRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: tabModel

                    delegate: Rectangle {
                        id: tabItem
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: tabText.implicitWidth + 32
                        radius: 20
                        layer.enabled: true
                        required property int index
                        required property string title

                        readonly property bool isSelected: tabItem.index === tabSelector.currentIndex

                        // Gradient background for selected tab
                        gradient: tabItem.isSelected ? selectedGradient : null
                        color: tabItem.isSelected ? "transparent" : "transparent"

                        Gradient {
                            id: selectedGradient
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Colors.gradientPrimaryStart }
                            GradientStop { position: 1.0; color: Colors.gradientPrimaryEnd }
                        }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: tabItem.title
                            color: tabItem.isSelected ? Colors.textOnPrimary : Colors.textPrimary
                            font.pixelSize: 15
                            font.weight: tabItem.isSelected ? Font.Medium : Font.Normal
                            opacity: tabItem.isSelected ? 1.0 : 0.7
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: tabSelector.currentIndex = tabItem.index
                            onEntered: {
                                if (!tabItem.isSelected) tabText.opacity = 0.9
                            }
                            onExited: {
                                if (!tabItem.isSelected) tabText.opacity = 0.7
                            }
                        }
                        
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }

        // Test Call Simulation Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabSelector.currentIndex === 1
            color: "#0D0D0D" // Very dark background
            radius: 12
            border.width: 1
            border.color: "#1A1A1C"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20

                // Title
                Text {
                    text: "Test Call Simulation"
                    color: Colors.white
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                // Description
                Text {
                    text: "This will simulate a call using your selected playback and mic devices."
                    color: Colors.textSecondary
                    font.pixelSize: 14
                    Layout.preferredWidth: 600
                    wrapMode: Text.WordWrap
                }

                Item {
                    height: 10
                    width: 1
                } // Spacer

                // Start Simulation Button
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 50
                    color: "transparent"
                    border.width: 1
                    border.color: Colors.textSecondary
                    radius: 4

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "▶" // Play icon
                            color: Colors.white
                            font.pixelSize: 14
                        }

                        Text {
                            text: "Start Simulation"
                            color: Colors.white
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: console.log("Start Simulation clicked")
                    }
                }

                Item {
                    height: 10
                    width: 1
                } // Spacer

                // Checkboxes Row
                RowLayout {
                    spacing: 40

                    // Record simulation
                    RowLayout {
                        spacing: 10

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: "#6366f1" // Checked purple

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            text: "Record simulation"
                            color: Colors.textSecondary
                            font.pixelSize: 14
                        }
                    }

                    // Save as .wav
                    RowLayout {
                        spacing: 10

                        Text {
                            text: "💾" // Icon placeholder
                            color: Colors.textSecondary
                        }

                        Text {
                            text: "[ Save as .wav ]"
                            color: Colors.textSecondary
                            font.pixelSize: 14
                        }
                    }
                }

                // Loop playback test
                RowLayout {
                    spacing: 10

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: "#6366f1" // Checked purple

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        text: "Loop playback test"
                        color: Colors.textSecondary
                        font.pixelSize: 14
                    }
                }

                Item {
                    height: 10
                    width: 1
                } // Spacer

                // Open last test link/button
                RowLayout {
                    spacing: 10

                    Text {
                        text: "📂"
                        color: Colors.textSecondary
                    }

                    Text {
                        text: "[ Open last test ]"
                        color: Colors.textSecondary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Vertical Spacer to push content up
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // Spacer to push content up and keep tabs fixed at top
        Item {
            visible: tabSelector.currentIndex !== 1
            Layout.fillHeight: true
        }
    }
}
