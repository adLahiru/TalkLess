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
    
    // Audio level properties
    property real micPeakLevel: 0.0
    property real masterPeakLevel: 0.0
    property real monitorPeakLevel: 0.0
    
    // Timer to update audio levels
    Timer {
        id: levelUpdateTimer
        interval: 50  // Update 20 times per second
        running: true
        repeat: true
        onTriggered: {
            root.micPeakLevel = soundboardService.getMicPeakLevel()
            root.masterPeakLevel = soundboardService.getMasterPeakLevel()
            root.monitorPeakLevel = soundboardService.getMonitorPeakLevel()
            // Reset peak levels for next measurement
            soundboardService.resetPeakLevels()
        }
    }

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

                            // Select Input Dropdown - using DropdownSelector
                            DropdownSelector {
                                id: inputDeviceDropdown
                                Layout.fillWidth: true
                                icon: "🎤"
                                placeholder: "Select Input Device"
                                model: soundboardService.getInputDevices()
                                
                                Component.onCompleted: {
                                    // Set default device if available
                                    var devices = soundboardService.getInputDevices()
                                    for (var i = 0; i < devices.length; i++) {
                                        if (devices[i].isDefault) {
                                            selectedId = devices[i].id
                                            selectedValue = devices[i].name
                                            break
                                        }
                                    }
                                }
                                
                                onItemSelected: function(id, name) {
                                    console.log("Input device selected:", name, "(id:", id, ")")
                                    soundboardService.setInputDevice(id)
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

                                    property bool isOn: soundboardService.isMicEnabled()
                                    onIsOnChanged: soundboardService.setMicEnabled(isOn)

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
                                    Text {
                                        text: "Mic Level:"
                                        color: "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // TriangleSlider - connected to backend
                                    TriangleSlider {
                                        id: micLevelSlider
                                        Layout.fillWidth: true
                                        from: -60
                                        to: 0
                                        value: soundboardService.micGainDb()
                                        unit: "dB"
                                        
                                        onSliderMoved: function(newValue) {
                                            soundboardService.setMicGainDb(newValue)
                                        }
                                    }
                                }

                                Text {
                                    text: "Adjust how loud your mic is in the output mix"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }

                            // Leveling Intensity - linked to mic peak level
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                // Calculate how many squares should be lit based on mic peak (0.0-1.0)
                                // We use 12 squares, so multiply peak by 12
                                property int activeSquares: Math.min(12, Math.floor(root.micPeakLevel * 12))

                                // Label and squares on same row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    // Label aligned with squares
                                    Text {
                                        text: "Mic Level Meter:"
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
                                                    // Color based on position and mic level
                                                    // Green for active (mic peak), gray for inactive
                                                    // Last 2 squares turn red when clipping (near max)
                                                    color: {
                                                        if (index < parent.parent.parent.parent.activeSquares) {
                                                            if (index >= 10) return "#EF4444"  // Red for clipping
                                                            if (index >= 8) return "#F59E0B"   // Orange/yellow for high
                                                            return "#22C55E"  // Green for normal
                                                        }
                                                        return "#3A3A3A"  // Dark gray for inactive
                                                    }
                                                    
                                                    required property int index
                                                    
                                                    Behavior on color {
                                                        ColorAnimation { duration: 50 }
                                                    }
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
                                    text: "Shows real-time microphone input level"
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

                                    property bool isOn: soundboardService.isMicPassthroughEnabled()
                                    onIsOnChanged: soundboardService.setMicPassthroughEnabled(isOn)

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
                                    value: soundboardService.getMicSoundboardBalance()
                                    onBalanceChanged: (newValue) => soundboardService.setMicSoundboardBalance(newValue)
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

                            // // ---- Row 1: Mic Input ----
                            // RowLayout {
                            //     spacing: 18
                            //     Layout.fillWidth: true

                            //     Label {
                            //         text: "Mic Input:"
                            //         color: "#EDEDED"
                            //         font.pixelSize: 14
                            //         Layout.preferredWidth: 110
                            //     }

                            //     DropdownSelector {
                            //         id: micInputDropdown
                            //         Layout.preferredWidth: 280
                            //         placeholder: "Select Input Device"
                            //         model: soundboardService.getInputDevices()
                                    
                            //         Component.onCompleted: {
                            //             var devices = soundboardService.getInputDevices()
                            //             for (var i = 0; i < devices.length; i++) {
                            //                 if (devices[i].isDefault) {
                            //                     selectedId = devices[i].id
                            //                     selectedValue = devices[i].name
                            //                     break
                            //                 }
                            //             }
                            //         }
                                    
                            //         onItemSelected: function(id, name) {
                            //             console.log("Mic input selected:", name)
                            //             soundboardService.setInputDevice(id)
                            //         }
                            //     }

                            //     DotMeter {
                            //         Layout.leftMargin: 10
                            //         activeDots: 3
                            //     }

                            //     Item { Layout.fillWidth: true } // pushes items left
                            // }

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

                                DropdownSelector {
                                    id: speakerOutputDropdown
                                    Layout.preferredWidth: 280
                                    placeholder: "Select Output Device"
                                    model: soundboardService.getOutputDevices()
                                    
                                    Component.onCompleted: {
                                        var devices = soundboardService.getOutputDevices()
                                        for (var i = 0; i < devices.length; i++) {
                                            if (devices[i].isDefault) {
                                                selectedId = devices[i].id
                                                selectedValue = devices[i].name
                                                break
                                            }
                                        }
                                    }
                                    
                                    onItemSelected: function(id, name) {
                                        console.log("Speaker output selected:", name)
                                        soundboardService.setOutputDevice(id)
                                    }
                                }

                                DotMeter {
                                    Layout.leftMargin: 10
                                    activeDots: Math.floor(Math.min(1.0, root.masterPeakLevel) * 10)
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Monitor output device
                            RowLayout {
                                spacing: 18
                                Layout.fillWidth: true

                                Label {
                                    text: "Monitor Output:"
                                    color: "#EDEDED"
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 110
                                }

                                DropdownSelector {
                                    id: secondOutputDropdown
                                    Layout.preferredWidth: 280
                                    placeholder: "Select Monitor Device"
                                    model: soundboardService.getOutputDevices()

                                    Component.onCompleted: {
                                        var devices = soundboardService.getOutputDevices()
                                        for (var i = 0; i < devices.length; i++) {
                                            if (devices[i].isDefault) {
                                                selectedId = devices[i].id
                                                selectedValue = devices[i].name
                                                break
                                            }
                                        }
                                    }

                                    onItemSelected: function(id, name) {
                                        console.log("Monitor output selected:", name)
                                        soundboardService.setMonitorOutputDevice(id)
                                    }
                                }

                                DotMeter {
                                    Layout.leftMargin: 10
                                    activeDots: Math.floor(Math.min(1.0, root.monitorPeakLevel) * 10)
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // ---- Row 3: Global Volume ----
                            RowLayout {
                                spacing: 18
                                Layout.fillWidth: true

                                Label {
                                    text: "Master Volume:"
                                    color: "#EDEDED"
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 110
                                }

                                Item {
                                    Layout.preferredWidth: 420
                                    Layout.preferredHeight: 40

                                    Slider {
                                        id: masterVolumeSlider
                                        anchors.fill: parent
                                        from: -60
                                        to: 0
                                        stepSize: 1
                                        value: soundboardService.masterGainDb()

                                        onMoved: {
                                            soundboardService.setMasterGainDb(value)
                                        }

                                        handle: Rectangle {
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: "#EDEDED"
                                            border.color: "#2A2A2A"
                                            border.width: 1

                                            x: masterVolumeSlider.leftPadding + masterVolumeSlider.visualPosition *
                                               (masterVolumeSlider.availableWidth - width)
                                            y: masterVolumeSlider.topPadding + masterVolumeSlider.availableHeight / 2 - height / 2

                                            Label {
                                                text: Math.round(masterVolumeSlider.value) + " dB"
                                                color: "#EDEDED"
                                                font.pixelSize: 12
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: 6

                                                background: Rectangle { color: "#1F1F1F"; radius: 4; opacity: 0.85 }
                                                padding: 4
                                            }
                                        }

                                        background: Rectangle {
                                            x: masterVolumeSlider.leftPadding
                                            y: masterVolumeSlider.topPadding + masterVolumeSlider.availableHeight / 2 - height / 2
                                            width: masterVolumeSlider.availableWidth
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
                                id: refreshButton
                                text: "Refresh Devices"
                                onClicked: console.log("Refresh Devices clicked")

                                contentItem: Text {
                                    text: refreshButton.text
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
                id: hotkeysFlickable
                contentWidth: width
                contentHeight: hotkeysContent.implicitHeight + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                
                // Show scrollbar when needed
                ScrollBar.vertical: ScrollBar {
                    policy: hotkeysFlickable.contentHeight > hotkeysFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }

                Rectangle {
                    id: hotkeysContent
                    width: parent.width - 20  // Leave room for scrollbar
                    implicitHeight: hotkeysColumn.implicitHeight + 56  // Column height + margins
                    color: "#0d0d0d"
                    radius: 12

                    property int tabIndex: 0 // 0 system, 1 preference

                    Column {
                        id: hotkeysColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
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
                                        id: systemHotkeysButton
                                        text: "System Hotkeys"
                                        width: 200
                                        height: parent.height
                                        checkable: true
                                        checked: hotkeysContent.tabIndex === 0
                                        onClicked: hotkeysContent.tabIndex = 0

                                        contentItem: Text {
                                            text: systemHotkeysButton.text
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
                                            opacity: systemHotkeysButton.checked ? 1.0 : 0.0
                                        }
                                    }

                                    Button {
                                        id: myPreferenceButton
                                        text: "My Preference"
                                        width: 200
                                        height: parent.height
                                        checkable: true
                                        checked: hotkeysContent.tabIndex === 1
                                        onClicked: hotkeysContent.tabIndex = 1

                                        contentItem: Text {
                                            text: myPreferenceButton.text
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
                                            opacity: myPreferenceButton.checked ? 1.0 : 0.0
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
                                onClicked: hotkeyManager.undoHotkeyChanges()

                                contentItem: Image {
                                    id: resetIcon
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/actions/ic_refresh.svg"
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
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
                                id: saveButton
                                width: 170
                                height: 55
                                text: "Save"
                                onClicked: hotkeyManager.saveHotkeys()

                                contentItem: Text {
                                    text: saveButton.text
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

                        // Content area - HotkeysTable with dynamic height
                        Loader {
                            id: hotkeysTableLoader
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
                            model: hotkeyManager.systemHotkeysModel
                            showHeader: false
                            showWarning: true
                            primaryText: "Reassign"
                            secondaryText: "Reset"

                            onPrimaryClicked: hotkeyManager.reassignSystem(id)
                            onSecondaryClicked: hotkeyManager.resetSystem(id)
                        }
                    }

                    Component {
                        id: prefView
                        HotkeysTable {
                            width: hotkeysContent.width - 56
                            title: "Soundboard Hotkeys"
                            model: hotkeyManager.preferenceHotkeysModel
                            showHeader: true
                            showWarning: false
                            primaryText: "Reassign"
                            secondaryText: "Delete"

                            onPrimaryClicked: hotkeyManager.reassignPreference(id)
                            onSecondaryClicked: hotkeyManager.deletePreference(id)
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
