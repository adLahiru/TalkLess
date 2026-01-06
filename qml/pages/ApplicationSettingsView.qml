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
                contentHeight: advancedAudioSection.y + advancedAudioSection.height + 40
                clip: true

                // Load fonts
                FontLoader {
                    id: poppinsFont
                    source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLEj6Z1JlFc-K.ttf"
                }

                FontLoader {
                    id: interFont
                    source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
                }

                RowLayout {
                    id: microphoneContent
                    width: parent.width - 40
                    x: 20
                    y: 20
                    height: 380
                    spacing: 20

                    // Left Panel: Input Device & Mic Capture
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 380
                        color: "#1A1A1A"
                        radius: 16

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 20

                            // Title
                            Text {
                                text: "Input Device & Mic Capture"
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            // Select Input Dropdown
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                color: "#2A2A2A"
                                radius: 12
                                border.width: 1
                                border.color: "#3A3A3A"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    // Mic icon
                                    Text {
                                        text: "🎤"
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text: "Select Input"
                                        color: "#AAAAAA"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 15
                                        Layout.fillWidth: true
                                    }

                                    // Dropdown arrow
                                    Text {
                                        text: "▼"
                                        color: "#666666"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Select input clicked")
                                }
                            }

                            // Always-On Mic Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // Toggle Switch
                                Rectangle {
                                    id: alwaysOnToggle
                                    width: 52
                                    height: 28
                                    radius: 14
                                    color: alwaysOnToggle.isOn ? "#22C55E" : "#3A3A3A"

                                    property bool isOn: true

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: "#FFFFFF"
                                        x: alwaysOnToggle.isOn ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on x {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: alwaysOnToggle.isOn = !alwaysOnToggle.isOn
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                Text {
                                    text: "Always-On Mic"
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 15
                                }
                            }

                            // Live Mic Volume Meter
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "Live Mic Volume Meter"
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 15
                                }

                                // Volume bar - using VolumeMeterSlider component
                                VolumeMeterSlider {
                                    Layout.fillWidth: true
                                    value: 0.45
                                    dbValue: -15
                                }
                            }

                            // Test Mic Button
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                color: "#2A2A2A"
                                radius: 12
                                border.width: 1
                                border.color: "#3A3A3A"

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Text {
                                        text: "Test Mic"
                                        color: "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Test mic clicked")
                                }
                            }
                        }
                    }

                    // Right Panel: Mixer Controls
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 380
                        color: "#1A1A1A"
                        radius: 16

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10

                            // Title
                            Text {
                                text: "Mixer Controls"
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            // Mic Level - separate text and component
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0  // Closer description

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    // Label aligned with slider bar
                                    // TriangleSlider bar center is vertically centered in 92px height
                                    // But visually the bar is at center.
                                    // Text needs to be vertically centered in the RowLayout to match the centered bar.
                                    Text {
                                        text: "Mic Level:"
                                        color: "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // TriangleSlider - bar is vertically centered
                                    TriangleSlider {
                                        Layout.fillWidth: true
                                        // Internal labels removed, just values
                                        from: -60
                                        to: 0
                                        value: -16
                                        unit: "dB"
                                    }
                                }

                                Text {
                                    text: "Adjust how loud your mic is in the output mix"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }

                            // Leveling Intensity - label and squares on same line
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                // Label and squares on same row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    // Label aligned with squares
                                    Text {
                                        text: "Leveling Intensity:"
                                        color: "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Spacer to push squares to the right
                                    Item { Layout.fillWidth: true }

                                    // Step indicator with Low/High labels - right aligned
                                    Column {
                                        spacing: 4

                                        // 12 squares, 13x13, radius 0
                                        Row {
                                            id: intensitySquares
                                            spacing: 5
                                            Repeater {
                                                model: 12
                                                Rectangle {
                                                    width: 13
                                                    height: 13
                                                    radius: 0
                                                    // Green for active (intensity), gray for inactive
                                                    color: index < 5 ? "#22C55E" : "#AAAAAA"
                                                    
                                                    required property int index
                                                }
                                            }
                                        }

                                        // Low/High labels - fixed width matching squares
                                        Item {
                                            width: (13 * 12) + (5 * 11)  // 12 squares + 11 gaps
                                            height: 14

                                            Text {
                                                anchors.left: parent.left
                                                text: "Low"
                                                color: "#666666"
                                                font.pixelSize: 11
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                text: "High"
                                                color: "#666666"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "Controls how aggressively volume leveling is applied"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }

                            // Output Mic + Soundboard Toggle
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Text {
                                    text: "Output Mic + Soundboard:"
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                // Toggle button - green when on, white/gray when off
                                Rectangle {
                                    id: outputToggle
                                    width: 52
                                    height: 28
                                    radius: 14
                                    color: outputToggle.isOn ? "#22C55E" : "#FFFFFF"

                                    property bool isOn: true

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: outputToggle.isOn ? "#FFFFFF" : "#666666"
                                        x: outputToggle.isOn ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on x {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: outputToggle.isOn = !outputToggle.isOn
                                    }
                                }

                                Text {
                                    text: "ON/OFF"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                text: "Send mixed mic + soundboard audio to output device"
                                color: "#666666"
                                font.pixelSize: 12
                            }

                            // Mic ↔ Soundboard Balance - using BalanceSlider component
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2  // Tighter spacing

                                Text {
                                    text: "Mic ↔ Soundboard Balance"
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                BalanceSlider {
                                    Layout.fillWidth: true
                                    leftLabel: "0% mic"
                                    rightLabel: "100% soundboard"
                                    value: 0.5
                                }

                                Text {
                                    text: "Adjust how much mic vs. audio plays in the mix"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                // Advanced Audio Settings Section
                ColumnLayout {
                    id: advancedAudioSection
                    width: parent.width - 40
                    x: 20
                    y: microphoneContent.y + microphoneContent.height + 40  // More top margin
                    spacing: 16

                    // Title
                    Text {
                        text: "Advanced Audio Settings"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    // Row 1: Sample Rate and Channels
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 40

                        // Sample Rate
                        RowLayout {
                            spacing: 12

                            Text {
                                text: "Sample Rate:"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 14
                            }

                            Rectangle {
                                width: 200
                                height: 40
                                color: "#2A2A2A"
                                radius: 8

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        text: "48 kHz"
                                        color: "#AAAAAA"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "▼"
                                        color: "#666666"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Sample Rate clicked")
                                }
                            }
                        }

                        // Channels
                        RowLayout {
                            spacing: 12

                            Text {
                                text: "Channels:"
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 14
                            }

                            Rectangle {
                                width: 200
                                height: 40
                                color: "#2A2A2A"
                                radius: 8

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12

                                    Text {
                                        text: "Stereo"
                                        color: "#AAAAAA"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "▼"
                                        color: "#666666"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Channels clicked")
                                }
                            }
                        }
                    }

                    // Row 2: Driver Mode
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Driver Mode:"
                            color: "#FFFFFF"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 14
                        }

                        Rectangle {
                            width: 200
                            height: 40
                            color: "#2A2A2A"
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "WASAPI"
                                    color: "#AAAAAA"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "▼"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Driver Mode clicked")
                            }
                        }
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

        // Bottom buttons - Cancel and Save
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 20
            Layout.bottomMargin: 20
            spacing: 12

            Item { Layout.fillWidth: true }  // Spacer to push buttons to right

            // Cancel button
            Rectangle {
                width: 80
                height: 40
                color: "#2A2A2A"
                radius: 8
                border.width: 1
                border.color: "#3A3A3A"

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("Cancel clicked")
                }
            }

            // Save button with gradient
            Rectangle {
                width: 80
                height: 40
                radius: 8

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#3B82F6" }  // Blue
                    GradientStop { position: 1.0; color: "#D946EF" }  // Purple/Magenta
                }

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("Save clicked")
                }
            }
        }
    }
}