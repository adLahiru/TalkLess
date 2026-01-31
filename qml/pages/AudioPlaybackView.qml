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
            
            // State for multi-selection
            property var selectedClipIds: []
            
            function toggleClipSelection(clipId, selected) {
                var newList = selectedClipIds.slice(); // Clone array
                var idx = newList.indexOf(clipId);
                if (selected && idx === -1) {
                    newList.push(clipId);
                } else if (!selected && idx !== -1) {
                    newList.splice(idx, 1);
                }
                selectedClipIds = newList;
            }
            
            function clearSelection() {
                selectedClipIds = [];
            }
            
            function selectAllClips() {
                var allIds = [];
                for (var i = 0; i < dashboardClipsModel.count; i++) {
                    var idx = dashboardClipsModel.index(i, 0);
                    var clipId = dashboardClipsModel.data(idx, 257); // 257 = IdRole
                    if (clipId !== undefined && clipId !== null) {
                        allIds.push(clipId);
                    }
                }
                selectedClipIds = allIds;
            }

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
                    
                    // Selection indicator and buttons
                    RowLayout {
                        visible: playbackDashboardCard.selectedClipIds.length > 0
                        spacing: 8
                        
                        // Selection count badge
                        Rectangle {
                            Layout.preferredWidth: selCountText.implicitWidth + 16
                            Layout.preferredHeight: 28
                            radius: 14
                            color: Colors.accent
                            
                            Text {
                                id: selCountText
                                anchors.centerIn: parent
                                text: playbackDashboardCard.selectedClipIds.length + " selected"
                                color: Colors.textOnAccent
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                        
                        // Clear selection button
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 28
                            radius: 6
                            color: clearSelMa.containsMouse ? Colors.surfaceLight : Colors.surfaceDark
                            border.width: 1
                            border.color: Colors.border
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Clear"
                                color: Colors.textSecondary
                                font.pixelSize: 11
                            }
                            
                            MouseArea {
                                id: clearSelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: playbackDashboardCard.clearSelection()
                            }
                        }
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
                        
                        // Reset All button
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            radius: 8
                            color: normalizationPanel.isResetting ? Colors.surfaceDark : (resetNormMa.containsMouse ? "#FF634766" : "#FF4444")
                            
                            property bool isResetting: false
                            property int resetCount: 0
                            property int resetTotal: 0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: parent.parent.isResetting ? "Resetting..." : "↩ Reset"
                                    color: "white"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: resetNormMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.isResetting ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !parent.isResetting && dashboardClipsModel.count > 0
                                onClicked: {
                                    var clipIds = [];
                                    for (var i = 0; i < dashboardClipsModel.count; i++) {
                                        var idx = dashboardClipsModel.index(i, 0);
                                        var clipId = dashboardClipsModel.data(idx, 257);
                                        if (clipId !== undefined && clipId !== null) {
                                            clipIds.push(clipId);
                                        }
                                    }

                                    if (clipIds.length > 0) {
                                        parent.isResetting = true;
                                        parent.resetCount = 0;
                                        parent.resetTotal = clipIds.length;
                                        soundboardService.resetClipToOriginalBatch(
                                            playbackDashboardCard.selectedBoardId,
                                            clipIds
                                        );
                                    }
                                }
                            }
                            
                            Connections {
                                target: soundboardService
                                function onClipReset(clipId, success, error) {
                                    if (parent.isResetting) {
                                        parent.resetCount++;
                                        if (parent.resetCount >= parent.resetTotal) {
                                            parent.isResetting = false;
                                            parent.resetCount = 0;
                                            parent.resetTotal = 0;
                                        }
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

                // Board-level Audio Effects Controls
                Rectangle {
                    id: effectsPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 8
                    color: Colors.surfaceDark
                    border.width: 1
                    border.color: Colors.border
                    visible: playbackDashboardCard.selectedBoardId >= 0

                    // Effects state
                    property string selectedEffect: "bassboost"
                    property bool isProcessing: false
                    property int processedCount: 0
                    property int totalToProcess: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        // Label
                        Text {
                            text: "🎛 Audio Effects"
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

                        // Effect buttons row
                        RowLayout {
                            spacing: 6

                            // Bass Boost button
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "bassboost" ? Colors.accent : (bassBoostMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "bassboost" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "🔊 Bass+"
                                    color: effectsPanel.selectedEffect === "bassboost" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: bassBoostMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "bassboost"
                                }
                            }

                            // Treble Boost button
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "trebleboost" ? Colors.accent : (trebleBoostMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "trebleboost" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "🔔 Treble+"
                                    color: effectsPanel.selectedEffect === "trebleboost" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: trebleBoostMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "trebleboost"
                                }
                            }

                            // Voice Enhance button
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "voiceenhance" ? Colors.accent : (voiceEnhanceMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "voiceenhance" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "🎤 Voice"
                                    color: effectsPanel.selectedEffect === "voiceenhance" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: voiceEnhanceMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "voiceenhance"
                                }
                            }

                            // Warmth button
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "warmth" ? Colors.accent : (warmthMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "warmth" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "🔥 Warm"
                                    color: effectsPanel.selectedEffect === "warmth" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: warmthMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "warmth"
                                }
                            }

                            // Low Cut button
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "lowcut" ? Colors.accent : (lowCutMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "lowcut" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "⬇️ LoCut"
                                    color: effectsPanel.selectedEffect === "lowcut" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: lowCutMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "lowcut"
                                }
                            }

                            // High Cut button
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 32
                                radius: 6
                                color: effectsPanel.selectedEffect === "highcut" ? Colors.accent : (highCutMa.containsMouse ? Colors.surfaceLight : Colors.background)
                                border.width: 1
                                border.color: effectsPanel.selectedEffect === "highcut" ? Colors.accent : Colors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "⬆️ HiCut"
                                    color: effectsPanel.selectedEffect === "highcut" ? Colors.textOnAccent : Colors.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: highCutMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: effectsPanel.selectedEffect = "highcut"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Progress indicator (shown while processing)
                        Text {
                            visible: effectsPanel.isProcessing
                            text: "Processing " + effectsPanel.processedCount + "/" + effectsPanel.totalToProcess + "..."
                            color: Colors.textSecondary
                            font.pixelSize: 13
                        }

                        // Apply to All button
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 36
                            radius: 8
                            color: effectsPanel.isProcessing ? Colors.surfaceDark : (applyEffectMa.containsMouse ? Colors.accentHover : Colors.accent)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                // Loading spinner when processing
                                Rectangle {
                                    visible: effectsPanel.isProcessing
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Colors.textOnAccent

                                    RotationAnimation on rotation {
                                        running: effectsPanel.isProcessing
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }

                                Text {
                                    text: effectsPanel.isProcessing ? "Applying..." : "Apply to All"
                                    color: Colors.textOnAccent
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: applyEffectMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: effectsPanel.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !effectsPanel.isProcessing && dashboardClipsModel.count > 0
                                onClicked: {
                                    // Collect all clip IDs from the model
                                    var clipIds = [];
                                    for (var i = 0; i < dashboardClipsModel.count; i++) {
                                        var idx = dashboardClipsModel.index(i, 0);
                                        var clipId = dashboardClipsModel.data(idx, 257); // 257 = IdRole
                                        if (clipId !== undefined && clipId !== null) {
                                            clipIds.push(clipId);
                                        }
                                    }

                                    if (clipIds.length > 0) {
                                        effectsPanel.isProcessing = true;
                                        effectsPanel.processedCount = 0;
                                        effectsPanel.totalToProcess = clipIds.length;
                                        soundboardService.applyEffectToClipBatch(
                                            playbackDashboardCard.selectedBoardId,
                                            clipIds,
                                            effectsPanel.selectedEffect
                                        );
                                    }
                                }
                            }
                        }
                        
                        // Apply to Selected button
                        Rectangle {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 36
                            radius: 8
                            color: effectsPanel.isProcessing || playbackDashboardCard.selectedClipIds.length === 0 
                                   ? Colors.surfaceDark 
                                   : (applySelectedMa.containsMouse ? "#6366F1" : "#4F46E5")
                            visible: playbackDashboardCard.selectedClipIds.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "Apply to Selected (" + playbackDashboardCard.selectedClipIds.length + ")"
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: applySelectedMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: effectsPanel.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !effectsPanel.isProcessing && playbackDashboardCard.selectedClipIds.length > 0
                                onClicked: {
                                    var clipIds = playbackDashboardCard.selectedClipIds;
                                    if (clipIds.length > 0) {
                                        effectsPanel.isProcessing = true;
                                        effectsPanel.processedCount = 0;
                                        effectsPanel.totalToProcess = clipIds.length;
                                        soundboardService.applyEffectToClipBatch(
                                            playbackDashboardCard.selectedBoardId,
                                            clipIds,
                                            effectsPanel.selectedEffect
                                        );
                                    }
                                }
                            }
                        }
                        
                        // Reset All button
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 36
                            radius: 8
                            color: effectsPanel.isResetting ? Colors.surfaceDark : (resetEffectsMa.containsMouse ? "#FF634766" : "#FF4444")
                            
                            property bool isResetting: false
                            property int resetCount: 0
                            property int resetTotal: 0

                            Text {
                                anchors.centerIn: parent
                                text: parent.isResetting ? "..." : "↩ Reset"
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: resetEffectsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.isResetting ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !parent.isResetting && dashboardClipsModel.count > 0
                                onClicked: {
                                    // Use selected clips if any, otherwise all clips
                                    var clipIds = playbackDashboardCard.selectedClipIds.length > 0 
                                        ? playbackDashboardCard.selectedClipIds 
                                        : [];
                                    
                                    if (clipIds.length === 0) {
                                        for (var i = 0; i < dashboardClipsModel.count; i++) {
                                            var idx = dashboardClipsModel.index(i, 0);
                                            var clipId = dashboardClipsModel.data(idx, 257);
                                            if (clipId !== undefined && clipId !== null) {
                                                clipIds.push(clipId);
                                            }
                                        }
                                    }

                                    if (clipIds.length > 0) {
                                        parent.isResetting = true;
                                        parent.resetCount = 0;
                                        parent.resetTotal = clipIds.length;
                                        soundboardService.resetClipToOriginalBatch(
                                            playbackDashboardCard.selectedBoardId,
                                            clipIds
                                        );
                                    }
                                }
                            }
                            
                            Connections {
                                target: soundboardService
                                function onClipReset(clipId, success, error) {
                                    if (parent.isResetting) {
                                        parent.resetCount++;
                                        if (parent.resetCount >= parent.resetTotal) {
                                            parent.isResetting = false;
                                            parent.resetCount = 0;
                                            parent.resetTotal = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Connect to effect signals for batch progress
                    Connections {
                        target: soundboardService
                        function onEffectComplete(clipId, success, error, outputPath) {
                            if (effectsPanel.isProcessing) {
                                effectsPanel.processedCount++;
                                if (effectsPanel.processedCount >= effectsPanel.totalToProcess) {
                                    effectsPanel.isProcessing = false;
                                    effectsPanel.processedCount = 0;
                                    effectsPanel.totalToProcess = 0;
                                }
                                if (!success) {
                                    console.log("Effect failed for clip", clipId, ":", error);
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
                        iconSource: model.imgPath || "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_speaker.svg"
                        boardId: playbackDashboardCard.selectedBoardId
                        
                        // Selection state
                        isSelected: playbackDashboardCard.selectedClipIds.indexOf(clipId) !== -1
                        
                        // Applied effects from model
                        appliedEffects: model.appliedEffects || []
                        
                        // Playing state
                        isPlaying: model.clipIsPlaying || false

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
                        
                        // Handle selection toggle
                        onSelectionToggled: function(id, selected) {
                            playbackDashboardCard.toggleClipSelection(id, selected);
                        }
                        
                        // Handle play/stop
                        onPlayClicked: function(id) {
                            soundboardService.playClip(id);
                        }
                        onStopClicked: function(id) {
                            soundboardService.stopClip(id);
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
