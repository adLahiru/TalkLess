import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qml/components"
import "qml/pages"

ApplicationWindow {
    id: mainWindow
    
    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    // Start in normal windowed mode, not fullscreen
    visibility: Window.Windowed
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

    // Splash Screen Overlay
    Rectangle {
        id: splashScreen
        anchors.fill: parent
        z: 1000  // Always on top
        color: "#000000"
        visible: opacity > 0

        Image {
            anchors.fill: parent
            source: "qrc:/qt/qml/TalkLess/resources/images/splashScreen.png"
            fillMode: Image.PreserveAspectCrop
        }

        // Fade out animation after delay
        Timer {
            id: splashTimer
            interval: 250  // Show splash for 2.5 seconds
            running: true
            onTriggered: {
                splashFadeOut.start()
            }
        }

        NumberAnimation {
            id: splashFadeOut
            target: splashScreen
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 500  // 0.5 second fade out
            easing.type: Easing.OutQuad
        }
    }
}
