import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import "../components"
import "../styles"

Rectangle {
    id: root
    color: Colors.background
    radius: 10

    // Properties for dynamic banner text
    property string bannerMainText: "Microphone Control & Mixer"
    property string bannerSecondaryText: "Manage and trigger your sound clips"

    // Audio level properties
    property real micPeakLevel: 0.0
    property real masterPeakLevel: 0.0
    property real monitorPeakLevel: 0.0

    // Helper function to convert linear amplitude (0.0-1.0) to a perceptually correct
    // meter level (0.0-1.0) using logarithmic/dB scaling.
    // This maps -60dB to 0dB onto 0.0 to 1.0, which matches how professional audio meters work.
    function linearToMeterLevel(linearAmplitude) {
        if (linearAmplitude <= 0.0001)
            return 0.0;  // Below -80dB, show as silent

        // Convert to dB: 20 * log10(amplitude)
        var dB = 20 * Math.log10(linearAmplitude);

        // Map dB range [-60, 0] to [0, 1]
        // -60 dB = 0.0 (minimum), 0 dB = 1.0 (maximum)
        var minDB = -60.0;
        var maxDB = 0.0;
        var normalized = (dB - minDB) / (maxDB - minDB);

        // Clamp to [0, 1]
        return Math.max(0.0, Math.min(1.0, normalized));
    }

    function restartUI() {
        mainLoader.active = false;
        mainLoader.active = true;
    }

    // Store previous device lists to detect changes
    property var previousInputDevices: []
    property var previousOutputDevices: []

    // Signal to notify dropdowns to refresh
    signal deviceRefreshRequested

    // Function to refresh device selections from backend
    function refreshDeviceSelections() {
        // Emit signal to refresh dropdowns inside the loader
        deviceRefreshRequested();
    }

    // Function to check if device list has changed
    function checkDeviceChanges() {
        var currentInputDevices = soundboardService.getInputDevices();
        var currentOutputDevices = soundboardService.getOutputDevices();

        var inputChanged = JSON.stringify(currentInputDevices) !== JSON.stringify(previousInputDevices);
        var outputChanged = JSON.stringify(currentOutputDevices) !== JSON.stringify(previousOutputDevices);

        if (inputChanged || outputChanged) {
            console.log("Audio devices changed, refreshing...");
            previousInputDevices = currentInputDevices;
            previousOutputDevices = currentOutputDevices;
            refreshDeviceSelections();
        }
    }

    // Refresh device selections when view becomes visible
    onVisibleChanged: {
        if (visible) {
            refreshDeviceSelections();
            // Store initial device lists
            previousInputDevices = soundboardService.getInputDevices();
            previousOutputDevices = soundboardService.getOutputDevices();
        }
    }

    // Timer to periodically check for device changes (hotplug detection)
    Timer {
        id: devicePollTimer
        interval: 2000  // Check every 2 seconds
        running: root.visible  // Only run when settings view is visible
        repeat: true
        onTriggered: {
            root.checkDeviceChanges();
        }
    }

    // Connection to handle audioDevicesChanged signal from backend
    Connections {
        target: soundboardService
        function onAudioDevicesChanged() {
            console.log("Audio devices changed signal received");
            root.refreshDeviceSelections();
        }
    }

    // Timer to update audio levels
    Timer {
        id: levelUpdateTimer
        interval: 50  // Update 20 times per second
        running: true
        repeat: true
        onTriggered: {
            root.micPeakLevel = soundboardService.getMicPeakLevel();
            root.masterPeakLevel = soundboardService.getMasterPeakLevel();
            root.monitorPeakLevel = soundboardService.getMonitorPeakLevel();
            // Reset peak levels for next measurement
            soundboardService.resetPeakLevels();
        }
    }

    FileDialog {
        id: exportSettingsDialog
        title: "Export Settings"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            if (soundboardService.exportSettings(selectedFile)) {
                hotkeyManager.showMessage("Settings exported successfully");
            } else {
                hotkeyManager.showMessage("Failed to export settings");
            }
        }
    }

    FileDialog {
        id: importSettingsDialog
        title: "Import Settings"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            if (soundboardService.importSettings(selectedFile)) {
                hotkeyManager.showMessage("Settings imported successfully");
                restartUI();
            } else {
                hotkeyManager.showMessage("Failed to import settings");
            }
        }
    }

    Loader {
        id: mainLoader
        anchors.fill: parent
        sourceComponent: mainContent
        active: true
    }

    Component {
        id: mainContent

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

                onTabSelected: function (index) {
                    contentStack.currentIndex = index;
                }
            }

            // Connection to handle settings import / external changes
            Connections {
                target: soundboardService
                function onSettingsChanged() {
                    console.log("Settings changed, UI updating via bindings");
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

                    // Refresh device selections when this tab becomes active
                    onVisibleChanged: {
                        if (visible && StackLayout.isCurrentItem) {
                            root.refreshDeviceSelections();
                        }
                    }

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
                        height: 480
                        spacing: 20

                        // Left Panel: Input Device & Mic Capture
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 480
                            color: Colors.panelBg
                            radius: 16

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 24
                                spacing: 20

                                // Title
                                Text {
                                    text: "Input Device & Mic Capture"
                                    color: Colors.textPrimary
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSizeLarge
                                    font.weight: Font.DemiBold
                                }

                                // Select Input Dropdown - using DropdownSelector
                                DropdownSelector {
                                    id: inputDeviceDropdown
                                    Layout.fillWidth: true
                                    icon: "🎤"
                                    placeholder: "Select Input Device"

                                    selectedId: soundboardService?.selectedCaptureDeviceId ?? ""

                                    // initial can be empty; we’ll fill on open
                                    model: []

                                    Component.onCompleted: {
                                        model = soundboardService?.getInputDevices() ?? [];
                                    }

                                    Connections {
                                        target: root
                                        function onDeviceRefreshRequested() {
                                            inputDeviceDropdown.model = soundboardService?.getInputDevices() ?? [];
                                            inputDeviceDropdown.selectedId = soundboardService?.selectedCaptureDeviceId ?? "";
                                        }
                                    }

                                    onAboutToOpen: {
                                        model = soundboardService.getInputDevices();
                                    }

                                    onItemSelected: function (id, name) {
                                        console.log("Input device selected:", name, "(id:", id, ")");
                                        soundboardService.setInputDevice(id);
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
                                        color: alwaysOnToggle.isOn ? Colors.success : Colors.surfaceLight

                                        property bool isOn: soundboardService?.micEnabled ?? false
                                        onIsOnChanged: {
                                            if (soundboardService && isOn !== soundboardService.micEnabled)
                                                soundboardService.setMicEnabled(isOn);
                                        }

                                        // Listen for backend changes to update the toggle
                                        Connections {
                                            target: soundboardService
                                            function onSettingsChanged() {
                                                if (soundboardService) {
                                                    alwaysOnToggle.isOn = soundboardService.micEnabled;
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: alwaysOnToggle.isOn ? Colors.textPrimary : Colors.border
                                            x: alwaysOnToggle.isOn ? parent.width - width - 3 : 3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: alwaysOnToggle.isOn = !alwaysOnToggle.isOn
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Always-On Mic"
                                        color: Colors.textPrimary
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 15
                                    }
                                }

                                // Test Mic Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    color: Colors.surface
                                    radius: 12
                                    border.width: 1
                                    border.color: Colors.border

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Text {
                                            text: "Test Mic"
                                            color: Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: Typography.fontSizeMedium
                                            font.weight: Font.Medium
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: console.log("Test mic clicked")
                                    }
                                }

                                // Noise Cancellation Section
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Layout.topMargin: 8

                                    Text {
                                        text: "Noise Cancellation"
                                        color: Colors.textPrimary
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: Typography.fontSizeMedium
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        text: "Reduce background noise from your microphone"
                                        color: Colors.textSecondary
                                        font.pixelSize: Typography.fontSizeSmall
                                    }

                                    // Noise Cancellation Level Selector
                                    RowLayout {
                                        id: noiseLevelSelector
                                        Layout.fillWidth: true
                                        spacing: 8

                                        property var levelNames: soundboardService?.getNoiseSuppressionLevelNames() ?? ["Off", "Low", "Moderate", "High", "Very High"]
                                        property int currentLevel: soundboardService?.noiseSuppressionLevel ?? 2

                                        // Update when settings change
                                        Connections {
                                            target: soundboardService
                                            function onSettingsChanged() {
                                                noiseLevelSelector.currentLevel = soundboardService?.noiseSuppressionLevel ?? 2;
                                            }
                                        }

                                        Repeater {
                                            model: noiseLevelSelector.levelNames

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 36
                                                radius: 8

                                                property bool isActive: index === noiseLevelSelector.currentLevel

                                                color: isActive ? Colors.accent : Colors.surface
                                                border.width: isActive ? 2 : 1
                                                border.color: isActive ? Colors.accentLight : Colors.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: parent.isActive ? Colors.textOnAccent : Colors.textPrimary
                                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                                    font.pixelSize: Typography.fontSizeSmall
                                                    font.weight: parent.isActive ? Font.DemiBold : Font.Normal
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        console.log("Noise cancellation level set to:", index, modelData);
                                                        soundboardService.setNoiseSuppressionLevel(index);
                                                    }
                                                }

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }

                                                Behavior on border.width {
                                                    NumberAnimation { duration: 150 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Right Panel: Mixer Controls
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 480
                            color: Colors.surface
                            radius: Theme.radiusLarge

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 24
                                spacing: 10

                                // Title
                                Text {
                                    text: "Mixer Controls"
                                    color: Colors.textPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: Typography.fontSizeLarge
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
                                            color: Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: Typography.fontSizeMedium
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // TriangleSlider - connected to backend
                                        TriangleSlider {
                                            id: micLevelSlider
                                            Layout.fillWidth: true
                                            from: -60
                                            to: 0
                                            value: soundboardService?.micGainDb ?? 0
                                            unit: "dB"

                                            onSliderMoved: function (newValue) {
                                                if (soundboardService)
                                                    soundboardService.setMicGainDb(newValue);
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Adjust how loud your mic is in the output mix"
                                        color: Colors.textSecondary
                                        font.pixelSize: Typography.fontSizeSmall
                                    }
                                }

                                // Leveling Intensity - linked to mic peak level
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    // Calculate how many squares should be lit based on mic peak level
                                    // Using logarithmic (dB) scaling for perceptually correct display
                                    property int activeSquares: Math.min(13, Math.floor(root.linearToMeterLevel(root.micPeakLevel) * 13))

                                    // Label and squares on same row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 20

                                        // Label aligned with squares
                                        Text {
                                            text: "Mic Level Meter:"
                                            color: Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: Typography.fontSizeMedium
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Spacer to push squares to the right
                                        Item {
                                            Layout.fillWidth: true
                                        }

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
                                                                if (index >= 10)
                                                                    return Colors.error;  // Red for clipping
                                                                if (index >= 8)
                                                                    return Colors.warning;   // Orange/yellow for high
                                                                return Colors.success;  // Green for normal
                                                            }
                                                            return Colors.border;  // Dark gray for inactive
                                                        }

                                                        required property int index

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: 50
                                                            }
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
                                                    color: Colors.textSecondary
                                                    font.pixelSize: Typography.fontSizeSmall
                                                }

                                                Text {
                                                    anchors.right: parent.right
                                                    text: "High"
                                                    color: Colors.textSecondary
                                                    font.pixelSize: Typography.fontSizeSmall
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Shows real-time microphone input level"
                                        color: Colors.textSecondary
                                        font.pixelSize: Typography.fontSizeSmall
                                    }
                                }

                                // Output Mic + Soundboard Toggle
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    Text {
                                        text: "Output Mic + Soundboard:"
                                        color: Colors.textPrimary
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: Typography.fontSizeMedium
                                    }

                                    // Toggle button - green when on, white/gray when off
                                    Rectangle {
                                        id: outputToggle
                                        width: 52
                                        height: 28
                                        radius: 14
                                        color: outputToggle.isOn ? Colors.success : Colors.surfaceLight

                                        property bool isOn: soundboardService?.micPassthroughEnabled ?? false
                                        onIsOnChanged: {
                                            if (soundboardService && isOn !== soundboardService.micPassthroughEnabled)
                                                soundboardService.setMicPassthroughEnabled(isOn);
                                        }

                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: outputToggle.isOn ? Colors.textPrimary : Colors.border
                                            x: outputToggle.isOn ? parent.width - width - 3 : 3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: 150
                                                }
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
                                        color: Colors.textSecondary
                                        font.pixelSize: Typography.fontSizeSmall
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: "Send mixed mic + soundboard audio to output device"
                                    color: Colors.textSecondary
                                    font.pixelSize: Typography.fontSizeSmall
                                }

                                // Mic ↔ Soundboard Balance - using BalanceSlider component
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2  // Tighter spacing

                                    Text {
                                        text: "Mic ↔ Soundboard Balance"
                                        color: Colors.textPrimary
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: Typography.fontSizeMedium
                                    }

                                    BalanceSlider {
                                        Layout.fillWidth: true
                                        leftLabel: "0% mic"
                                        rightLabel: "100% soundboard"
                                        value: soundboardService?.micSoundboardBalance ?? 0.5
                                        onBalanceChanged: newValue => {
                                            if (soundboardService)
                                                soundboardService.setMicSoundboardBalance(newValue);
                                        }
                                    }

                                    Text {
                                        text: "Adjust how much mic vs. audio plays in the mix"
                                        color: Colors.textSecondary
                                        font.pixelSize: Typography.fontSizeSmall
                                    }
                                }
                            }
                        }
                    }
                    // Advanced Audio Settings Section
                    ColumnLayout {
                        id: advancedAudioSection
                        width: parent.width - 80  // Account for left and right margins
                        x: 40
                        y: microphoneContent.y + microphoneContent.height + 40  // More top margin
                        spacing: 20

                        // Title
                        Text {
                            text: "Advanced Audio Settings"
                            color: Colors.textPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: Typography.fontSizeLarge
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
                                    color: Colors.textPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                // Sample Rate Dropdown
                                DropdownSelector {
                                    id: sampleRateDropdown
                                    Layout.preferredWidth: 200
                                    height: 40
                                    placeholder: "Select Sample Rate"
                                    selectedId: (soundboardService?.sampleRate ?? 48000).toString()
                                    model: [
                                        {
                                            id: "44100",
                                            name: "44.1 kHz"
                                        },
                                        {
                                            id: "48000",
                                            name: "48 kHz"
                                        },
                                        {
                                            id: "96000",
                                            name: "96 kHz"
                                        }
                                    ]
                                    onItemSelected: function (id, name) {
                                        soundboardService.setSampleRate(parseInt(id));
                                    }
                                }
                            }

                            // Channels
                            RowLayout {
                                spacing: 12

                                Text {
                                    text: "Channels:"
                                    color: Colors.textPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                // Channels Dropdown
                                DropdownSelector {
                                    id: channelsDropdown
                                    Layout.preferredWidth: 200
                                    height: 40
                                    placeholder: "Select Channels"
                                    selectedId: (soundboardService?.audioChannels ?? 2).toString()
                                    model: [
                                        {
                                            id: "1",
                                            name: "Mono"
                                        },
                                        {
                                            id: "2",
                                            name: "Stereo"
                                        }
                                    ]
                                    onItemSelected: function (id, name) {
                                        soundboardService.setAudioChannels(parseInt(id));
                                    }
                                }
                            }
                        }

                        // Row 2: Buffer Size and Latency
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 40

                            RowLayout {
                                spacing: 12

                                Text {
                                    text: "Buffer Size:"
                                    color: Colors.textPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                // Buffer Size Dropdown
                                DropdownSelector {
                                    id: bufferSizeDropdown
                                    Layout.preferredWidth: 200
                                    placeholder: "Select Buffer Size"
                                    openUpward: true
                                    selectedId: (soundboardService?.bufferSizeFrames ?? 1024).toString()
                                    model: [
                                        {
                                            id: "256",
                                            name: "256 samples (Low latency)"
                                        },
                                        {
                                            id: "512",
                                            name: "512 samples"
                                        },
                                        {
                                            id: "1024",
                                            name: "1024 samples (Recommended)"
                                        },
                                        {
                                            id: "2048",
                                            name: "2048 samples"
                                        },
                                        {
                                            id: "4096",
                                            name: "4096 samples (High stability)"
                                        }
                                    ]
                                    onItemSelected: function (id, name) {
                                        soundboardService.setBufferSizeFrames(parseInt(id));
                                    }
                                }
                            }

                            // Buffer Periods
                            RowLayout {
                                spacing: 12

                                Text {
                                    text: "Buffer Periods:"
                                    color: Colors.textPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 14
                                }

                                // Buffer Periods Dropdown
                                DropdownSelector {
                                    id: bufferPeriodsDropdown
                                    Layout.preferredWidth: 200
                                    placeholder: "Select Periods"
                                    openUpward: true
                                    selectedId: (soundboardService?.bufferPeriods ?? 3).toString()
                                    model: [
                                        {
                                            id: "2",
                                            name: "2 periods (Low latency)"
                                        },
                                        {
                                            id: "3",
                                            name: "3 periods (Recommended)"
                                        },
                                        {
                                            id: "4",
                                            name: "4 periods (High stability)"
                                        }
                                    ]
                                    onItemSelected: function (id, name) {
                                        soundboardService.setBufferPeriods(parseInt(id));
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            // Note about restarting
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                text: "⚠ Changes require app restart to take effect"
                                color: Colors.textSecondary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                font.italic: true
                            }

                            Button {
                                text: "Restart Now"
                                Layout.preferredWidth: 120
                                onClicked: {
                                    soundboardService.restartApplication();
                                }
                            }
                        }
                    }
                }

                // Tab 1: Language & Theme
                Flickable {
                    id: languageFlickable
                    contentWidth: width
                    contentHeight: languageContentLayout.implicitHeight + 40
                    clip: true

                    ColumnLayout {
                        id: languageContentLayout
                        width: parent.width - 40
                        x: 20
                        y: 20
                        spacing: 24

                        RowLayout {
                            spacing: 24
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignTop

                            // Left Pane: Theme & Language
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignTop
                                color: Colors.surface
                                radius: 16
                                border.color: Colors.surfaceHighlight

                                ColumnLayout {
                                    id: leftPaneColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 20
                                    spacing: 20

                                    ColumnLayout {
                                        spacing: 8
                                        Text {
                                            text: "Language Selection"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        DropdownSelector {
                                            id: langDropdown
                                            Layout.fillWidth: true
                                            model: [
                                                {
                                                    id: "English",
                                                    name: "English",
                                                    isDefault: true
                                                },
                                                {
                                                    id: "Spanish",
                                                    name: "Spanish"
                                                }
                                            ]
                                            selectedId: soundboardService?.language ?? "English"
                                            onItemSelected: id => {
                                                if (soundboardService)
                                                    soundboardService.setLanguage(id);
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 12
                                        Text {
                                            text: "Theme Mode"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        RowLayout {
                                            spacing: 20
                                            Repeater {
                                                model: [
                                                    {
                                                        label: "Light",
                                                        value: "light"
                                                    },
                                                    {
                                                        label: "Dark",
                                                        value: "dark"
                                                    }
                                                ]
                                                delegate: Item {
                                                    required property var modelData
                                                    implicitWidth: themeOptionRow.implicitWidth
                                                    implicitHeight: themeOptionRow.implicitHeight

                                                    RowLayout {
                                                        id: themeOptionRow
                                                        spacing: 8
                                                        Rectangle {
                                                            width: 16
                                                            height: 16
                                                            radius: 8
                                                            color: "transparent"
                                                            border.color: Colors.textPrimary
                                                            border.width: 1
                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: 8
                                                                height: 8
                                                                radius: 4
                                                                color: Colors.accent
                                                                // Check case-insensitive to be safe, or direct match
                                                                visible: (soundboardService?.theme ?? "dark").toLowerCase() === modelData.value
                                                            }
                                                        }
                                                        Text {
                                                            text: modelData.label
                                                            color: Colors.textPrimary
                                                            font.pixelSize: 14
                                                        }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            if (soundboardService)
                                                                soundboardService.setTheme(modelData.value);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 12
                                        Text {
                                            text: "Base Theme Color"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            text: "Choose your primary accent color for buttons, highlights, and icons."
                                            color: Colors.textSecondary
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }
                                        RowLayout {
                                            spacing: 12
                                            Repeater {
                                                model: ["#3B82F6", "#EF4444", "#D946EF", "#22C55E", "#EAB308", "#06B6D4", "#F97316"]
                                                delegate: Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 16
                                                    color: modelData
                                                    border.color: Colors.textPrimary
                                                    border.width: (soundboardService?.accentColor ?? "") === modelData ? 2 : 0
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            if (soundboardService)
                                                                soundboardService.setAccentColor(modelData);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 8
                                        Text {
                                            text: "Custom Color Picker"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        RowLayout {
                                            spacing: 8
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 36
                                                color: Colors.background
                                                radius: 6
                                                border.color: Colors.surfaceHighlight
                                                TextInput {
                                                    id: customColorInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: Colors.textPrimary
                                                    font.pixelSize: 13
                                                    text: soundboardService?.accentColor ?? "#3B82F6"
                                                    onEditingFinished: {
                                                        if (soundboardService)
                                                            soundboardService.setAccentColor(text);
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                width: 60
                                                height: 36
                                                color: Colors.surfaceHighlight
                                                radius: 6
                                                border.color: Colors.surfaceHighlight
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Apply"
                                                    color: Colors.textPrimary
                                                    font.pixelSize: 12
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (soundboardService)
                                                            soundboardService.setAccentColor(customColorInput.text);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Right Pane: Slot Size & Preview
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignTop
                                color: Colors.surface
                                radius: 16
                                border.color: Colors.surfaceHighlight

                                ColumnLayout {
                                    id: rightPaneColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 20
                                    spacing: 24

                                    ColumnLayout {
                                        spacing: 12
                                        Text {
                                            text: "Slot Size"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        RowLayout {
                                            spacing: 12
                                            Text {
                                                text: "Small"
                                                color: Colors.textSecondary
                                                font.pixelSize: 12
                                            }
                                            Slider {
                                                id: slotSizeSlider
                                                Layout.fillWidth: true
                                                from: 0.5
                                                to: 1.5
                                                stepSize: 0  // Continuous slider
                                                value: soundboardService?.slotSizeScale ?? 1.0
                                                onMoved: {
                                                    if (soundboardService)
                                                        soundboardService.setSlotSizeScale(value);
                                                }
                                            }
                                            Text {
                                                text: "Large"
                                                color: Colors.textSecondary
                                                font.pixelSize: 12
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 12
                                        Text {
                                            text: "Slot Size Presets"
                                            color: Colors.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        Repeater {
                                            model: [
                                                {
                                                    name: "Compact",
                                                    scale: 0.7
                                                },
                                                {
                                                    name: "Standard",
                                                    scale: 1.0
                                                },
                                                {
                                                    name: "Comfortable",
                                                    scale: 1.3
                                                }
                                            ]
                                            delegate: Item {
                                                required property var modelData
                                                implicitWidth: slotSizeOptionRow.implicitWidth
                                                implicitHeight: slotSizeOptionRow.implicitHeight

                                                RowLayout {
                                                    id: slotSizeOptionRow
                                                    spacing: 10
                                                    Rectangle {
                                                        width: 16
                                                        height: 16
                                                        radius: 8
                                                        color: "transparent"
                                                        border.color: Colors.textPrimary
                                                        border.width: 1
                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: 8
                                                            height: 8
                                                            radius: 4
                                                            color: Colors.accent
                                                            visible: Math.abs((soundboardService?.slotSizeScale ?? 1.0) - modelData.scale) < 0.1
                                                        }
                                                    }
                                                    Text {
                                                        text: modelData.name
                                                        color: Colors.textPrimary
                                                        font.pixelSize: 14
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (soundboardService)
                                                            soundboardService.setSlotSizeScale(modelData.scale);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 12
                                        Text {
                                            text: "Preview"
                                            color: Colors.textSecondary
                                            font.pixelSize: 12
                                        }

                                        // Use actual ClipTile component for accurate preview
                                        // Size matches SoundboardView: baseWidth=180, aspect ratio 111:79
                                        ClipTile {
                                            id: previewTile
                                            readonly property real previewBaseWidth: 180
                                            readonly property real previewAspectRatio: 79 / 111
                                            Layout.preferredWidth: previewBaseWidth * (soundboardService?.slotSizeScale ?? 1.0)
                                            Layout.preferredHeight: previewBaseWidth * previewAspectRatio * (soundboardService?.slotSizeScale ?? 1.0)
                                            title: "Morning"
                                            hotkeyText: "Alt+Shift+M"
                                            selected: false
                                            showActions: false
                                            isPlaying: false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Tab 2: Audio & Devices
                Flickable {
                    contentWidth: width
                    contentHeight: audioContent.height
                    clip: true

                    // Refresh device selections when this tab becomes active
                    onVisibleChanged: {
                        if (visible && StackLayout.isCurrentItem) {
                            root.refreshDeviceSelections();
                        }
                    }

                    Rectangle {
                        id: audioContent
                        width: parent.width
                        height: 400
                        color: Colors.background
                        radius: 12

                        Label {
                            text: "Audio & Devices"
                            color: Colors.textPrimary
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
                            color: Colors.surface
                            border.color: Colors.surfaceHighlight

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 22
                                spacing: 22

                                // ---- Row 2: Speaker Output ----
                                RowLayout {
                                    spacing: 18
                                    Layout.fillWidth: true

                                    Label {
                                        text: "Speaker Output:"
                                        color: Colors.textPrimary
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 110
                                    }

                                    DropdownSelector {
                                        id: speakerOutputDropdown
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 180
                                        Layout.maximumWidth: 320
                                        placeholder: "Select Output Device"
                                        selectedId: soundboardService?.selectedPlaybackDeviceId ?? ""

                                        // initial can be empty; we’ll fill on open
                                        model: []

                                        Component.onCompleted: {
                                            model = soundboardService?.getOutputDevices() ?? [];
                                        }

                                        Connections {
                                            target: root
                                            function onDeviceRefreshRequested() {
                                                speakerOutputDropdown.model = soundboardService?.getOutputDevices() ?? [];
                                                speakerOutputDropdown.selectedId = soundboardService?.selectedPlaybackDeviceId ?? "";
                                            }
                                        }

                                        onAboutToOpen: {
                                            model = soundboardService.getOutputDevices();
                                        }

                                        onItemSelected: function (id, name) {
                                            console.log("Speaker output selected:", name);
                                            soundboardService.setOutputDevice(id);
                                        }
                                    }

                                    DotMeter {
                                        Layout.leftMargin: 10
                                        // Using logarithmic (dB) scaling for perceptually correct display
                                        activeDots: Math.floor(root.linearToMeterLevel(root.masterPeakLevel) * 10)
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                // Monitor output device
                                RowLayout {
                                    spacing: 18
                                    Layout.fillWidth: true

                                    Label {
                                        text: "Monitor Output:"
                                        color: Colors.textPrimary
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 110
                                    }

                                    DropdownSelector {
                                        id: secondOutputDropdown
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 180
                                        Layout.maximumWidth: 320
                                        placeholder: "Select Monitor Device"

                                        selectedId: soundboardService?.selectedMonitorDeviceId ?? ""

                                        model: []

                                        Component.onCompleted: {
                                            model = soundboardService?.getOutputDevices() ?? [];
                                        }

                                        Connections {
                                            target: root
                                            function onDeviceRefreshRequested() {
                                                secondOutputDropdown.model = soundboardService.getOutputDevices();
                                                secondOutputDropdown.selectedId = soundboardService.selectedMonitorDeviceId;
                                            }
                                        }

                                        onAboutToOpen: {
                                            model = soundboardService.getOutputDevices();
                                        }

                                        onItemSelected: function (id, name) {
                                            console.log("Monitor output selected:", name);
                                            soundboardService.setMonitorOutputDevice(id);
                                        }
                                    }

                                    DotMeter {
                                        Layout.leftMargin: 10
                                        // Using logarithmic (dB) scaling for perceptually correct display
                                        activeDots: Math.floor(root.linearToMeterLevel(root.monitorPeakLevel) * 10)
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                // ---- Row 3: Global Volume ----
                                RowLayout {
                                    spacing: 18
                                    Layout.fillWidth: true

                                    Label {
                                        text: "Master Volume:"
                                        color: Colors.textPrimary
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
                                            value: soundboardService?.masterGainDb ?? 0

                                            onMoved: {
                                                if (soundboardService)
                                                    soundboardService.setMasterGainDb(value);
                                            }

                                            handle: Rectangle {
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: Colors.textPrimary
                                                border.color: Colors.surfaceHighlight
                                                border.width: 1

                                                x: masterVolumeSlider.leftPadding + masterVolumeSlider.visualPosition * (masterVolumeSlider.availableWidth - width)
                                                y: masterVolumeSlider.topPadding + masterVolumeSlider.availableHeight / 2 - height / 2

                                                Label {
                                                    text: Math.round(masterVolumeSlider.value) + " dB"
                                                    color: Colors.textPrimary
                                                    font.pixelSize: 12
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.top
                                                    anchors.bottomMargin: 6

                                                    background: Rectangle {
                                                        color: Colors.surfaceHighlight
                                                        radius: 4
                                                        opacity: 0.85
                                                    }
                                                    padding: 4
                                                }
                                            }

                                            background: Rectangle {
                                                x: masterVolumeSlider.leftPadding
                                                y: masterVolumeSlider.topPadding + masterVolumeSlider.availableHeight / 2 - height / 2
                                                width: masterVolumeSlider.availableWidth
                                                height: 3
                                                radius: 1
                                                color: Colors.textPrimary
                                                opacity: 0.9
                                            }
                                        }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                Button {
                                    id: refreshButton
                                    text: "Refresh Devices"
                                    onClicked: {
                                        soundboardService.refreshAudioDevices();
                                        root.refreshDeviceSelections();
                                    }

                                    background: Rectangle {
                                        color: parent.hovered ? Colors.surfaceLight : Colors.surface
                                        radius: 8
                                        border.color: Colors.border
                                        border.width: 1
                                    }

                                    contentItem: Text {
                                        text: refreshButton.text
                                        color: Colors.textPrimary
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
                        color: Colors.background
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
                            RowLayout {
                                width: parent.width
                                height: 60
                                spacing: 20

                                // Tabs group
                                Rectangle {
                                    height: 55
                                    radius: 8
                                    color: Colors.surface
                                    border.color: Colors.surfaceHighlight
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        Button {
                                            id: systemHotkeysButton
                                            text: "System Hotkeys"
                                            width: 200
                                            height: parent.height
                                            // Manual active state management to avoid binding loops
                                            property bool isActive: hotkeysContent.tabIndex === 0

                                            onClicked: hotkeysContent.tabIndex = 0

                                            contentItem: Text {
                                                text: systemHotkeysButton.text
                                                color: systemHotkeysButton.isActive ? Colors.textOnPrimary : Colors.textSecondary
                                                font.pixelSize: 15
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                radius: 8
                                                layer.enabled: true

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

                                                // turn gradient on/off
                                                opacity: systemHotkeysButton.isActive ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 150
                                                    }
                                                }
                                            }
                                        }

                                        Button {
                                            id: myPreferenceButton
                                            text: "My Preference"
                                            width: 200
                                            height: parent.height
                                            // Manual active state management
                                            property bool isActive: hotkeysContent.tabIndex === 1

                                            onClicked: hotkeysContent.tabIndex = 1

                                            contentItem: Text {
                                                text: myPreferenceButton.text
                                                color: myPreferenceButton.isActive ? Colors.textOnPrimary : Colors.textSecondary
                                                font.pixelSize: 15
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                radius: 8
                                                layer.enabled: true

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

                                                // turn gradient on/off
                                                opacity: myPreferenceButton.isActive ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 150
                                                    }
                                                }
                                            }
                                        }

                                        Button {
                                            id: soundboardHotkeyButton
                                            text: "Clips Hotkeys"
                                            width: 200
                                            height: parent.height
                                            // Manual active state management to avoid binding loops
                                            property bool isActive: hotkeysContent.tabIndex === 3

                                            onClicked: hotkeysContent.tabIndex = 3

                                            contentItem: Text {
                                                text: soundboardHotkeyButton.text
                                                color: soundboardHotkeyButton.isActive ? Colors.textOnPrimary : Colors.textSecondary
                                                font.pixelSize: 15
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                radius: 8
                                                layer.enabled: true

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

                                                // turn gradient on/off
                                                opacity: soundboardHotkeyButton.isActive ? 1.0 : 0.0

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 150
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Item {Layout.fillWidth: true}
                                Item {
                                    width: parent.width
                                    height: 1
                                } // push right-side buttons

                            }

                            // Content area - HotkeysTable with dynamic height
                            Loader {
                                id: hotkeysTableLoader
                                width: parent.width
                                sourceComponent: {
                                    if (hotkeysContent.tabIndex === 0)
                                        return systemView;
                                    else if (hotkeysContent.tabIndex === 1)
                                        return prefView;
                                    else if (hotkeysContent.tabIndex === 3)
                                        return soundboardView;
                                    return systemView; // fallback
                                }
                            }
                        }

                        // ----- Tab pages -----
                        Component {
                            id: systemView
                            HotkeysTable {
                                width: hotkeysContent.width - 56
                                title: "System Hotkeys"
                                model: hotkeyManager?.systemHotkeysModel ?? null
                                showHeader: false
                                showWarning: true
                                primaryText: "Reassign"
                                secondaryText: "Reset"

                                onPrimaryClicked: {
                                    if (hotkeyManager)
                                        hotkeyManager.reassignSystem(id);
                                }
                                onSecondaryClicked: {
                                    if (hotkeyManager)
                                        hotkeyManager.resetSystem(id);
                                }
                            }
                        }

                        Component {
                            id: prefView
                            HotkeysTable {
                                width: hotkeysContent.width - 56
                                title: "Soundboard Hotkeys"
                                model: hotkeyManager?.preferenceHotkeysModel ?? null
                                showHeader: true
                                showWarning: false
                                primaryText: "Reassign"
                                secondaryText: "Delete"

                                onPrimaryClicked: {
                                    if (hotkeyManager)
                                        hotkeyManager.reassignPreference(id);
                                }
                                onSecondaryClicked: {
                                    if (hotkeyManager)
                                        hotkeyManager.deletePreference(id);
                                }
                            }
                        }

                        Component {
                            id: soundboardView
                            Column {
                                width: hotkeysContent.width - 56
                                spacing: 20

                                // Soundboard Selector
                                RowLayout {
                                    width: parent.width
                                    spacing: 15
                                    Text {
                                        text: "Selected Soundboard:"
                                        color: Colors.textSecondary
                                        font.pixelSize: 14
                                    }

                                    DropdownSelector {
                                        id: clipHotkeyBoardSelector
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 200
                                        placeholder: "Select Soundboard"

                                        property int selectedBoardId: -1

                                        // Load boards
                                        model: soundboardService?.listBoardsForDropdown() ?? []

                                        onItemSelected: function (id, name) {
                                            selectedBoardId = parseInt(id);
                                            clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(selectedBoardId);
                                        }

                                        Component.onCompleted: {
                                            if (soundboardService) {
                                                // Try active board
                                                var activeId = soundboardService.activeBoardId;
                                                if (activeId !== -1) {
                                                    selectedId = activeId.toString();
                                                    selectedBoardId = activeId;
                                                    clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(activeId);
                                                } else {
                                                    // select first
                                                    if (model && model.length > 0) {
                                                        var first = model[0];
                                                        selectedId = first.id.toString();
                                                        selectedBoardId = first.id;
                                                        clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(first.id);
                                                    }
                                                }
                                            }
                                        }

                                        Connections {
                                            target: soundboardService
                                            function onBoardsChanged() {
                                                clipHotkeyBoardSelector.model = soundboardService.listBoardsForDropdown();
                                            }
                                        }
                                    }
                                }

                                HotkeysTable {
                                    id: clipsHotkeyTable
                                    width: parent.width
                                    title: "Clips Hotkeys"
                                    model: []

                                    showHeader: true
                                    showWarning: false
                                    primaryText: "Reassign"
                                    secondaryText: "Unbind"

                                    onPrimaryClicked: {
                                        if (clipHotkeyBoardSelector.selectedBoardId !== -1)
                                            hotkeyManager.reassignClip(clipHotkeyBoardSelector.selectedBoardId, id);
                                    }

                                    onSecondaryClicked: {
                                        if (clipHotkeyBoardSelector.selectedBoardId !== -1) {
                                            var boardId = clipHotkeyBoardSelector.selectedBoardId;
                                            var data = soundboardService.getClipData(boardId, id);
                                            if (data) {
                                                soundboardService.updateClipInBoard(boardId, id, data["title"], "", data["tags"]);
                                                clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(boardId);
                                            }
                                        }
                                    }

                                    Connections {
                                        target: soundboardService
                                        function onActiveClipsChanged() {
                                            if (clipHotkeyBoardSelector.selectedBoardId !== -1) {
                                                clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(clipHotkeyBoardSelector.selectedBoardId);
                                            }
                                        }
                                        function onClipUpdated(boardId, clipId) {
                                            if (boardId === clipHotkeyBoardSelector.selectedBoardId) {
                                                clipsHotkeyTable.model = soundboardService.getClipsForBoardVariant(boardId);
                                            }
                                        }
                                    }
                                }
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
                        color: Colors.surface
                        radius: 12

                        Text {
                            anchors.centerIn: parent
                            text: "AI & Productivity Tools"
                            color: Colors.textPrimary
                            font.pixelSize: Typography.fontSizeLarge
                            font.weight: Font.Medium
                        }
                    }
                }

                // Tab 5: System
                Flickable {
                    contentWidth: width
                    contentHeight: preferencesContent.implicitHeight + 40
                    clip: true

                    ColumnLayout {
                        id: preferencesContent
                        width: parent.width - 40
                        x: 20
                        y: 20
                        spacing: 24

                        // Data Management Section
                        ColumnLayout {
                            spacing: 16
                            Layout.fillWidth: true

                            Text {
                                text: "Data Management"
                                color: Colors.textPrimary
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                color: Colors.surface
                                radius: 16
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 20
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Export & Import Settings"
                                            color: Colors.textPrimary
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            text: "Save or load your application settings (audio devices, volumes, theme)."
                                            color: Colors.textSecondary
                                            font.pixelSize: 12
                                        }
                                    }
                                    RowLayout {
                                        spacing: 12
                                        Rectangle {
                                            width: 120
                                            height: 40
                                            color: Colors.surfaceHighlight
                                            radius: 8
                                            border.color: Colors.surfaceHighlight
                                            Text {
                                                anchors.centerIn: parent
                                                text: "📤 Export"
                                                color: Colors.textPrimary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: exportSettingsDialog.open()
                                            }
                                        }
                                        Rectangle {
                                            width: 120
                                            height: 40
                                            color: Colors.surfaceHighlight
                                            radius: 8
                                            border.color: Colors.surfaceHighlight
                                            Text {
                                                anchors.centerIn: parent
                                                text: "📥 Import"
                                                color: Colors.textPrimary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: importSettingsDialog.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Factory Reset Section
                        ColumnLayout {
                            spacing: 16
                            Layout.fillWidth: true

                            Text {
                                text: "Factory Reset"
                                color: Colors.textPrimary
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                color: Colors.surface
                                radius: 16
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 20
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Reset All Settings & Hotkeys"
                                            color: Colors.textPrimary
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            text: "This will restore everything to defaults. This action cannot be undone."
                                            color: Colors.textSecondary
                                            font.pixelSize: 12
                                        }
                                    }
                                    Rectangle {
                                        width: 140
                                        height: 40
                                        color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2)
                                        radius: 8
                                        border.color: Colors.error
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⚠ Reset All"
                                            color: Colors.error
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: resetConfirmDialog.open()
                                        }
                                    }
                                }
                            }
                        }

                        MessageDialog {
                            id: resetConfirmDialog
                            title: "Confirm Factory Reset"
                            text: "Are you sure you want to reset all settings and hotkeys? This will restore everything to factory defaults."
                            buttons: MessageDialog.Yes | MessageDialog.No
                            onAccepted: {
                                console.log("Factory reset confirmed");
                                soundboardService.resetSettings();
                                hotkeyManager.resetAllHotkeys();
                                hotkeyManager.showMessage("Application has been reset to defaults.");
                                root.restartUI();
                            }
                        }

                        Item {
                            Layout.preferredHeight: 40
                        } // Spacer
                    }
                }
            }
        }
    }
}
