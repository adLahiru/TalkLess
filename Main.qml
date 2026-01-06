import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qml/components"
import "qml/pages"

ApplicationWindow {
    id: mainWindow
    
    width: 1920
    height: 1080
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: qsTr("TalkLess")
    color: '#000000'

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

       

        // Main content row (sidebar + pages)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            SideBar {
                id: sidebar
                Layout.preferredWidth: 280
                Layout.fillHeight: true

                onSelected: (route) => {
                    console.log("Selected route:", route)
                    switch(route) {
                        case "soundboard":
                            contentStack.currentIndex = 0
                            break
                        case "engine":
                            contentStack.currentIndex = 1
                            break
                        case "macros":
                            contentStack.currentIndex = 2
                            break
                        case "settings":
                            contentStack.currentIndex = 3
                            break
                        case "stats":
                            contentStack.currentIndex = 4
                            break
                    }
                }
            }

            // Main content area - header + pages in column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Header Bar at the top (height fits content)
                HeaderBar {
                    id: headerBar
                    Layout.fillWidth: true
                }

                // Page stack below header
                StackLayout {
                    id: contentStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: 0

                    // Soundboard Page
                    SoundboardView {
                    }

                    // Audio Playback Engine (placeholder)
                    Rectangle {
                        color: "#0d0d0d"
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Audio Playback Engine"
                            color: "#666"
                            font.pixelSize: 32
                        }
                    }

                    // Macros & Automation (placeholder)
                    Rectangle {
                        color: "#0d0d0d"
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Macros & Automation"
                            color: "#666"
                            font.pixelSize: 32
                        }
                    }

                    // Application Settings
                    ApplicationSettingsView {
                    }

                    // Statistics & Reporting (placeholder)
                    Rectangle {
                        color: "#0d0d0d"
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Statistics & Reporting"
                            color: "#666"
                            font.pixelSize: 32
                        }
                    }
                }
            }
        }
    }
}
