import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
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
                    height: 400
                    color: "#0d0d0d"
                    radius: 12


                    Label {
                        text: "Audio & Devices"
                        color: "#EDEDED"
                        font.pixelSize: 20
                        anchors.left: panel.left
                        anchors.leftMargin: 22
                        anchors.bottom: panel.top
                        anchors.bottomMargin: 10
                    }

                    Rectangle {
                        id: panel
                        width: parent.width * 0.92
                        height: parent.height * 0.85
                        anchors.centerIn: parent
                        radius: 10
                        color: "#101010"
                        border.color: "#1b1b1b"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 22

                            // ---- Row 1: Mic Input ----
                            RowLayout {
                                spacing: 18
                                Layout.fillWidth: true

                                Label {
                                    text: "Mic Input:"
                                    color: "#EDEDED"
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 110
                                }

                                ComboBox {
                                    Layout.preferredWidth: 220
                                    model: ["Select", "Microphone 1", "Microphone 2"]
                                    currentIndex: 0
                                }

                                DotMeter {
                                    Layout.leftMargin: 10
                                    activeDots: 3
                                }

                                Item { Layout.fillWidth: true } // pushes items left
                            }

                            // ---- Row 2: Speaker Output ----
                            RowLayout {
                                spacing: 18
                                Layout.fillWidth: true

                                Label {
                                    text: "Speaker Output:"
                                    color: "#EDEDED"
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 110
                                }

                                ComboBox {
                                    Layout.preferredWidth: 220
                                    model: ["Select", "Speakers", "Headphones"]
                                    currentIndex: 0
                                }

                                DotMeter {
                                    Layout.leftMargin: 10
                                    activeDots: 3
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // ---- Row 3: Global Volume ----
                            RowLayout {
                                spacing: 18
                                Layout.fillWidth: true

                                Label {
                                    text: "Global Volume:"
                                    color: "#EDEDED"
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 110
                                }

                                Item {
                                    Layout.preferredWidth: 420   // increase this to make slider longer
                                    Layout.preferredHeight: 40

                                    Slider {
                                        id: volumeDbSlider
                                        anchors.fill: parent
                                        from: -80
                                        to: 20
                                        stepSize: 1
                                        value: linearToDb(gainLinear)

                                        onMoved: gainLinear = dbToLinear(value)

                                        // smaller handle + moving text
                                        handle: Rectangle {
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: "#EDEDED"
                                            border.color: "#2A2A2A"
                                            border.width: 1

                                            x: volumeDbSlider.leftPadding + volumeDbSlider.visualPosition *
                                               (volumeDbSlider.availableWidth - width)
                                            y: volumeDbSlider.topPadding + volumeDbSlider.availableHeight / 2 - height / 2

                                            // TEXT that moves with the handle
                                            Label {
                                                text: Math.round(volumeDbSlider.value) + " dB"
                                                color: "#EDEDED"
                                                font.pixelSize: 12
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: 6

                                                // optional: little background so it's readable
                                                background: Rectangle { color: "#1F1F1F"; radius: 4; opacity: 0.85 }
                                                padding: 4
                                            }
                                        }

                                        background: Rectangle {
                                            x: volumeDbSlider.leftPadding
                                            y: volumeDbSlider.topPadding + volumeDbSlider.availableHeight / 2 - height / 2
                                            width: volumeDbSlider.availableWidth
                                            height: 3
                                            radius: 1
                                            color: "#EDEDED"
                                            opacity: 0.9
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }

                            Button {
                                text: "Refresh Devices"
                                onClicked: console.log("Refresh Devices clicked")

                                contentItem: Text {
                                    text: parent.text
                                    color: "#EDEDED"
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
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
                    color: "#0d0d0d"
                    radius: 12

                    property int tabIndex: 0 // 0 system, 1 preference

                    Column {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 22

                        // Top row: Tabs (left) + Undo + Save (right)
                        RowLayout  {
                            width: parent.width
                            height: 60
                            spacing: 20

                            // Tabs group
                            Rectangle {
                                height: 55
                                radius: 8
                                color: "#0f0f0f"
                                border.color: "#4a4a4a"
                                border.width: 1

                                RowLayout  {
                                    anchors.fill: parent
                                    spacing: 0

                                    Button {
                                        text: "System Hotkeys"
                                        width: 200
                                        height: parent.height
                                        checkable: true
                                        checked: hotkeysContent.tabIndex === 0
                                        onClicked: hotkeysContent.tabIndex = 0

                                        contentItem: Text {
                                            text: parent.text
                                            color: "#EDEDED"
                                            font.pixelSize: 15
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            radius: 8
                                            color: "transparent"

                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "#3C7BFF" }
                                                GradientStop { position: 1.0; color: "#B400FF" }
                                            }

                                            // turn gradient on/off
                                            opacity: parent.checked ? 1.0 : 0.0
                                        }
                                    }

                                    Button {
                                        text: "My Preference"
                                        width: 200
                                        height: parent.height
                                        checkable: true
                                        checked: hotkeysContent.tabIndex === 1
                                        onClicked: hotkeysContent.tabIndex = 1

                                        contentItem: Text {
                                            text: parent.text
                                            color: "#EDEDED"
                                            font.pixelSize: 15
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            radius: 8
                                            color: "transparent"

                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "#3C7BFF" }
                                                GradientStop { position: 1.0; color: "#B400FF" }
                                            }

                                            // turn gradient on/off
                                            opacity: parent.checked ? 1.0 : 0.0
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                            // Item { width: parent.width; height: 1 } // push right-side buttons

                            // Undo square button (icon placeholder)
                            Button {
                                width: 30
                                height: 30
                                onClicked: if (backend.undoHotkeyChanges) backend.undoHotkeyChanges()

                                contentItem: Image {
                                    id: resetIcon
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/refresh.svg"
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                MultiEffect {
                                    anchors.fill: undoIcon
                                    source: undoIcon
                                    colorization: 1.0
                                    colorizationColor: "white"
                                }

                                background: Rectangle {
                                    radius: 8
                                    color: "#0f0f0f"
                                    border.color: "#4a4a4a"
                                    border.width: 1
                                }
                            }

                            // Save gradient button
                            Button {
                                width: 170
                                height: 55
                                text: "Save"
                                onClicked: if (backend.saveHotkeys) backend.saveHotkeys()

                                contentItem: Text {
                                    text: parent.text
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    radius: 10
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#2F7BFF" }
                                        GradientStop { position: 1.0; color: "#C800FF" }
                                    }
                                }
                            }
                        }

                        // Content area
                        Loader {
                            width: parent.width
                            sourceComponent: hotkeysContent.tabIndex === 0 ? systemView : prefView
                        }
                    }

                    // ----- Tab pages -----
                    Component {
                        id: systemView
                        HotkeysTable {
                            width: hotkeysContent.width - 56
                            title: "System Hotkeys"
                            model: backend.systemHotkeysModel
                            showHeader: false
                            showWarning: true
                            primaryText: "Reassign"
                            secondaryText: "Reset"

                            onPrimaryClicked: backend.reassignSystem(id)
                            onSecondaryClicked: backend.resetSystem(id)
                        }
                    }

                    Component {
                        id: prefView
                        HotkeysTable {
                            width: hotkeysContent.width - 56
                            title: "My Preference"
                            model: backend.preferenceHotkeysModel
                            showHeader: true
                            showWarning: false
                            primaryText: "Reassign"
                            secondaryText: "Delete"

                            onPrimaryClicked: backend.reassignPreference(id)
                            onSecondaryClicked: backend.deletePreference(id)
                        }
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
