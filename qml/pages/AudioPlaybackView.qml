import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"
import TalkLess.Models

Item {
    id: root

    // Signal to request navigation to soundboard for simulation
    signal startSimulationRequested

    // Local model for the dashboard
    ClipsListModel {
        id: dashboardClipsModel
        service: soundboardService
        boardId: -1 // Explicitly start with no board selected
        autoLoadActive: false // Don't auto-load the active board from service
    }

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

        // Tab Selector
        Rectangle {
            id: tabSelector
            Layout.fillWidth: true
            height: 56
            color: "transparent"

            property int currentIndex: 1 // Default to Test Call Simulation

            ListModel {
                id: tabModel
                ListElement {
                    title: "Playback Dashboard"
                }
                ListElement {
                    title: "Test Call Simulation"
                }
            }

            Rectangle {
                anchors.centerIn: tabRow
                width: tabRow.width + 20
                height: 48
                radius: 24
                color: Colors.surfaceDark
            }

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

                        gradient: tabItem.isSelected ? selectedGradient : null
                        color: tabItem.isSelected ? "white" : "transparent"

                        Gradient {
                            id: selectedGradient
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
                                if (!tabItem.isSelected)
                                    tabText.opacity = 0.9;
                            }
                            onExited: {
                                if (!tabItem.isSelected)
                                    tabText.opacity = 0.7;
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }
            }
        }

        // Test Call Simulation Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: tabSelector.currentIndex === 1
            color: Colors.surface
            radius: 12
            border.width: 1
            border.color: Colors.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20

                // Title
                Text {
                    text: "Test Call Simulation"
                    color: Colors.textPrimary
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
                }

                // Start Simulation Button
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 50
                    color: startSimMA.containsMouse ? Colors.surfaceLight : "transparent"
                    border.width: 1
                    border.color: Colors.textSecondary
                    radius: 4

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "▶"
                            color: Colors.textPrimary
                            font.pixelSize: 14
                        }

                        Text {
                            text: "Start Simulation"
                            color: Colors.textPrimary
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: startSimMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            soundboardService.startTestCallSimulation();
                            root.startSimulationRequested();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                Item {
                    height: 10
                    width: 1
                }

                // Record simulation checkbox
                RowLayout {
                    spacing: 10

                    Rectangle {
                        id: recordCheckbox
                        width: 18
                        height: 18
                        radius: 4
                        color: recordCheckbox.checked ? Colors.accent : "transparent"
                        border.width: recordCheckbox.checked ? 0 : 1
                        border.color: Colors.textSecondary

                        property bool checked: true

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Colors.textOnAccent
                            font.pixelSize: 12
                            visible: recordCheckbox.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recordCheckbox.checked = !recordCheckbox.checked
                        }
                    }

                    Text {
                        text: "Record simulation"
                        color: Colors.textSecondary
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recordCheckbox.checked = !recordCheckbox.checked
                        }
                    }
                }

                // Loop playback test checkbox
                RowLayout {
                    spacing: 10

                    Rectangle {
                        id: loopCheckbox
                        width: 18
                        height: 18
                        radius: 4
                        color: loopCheckbox.checked ? Colors.accent : "transparent"
                        border.width: loopCheckbox.checked ? 0 : 1
                        border.color: Colors.textSecondary

                        property bool checked: true

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Colors.textOnAccent
                            font.pixelSize: 12
                            visible: loopCheckbox.checked
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loopCheckbox.checked = !loopCheckbox.checked
                        }
                    }

                    Text {
                        text: "Loop playback test"
                        color: Colors.textSecondary
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loopCheckbox.checked = !loopCheckbox.checked
                        }
                    }
                }

                Item {
                    height: 10
                    width: 1
                }

                // Action buttons row
                RowLayout {
                    spacing: 20

                    // Play Last Recording button
                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 40
                        color: playLastMA.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                        radius: 8
                        border.width: 1
                        border.color: Colors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "▶"
                                color: Colors.accent
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Play Last Recording"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: playLastMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                soundboardService.playLastTestCallRecording();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // Open Recordings Folder button
                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 40
                        color: openFolderMA.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                        radius: 8
                        border.width: 1
                        border.color: Colors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "📂"
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Open Recordings Folder"
                                color: Colors.textPrimary
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: openFolderMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                soundboardService.openTestCallRecordingsFolder();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                // Vertical Spacer
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // Playback Dashboard Card
        Rectangle {
            id: playbackDashboardCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 900
            visible: tabSelector.currentIndex === 0
            color: Colors.surface
            radius: 12
            border.width: 1
            border.color: Colors.border

            // State for selected soundboard
            property int selectedBoardId: -1
            property string selectedBoardName: ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Header row with dropdown
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    z: 50 // Ensure dropdowns appear above content below

                    // Title
                    Text {
                        text: "Playback Dashboard"
                        color: Colors.textPrimary
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Select Soundboard dropdown
                    Rectangle {
                        id: soundboardDropdown
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 40
                        radius: 8
                        color: dropdownMa.containsMouse ? Colors.surfaceLight : Colors.background
                        border.width: 1
                        border.color: Colors.border

                        property bool isOpen: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: playbackDashboardCard.selectedBoardName || "Select Soundboard"
                                color: playbackDashboardCard.selectedBoardName ? Colors.textPrimary : Colors.textSecondary
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            Text {
                                text: soundboardDropdown.isOpen ? "▲" : "▼"
                                color: Colors.textSecondary
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: dropdownMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: soundboardDropdown.isOpen = !soundboardDropdown.isOpen
                        }

                        // Dropdown popup
                        Rectangle {
                            id: dropdownPopup
                            anchors.top: parent.bottom
                            anchors.left: parent.left
                            anchors.topMargin: 4
                            width: parent.width
                            height: Math.min(boardsList.contentHeight + 8, 200)
                            radius: 8
                            color: Colors.surface
                            border.width: 1
                            border.color: Colors.border
                            visible: soundboardDropdown.isOpen
                            z: 100 // High Z to appear above other elements

                            ListView {
                                id: boardsList
                                anchors.fill: parent
                                anchors.margins: 4
                                clip: true
                                model: soundboardService ? soundboardService.boardsDropdownList : []

                                delegate: Rectangle {
                                    id: boardDelegate
                                    width: boardsList.width
                                    height: 36
                                    radius: 6
                                    color: boardItemMa.containsMouse ? Colors.surfaceLight : "transparent"

                                    required property var modelData
                                    required property int index

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: boardDelegate.modelData.name || ""
                                        color: Colors.textPrimary
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: boardItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            playbackDashboardCard.selectedBoardId = boardDelegate.modelData.id;
                                            playbackDashboardCard.selectedBoardName = boardDelegate.modelData.name;
                                            dashboardClipsModel.boardId = boardDelegate.modelData.id;
                                            soundboardDropdown.isOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Board-level Normalization Controls
                Rectangle {
                    id: normalizationPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 8
                    color: Colors.surfaceDark
                    border.width: 1
                    border.color: Colors.border
                    visible: playbackDashboardCard.selectedBoardId >= 0

                    // Normalization state
                    property string normalizeType: "LUFS"
                    property double normalizeTarget: -16.0
                    property bool isNormalizing: false
                    property int normalizedCount: 0
                    property int totalToNormalize: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        // Label
                        Text {
                            text: "🎚 Normalize All Clips"
                            color: Colors.textPrimary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        // Separator
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 32
                            color: Colors.border
                        }

                        // Type selector (LUFS/RMS)
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            radius: 8
                            color: Colors.background
                            border.width: 1
                            border.color: Colors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                Rectangle {
                                    width: 48
                                    height: 30
                                    radius: 6
                                    color: normalizationPanel.normalizeType === "LUFS" ? Colors.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "LUFS"
                                        color: normalizationPanel.normalizeType === "LUFS" ? Colors.textOnAccent : Colors.textSecondary
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            normalizationPanel.normalizeType = "LUFS";
                                            normalizationPanel.normalizeTarget = -16.0;
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 48
                                    height: 30
                                    radius: 6
                                    color: normalizationPanel.normalizeType === "RMS" ? Colors.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RMS"
                                        color: normalizationPanel.normalizeType === "RMS" ? Colors.textOnAccent : Colors.textSecondary
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            normalizationPanel.normalizeType = "RMS";
                                            normalizationPanel.normalizeTarget = -14.0;
                                        }
                                    }
                                }
                            }
                        }

                        // Target level dropdown
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 36
                            radius: 8
                            color: Colors.background
                            border.width: 1
                            border.color: Colors.border

                            ComboBox {
                                id: boardTargetLevelCombo
                                anchors.fill: parent
                                model: normalizationPanel.normalizeType === "LUFS"
                                    ? ["-14 dB", "-16 dB", "-18 dB", "-23 dB"]
                                    : ["-12 dB", "-14 dB", "-16 dB", "-18 dB"]
                                currentIndex: 1

                                onCurrentTextChanged: {
                                    var val = parseFloat(currentText);
                                    if (!isNaN(val)) {
                                        normalizationPanel.normalizeTarget = val;
                                    }
                                }

                                background: Rectangle {
                                    color: "transparent"
                                }

                                contentItem: Text {
                                    text: boardTargetLevelCombo.displayText
                                    color: Colors.textPrimary
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                indicator: Text {
                                    x: parent.width - width - 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "▼"
                                    font.pixelSize: 10
                                    color: Colors.textSecondary
                                }

                                popup: Popup {
                                    y: parent.height + 4
                                    width: parent.width
                                    padding: 4

                                    background: Rectangle {
                                        color: Colors.cardBg
                                        border.color: Colors.border
                                        border.width: 1
                                        radius: 8
                                    }

                                    contentItem: ListView {
                                        implicitHeight: contentHeight
                                        model: boardTargetLevelCombo.popup.visible ? boardTargetLevelCombo.delegateModel : null
                                        clip: true
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: boardTargetLevelCombo.width
                                    height: 32
                                    contentItem: Text {
                                        text: modelData
                                        color: Colors.textPrimary
                                        font.pixelSize: 13
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: highlighted ? Colors.surfaceLight : "transparent"
                                        radius: 6
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Progress indicator (shown while normalizing)
                        Text {
                            visible: normalizationPanel.isNormalizing
                            text: "Processing " + normalizationPanel.normalizedCount + "/" + normalizationPanel.totalToNormalize + "..."
                            color: Colors.textSecondary
                            font.pixelSize: 13
                        }

                        // Normalize All button
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 36
                            radius: 8
                            color: normalizationPanel.isNormalizing ? Colors.surfaceDark : (normalizeAllMa.containsMouse ? Colors.accentHover : Colors.accent)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                // Loading spinner when normalizing
                                Rectangle {
                                    visible: normalizationPanel.isNormalizing
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Colors.textOnAccent

                                    RotationAnimation on rotation {
                                        running: normalizationPanel.isNormalizing
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }

                                Text {
                                    text: normalizationPanel.isNormalizing ? "Normalizing..." : "Normalize All"
                                    color: Colors.textOnAccent
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: normalizeAllMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: normalizationPanel.isNormalizing ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !normalizationPanel.isNormalizing && dashboardClipsModel.count > 0
                                onClicked: {
                                    // Collect all clip IDs from the model
                                    var clipIds = [];
                                    for (var i = 0; i < dashboardClipsModel.count; i++) {
                                        var idx = dashboardClipsModel.index(i, 0);
                                        var clipId = dashboardClipsModel.data(idx, 257); // 257 = IdRole (Qt.UserRole + 1)
                                        if (clipId !== undefined && clipId !== null) {
                                            clipIds.push(clipId);
                                        }
                                    }

                                    if (clipIds.length > 0) {
                                        normalizationPanel.isNormalizing = true;
                                        normalizationPanel.normalizedCount = 0;
                                        normalizationPanel.totalToNormalize = clipIds.length;
                                        soundboardService.normalizeClipBatch(
                                            playbackDashboardCard.selectedBoardId,
                                            clipIds,
                                            normalizationPanel.normalizeTarget,
                                            normalizationPanel.normalizeType
                                        );
                                    }
                                }
                            }
                        }
                    }

                    // Connect to normalization signals for batch progress
                    Connections {
                        target: soundboardService
                        function onNormalizationComplete(clipId, success, error, outputPath) {
                            if (normalizationPanel.isNormalizing) {
                                normalizationPanel.normalizedCount++;
                                if (normalizationPanel.normalizedCount >= normalizationPanel.totalToNormalize) {
                                    normalizationPanel.isNormalizing = false;
                                    normalizationPanel.normalizedCount = 0;
                                    normalizationPanel.totalToNormalize = 0;
                                }
                                if (!success) {
                                    console.log("Normalization failed for clip", clipId, ":", error);
                                }
                            }
                        }
                    }
                }

                // Clips list
                ListView {
                    id: clipsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: dashboardClipsModel

                    // Track which clip is currently expanded (only one at a time)
                    property int expandedClipId: -1

                    // Optimize list performance
                    cacheBuffer: 1000
                    displayMarginBeginning: 100
                    displayMarginEnd: 100

                    delegate: AudioPlaybackSlot {
                        width: clipsListView.width - (clipsListView.leftMargin + clipsListView.rightMargin)

                        // Direct model role access
                        clipId: model.clipId || -1
                        clipTitle: model.clipTitle || model.filePath || "Untitled"
                        hotkeyLabel: model.hotkey || ""
                        iconSource: model.imgPath || "qrc:/assets/icons/sound.svg"
                        boardId: playbackDashboardCard.selectedBoardId

                        // Accordion behavior: only this clip is expanded if its ID matches
                        expanded: clipId === clipsListView.expandedClipId

                        // When expanded state changes, update the list's tracker
                        onExpandedChanged: {
                            if (expanded) {
                                clipsListView.expandedClipId = clipId;
                            } else if (clipId === clipsListView.expandedClipId) {
                                clipsListView.expandedClipId = -1;
                            }
                        }

                        onSettingsClicked: {
                            console.log("Settings clicked for clip:", clipId);
                        }
                    }

                    // Custom scrollbar
                    ScrollBar.vertical: ScrollBar {
                        parent: clipsListView.parent
                        anchors.top: clipsListView.top
                        anchors.right: clipsListView.right
                        anchors.bottom: clipsListView.bottom
                        active: clipsListView.moving || clipsListView.flicking
                    }

                    // Empty state centered in list
                    Text {
                        anchors.centerIn: parent
                        visible: clipsListView.count === 0
                        text: playbackDashboardCard.selectedBoardId >= 0 ? "No clips in this soundboard" : "Select a soundboard to view clips"
                        color: Colors.textSecondary
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
