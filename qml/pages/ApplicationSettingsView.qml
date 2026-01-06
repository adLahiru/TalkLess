import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0d0d0d"
    radius: 10

    // Properties for dynamic banner text
    property string bannerMainText: "Microphone Control & Mixer"
    property string bannerSecondaryText: "Manage and trigger your sound clips"

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Background Banner at the top
        BackgroundBanner {
            id: banner
            Layout.fillWidth: true
            Layout.preferredHeight: 145
            displayText: root.bannerMainText + "," + root.bannerSecondaryText
        }

        // Tab Selector
        SettingsTabSelector {
            id: tabSelector
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 56

            onTabSelected: function(index) {
                contentStack.currentIndex = index
            }
        }

        // Tab content area with StackLayout
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // Tab 0: Microphone Controller
            Flickable {
                contentWidth: width
                contentHeight: microphoneContent.height
                clip: true

                Rectangle {
                    id: microphoneContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "Microphone Controller"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }

            // Tab 1: Language & Theme
            Flickable {
                contentWidth: width
                contentHeight: languageContent.height
                clip: true

                Rectangle {
                    id: languageContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "Language & Theme"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }

            // Tab 2: Audio & Devices
            Flickable {
                contentWidth: width
                contentHeight: audioContent.height
                clip: true

                Rectangle {
                    id: audioContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "Audio & Devices"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }

            // Tab 3: Hotkeys
            Flickable {
                contentWidth: width
                contentHeight: hotkeysContent.height
                clip: true

                Rectangle {
                    id: hotkeysContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "Hotkeys"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }

            // Tab 4: AI & Productivity Tools
            Flickable {
                contentWidth: width
                contentHeight: aiContent.height
                clip: true

                Rectangle {
                    id: aiContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "AI & Productivity Tools"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }

            // Tab 5: Preferences
            Flickable {
                contentWidth: width
                contentHeight: preferencesContent.height
                clip: true

                Rectangle {
                    id: preferencesContent
                    width: parent.width
                    height: 200
                    color: "#1F1F1F"
                    radius: 12

                    Text {
                        anchors.centerIn: parent
                        text: "Preferences"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}