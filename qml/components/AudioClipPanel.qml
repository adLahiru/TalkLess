pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Right side panel for audio clip editing/recording
// Contains 5 tabs: Settings, Add, Record, Split, Audio
Rectangle {
    id: root
    color: "#1A1A1A"
    radius: 16
    border.color: "#2A2A2A"
    border.width: 1

    // Current active tab index
    property int currentTab: 0

    // Tab button model
    readonly property var tabIcons: ["⚙", "+", "●", "⧉", "🔊"]
    readonly property var tabNames: ["Settings", "Add", "Record", "Split", "Audio"]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header row with title and tab buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Title (e.g., "F1" for slot name)
            Text {
                text: "F1"
                color: "#FFFFFF"
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            // Tab buttons row
            Row {
                spacing: 4

                Repeater {
                    model: root.tabIcons.length

                    Rectangle {
                        id: tabButton
                        required property int index

                        width: 36
                        height: 36
                        radius: 8
                        color: root.currentTab === tabButton.index ? "#333333" : (tabMouseArea.containsMouse ? "#2A2A2A" : "transparent")
                        border.color: root.currentTab === tabButton.index ? "#444444" : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.tabIcons[tabButton.index]
                            color: root.currentTab === tabButton.index ? "#FFFFFF" : "#888888"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = tabButton.index
                        }

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }
        }

        // Separator line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#333333"
        }

        // Tab content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Settings Tab (index 0)
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === 0
                spacing: 12

                Text {
                    text: "Settings Tab"
                    color: "#888888"
                    font.pixelSize: 14
                }
                Text {
                    text: "Configure clip settings here"
                    color: "#666666"
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }

            // Add Tab (index 1)
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === 1
                spacing: 12

                Text {
                    text: "Add Tab"
                    color: "#888888"
                    font.pixelSize: 14
                }
                Text {
                    text: "Add new audio clips here"
                    color: "#666666"
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }

            // Record Tab (index 2)
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === 2
                spacing: 12

                Text {
                    text: "Record Tab"
                    color: "#888888"
                    font.pixelSize: 14
                }
                Text {
                    text: "Record audio here"
                    color: "#666666"
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }

            // Split Tab (index 3)
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === 3
                spacing: 12

                Text {
                    text: "Split Tab"
                    color: "#888888"
                    font.pixelSize: 14
                }
                Text {
                    text: "Split and trim audio here"
                    color: "#666666"
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }

            // Audio Tab (index 4)
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentTab === 4
                spacing: 12

                Text {
                    text: "Audio Tab"
                    color: "#888888"
                    font.pixelSize: 14
                }
                Text {
                    text: "Audio playback settings here"
                    color: "#666666"
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
