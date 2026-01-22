// SoundboardView.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
import "../components"
import "../styles"

Rectangle {
    id: root
    color: Colors.background
    radius: 10

    property int selectedClipId: -1  // Keep track of which clip is selected
    property int playingClipId: -1   // Last started clip that is still playing
    property var displayedClipData: null // Data currently shown in the player card
    property int hotkeyEditingClipId: -1 // Track which clip's hotkey is being edited from a tile
    property var pausedClipIds: ({}) // Track paused clips to keep showing progress

    // Drag and drop state for clip reordering
    property bool isDragging: false
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property string dragClipTitle: ""
    property string dragClipImage: ""
    property point dragPosition: Qt.point(0, 0)

    property bool isDetached: false

    // Override board ID for detached windows - if set, this view shows that specific board
    // instead of following the global clipsModel.boardId
    property int overrideBoardId: -1

    // Local clips model for detached windows (optional - if not set, uses global clipsModel)
    property var localClipsModel: null

    // Track soundboard count for empty state detection
    property int soundboardCount: soundboardsModel ? soundboardsModel.rowCount() : 0

    // Update soundboard count when model changes
    Connections {
        target: soundboardsModel
        function onRowsInserted() {
            root.soundboardCount = soundboardsModel.rowCount();
        }
        function onRowsRemoved() {
            root.soundboardCount = soundboardsModel.rowCount();
        }
        function onModelReset() {
            root.soundboardCount = soundboardsModel.rowCount();
        }
    }

    // Active clips model - uses local if available, otherwise global clipsModel
    readonly property var activeClipsModel: localClipsModel ? localClipsModel : clipsModel

    // Effective board ID - uses override if set, otherwise uses active model's boardId
    // Effective board ID - uses override if set, otherwise uses active model's boardId
    readonly property int effectiveBoardId: overrideBoardId >= 0 ? overrideBoardId : (activeClipsModel ? activeClipsModel.boardId : -1)

    // Trigger waveform caching when board changes
    onEffectiveBoardIdChanged: {
        if (effectiveBoardId >= 0 && soundboardService) {
            // console.log("[QML] Board changed, caching waveforms...")
            soundboardService.cacheActiveBoardWaveforms();
        }
    }

    signal requestOpenBoard(int boardId)
    signal requestDetach
    signal requestDock

    // =========================
    // PLAYBACK PROGRESS TIMER
    // =========================
    // Timer that updates playback progress for all playing clips
    Timer {
        id: progressUpdateTimer
        interval: 150  // Update every 150ms for better performance
        repeat: true
        running: true  // Always run to check for playing clips

        // Map of clipId -> progress (0.0 to 1.0)
        property var clipProgressMap: ({})

        onTriggered: {
            if (!soundboardService)
                return;

            // Get all currently playing clip IDs
            var playingIds = soundboardService.playingClipIDs();

            // Early exit if nothing is playing and no paused clips
            var pausedCount = Object.keys(root.pausedClipIds).length;
            if (playingIds.length === 0 && pausedCount === 0) {
                if (Object.keys(clipProgressMap).length > 0) {
                    clipProgressMap = {};
                }
                return;
            }

            var newMap = {};

            // Add playing clips
            for (var i = 0; i < playingIds.length; i++) {
                var clipId = playingIds[i];
                var progress = soundboardService.getClipPlaybackProgress(clipId);
                newMap[clipId] = Math.max(0, Math.min(1, progress));
            }

            // Add paused clips
            for (var pId in root.pausedClipIds) {
                if (newMap[pId] === undefined) {
                    var pClipId = parseInt(pId);
                    var pProgress = soundboardService.getClipPlaybackProgress(pClipId);
                    newMap[pId] = Math.max(0, Math.min(1, pProgress));
                }
            }

            // Direct assignment (more efficient than JSON comparison)
            clipProgressMap = newMap;
        }
    }

    // Expose function to open the add soundboard dialog
    function showAddSoundboardDialog() {
        addSoundboardDialog.open();
    }

    // Helper function to find clip data by ID in the model
    function getClipDataById(clipId) {
        if (clipId === -1)
            return null;

        // Use the new backend function for more reliable and efficient data retrieval
        const data = soundboardService.getClipData(activeClipsModel.boardId, clipId);
        if (!data || Object.keys(data).length === 0)
            return null;

        return {
            clipId: data.id,
            title: data.title,
            filePath: data.filePath,
            hotkey: data.hotkey,
            imgPath: data.imgPath,
            isPlaying: data.isPlaying,
            isRepeat: data.isRepeat,
            tags: data.tags || [],
            clipVolume: data.volume,
            clipSpeed: data.speed,
            reproductionMode: data.reproductionMode,
            stopOtherSounds: data.stopOtherSounds,
            muteOtherSounds: data.muteOtherSounds,
            muteMicDuringPlayback: data.muteMicDuringPlayback,
            durationSec: data.durationSec,
            trimStartMs: data.trimStartMs,
            trimEndMs: data.trimEndMs
        };
    }

    // Update what's shown in the player card and editor
    function updateDisplayedClipData() {
        // 1. Player Card Logic (Priority: Playing Clip > Selected Clip)
        let playerCardData = getClipDataById(playingClipId);
        if (!playerCardData) {
            playerCardData = getClipDataById(selectedClipId);
        }
        displayedClipData = playerCardData;

        // 2. Editor Sidebar Logic (Always Selected Clip)
        if (selectedClipId !== -1) {
            const editorData = getClipDataById(selectedClipId);
            if (editorData) {
                pushToEditor(editorData);
            }
        }
    }

    function pushToEditor(data) {
        if (!data)
            return;

        clipEditorTab.editingClipName = data.title || "";
        clipEditorTab.editingClipHotkey = data.hotkey || "";
        clipEditorTab.editingClipTags = data.tags || [];
        clipEditorTab.editingClipImgPath = data.imgPath || "";
        clipEditorTab.clipVolume = data.clipVolume !== undefined ? data.clipVolume : 100;
        clipEditorTab.clipSpeed = data.clipSpeed !== undefined ? data.clipSpeed : 1.0;
        clipEditorTab.clipIsRepeat = data.isRepeat || false;

        // Update reproduction mode - set both properties to ensure sync
        const newMode = data.reproductionMode !== undefined ? data.reproductionMode : 1;
        clipEditorTab.reproductionMode = newMode;

        // Directly update the mode selector UI if it exists
        // if (typeof modeSelectorRow !== 'undefined' && modeSelectorRow !== null) {
        //     modeSelectorRow.selectedMode = newMode;
        // }

        // Playback behavior options
        clipEditorTab.stopOtherSounds = data.stopOtherSounds || false;
        clipEditorTab.muteOtherSounds = data.muteOtherSounds || false;
        clipEditorTab.muteMicDuringPlayback = data.muteMicDuringPlayback || false;

        clipEditorTab.durationSec = data.durationSec || 0.0;
        clipEditorTab.trimStartMs = data.trimStartMs || 0.0;
        clipEditorTab.trimEndMs = data.trimEndMs || 0.0;

        // Use title if available, otherwise extract filename from filePath
        var displayTitle = data.title || "";
        if (!displayTitle && data.filePath) {
            // Extract filename without extension from file path
            var pathParts = data.filePath.replace(/\\/g, '/').split('/');
            var filename = pathParts[pathParts.length - 1];
            // Remove extension
            var dotIndex = filename.lastIndexOf('.');
            if (dotIndex > 0) {
                displayTitle = filename.substring(0, dotIndex);
            } else {
                displayTitle = filename;
            }
        }
        clipEditorTab.displayComputedTitle = displayTitle;
        clipTitleInput.text = displayTitle;
    }

    // Refresh when core IDs change
    onSelectedClipIdChanged: updateDisplayedClipData()
    onPlayingClipIdChanged: updateDisplayedClipData()

    // Refresh editor when model data changes (e.g., after saving settings)
    Connections {
        target: activeClipsModel
        function onClipsChanged() {
            // Re-fetch and push data to editor when model reloads
            if (root.selectedClipId !== -1) {
                updateDisplayedClipData();
            }
        }
    }

    // File picking logic
    FileDialog {
        id: audioFileDialog
        title: "Select Audio File"
        nameFilters: ["Audio files (*.mp3 *.wav *.ogg *.m4a)", "All files (*)"]
        onAccepted: {
            const boardId = activeClipsModel.boardId;
            if (boardId >= 0) {
                const success = soundboardService.addClip(boardId, selectedFile.toString());
                if (success) {
                    activeClipsModel.reload();
                }
            }
        }
    }

    // Track which clip is being edited for background image
    property int clipToEditImageId: -1

    // Image file dialog for background image selection
    FileDialog {
        id: imageFileDialog
        title: "Select Background Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.webp *.bmp)", "All files (*)"]
        onAccepted: {
            if (root.clipToEditImageId >= 0) {
                const success = activeClipsModel.updateClipImage(root.clipToEditImageId, selectedFile.toString());
                if (success) {
                    activeClipsModel.reload();  // Reload to show new image
                }
                root.clipToEditImageId = -1;
            }
        }
        onRejected: {
            root.clipToEditImageId = -1;
        }
    }

    // Listen for clip selection requests from backend
    Connections {
        target: soundboardService
        function onClipSelectionRequested(clipId) {
            root.selectedClipId = clipId;
            root.updateDisplayedClipData();
        }
        function onClipUpdated(boardId, clipId) {
            if (clipId === root.selectedClipId) {
                root.updateDisplayedClipData();
            }
        }
    }

    Connections {
        target: activeClipsModel
        function onBoardIdChanged() {
            root.selectedClipId = -1;
            root.playingClipId = -1;
        }
        function onClipsChanged() {
            root.updateDisplayedClipData();
        }
    }

    // Handle play/pause hotkey and playback state from soundboardService
    Connections {
        target: soundboardService
        function onPlaySelectedRequested() {
            console.log("Play selected hotkey triggered, selectedClipId:", root.selectedClipId);
            if (root.selectedClipId !== -1) {
                if (soundboardService.isClipPlaying(root.selectedClipId)) {
                    soundboardService.stopClip(root.selectedClipId);
                } else {
                    soundboardService.playClip(root.selectedClipId);
                }
            }
        }

        function onClipPlaybackStarted(clipId) {
            root.playingClipId = clipId;
            // Remove from paused list if it was there
            var pIds = Object.assign({}, root.pausedClipIds);
            if (pIds[clipId]) {
                delete pIds[clipId];
                root.pausedClipIds = pIds; // Trigger change
            }
            root.updateDisplayedClipData();
        }

        function onClipPlaybackPaused(clipId) {
            // Add to paused list
            var pIds = Object.assign({}, root.pausedClipIds);
            pIds[clipId] = true;
            root.pausedClipIds = pIds; // Trigger change

            // Update the UI when a clip is paused (but keep it as the displayed clip)
            root.updateDisplayedClipData();
        }

        function onClipPlaybackStopped(clipId) {
            // Remove from paused list
            var pIds = Object.assign({}, root.pausedClipIds);
            if (pIds[clipId]) {
                delete pIds[clipId];
                root.pausedClipIds = pIds; // Trigger change
            }

            if (root.playingClipId === clipId) {
                // Find if any other clip is still playing
                let foundPlaying = -1;
                for (let i = 0; i < activeClipsModel.count; i++) {
                    const index = activeClipsModel.index(i, 0);
                    if (activeClipsModel.data(index, 263)) { // IsPlayingRole
                        foundPlaying = activeClipsModel.data(index, 257); // IdRole
                        break;
                    }
                }
                root.playingClipId = foundPlaying;
            }
            root.updateDisplayedClipData();
        }

        function onClipLooped(clipId) {
            // Update the UI when a looping clip restarts - this helps reset progress display
            root.updateDisplayedClipData();
        }

        function onErrorOccurred(message) {
            // Show error popup to user
            errorNotificationText.text = message;
            errorNotificationPopup.open();
        }
    }

    // Load fonts at root level
    FontLoader {
        id: poppinsFont
        source: "https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLEj6Z1JlFc-K.ttf"
    }

    FontLoader {
        id: interFont
        source: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf"
    }

    // ============================================
    // Error Notification Popup
    // ============================================
    Popup {
        id: errorNotificationPopup
        anchors.centerIn: parent
        width: 360
        height: 140
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: Colors.surface
            radius: 16
            border.color: "#FF6B6B"
            border.width: 2
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "⚠️ Error"
                font.family: "Inter"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#FF6B6B"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                id: errorNotificationText
                text: ""
                font.family: "Inter"
                font.pixelSize: 14
                color: Colors.textPrimary
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: 100
                height: 36
                radius: 8
                color: "#FF6B6B"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "OK"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "white"
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: errorNotificationPopup.close()
                }
            }
        }
    }

    // ============================================
    // Add Soundboard Dialog
    // ============================================
    Popup {
        id: addSoundboardDialog
        anchors.centerIn: parent
        width: 400
        height: 340
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property string errorMessage: ""
        property string selectedArtworkPath: ""

        background: Rectangle {
            color: Colors.surface
            radius: 16
            border.color: Colors.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "Add New Soundboard"
                color: Colors.textPrimary
                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                font.pixelSize: 18
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            // Artwork picker
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Image preview/picker
                Rectangle {
                    id: artworkPreview
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 80
                    radius: 12
                    color: Colors.surfaceDark
                    border.color: artworkMouseArea.containsMouse ? Colors.accent : Colors.border
                    border.width: 1
                    clip: true

                    Image {
                        id: artworkImage
                        anchors.fill: parent
                        source: addSoundboardDialog.selectedArtworkPath || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: addSoundboardDialog.selectedArtworkPath !== ""
                    }

                    // Default placeholder when no image
                    Column {
                        anchors.centerIn: parent
                        visible: addSoundboardDialog.selectedArtworkPath === ""
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "+"
                            font.pixelSize: 28
                            font.weight: Font.Light
                            color: Colors.textDisabled
                        }

                        Text {
                            text: "Add Image"
                            font.pixelSize: 10
                            color: Colors.textDisabled
                        }
                    }

                    MouseArea {
                        id: artworkMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            soundboardArtworkPicker.open();
                        }
                    }
                }

                // Name input area
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Soundboard Name"
                        color: Colors.textSecondary
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: Colors.surfaceDark
                        radius: 8
                        border.color: newSoundboardNameInput.activeFocus ? Colors.accent : (addSoundboardDialog.errorMessage ? Colors.error : Colors.border)
                        border.width: 1

                        TextInput {
                            id: newSoundboardNameInput
                            anchors.fill: parent
                            anchors.margins: 12
                            color: Colors.textPrimary
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                text: "Enter soundboard name..."
                                color: Colors.textDisabled
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                            }

                            onTextChanged: {
                                addSoundboardDialog.errorMessage = "";
                            }

                            Keys.onReturnPressed: {
                                createSoundboardBtn.clicked();
                            }
                        }
                    }

                    Text {
                        visible: addSoundboardDialog.errorMessage !== ""
                        text: addSoundboardDialog.errorMessage
                        color: Colors.error
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                text: "Cover image is optional. If not provided, a default will be used."
                color: Colors.textDisabled
                font.pixelSize: 11
                font.italic: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    color: cancelSoundboardBtn.containsMouse ? Colors.surfaceLight : Colors.surface
                    radius: 8
                    border.color: Colors.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.textPrimary
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelSoundboardBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            addSoundboardDialog.close();
                            newSoundboardNameInput.text = "";
                            addSoundboardDialog.errorMessage = "";
                            addSoundboardDialog.selectedArtworkPath = "";
                        }
                    }
                }

                Rectangle {
                    id: createSoundboardBtn
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: createSoundboardBtnArea.containsMouse ? Colors.primaryLight : Colors.primary
                        }
                        GradientStop {
                            position: 1.0
                            color: createSoundboardBtnArea.containsMouse ? Colors.secondary : Colors.gradientPrimaryEnd
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Create"
                        color: Colors.textOnPrimary
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    signal clicked

                    MouseArea {
                        id: createSoundboardBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.clicked()
                    }

                    onClicked: {
                        const name = newSoundboardNameInput.text.trim();
                        if (name === "") {
                            addSoundboardDialog.errorMessage = "Please enter a name";
                            return;
                        }

                        if (soundboardService.boardNameExists(name)) {
                            addSoundboardDialog.errorMessage = "A soundboard with this name already exists";
                            return;
                        }

                        // Create board with or without artwork and switch to it
                        var newBoardId;
                        if (addSoundboardDialog.selectedArtworkPath !== "") {
                            newBoardId = soundboardService.createBoardWithArtwork(name, addSoundboardDialog.selectedArtworkPath);
                        } else {
                            newBoardId = soundboardService.createBoard(name);
                        }

                        // Switch to the newly created soundboard to make it active
                        if (newBoardId >= 0 && clipsModel) {
                            clipsModel.boardId = newBoardId;
                            clipsModel.reload();
                        }

                        // Model automatically reloads when boardsChanged is emitted by the service
                        addSoundboardDialog.close();
                        newSoundboardNameInput.text = "";
                        addSoundboardDialog.errorMessage = "";
                        addSoundboardDialog.selectedArtworkPath = "";
                    }
                }
            }
        }

        onOpened: {
            newSoundboardNameInput.text = "";
            addSoundboardDialog.errorMessage = "";
            addSoundboardDialog.selectedArtworkPath = "";
            newSoundboardNameInput.forceActiveFocus();
        }
    }

    // File dialog for soundboard artwork
    FileDialog {
        id: soundboardArtworkPicker
        title: "Select Soundboard Cover Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp *.webp)"]
        onAccepted: {
            addSoundboardDialog.selectedArtworkPath = currentFile.toString();
        }
    }

    // Main 3-column layout
    RowLayout {
        anchors.fill: parent
        spacing: 15

        // LEFT COLUMN: Banner and Content Area
        ColumnLayout {
            id: leftColumn
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Removed maximumWidth to allow pushing sidebar to the right
            spacing: 20

            // Full-coverage DropArea for adding audio files via drag and drop anywhere in the soundboard
            DropArea {
                id: fullSoundboardDropArea
                anchors.fill: parent
                keys: ["text/uri-list"] // Standard for file drops
                z: 1000 // Ensure it's above other elements for drag detection

                onEntered: function (drag) {
                    // Accept the drag if it contains file URLs
                    drag.accepted = drag.hasUrls;
                }

                onDropped: function (drop) {
                    if (drop.hasUrls) {
                        let urls = [];
                        for (let i = 0; i < drop.urls.length; i++) {
                            urls.push(drop.urls[i].toString());
                        }

                        const boardId = activeClipsModel.boardId;
                        if (boardId !== -1) {
                            const success = soundboardService.addClips(boardId, urls);
                            if (success) {
                                activeClipsModel.reload();
                            }
                        }
                        drop.accept();
                    }
                }

                // Visual feedback overlay for file dragging - covers entire soundboard
                Rectangle {
                    id: dropOverlay
                    anchors.fill: parent
                    color: Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.15)
                    visible: parent.containsDrag
                    radius: 16
                    z: 999

                    // Animated border
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 16
                        border.color: Colors.success
                        border.width: 3

                        // Pulsing animation
                        SequentialAnimation on border.width {
                            running: dropOverlay.visible
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 3
                                to: 5
                                duration: 400
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: 5
                                to: 3
                                duration: 400
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    // Center content
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 15

                        // Large plus icon with glow effect
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 80
                            height: 80
                            radius: 40
                            color: Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.2)
                            border.color: Colors.success
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: Colors.success
                                font.pixelSize: 48
                                font.weight: Font.Light
                            }

                            // Pulsing scale animation
                            SequentialAnimation on scale {
                                running: dropOverlay.visible
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 1.0
                                    to: 1.1
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: 1.1
                                    to: 1.0
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Drop audio files to add to soundboard"
                            color: Colors.success
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Supports MP3, WAV, FLAC, OGG, and more"
                            color: Colors.success
                            font.pixelSize: 14
                            font.weight: Font.Normal
                            opacity: 0.8
                        }
                    }
                }
            }

            // Background Banner - hidden when no soundboards
            Rectangle {
                id: bannerContainer
                Layout.fillWidth: true
                Layout.preferredHeight: root.soundboardCount > 0 ? 145 : 0
                Layout.maximumHeight: root.soundboardCount > 0 ? 145 : 0
                visible: root.soundboardCount > 0
                radius: 16
                clip: true
                color: "transparent"

                // Background image
                Image {
                    id: backgroundImage
                    anchors.fill: parent
                    source: Colors.bannerImage
                    fillMode: Image.PreserveAspectCrop
                }

                // Dark overlay for text readability
                Rectangle {
                    anchors.fill: parent
                    color: Colors.overlay
                    opacity: 0.3
                }

                // Three dots menu button - top right corner
                Rectangle {
                    id: moreButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.rightMargin: 10
                    width: 28
                    height: 28
                    radius: 6
                    color: moreMouseArea.containsMouse || moreOptionsMenu.visible ? "#33FFFFFF" : "#22FFFFFF"

                    // Three vertical dots
                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Colors.primary
                            }
                        }
                    }

                    MouseArea {
                        id: moreMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            moreOptionsMenu.open();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    // Popup menu
                    Popup {
                        id: moreOptionsMenu
                        x: (parent.width - width) / 2  // Center horizontally under the dots
                        y: parent.height + 5
                        width: 160
                        padding: 8

                        background: Rectangle {
                            color: Colors.surface
                            radius: 8
                            border.color: Colors.border
                            border.width: 1
                        }

                        contentItem: Column {
                            spacing: 4

                            Repeater {
                                model: ["Select Slots", "Detach Window", "Edit Cover", "Delete"]

                                delegate: Rectangle {
                                    id: menuItem
                                    width: 144
                                    height: 36
                                    radius: 6
                                    color: menuItemMouse.containsMouse ? Colors.surfaceLight : "transparent"

                                    required property string modelData

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: menuItem.modelData
                                        color: menuItem.modelData === "Delete" ? Colors.error : Colors.textPrimary
                                    }

                                    MouseArea {
                                        id: menuItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            console.log("Menu item clicked:", menuItem.modelData);
                                            if (menuItem.modelData === "Detach Window") {
                                                root.requestDetach();
                                            }
                                            moreOptionsMenu.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Content row - text left, button right
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 25
                    anchors.rightMargin: 20
                    anchors.topMargin: 15
                    anchors.bottomMargin: 15
                    spacing: 15

                    // Text column (left side)
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        // Main text
                        Text {
                            text: activeClipsModel?.boardName ?? "Soundboard"
                            color: Colors.textPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        // Secondary text
                        Text {
                            text: "Manage and trigger your audio clips"
                            color: Colors.textPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 15
                            font.weight: Font.Normal
                            opacity: 0.9
                        }
                    }

                    // Spacer
                    Item {
                        Layout.fillWidth: true
                    }

                    // Add Soundboard button
                    Rectangle {
                        id: addButton
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        radius: 8
                        clip: true

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: addMouseArea.containsMouse ? Colors.primaryLight : Colors.primary
                            }
                            GradientStop {
                                position: 1.0
                                color: addMouseArea.containsMouse ? Colors.secondary : Colors.gradientPrimaryEnd
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Add Soundboard"
                            color: Colors.textOnPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: addMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                addSoundboardDialog.open();
                            }
                        }
                    }

                    // Disconnect button
                    Rectangle {
                        id: disconnectButton
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        radius: 8
                        color: disconnectMouseArea.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.1) : Colors.surface
                        border.color: disconnectMouseArea.containsMouse ? Colors.error : Colors.border
                        border.width: 1

                        MouseArea {
                            id: disconnectMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isDetached) {
                                    root.requestDock();
                                } else {
                                    root.requestDetach();
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.isDetached ? "⬇" : "↗"
                            color: Colors.error
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            visible: true
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }
            }

            // Spacer between banner and content - hidden when no soundboards
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.soundboardCount > 0 ? 10 : 0
                visible: root.soundboardCount > 0
            }

            // Soundboard content area
            Rectangle {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.surfaceDark
                radius: 12

                // Tile sizing properties - responsive layout with scale factor
                readonly property real tileSpacing: 15
                readonly property real tilePadding: 20
                // Base size range, scaled by slotSizeScale (0.5 to 1.5)
                readonly property real baseMinTileWidth: 120
                readonly property real baseMaxTileWidth: 180
                readonly property real minTileWidth: baseMinTileWidth * (soundboardService?.slotSizeScale ?? 1.0)
                readonly property real maxTileWidth: baseMaxTileWidth * (soundboardService?.slotSizeScale ?? 1.0)

                // Calculate number of columns based on available width
                // Default to 5 columns for normal displays, but adjust based on space
                readonly property int columnsCount: {
                    const availableWidth = width - tilePadding * 2;
                    // Try different column counts and find the best fit
                    for (let cols = 8; cols >= 2; cols--) {
                        const calculatedWidth = (availableWidth - tileSpacing * (cols - 1)) / cols;
                        if (calculatedWidth >= minTileWidth && calculatedWidth <= maxTileWidth) {
                            return cols;
                        }
                    }
                    // Fallback: calculate based on minimum width
                    return Math.max(2, Math.floor((availableWidth + tileSpacing) / (minTileWidth + tileSpacing)));
                }

                // Width calculation based on column count - proportionally scaled
                readonly property real tileWidth: (width - tilePadding * 2 - tileSpacing * (columnsCount - 1)) / columnsCount
                readonly property real tileHeight: tileWidth * 79 / 111  // 111:79 aspect ratio maintained

                // Dummy clips data - REMOVED, now using real activeClipsModel
                // The activeClipsModel is exposed from C++ and updated when a soundboard is selected

                // Flickable area for scrolling
                Flickable {
                    id: clipsFlickable
                    anchors.fill: parent
                    anchors.margins: contentArea.tilePadding
                    contentWidth: width
                    contentHeight: clipsGrid.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    // Background MouseArea for right-click context menu (Paste)
                    MouseArea {
                        anchors.fill: parent
                        z: -1 // Behind the grid items
                        acceptedButtons: Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                boardContextMenu.popup();
                            }
                        }
                    }

                    Menu {
                        id: boardContextMenu
                        MenuItem {
                            text: "Paste Clip"
                            enabled: soundboardService?.canPaste ?? false
                            onTriggered: {
                                const bId = activeClipsModel.boardId;
                                if (bId !== -1 && soundboardService.pasteClip(bId)) {
                                    activeClipsModel.reload();
                                }
                            }
                        }
                    }

                    // Grid layout for tiles
                    Flow {
                        id: clipsGrid
                        width: parent.width
                        spacing: contentArea.tileSpacing

                        // Helper function to calculate drop index from position
                        function getDropIndexFromPosition(globalX, globalY) {
                            // Map position to grid coordinates
                            var localPos = clipsGrid.mapFromItem(clipsFlickable, globalX, globalY);
                            var x = localPos.x;
                            var y = localPos.y;

                            // Calculate column and row
                            var tileWidthWithSpacing = contentArea.tileWidth + contentArea.tileSpacing;
                            var tileHeightWithSpacing = contentArea.tileHeight + contentArea.tileSpacing;

                            var col = Math.floor(x / tileWidthWithSpacing);
                            var row = Math.floor(y / tileHeightWithSpacing);

                            // Clamp to valid range
                            col = Math.max(0, Math.min(col, contentArea.columnsCount - 1));

                            // Calculate index (accounting for AddAudioTile at position 0)
                            var index = row * contentArea.columnsCount + col - 1; // -1 for AddAudioTile

                            // Clamp to valid clip range
                            return Math.max(0, Math.min(index, activeClipsModel.count - 1));
                        }

                        // Add Audio Tile (first item)
                        AddAudioTile {
                            id: addAudioTile
                            width: contentArea.tileWidth
                            height: contentArea.tileHeight
                            enabled: true
                            onClicked: {
                                rightSidebar.currentTabIndex = 1;
                                rightSidebar.isSoundboardView = false;
                            }
                        }

                        // Real Clip Tiles from activeClipsModel with drag-and-drop reordering
                        Repeater {
                            id: clipsRepeater
                            model: activeClipsModel

                            Item {
                                id: clipWrapper
                                required property int index
                                required property int clipId
                                required property string clipTitle
                                required property string hotkey
                                required property string imgPath
                                required property string filePath
                                required property bool clipIsPlaying

                                width: contentArea.tileWidth
                                height: contentArea.tileHeight

                                // Store original position for drag reset
                                property real startX: 0
                                property real startY: 0
                                property bool isBeingDragged: false

                                // Check if this is the drop target position
                                property bool isDropTarget: root.isDragging && root.dragTargetIndex === clipWrapper.index && root.dragSourceIndex !== clipWrapper.index
                                property bool isDropTargetLeft: isDropTarget && root.dragSourceIndex > clipWrapper.index
                                property bool isDropTargetRight: isDropTarget && root.dragSourceIndex < clipWrapper.index

                                // Visual offset when item is dragged over
                                property real visualOffsetX: {
                                    if (!root.isDragging)
                                        return 0;
                                    if (clipWrapper.index === root.dragSourceIndex)
                                        return 0;

                                    // Items between source and target shift to make room
                                    if (root.dragSourceIndex < root.dragTargetIndex) {
                                        // Dragging right - items in between shift left
                                        if (clipWrapper.index > root.dragSourceIndex && clipWrapper.index <= root.dragTargetIndex) {
                                            return -(contentArea.tileWidth + contentArea.tileSpacing) * 0.15;
                                        }
                                    } else if (root.dragSourceIndex > root.dragTargetIndex) {
                                        // Dragging left - items in between shift right
                                        if (clipWrapper.index >= root.dragTargetIndex && clipWrapper.index < root.dragSourceIndex) {
                                            return (contentArea.tileWidth + contentArea.tileSpacing) * 0.15;
                                        }
                                    }
                                    return 0;
                                }

                                // Animate the offset
                                Behavior on visualOffsetX {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                // Apply the transform
                                transform: Translate {
                                    x: clipWrapper.isBeingDragged ? 0 : clipWrapper.visualOffsetX
                                }

                                // Fade out the source position when dragging
                                opacity: clipWrapper.isBeingDragged ? 0.3 : 1.0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                // For drag-drop visual feedback
                                Drag.active: dragHandler.active
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                // Drop indicator - left edge
                                Rectangle {
                                    id: dropIndicatorLeft
                                    visible: clipWrapper.isDropTargetLeft
                                    width: 4
                                    height: parent.height
                                    x: -contentArea.tileSpacing / 2 - 2
                                    y: 0
                                    radius: 2
                                    color: "#3B82F6"

                                    // Glow effect
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 12
                                        height: parent.height
                                        radius: 6
                                        color: "#3B82F6"
                                        opacity: 0.3
                                    }

                                    // Pulsing animation
                                    SequentialAnimation on opacity {
                                        running: clipWrapper.isDropTargetLeft
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: 1.0
                                            to: 0.6
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            from: 0.6
                                            to: 1.0
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                // Drop indicator - right edge
                                Rectangle {
                                    id: dropIndicatorRight
                                    visible: clipWrapper.isDropTargetRight
                                    width: 4
                                    height: parent.height
                                    x: parent.width + contentArea.tileSpacing / 2 - 2
                                    y: 0
                                    radius: 2
                                    color: "#3B82F6"

                                    // Glow effect
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 12
                                        height: parent.height
                                        radius: 6
                                        color: "#3B82F6"
                                        opacity: 0.3
                                    }

                                    // Pulsing animation
                                    SequentialAnimation on opacity {
                                        running: clipWrapper.isDropTargetRight
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: 1.0
                                            to: 0.6
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            from: 0.6
                                            to: 1.0
                                            duration: 500
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                ClipTile {
                                    id: clipTile
                                    anchors.fill: parent

                                    // Use title if available, otherwise extract filename from filePath
                                    title: {
                                        if (clipWrapper.clipTitle && clipWrapper.clipTitle.length > 0) {
                                            return clipWrapper.clipTitle;
                                        } else if (clipWrapper.filePath && clipWrapper.filePath.length > 0) {
                                            // Extract filename without extension
                                            var path = clipWrapper.filePath.replace(/\\/g, '/');
                                            var parts = path.split('/');
                                            var filename = parts[parts.length - 1];
                                            var dotIndex = filename.lastIndexOf('.');
                                            if (dotIndex > 0) {
                                                return filename.substring(0, dotIndex);
                                            }
                                            return filename;
                                        }
                                        return "Clip " + (clipWrapper.index + 1);
                                    }
                                    hotkeyText: clipWrapper.hotkey
                                    imageSource: {
                                        if (clipWrapper.imgPath.length === 0) {
                                            return "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png";
                                        } else if (clipWrapper.imgPath.startsWith("qrc:") || clipWrapper.imgPath.startsWith("file:") || clipWrapper.imgPath.startsWith("http")) {
                                            return clipWrapper.imgPath;
                                        } else {
                                            return "file:///" + clipWrapper.imgPath; // Use 3 slashes for Windows local paths
                                        }
                                    }
                                    isPlaying: clipWrapper.clipIsPlaying
                                    clipId: clipWrapper.clipId
                                    playbackProgress: progressUpdateTimer.clipProgressMap[clipWrapper.clipId] || 0.0
                                    filePath: clipWrapper.filePath
                                    currentBoardId: activeClipsModel.boardId

                                    onClicked: {
                                        // Selecting the clip updates the sidebar
                                        soundboardService.setCurrentlySelectedClip(clipWrapper.clipId);
                                        soundboardService.playClip(clipWrapper.clipId);
                                        rightSidebar.isSoundboardView = true;
                                        rightSidebar.currentTabIndex = 0;
                                    }

                                    onPlayClicked: {
                                        soundboardService.playClip(clipWrapper.clipId);
                                        rightSidebar.isSoundboardView = true;
                                        rightSidebar.currentTabIndex = 0;
                                    }
                                    onStopClicked: {
                                        soundboardService.stopClip(clipWrapper.clipId);
                                        rightSidebar.isSoundboardView = true;
                                        rightSidebar.currentTabIndex = 0;
                                    }
                                    onDeleteClicked: {
                                        if (soundboardService.deleteClip(activeClipsModel.boardId, clipWrapper.clipId)) {
                                            if (root.selectedClipId === clipWrapper.clipId)
                                                root.selectedClipId = -1;
                                            activeClipsModel.reload();
                                        }
                                    }
                                    onEditClicked: {
                                        soundboardService.setCurrentlySelectedClip(clipWrapper.clipId);
                                        rightSidebar.currentTabIndex = 0; // Focus the editor tab
                                        rightSidebar.isSoundboardView = true;
                                    }
                                    onWebClicked: {
                                        // Open sharing URL?
                                    }
                                    onSendToClicked: {
                                        // Popup opens automatically from ClipTile
                                    }
                                    onPasteClicked: {
                                        if (soundboardService.pasteClip(activeClipsModel.boardId)) {
                                            activeClipsModel.reload();
                                        }
                                    }
                                    onEditBackgroundClicked: {
                                        root.clipToEditImageId = clipWrapper.clipId;
                                        imageFileDialog.open();
                                    }
                                    onHotkeyClicked: {
                                        root.hotkeyEditingClipId = clipWrapper.clipId;
                                        clipHotkeyPopup.open();
                                    }
                                    onTeleprompterClicked: {
                                        clipTeleprompterPopup.clipId = clipWrapper.clipId;
                                        clipTeleprompterPopup.clipTitle = clipTile.title;
                                        clipTeleprompterPopup.teleprompterText = clipWrapper.teleprompterText || "";
                                        clipTeleprompterPopup.open();
                                    }
                                }

                                // Drag handler for reordering
                                DragHandler {
                                    id: dragHandler
                                    target: null  // We handle position manually

                                    onActiveChanged: {
                                        if (active) {
                                            // Set dragging state
                                            clipWrapper.isBeingDragged = true;
                                            root.isDragging = true;
                                            root.dragSourceIndex = clipWrapper.index;
                                            root.dragTargetIndex = clipWrapper.index;
                                            root.dragClipTitle = clipWrapper.clipTitle;
                                            root.dragClipImage = clipWrapper.imgPath;

                                            // Store the starting position
                                            clipWrapper.startX = clipWrapper.x;
                                            clipWrapper.startY = clipWrapper.y;
                                            // Reparent to root for dragging above other items
                                            clipWrapper.parent = clipsFlickable;
                                            clipWrapper.z = 100;
                                        } else {
                                            // Clear dragging state first
                                            clipWrapper.isBeingDragged = false;
                                            var finalDropIndex = root.dragTargetIndex;
                                            var sourceIndex = root.dragSourceIndex;

                                            // Reset global drag state
                                            root.isDragging = false;
                                            root.dragSourceIndex = -1;
                                            root.dragTargetIndex = -1;
                                            root.dragClipTitle = "";
                                            root.dragClipImage = "";

                                            // Reparent back to grid
                                            clipWrapper.parent = clipsGrid;
                                            clipWrapper.z = 0;

                                            // If dropped on a valid position, reorder
                                            if (finalDropIndex >= 0 && finalDropIndex !== sourceIndex) {
                                                soundboardService.moveClip(activeClipsModel.boardId, sourceIndex, finalDropIndex);
                                                activeClipsModel.reload();
                                            }
                                        }
                                    }

                                    // Update target position while dragging
                                    onCentroidChanged: {
                                        if (active) {
                                            var pos = centroid.position;
                                            var globalPos = clipWrapper.mapToItem(clipsFlickable, pos.x, pos.y);
                                            root.dragPosition = Qt.point(globalPos.x, globalPos.y);

                                            // Move the clipWrapper to follow the drag
                                            if (clipWrapper.parent === clipsFlickable) {
                                                clipWrapper.x = globalPos.x - clipWrapper.width / 2;
                                                clipWrapper.y = globalPos.y - clipWrapper.height / 2;
                                            }

                                            // Calculate drop target
                                            var newTargetIndex = clipsGrid.getDropIndexFromPosition(globalPos.x, globalPos.y);
                                            if (newTargetIndex !== root.dragTargetIndex) {
                                                root.dragTargetIndex = newTargetIndex;
                                            }
                                        }
                                    }
                                }

                                // Drop area for receiving dragged items - now with improved feedback
                                DropArea {
                                    id: dropArea
                                    anchors.fill: parent
                                    enabled: root.isDragging && clipWrapper.index !== root.dragSourceIndex

                                    onEntered: function (drag) {
                                        if (clipWrapper.index !== root.dragSourceIndex) {
                                            root.dragTargetIndex = clipWrapper.index;
                                        }
                                    }

                                    // Highlight overlay when this is a drop target
                                    Rectangle {
                                        anchors.fill: parent
                                        color: parent.containsDrag ? Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.25) : "transparent"
                                        radius: 16
                                        border.width: parent.containsDrag ? 2 : 0
                                        border.color: Colors.success
                                    }
                                }
                            }
                        }

                        // Drag preview overlay - shows a ghost of the dragged clip
                        Item {
                            id: dragPreviewContainer
                            parent: clipsFlickable
                            visible: root.isDragging
                            z: 1000

                            // Position at drag location
                            x: root.dragPosition.x - contentArea.tileWidth / 2
                            y: root.dragPosition.y - contentArea.tileHeight / 2

                            Rectangle {
                                id: dragPreview
                                width: contentArea.tileWidth
                                height: contentArea.tileHeight
                                radius: 16
                                color: "#1F1F1F"
                                border.width: 3
                                border.color: "#3B82F6"
                                opacity: 0.9
                                visible: root.isDragging

                                // Scale up slightly for emphasis
                                scale: 1.05

                                // Clip image
                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: {
                                        if (root.dragClipImage.length === 0) {
                                            return "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png";
                                        } else if (root.dragClipImage.startsWith("qrc:") || root.dragClipImage.startsWith("file:") || root.dragClipImage.startsWith("http")) {
                                            return root.dragClipImage;
                                        } else {
                                            return "file:///" + root.dragClipImage;
                                        }
                                    }
                                    fillMode: Image.PreserveAspectCrop

                                    // Rounded corners
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: previewImage.width
                                                height: previewImage.height
                                                radius: 14
                                            }
                                        }
                                    }
                                }

                                // Title overlay
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 30
                                    color: "#CC000000"
                                    radius: 12

                                    // Only bottom corners rounded
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: parent.radius
                                        color: parent.color
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.dragClipTitle || "Moving..."
                                        color: "#FFFFFF"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width - 16
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // Move icon overlay
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: "#3B82F6"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⋮⋮"
                                        color: "#FFFFFF"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }

                    // Clicking empty space deselects
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: root.selectedClipId = -1
                    }

                    // Scrollbar
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                // Empty state overlay - shown when no soundboards exist
                Rectangle {
                    id: noSoundboardsOverlay
                    anchors.fill: parent
                    color: Colors.surfaceDark
                    radius: 12
                    visible: root.soundboardCount === 0
                    z: 100

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 20

                        // Icon
                        Rectangle {
                            width: 80
                            height: 80
                            radius: 40
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
                            Layout.alignment: Qt.AlignHCenter

                            Text {
                                anchors.centerIn: parent
                                text: "🎵"
                                font.pixelSize: 36
                            }
                        }

                        // Title
                        Text {
                            text: "No Soundboards"
                            color: Colors.textPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Description
                        Text {
                            text: "Create your first soundboard to start\nadding and playing audio clips"
                            color: Colors.textSecondary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Add Soundboard Button
                        Rectangle {
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 10
                            radius: 12

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: addSbBtnMouse.containsMouse ? Colors.primaryLight : Colors.primary
                                }
                                GradientStop {
                                    position: 1.0
                                    color: addSbBtnMouse.containsMouse ? Colors.secondary : Colors.gradientPrimaryEnd
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "+ Add Soundboard"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: addSbBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    addSoundboardDialog.open();
                                }
                            }
                        }
                    }
                }
            }

            // Audio Player Card - below the clips grid
            AudioPlayerCard {
                id: audioPlayerCard
                Layout.preferredWidth: 228
                Layout.preferredHeight: 175
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10

                // Visible only when a clip is selected or playing AND there are soundboards
                visible: root.soundboardCount > 0 && root.displayedClipData !== null

                // Bind to displayed clip data (prioritizes playing clip)
                songName: (root.displayedClipData && root.displayedClipData.title) ? root.displayedClipData.title : "No clip selected"
                hotkeyText: (root.displayedClipData && root.displayedClipData.hotkey) ? "Press " + root.displayedClipData.hotkey + " to play" : "No hotkey assigned"
                // Convert local path to file:// URL if needed for QML Image
                imageSource: {
                    const imgPath = (root.displayedClipData && root.displayedClipData.imgPath) ? root.displayedClipData.imgPath : "";
                    if (imgPath.length === 0) {
                        return "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png";
                    } else if (imgPath.startsWith("qrc:") || imgPath.startsWith("file:") || imgPath.startsWith("http")) {
                        return imgPath;
                    } else {
                        // Local path - convert to file:// URL
                        return "file:///" + imgPath;
                    }
                }

                // Bind isPlaying state
                isPlaying: root.displayedClipData ? root.displayedClipData.isPlaying : false

                // Waveform progress - bind totalTime from clip duration (in seconds)
                totalTime: (root.displayedClipData && root.displayedClipData.durationSec > 0) ? root.displayedClipData.durationSec : 210

                // currentTime is updated by the timer below
                property real playbackPositionMs: 0
                property int lastClipId: -1  // Track which clip we're displaying
                property var currentWaveformData: []  // Real waveform data for current clip

                // Timer to poll playback position - runs when playing
                Timer {
                    id: audioPlayerTimer
                    interval: 50  // Update every 50ms for smoother sync
                    repeat: true
                    running: audioPlayerCard.isPlaying && root.displayedClipData !== null
                    onTriggered: {
                        if (root.displayedClipData) {
                            audioPlayerCard.playbackPositionMs = soundboardService.getClipPlaybackPositionMs(root.displayedClipData.clipId);
                        }
                    }
                }

                // Convert ms to seconds for currentTime
                currentTime: playbackPositionMs / 1000.0

                // Sync position immediately when playback state changes
                onIsPlayingChanged: {
                    if (root.displayedClipData) {
                        // Always sync position when state changes
                        playbackPositionMs = soundboardService.getClipPlaybackPositionMs(root.displayedClipData.clipId);
                    }
                }

                // Reset position and load waveform when switching to a different clip
                onDisplayedClipDataChanged: {
                    if (root.displayedClipData) {
                        if (lastClipId !== root.displayedClipData.clipId) {
                            // New clip - get current position from backend
                            playbackPositionMs = soundboardService.getClipPlaybackPositionMs(root.displayedClipData.clipId);
                            lastClipId = root.displayedClipData.clipId;

                            // Load waveform data for the new clip (32 bars to match UI strip)
                            currentWaveformData = soundboardService.getClipWaveformPeaks(root.displayedClipData.clipId, 32);
                        }
                    } else {
                        playbackPositionMs = 0;
                        lastClipId = -1;
                        currentWaveformData = [];
                    }
                }

                // Bind waveform data to the AudioPlayerCard
                waveformData: currentWaveformData

                // Helper to access displayed clip data from handlers
                property var displayedClipData: root.displayedClipData

                // Play/Pause the displayed clip
                onPlayClicked: {
                    if (root.displayedClipData) {
                        soundboardService.playClip(root.displayedClipData.clipId);
                    }
                }
                onPauseClicked: {
                    if (root.displayedClipData) {
                        soundboardService.playClip(root.displayedClipData.clipId);
                    }
                }

                // Navigate to previous/next clip in the list
                onPreviousClicked: {
                    if (activeClipsModel.count === 0)
                        return;

                    rightSidebar.isSoundboardView = true;
                    // Find current index and go to previous
                    let currentIndex = -1;
                    for (let i = 0; i < activeClipsModel.count; i++) {
                        const index = activeClipsModel.index(i, 0);
                        const id = activeClipsModel.data(index, 257);
                        if (id === root.selectedClipId) {
                            currentIndex = i;
                            break;
                        }
                    }

                    if (currentIndex > 0) {
                        const prevIndex = activeClipsModel.index(currentIndex - 1, 0);
                        root.selectedClipId = activeClipsModel.data(prevIndex, 257);
                    } else if (currentIndex === 0 && activeClipsModel.count > 0) {
                        // Wrap to last clip
                        const lastIndex = activeClipsModel.index(activeClipsModel.count - 1, 0);
                        root.selectedClipId = activeClipsModel.data(lastIndex, 257);
                    }
                }
                onNextClicked: {
                    if (activeClipsModel.count === 0)
                        return;

                    rightSidebar.isSoundboardView = true;
                    // Find current index and go to next
                    let currentIndex = -1;
                    for (let i = 0; i < activeClipsModel.count; i++) {
                        const index = activeClipsModel.index(i, 0);
                        const id = activeClipsModel.data(index, 257);
                        if (id === root.selectedClipId) {
                            currentIndex = i;
                            break;
                        }
                    }

                    if (currentIndex >= 0 && currentIndex < activeClipsModel.count - 1) {
                        const nextIndex = activeClipsModel.index(currentIndex + 1, 0);
                        root.selectedClipId = activeClipsModel.data(nextIndex, 257);
                    } else if (currentIndex === activeClipsModel.count - 1) {
                        // Wrap to first clip
                        const firstIndex = activeClipsModel.index(0, 0);
                        root.selectedClipId = activeClipsModel.data(firstIndex, 257);
                    }
                }
                isMuted: !(soundboardService?.isMicEnabled() ?? true)
                onMuteClicked: {
                    soundboardService.setMicEnabled(!isMuted);
                }

                // Handle seek/scrub requests from waveform
                onSeekRequested: function (positionMs) {
                    if (root.displayedClipData) {
                        // Use playClipFromPosition for seeking
                        soundboardService.playClipFromPosition(root.displayedClipData.clipId, positionMs);
                    }
                }
            }
        }

        // RIGHT COLUMN: Modern Sidebar with Premium Styling - hidden when no soundboards
        Rectangle {
            id: rightSidebar
            // Responsive width calculation: prefer 340px but allow shrinking to 280px minimum
            // and take up to 35% of parent width on very wide screens
            property real parentWidth: root.width > 0 ? root.width : 800
            property real responsiveWidth: Math.min(340, Math.max(280, parentWidth * 0.35))

            visible: root.soundboardCount > 0
            Layout.preferredWidth: root.soundboardCount > 0 ? responsiveWidth : 0
            Layout.minimumWidth: root.soundboardCount > 0 ? 280 : 0
            Layout.maximumWidth: root.soundboardCount > 0 ? 380 : 0
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 0
            Layout.rightMargin: 0

            // Glassmorphism effect
            color: Colors.cardBg
            border.color: Colors.border
            border.width: 1

            // Rounded only on left side if desired, but let's keep it simple and clean
            radius: 0 // Flush to the right side edge looks better for fixed sidebar

            // Tab state: 0=Editor, 1=Plus, 2=Record, 3=Teleprompter, 4=Speaker
            property bool isSoundboardView: true
            property int currentTabIndex: 0  // Default to Record tab
            property var tabState: ["Editor", "Add", "Record", "Prompter", "TTS"]
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Top section with modern header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    // Header background with very subtle bottom border
                    color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Colors.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        // Current Tab Title (shows clip name for Editor tab)
                        Text {
                            text: {
                                // if (rightSidebar.currentTabIndex === 0 && root.selectedClipId !== -1 && clipEditorTab.displayComputedTitle !== "") {
                                //    return clipEditorTab.displayComputedTitle;
                                // }
                                return rightSidebar.tabState[rightSidebar.currentTabIndex];
                            }
                            color: Colors.textPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideRight
                            Layout.maximumWidth: 200
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Icon buttons row
                        Row {
                            spacing: 8
                            Layout.alignment: Qt.AlignVCenter

                            TabButton {
                                index: 0
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_settings.svg"
                                visible: rightSidebar.isSoundboardView
                            }
                            TabButton {
                                index: 1
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_add.svg"
                                visible: !rightSidebar.isSoundboardView
                            }
                            TabButton {
                                index: 2
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_record.svg"
                            }
                            TabButton {
                                index: 3
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_prompt.svg"
                            }
                            TabButton {
                                index: 4
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_speaker.svg"
                            }
                        }
                    }
                }

                // Modern Header Separator is now part of the header rectangle above

                // Recording Tab Content (Tab 2)
                ColumnLayout {
                    id: recordingTab
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    visible: rightSidebar.currentTabIndex === 2

                    // Recording waveform peaks data (to be populated by recording)
                    property var recordingPeaks: []
                    // Error message for validation
                    property string recordingError: ""
                    // Final recorded duration (updated after recording stops)
                    property real finalRecordedDuration: 0
                    // Preview playback position in seconds (for playhead indicator)
                    property real previewPlaybackTime: 0

                    // Timer to poll preview playback position
                    Timer {
                        id: previewPlayheadTimer
                        interval: 50  // Update every 50ms for smooth animation
                        repeat: true
                        running: soundboardService?.isRecordingPreviewPlaying ?? false
                        onTriggered: {
                            let posMs = soundboardService?.getPreviewPlaybackPositionMs() ?? 0;
                            recordingTab.previewPlaybackTime = posMs / 1000.0;
                        }
                        onRunningChanged: {
                            if (!running) {
                                recordingTab.previewPlaybackTime = 0;
                            }
                        }
                    }

                    // Initialize input device dropdown when tab becomes visible
                    onVisibleChanged: {
                        if (!visible) {
                            recordingNameInput.focus = false;
                            // Clear recording state when navigating away
                            recordingTab.recordingPeaks = [];
                            recordingTab.recordingError = "";
                            recordingTab.finalRecordedDuration = 0;
                            recordingTab.previewPlaybackTime = 0;
                            // Cancel any pending recording and delete temp file
                            if (soundboardService) {
                                soundboardService.cancelPendingRecording();
                            }
                        }
                        if (visible && inputDeviceDropdown.model.length === 0) {
                            const list = soundboardService.getInputDevices();
                            list.unshift({
                                id: "-1",
                                name: "None",
                                isDefault: false
                            });
                            inputDeviceDropdown.model = list;
                        }
                    }

                    // Timer to collect peaks during recording for waveform visualization
                    Timer {
                        id: waveformPeakTimer
                        interval: 100 // Collect peak every 100ms
                        repeat: true
                        running: soundboardService?.isRecording ?? false

                        onTriggered: {
                            if (soundboardService) {
                                const peakLevel = soundboardService.recordingPeakLevel;
                                // Normalize peak level (already 0-1 from service)
                                const normalizedPeak = Math.max(0.1, Math.min(1.0, peakLevel));

                                // Create a new array to trigger property change
                                let peaks = recordingTab.recordingPeaks.slice();
                                peaks.push(normalizedPeak);

                                // Keep only last 60 samples for display
                                if (peaks.length > 60) {
                                    peaks = peaks.slice(-60);
                                }
                                recordingTab.recordingPeaks = peaks;
                            }
                        }
                    }

                    // Reset peaks when recording starts/stops
                    Connections {
                        target: soundboardService
                        function onRecordingStateChanged() {
                            if (!soundboardService.isRecording) {
                                // Recording stopped - load full waveform from file after a short delay
                                // (to ensure file is fully written)
                                waveformLoadTimer.start();
                            } else {
                                // Clear peaks and duration when recording starts
                                recordingTab.recordingPeaks = [];
                                recordingTab.recordingError = "";
                                recordingTab.finalRecordedDuration = 0;
                                // Reset trim sliders to full range for new recording
                                waveformTrim.resetTrimPositions();
                            }
                        }
                    }

                    // Timer to delay loading waveform until file is ready
                    Timer {
                        id: waveformLoadTimer
                        interval: 300  // Wait 300ms for file to be fully written
                        repeat: false
                        onTriggered: {
                            if (soundboardService && soundboardService.lastRecordingPath && soundboardService.lastRecordingPath !== "") {
                                // Load waveform peaks from the recorded file
                                const peaks = soundboardService.getWaveformPeaks(soundboardService.lastRecordingPath, 60);
                                if (peaks && peaks.length > 0) {
                                    recordingTab.recordingPeaks = peaks;
                                }
                                // Get accurate file duration
                                const duration = soundboardService.getFileDuration(soundboardService.lastRecordingPath);
                                if (duration > 0) {
                                    recordingTab.finalRecordedDuration = duration;
                                }
                            }
                        }
                    }

                    // ============================================================
                    // Name Audio File (SINGLE INPUT - fixed duplicate name issue)
                    // ============================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Header with title and clipboard icon
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Name Audio File"
                                color: Colors.textPrimary
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 24
                                height: 24
                                color: "transparent"

                                Image {
                                    id: clipboardIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_clipboard.svg"
                                    width: 16
                                    height: 16
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: clipboardIcon
                                    anchors.fill: clipboardIcon
                                    colorization: 1.0
                                    colorizationColor: Colors.textPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: console.log("Clipboard clicked")
                                }
                            }
                        }

                        // Text Input Field (single input used for saving)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: Colors.surface
                            radius: 8
                            border.color: Colors.border
                            border.width: 1

                            TextInput {
                                id: recordingNameInput
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.textPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 0
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Enter a name for your recording..."
                                    color: Colors.textDisabled
                                    font: parent.font
                                    visible: !parent.text && !parent.activeFocus
                                }
                            }
                        }

                        // Error message for clip name validation
                        Text {
                            visible: recordingTab.recordingError !== ""
                            text: recordingTab.recordingError
                            color: Colors.error
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // ============================================================
                    // Input Source Section
                    // ============================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 3

                        Text {
                            text: "Input Source"
                            color: Colors.textPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        DropdownSelector {
                            id: inputDeviceDropdown
                            Layout.fillWidth: true
                            icon: "🔴"
                            placeholder: "Select Mic Device"
                            // Default to the selected recording device (which defaults to capture device)
                            selectedId: soundboardService?.selectedRecordingDeviceId ?? "-1"
                            model: []

                            onAboutToOpen: {
                                const list = soundboardService.getInputDevices();
                                list.unshift({
                                    id: "-1",
                                    name: "None",
                                    isDefault: false
                                });
                                model = list;
                            }

                            onItemSelected: function (id, name) {
                                console.log("Recording input device selected:", name, "(id:", id, ")");
                                soundboardService.setRecordingInputDevice(id);
                            }
                        }
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 4
                    }
                    ColumnLayout {
                        CheckBox {
                            id: isClipboardRecording
                            text: "Clipboard Recording"
                            checked: soundboardService?.recordWithClipboard ?? false
                            onToggled: {
                                if (soundboardService) {
                                    soundboardService.recordWithClipboard = checked;
                                }
                            }
                        }

                        // Error message display for recording validation
                        Text {
                            visible: recordingTab.recordingError !== ""
                            text: recordingTab.recordingError
                            color: Colors.error
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: 5
                            Layout.rightMargin: 5
                        }
                    }

                    // ============================================================
                    // Start/Stop Recording Button Section
                    // ============================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Rectangle {
                            id: micButton
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignHCenter
                            radius: 18

                            // Button color changes based on hover + recording state
                            color: micButtonArea.containsMouse ? ((soundboardService?.isRecording ?? false) ? "#7F1D1D" : "#4A4A4A") : ((soundboardService?.isRecording ?? false) ? "#991B1B" : "#3A3A3A")

                            border.color: (soundboardService?.isRecording ?? false) ? "#EF4444" : "#4A4A4A"
                            border.width: 1

                            // subtle pulse ring while recording
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 10
                                height: parent.height + 10
                                radius: (parent.width + 10) / 2
                                color: "transparent"
                                border.width: 2
                                border.color: "#EF4444"
                                opacity: 0.0
                                visible: soundboardService?.isRecording ?? false

                                SequentialAnimation on opacity {
                                    running: soundboardService?.isRecording ?? false
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        to: 0.35
                                        duration: 450
                                    }
                                    NumberAnimation {
                                        to: 0.05
                                        duration: 450
                                    }
                                }
                            }

                            Image {
                                id: micIcon
                                anchors.centerIn: parent
                                source: "qrc:/qt/qml/TalkLess/resources/icons/actions/ic_mic.svg"
                                width: 18
                                height: 18
                                fillMode: Image.PreserveAspectFit
                                visible: false
                            }

                            MultiEffect {
                                source: micIcon
                                anchors.fill: micIcon
                                colorization: 1.0
                                // blue when recording (or red if you prefer)
                                colorizationColor: (soundboardService?.isRecording ?? false) ? "#EF4444" : "#FFFFFF"
                            }

                            MouseArea {
                                id: micButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (soundboardService?.isRecording ?? false) {
                                        soundboardService.stopRecording();
                                    } else {
                                        // Validate recording source selection
                                        const recordFromClipboard = isClipboardRecording.checked;
                                        const hasInputDevice = inputDeviceDropdown.selectedId !== "" && inputDeviceDropdown.selectedId !== "-1";

                                        // Check if neither source is selected (need input device OR clipboard)
                                        if (!hasInputDevice && !recordFromClipboard) {
                                            recordingTab.recordingError = "Please select an input device or enable Clipboard Recording";
                                            return;
                                        }

                                        recordingTab.recordingError = "";
                                        soundboardService.startRecording();
                                    }
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        Text {
                            text: (soundboardService?.isRecording ?? false) ? "Stop Recording" : "Start Recording"
                            color: "#888888"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            visible: soundboardService?.isRecording ?? false
                            text: {
                                const t = soundboardService?.recordingDuration ?? 0;
                                const mins = Math.floor(t / 60);
                                const secs = Math.floor(t % 60);
                                return mins + ":" + (secs < 10 ? "0" + secs : secs);
                            }
                            color: Colors.textSecondary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 8
                    }

                    // ============================================================
                    // Trim Audio Section (visible only after recording finishes)
                    // ============================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8
                        visible: !(soundboardService?.isRecording ?? false) && (soundboardService?.lastRecordingPath ?? "") !== ""

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 16
                                height: 16
                                color: "transparent"

                                Image {
                                    id: scissorsIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_scissors.svg"
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    source: scissorsIcon
                                    anchors.fill: scissorsIcon
                                    colorization: 1.0
                                    colorizationColor: Colors.textPrimary
                                }
                            }

                            Text {
                                text: "Trim Audio"
                                color: Colors.textPrimary
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        TrimWaveform {
                            id: waveformTrim
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90

                            // Show playhead during recording or preview playback
                            currentTime: {
                                if (soundboardService?.isRecording ?? false) {
                                    return soundboardService?.recordingDuration ?? 0;
                                }
                                if (soundboardService?.isRecordingPreviewPlaying ?? false) {
                                    return recordingTab.previewPlaybackTime;
                                }
                                return 0;
                            }
                            totalDuration: {
                                // After recording: use accurate file duration
                                if (recordingTab.finalRecordedDuration > 0) {
                                    return recordingTab.finalRecordedDuration;
                                }
                                // During recording: use live duration with minimum
                                return Math.max(soundboardService?.recordingDuration ?? 0, 5);
                            }

                            // Use real waveform from file, or live peaks during recording
                            waveformData: recordingTab.recordingPeaks.length > 0 ? recordingTab.recordingPeaks : waveformTrim.generateMockWaveform()

                            onTrimStartMoved: function (pos) {
                                waveformTrim.trimStart = pos;
                            }
                            onTrimEndMoved: function (pos) {
                                waveformTrim.trimEnd = pos;
                            }
                        }

                        // Preview trimmed audio button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 8
                            color: (soundboardService?.isRecordingPreviewPlaying ?? false) ? Colors.error : Colors.accent
                            visible: !(soundboardService?.isRecording ?? false) && (soundboardService?.lastRecordingPath ?? "") !== ""

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: (soundboardService?.isRecordingPreviewPlaying ?? false) ? "■" : "▶"
                                    color: Colors.textOnPrimary
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: (soundboardService?.isRecordingPreviewPlaying ?? false) ? "Stop Preview" : "Preview Trim"
                                    color: Colors.textOnPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (soundboardService?.isRecordingPreviewPlaying) {
                                        soundboardService.stopLastRecordingPreview();
                                    } else {
                                        // Calculate trim times from normalized positions
                                        let durationMs = recordingTab.finalRecordedDuration * 1000.0;
                                        let startMs = waveformTrim.trimStart * durationMs;
                                        let endMs = waveformTrim.trimEnd * durationMs;
                                        soundboardService.playLastRecordingPreviewTrimmed(startMs, endMs);
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredHeight: 1
                    }

                    Text {
                        text: "Add To Soundboard"
                        color: Colors.textPrimary
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        visible: !(soundboardService?.isRecording ?? false) && (soundboardService?.lastRecordingPath ?? "") !== ""
                    }

                    DropdownSelector {
                        id: recordingBoardDropdown
                        Layout.fillWidth: true
                        placeholder: activeClipsModel.boardName !== "" ? activeClipsModel.boardName : "Select Soundboard"
                        selectedId: ""     // keep as string for your dropdown component
                        model: []
                        visible: !(soundboardService?.isRecording ?? false) && (soundboardService?.lastRecordingPath ?? "") !== ""

                        function refreshBoards() {
                            const boards = soundboardService.listBoardsForDropdown();
                            model = boards.map(b => ({
                                        id: String(b.id),
                                        name: b.name
                                    }));

                            // default -> opened soundboard (activeClipsModel.boardId)
                            if (selectedId === "" && activeClipsModel.boardId >= 0) {
                                selectedId = String(activeClipsModel.boardId);
                            }
                        }

                        Component.onCompleted: refreshBoards()
                        onAboutToOpen: refreshBoards()
                    }

                    // If user changes boards elsewhere, keep default synced
                    Connections {
                        target: activeClipsModel
                        function onBoardIdChanged() {
                            // Always sync dropdown with currently displayed board
                            if (activeClipsModel.boardId >= 0) {
                                recordingBoardDropdown.selectedId = String(activeClipsModel.boardId);
                            }
                        }
                    }

                    // Refresh dropdown list when boards are added/removed
                    Connections {
                        target: soundboardService
                        function onBoardsChanged() {
                            recordingBoardDropdown.refreshBoards();
                        }
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 2
                    }

                    // ============================================================
                    // Cancel and Save buttons (visible only after recording finishes)
                    // ============================================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8
                        visible: !(soundboardService?.isRecording ?? false) && (soundboardService?.lastRecordingPath ?? "") !== ""

                        Item {
                            Layout.fillWidth: true
                        }

                        // Cancel button
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            color: cancelBtnArea.containsMouse ? Colors.surfaceLight : Colors.surface
                            radius: 8
                            border.width: 1
                            border.color: Colors.border

                            Text {
                                anchors.centerIn: parent
                                text: "Rest"
                                color: Colors.textPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: cancelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    recordingNameInput.text = "";
                                    soundboardService.cancelPendingRecording(); // NEW: stops + deletes + clears
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // Save button
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            radius: 8
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: saveBtnArea.containsMouse ? Colors.accentLight : Colors.accent
                                }
                                GradientStop {
                                    position: 1.0
                                    color: saveBtnArea.containsMouse ? Colors.accentDark : Colors.accentMedium
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: saveBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("Save clicked");

                                    const boardId = parseInt(recordingBoardDropdown.selectedId);
                                    if (isNaN(boardId) || boardId < 0) {
                                        console.log("Cannot save: invalid board id", recordingBoardDropdown.selectedId);
                                        return;
                                    }

                                    // Stop recording if still recording
                                    if (soundboardService?.isRecording ?? false) {
                                        soundboardService.stopRecording();
                                    }

                                    // Validate Name
                                    let title = recordingNameInput.text.trim();

                                    if (title === "") {
                                        // User did not add a name -> Generate unique name automatically
                                        title = soundboardService.generateUniqueClipTitle(boardId, "Recording");
                                    } else {
                                        // User added a name -> Check for duplicates
                                        if (soundboardService.clipTitleExistsInBoard(boardId, title)) {
                                            recordingTab.recordingError = "A clip with this name already exists. Please choose a different name.";
                                            return; // Stop here, do not consume recording
                                        }
                                    }

                                    // Clear any previous error
                                    recordingTab.recordingError = "";

                                    // Validation passed, now consume the recording path
                                    const localPath = soundboardService.consumePendingRecordingPath();
                                    if (!localPath || localPath === "") {
                                        console.log("Cannot save: no pending recording");
                                        return;
                                    }

                                    // Convert normalized trim (0..1) to milliseconds
                                    const durationSec = soundboardService.getFileDuration(localPath); // seconds
                                    const durationMs = Math.max(0, durationSec * 1000.0);

                                    let trimStartMs = waveformTrim.trimStart * durationMs;
                                    let trimEndMs = waveformTrim.trimEnd * durationMs;

                                    trimStartMs = Math.max(0, Math.min(trimStartMs, durationMs));
                                    trimEndMs = Math.max(0, Math.min(trimEndMs, durationMs));

                                    if (trimEndMs <= trimStartMs + 10) {
                                        trimEndMs = Math.min(durationMs, trimStartMs + 10);
                                    }

                                    const noTrim = (waveformTrim.trimStart <= 0.0001 && waveformTrim.trimEnd >= 0.9999);
                                    if (noTrim) {
                                        trimStartMs = 0;
                                        trimEndMs = 0; // engine treats 0 as full length
                                    }

                                    console.log("Adding clip - boardId:", boardId, "path:", localPath, "title:", title);
                                    const success = soundboardService.addClipWithSettings(boardId, localPath, title, trimStartMs, trimEndMs);

                                    if (success) {
                                        console.log("Clip added successfully");

                                        // Switch to the target board if we saved to a different one
                                        if (activeClipsModel.boardId !== boardId) {
                                            console.log("Requesting switch to board:", boardId);
                                            root.requestOpenBoard(boardId);
                                        } else {
                                            console.log("Reloading current board");
                                            activeClipsModel.reload();
                                        }

                                        recordingNameInput.text = "";
                                        rightSidebar.currentTabIndex = 0;
                                    } else {
                                        console.log("addClipWithSettings failed for path:", localPath);
                                        // If save failed, we might want to show an error, but for now we just log it.
                                        // The pending recording is consumed, which is unfortunate if backend failed,
                                        // but usually adding shouldn't fail if path is valid.
                                    }
                                }
                            }
                        }
                    }

                    // Fill remaining space
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Settings Tab Content (Tab 0) - New Modern Clip Editor
                Flickable {
                    id: settingsScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: clipEditorTab.implicitHeight
                    clip: true
                    visible: rightSidebar.currentTabIndex === 0
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    ColumnLayout {
                        id: clipEditorTab
                        width: parent.width
                        spacing: 10

                        // Properties for editing
                        property string editingClipName: ""
                        property string editingClipHotkey: ""
                        property var editingClipTags: []
                        property bool hasUnsavedChanges: false
                        property string editingClipImgPath: ""
                        property real clipVolume: 100
                        property real clipSpeed: 1.0
                        property bool stopOtherSounds: true
                        property bool muteOtherSounds: true
                        property bool muteMicDuringPlayback: true
                        property bool persistentSettings: true
                        property bool clipIsRepeat: false
                        property int reproductionMode: 0  // 0=Overlay(default), 1=Play/Pause, 2=Play/Stop, 3=Exclusive, 4=Loop
                        property real durationSec: 0.0
                        property real trimStartMs: 0.0
                        property real trimEndMs: 0.0
                        property string displayComputedTitle: ""
                        property bool isTitleEditing: false

                        // Update when selected clip changes
                        Connections {
                            target: root
                            function onSelectedClipIdChanged() {
                                clipEditorTab.isTitleEditing = false;
                                if (root.selectedClipId !== -1) {
                                    const data = root.getClipDataById(root.selectedClipId);
                                    if (data) {
                                        root.pushToEditor(data);
                                    }
                                } else {
                                    clipEditorTab.editingClipName = "";
                                    clipEditorTab.editingClipHotkey = "";
                                    clipEditorTab.editingClipTags = [];
                                    clipEditorTab.editingClipImgPath = "";
                                    clipEditorTab.clipVolume = 100;
                                    clipEditorTab.clipSpeed = 1.0;
                                    clipEditorTab.clipIsRepeat = false;
                                    clipEditorTab.reproductionMode = 0;
                                    clipEditorTab.durationSec = 0.0;
                                    clipEditorTab.trimStartMs = 0.0;
                                    clipEditorTab.trimEndMs = 0.0;
                                    clipTitleInput.text = "";
                                    addTagInput.text = "";
                                    clipEditorTab.hasUnsavedChanges = false;
                                }
                            }
                        }

                        // Show "No clip selected" message when no clip is selected
                        // Show "No clip selected" message when no clip is selected
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            visible: root.selectedClipId === -1

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "No Clip Selected"
                                    color: Colors.textPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "Select a clip to edit its\nsettings and properties"
                                    color: Colors.textSecondary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Clip Editor Content - visible when clip is selected
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            spacing: 12
                            visible: root.selectedClipId !== -1

                            // ===== MICROPHONE PREVIEW SECTION =====
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 140

                                // Background with clip image or default
                                Rectangle {
                                    anchors.fill: parent
                                    color: Colors.surfaceDark // was #1A1A1A
                                    radius: 12

                                    // Clip preview image
                                    Image {
                                        id: clipPreviewImage
                                        anchors.centerIn: parent
                                        width: 150
                                        height: 150
                                        fillMode: Image.PreserveAspectFit
                                        source: {
                                            const imgPath = clipEditorTab.editingClipImgPath;
                                            if (imgPath.length === 0) {
                                                return "qrc:/qt/qml/TalkLess/resources/images/audioClipDefaultBackground.png";
                                            } else if (imgPath.startsWith("qrc:") || imgPath.startsWith("file:") || imgPath.startsWith("http")) {
                                                return imgPath;
                                            } else {
                                                return "file:///" + imgPath; // Use 3 slashes for Windows local paths
                                            }
                                        }
                                    }

                                    // Decorative music notes (left side)
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 15
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        text: "🎵"
                                        font.pixelSize: 16
                                        opacity: 0.7
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 25
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 35
                                        text: "🎶"
                                        font.pixelSize: 14
                                        opacity: 0.6
                                    }

                                    // Decorative music notes (right side)
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 25
                                        text: "🎵"
                                        font.pixelSize: 18
                                        opacity: 0.7
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 35
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 40
                                        text: "🎶"
                                        font.pixelSize: 12
                                        opacity: 0.5
                                    }

                                    // Upload/Edit button (top right)
                                    Rectangle {
                                        id: editImageBtn
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 8
                                        anchors.rightMargin: 8
                                        width: 24
                                        height: 24
                                        radius: 4
                                        color: editImageArea.containsMouse ? Colors.surfaceLight : Colors.surface // was #444444/#333333

                                        Text {
                                            anchors.centerIn: parent
                                            text: "📷"
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: editImageArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.clipToEditImageId = root.selectedClipId;
                                                imageFileDialog.open();
                                            }
                                        }
                                    }
                                }
                            }

                            // ===== TITLE WITH EDIT ICON =====
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                spacing: 8

                                TextInput {
                                    id: clipTitleInput
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Colors.textPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    clip: true
                                    selectByMouse: true
                                    wrapMode: TextInput.NoWrap
                                    visible: clipEditorTab.isTitleEditing

                                    onVisibleChanged: {
                                        if (visible) {
                                            forceActiveFocus();
                                            // Select all text when entering edit mode? Optional.
                                            // selectAll();
                                        }
                                    }

                                    onTextChanged: {
                                        if (text !== clipEditorTab.editingClipName) {
                                            clipEditorTab.hasUnsavedChanges = true;
                                        }
                                    }

                                    // Save on Enter key with duplicate name validation
                                    Keys.onReturnPressed: {
                                        if (root.selectedClipId !== -1 && text.length > 0) {
                                            // Check for duplicate name (only if name changed)
                                            if (text !== clipEditorTab.editingClipName) {
                                                const isDuplicate = soundboardService.clipTitleExistsInBoard(soundboardService.activeBoardId, text);
                                                if (isDuplicate) {
                                                    // Generate a unique name instead
                                                    const uniqueName = soundboardService.generateUniqueClipTitle(soundboardService.activeBoardId, text);
                                                    clipTitleInput.text = uniqueName;
                                                    return; // Don't save yet, let user see the suggested name
                                                }
                                            }
                                            activeClipsModel.updateClip(root.selectedClipId, text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                            clipEditorTab.editingClipName = text;
                                            clipEditorTab.displayComputedTitle = text;
                                            activeClipsModel.reload();
                                        }
                                        clipEditorTab.isTitleEditing = false;
                                    }

                                    // Save on focus loss with duplicate name validation
                                    onActiveFocusChanged: {
                                        if (!activeFocus && visible) {
                                            if (root.selectedClipId !== -1 && text.length > 0 && text !== clipEditorTab.editingClipName) {
                                                // Check for duplicate name
                                                const isDuplicate = soundboardService.clipTitleExistsInBoard(soundboardService.activeBoardId, text);
                                                let finalName = text;
                                                if (isDuplicate) {
                                                    // Generate a unique name
                                                    finalName = soundboardService.generateUniqueClipTitle(soundboardService.activeBoardId, text);
                                                }
                                                activeClipsModel.updateClip(root.selectedClipId, finalName, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                                clipEditorTab.editingClipName = finalName;
                                                clipEditorTab.displayComputedTitle = finalName;
                                                activeClipsModel.reload();
                                            }
                                            clipEditorTab.isTitleEditing = false;
                                        }
                                    }
                                }

                                // Read-only Title Display
                                Text {
                                    id: clipTitleDisplay
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: clipEditorTab.displayComputedTitle
                                    color: Colors.textPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    visible: !clipEditorTab.isTitleEditing

                                    MouseArea {
                                        anchors.fill: parent
                                        onDoubleClicked: {
                                            clipTitleInput.text = clipEditorTab.displayComputedTitle;
                                            clipEditorTab.isTitleEditing = true;
                                        }
                                    }
                                }

                                // Edit icon
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 4
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✏️"
                                        font.pixelSize: 12
                                        color: Colors.textPrimary
                                        opacity: 0.7
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            clipTitleInput.text = clipEditorTab.displayComputedTitle;
                                            clipEditorTab.isTitleEditing = true;
                                        }
                                    }
                                }
                            }

                            // ===== HOTKEY SECTION =====
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                spacing: 12

                                Text {
                                    text: "Hotkey"
                                    color: Colors.textSecondary // was #AAAAAA
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: Colors.surfaceDark // was #1A1A1A
                                    radius: 8
                                    border.color: hotkeyArea.containsMouse ? Colors.accent : Colors.border // was #8B5CF6 / #3A3A3A
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: clipEditorTab.editingClipHotkey !== "" ? clipEditorTab.editingClipHotkey : "Not Set"
                                        color: clipEditorTab.editingClipHotkey !== "" ? Colors.textPrimary : Colors.textSecondary // was #FFFFFF / #666666
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                        font.weight: clipEditorTab.editingClipHotkey !== "" ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        id: hotkeyArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.hotkeyEditingClipId = -1; // Use editor behavior
                                            clipHotkeyPopup.open();
                                        }
                                    }
                                }

                                // Clear Hotkey button
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 8
                                    color: clearHotkeyArea.containsMouse ? Colors.surfaceLight : "transparent"
                                    border.color: clearHotkeyArea.containsMouse ? Colors.error : "transparent"
                                    border.width: 1
                                    visible: clipEditorTab.editingClipHotkey !== ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: "#FF4D4D"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: clearHotkeyArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            clipEditorTab.editingClipHotkey = "";
                                            clipEditorTab.hasUnsavedChanges = true;
                                        }
                                    }
                                }
                            }

                            // ===== VOICE VOLUME SLIDER =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Voice Volume"
                                        color: Colors.textPrimary // was #FFFFFF
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Math.round(clipEditorTab.clipVolume)
                                        color: Colors.textSecondary // was #AAAAAA
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 11
                                    }
                                }

                                Slider {
                                    id: volumeSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    from: 0
                                    to: 100
                                    value: clipEditorTab.clipVolume

                                    onValueChanged: {
                                        clipEditorTab.clipVolume = value;
                                        // Real-time volume update - no need to save
                                        if (root.selectedClipId !== -1) {
                                            activeClipsModel.setClipVolume(root.selectedClipId, Math.round(value));
                                        }
                                    }

                                    background: Rectangle {
                                        x: volumeSlider.leftPadding
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        width: volumeSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: Colors.surfaceLight // was #3A3A3A

                                        Rectangle {
                                            width: volumeSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
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
                                        }
                                    }

                                    handle: Rectangle {
                                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: Colors.textOnPrimary
                                    }
                                }
                            }

                            // ===== REPRODUCTION MODES SECTION =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                Layout.topMargin: 8
                                spacing: 12

                                // Section header
                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: "🔁"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: "Reproduction Mode"
                                        color: Colors.textPrimary // was #FFFFFF
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }

                                // Mode icons row (SVG + blue circle when selected)
                                RowLayout {
                                    id: modeSelectorRow
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 8

                                    // change this to your real theme flag
                                    property bool isLightTheme: Colors.currentTheme === "light"

                                    // helper: pick correct svg for mode + theme
                                    function modeIconSource(mode) {
                                        const base = "qrc:/qt/qml/TalkLess/resources/icons/reproduction/";
                                        const suffix = isLightTheme ? "_light.svg" : "_dark.svg";
                                        switch (mode) {
                                        case 0:
                                            return base + "overlay" + suffix;
                                        case 1:
                                            return base + "play-pause" + suffix;
                                        case 2:
                                            return base + "play-stop" + suffix;
                                        case 3:
                                            return base + "restart" + suffix;
                                        case 4:
                                            return base + "loop" + suffix;
                                        default:
                                            return "";
                                        }
                                    }

                                    ModeButton {
                                        mode: 0
                                    }
                                    ModeButton {
                                        mode: 1
                                    }
                                    ModeButton {
                                        mode: 2
                                    }
                                    ModeButton {
                                        mode: 3
                                    }
                                    ModeButton {
                                        mode: 4
                                    }
                                }

                                // Mode description text
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        const mode = parent.children[1].selectedMode;
                                        switch (mode) {
                                        case 0:
                                            return "Sound plays with other sounds";
                                        case 1:
                                            return "First click plays, second pauses";
                                        case 2:
                                            return "Second click stops and resets";
                                        case 3:
                                            return "Plays from start, pauses others";
                                        case 4:
                                            return "Loops from beginning, stops others";
                                        default:
                                            return "";
                                        }
                                    }
                                    color: Colors.textSecondary // was #AAAAAA
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ===== PLAYBACK BEHAVIOR SECTION =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Playback Behavior"
                                    color: Colors.textOnPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                // Checkbox items
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // Stop other sounds on play
                                    RowLayout {
                                        spacing: 8
                                        // Disabled when mode is Overlay (0), Play/Pause (1), or Play/Stop (2)
                                        property bool isReadOnly: clipEditorTab.reproductionMode === 0 || clipEditorTab.reproductionMode === 1 || clipEditorTab.reproductionMode === 2
                                        opacity: isReadOnly ? 0.5 : 1.0

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            // Force checked when mode is Play/Stop (2), force unchecked when Overlay (0) or Play/Pause (1)
                                            property bool effectiveValue: clipEditorTab.reproductionMode === 2 ? true : (clipEditorTab.reproductionMode === 0 || clipEditorTab.reproductionMode === 1 ? false : clipEditorTab.stopOtherSounds)
                                            color: effectiveValue ? Colors.gradientPrimaryStart : Colors.surfaceDark
                                            border.color: effectiveValue ? Colors.gradientPrimaryEnd : Colors.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.effectiveValue ? "✓" : ""
                                                color: Colors.textOnPrimary
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: parent.parent.isReadOnly ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                enabled: !parent.parent.isReadOnly
                                                onClicked: {
                                                    if (root.selectedClipId !== -1 && soundboardService) {
                                                        clipEditorTab.stopOtherSounds = !clipEditorTab.stopOtherSounds;
                                                        soundboardService.setClipStopOtherSounds(activeClipsModel.boardId, root.selectedClipId, clipEditorTab.stopOtherSounds);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: clipEditorTab.reproductionMode === 2 ? "Stop other sounds on play (auto)" : clipEditorTab.reproductionMode === 1 ? "Stop other sounds on play (disabled)" : clipEditorTab.reproductionMode === 0 ? "Stop other sounds on play (disabled)" : "Stop other sounds on play"
                                            color: parent.isReadOnly ? Colors.textDisabled : Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Mute other sounds
                                    RowLayout {
                                        spacing: 8
                                        // Disabled when mode is Overlay (0)
                                        property bool isReadOnly: clipEditorTab.reproductionMode === 0
                                        opacity: isReadOnly ? 0.5 : 1.0

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            // Force unchecked when Overlay mode
                                            property bool effectiveValue: clipEditorTab.reproductionMode === 0 ? false : clipEditorTab.muteOtherSounds
                                            color: effectiveValue ? Colors.gradientPrimaryStart : Colors.surfaceDark
                                            border.color: effectiveValue ? Colors.gradientPrimaryEnd : Colors.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.effectiveValue ? "✓" : ""
                                                color: Colors.textOnPrimary
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: parent.parent.isReadOnly ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                enabled: !parent.parent.isReadOnly
                                                onClicked: {
                                                    if (root.selectedClipId !== -1 && soundboardService) {
                                                        clipEditorTab.muteOtherSounds = !clipEditorTab.muteOtherSounds;
                                                        soundboardService.setClipMuteOtherSounds(activeClipsModel.boardId, root.selectedClipId, clipEditorTab.muteOtherSounds);
                                                        // If muteOtherSounds is enabled, also enable muteMicDuringPlayback
                                                        if (clipEditorTab.muteOtherSounds) {
                                                            clipEditorTab.muteMicDuringPlayback = true;
                                                            soundboardService.setClipMuteMicDuringPlayback(activeClipsModel.boardId, root.selectedClipId, true);
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: clipEditorTab.reproductionMode === 0 ? "Mute other sounds (disabled)" : "Mute other sounds"
                                            color: parent.isReadOnly ? Colors.textDisabled : Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Mute mic during playback
                                    RowLayout {
                                        spacing: 8
                                        // Disabled when muteOtherSounds is enabled - it's automatically on
                                        opacity: clipEditorTab.muteOtherSounds ? 0.5 : 1.0

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            // Force checked when muteOtherSounds is enabled
                                            property bool effectiveValue: clipEditorTab.muteOtherSounds || clipEditorTab.muteMicDuringPlayback
                                            color: effectiveValue ? Colors.gradientPrimaryStart : Colors.surfaceDark
                                            border.color: effectiveValue ? Colors.gradientPrimaryEnd : Colors.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.effectiveValue ? "✓" : ""
                                                color: Colors.textOnPrimary
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: clipEditorTab.muteOtherSounds ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                enabled: !clipEditorTab.muteOtherSounds
                                                onClicked: {
                                                    if (root.selectedClipId !== -1 && soundboardService) {
                                                        clipEditorTab.muteMicDuringPlayback = !clipEditorTab.muteMicDuringPlayback;
                                                        soundboardService.setClipMuteMicDuringPlayback(activeClipsModel.boardId, root.selectedClipId, clipEditorTab.muteMicDuringPlayback);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: clipEditorTab.muteOtherSounds ? "Mute mic during playback (auto)" : "Mute mic during playback"
                                            color: clipEditorTab.muteOtherSounds ? Colors.textDisabled : Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Persistent settings
                                    RowLayout {
                                        spacing: 8

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            color: clipEditorTab.persistentSettings ? Colors.gradientPrimaryStart : Colors.surfaceDark
                                            border.color: clipEditorTab.persistentSettings ? Colors.gradientPrimaryEnd : Colors.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: clipEditorTab.persistentSettings ? "✓" : ""
                                                color: Colors.textOnPrimary
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    clipEditorTab.persistentSettings = !clipEditorTab.persistentSettings;
                                                    // Auto-save (Note: persistentSettings not currently saved to backend)
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Persistent settings"
                                            color: Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Loop playback (real-time update)
                                    RowLayout {
                                        spacing: 8

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            color: clipEditorTab.clipIsRepeat ? Colors.gradientPrimaryStart : Colors.surfaceDark
                                            border.color: clipEditorTab.clipIsRepeat ? Colors.gradientPrimaryEnd : Colors.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: clipEditorTab.clipIsRepeat ? "✓" : ""
                                                color: Colors.textOnPrimary
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    // Toggle repeat - real-time update, saved immediately
                                                    if (root.selectedClipId !== -1 && activeClipsModel) {
                                                        clipEditorTab.clipIsRepeat = !clipEditorTab.clipIsRepeat;
                                                        activeClipsModel.setClipRepeat(root.selectedClipId, clipEditorTab.clipIsRepeat);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Loop playback"
                                            color: Colors.textPrimary
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            // ===== ADD TAG SECTION =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "Add Tag"
                                    color: Colors.textOnPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: Colors.surfaceDark
                                    radius: 18
                                    border.color: addTagInput.activeFocus ? "#8B5CF6" : "#3A3A3A"
                                    border.width: 1

                                    TextInput {
                                        id: addTagInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Colors.textPrimary
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                        clip: true
                                        selectByMouse: true

                                        Keys.onReturnPressed: {
                                            if (text.trim().length > 0) {
                                                clipEditorTab.editingClipTags.push(text.trim());
                                                // Auto-save tags
                                                if (root.selectedClipId !== -1) {
                                                    activeClipsModel.updateClip(root.selectedClipId, clipTitleInput.text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                                    activeClipsModel.reload();
                                                }
                                                text = "";
                                            }
                                        }

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            verticalAlignment: Text.AlignVCenter
                                            text: "Add tag and press enter"
                                            color: Colors.textSecondary
                                            font: parent.font
                                            visible: !parent.text && !parent.activeFocus
                                        }
                                    }
                                }

                                // Display current tags
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: clipEditorTab.editingClipTags.length > 0

                                    Repeater {
                                        model: clipEditorTab.editingClipTags

                                        Rectangle {
                                            required property string modelData
                                            required property int index

                                            width: tagText.implicitWidth + 24
                                            height: 24
                                            radius: 12
                                            color: Colors.surfaceDark

                                            Text {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: Colors.textPrimary
                                                font.pixelSize: 10
                                            }

                                            // Remove tag on click
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    clipEditorTab.editingClipTags.splice(index, 1);
                                                    clipEditorTab.editingClipTagsChanged();
                                                    // Auto-save tags
                                                    if (root.selectedClipId !== -1) {
                                                        activeClipsModel.updateClip(root.selectedClipId, clipTitleInput.text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                                        activeClipsModel.reload();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bottom padding (auto-save enabled - no manual save needed)
                            Item {
                                Layout.preferredHeight: 10
                            }
                        }
                    }
                }

                // Hotkey Capture Popup for clip
                HotkeyCapturePopup {
                    id: clipHotkeyPopup
                    title: "Assign Clip Hotkey"
                    anchors.centerIn: Overlay.overlay

                    onHotkeyConfirmed: function (hotkeyText) {
                        if (root.hotkeyEditingClipId !== -1) {
                            // Update immediately from tile click
                            const data = root.getClipDataById(root.hotkeyEditingClipId);
                            if (data) {
                                activeClipsModel.updateClip(root.hotkeyEditingClipId, data.title, hotkeyText, data.tags);
                                activeClipsModel.reload();
                            }
                            root.hotkeyEditingClipId = -1;
                        } else {
                            // Standard editor behavior - AUTO-SAVE hotkey
                            clipEditorTab.editingClipHotkey = hotkeyText;
                            if (root.selectedClipId !== -1) {
                                activeClipsModel.updateClip(root.selectedClipId, clipTitleInput.text, hotkeyText, clipEditorTab.editingClipTags);
                                activeClipsModel.reload();
                            }
                        }
                    }

                    onCancelled: {
                        console.log("Hotkey capture cancelled");
                        root.hotkeyEditingClipId = -1;
                    }
                }

                // Teleprompter Popup for clip-wise scripts
                TeleprompterPopup {
                    id: clipTeleprompterPopup

                    onSaved: function(clipId, text) {
                        console.log("Teleprompter saved for clip", clipId, ":", text);
                        // TODO: Save teleprompter text to clip data via service
                        // soundboardService.setClipTeleprompterText(clipId, text);
                    }

                    onCancelled: {
                        console.log("Teleprompter cancelled");
                    }
                }

                // Add Tab Content (Tab 1) - Wrapped in Item for loading overlay
                Item {
                    id: uploadTabContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: rightSidebar.currentTabIndex === 1

                    // Waveform loading state
                    property bool isLoadingWaveform: false
                    property string pendingWaveformPath: ""

                    // Timer to defer waveform loading (allows UI to update first)
                    Timer {
                        id: uploadWaveformLoadTimer
                        interval: 50  // Small delay to let UI render loading state
                        repeat: false
                        onTriggered: {
                            if (uploadTabContainer.pendingWaveformPath !== "") {
                                console.log("Loading waveform for:", uploadTabContainer.pendingWaveformPath);
                                const peaks = soundboardService.getWaveformPeaks(uploadTabContainer.pendingWaveformPath, 60);
                                if (peaks && peaks.length > 0) {
                                    uploadWaveform.waveformData = peaks;
                                }
                                uploadTabContainer.pendingWaveformPath = "";
                                uploadTabContainer.isLoadingWaveform = false;
                            }
                        }
                    }

                    ColumnLayout {
                        id: uploadTab
                        anchors.fill: parent
                        spacing: 6

                        // Preview playback position tracking
                        property real uploadPreviewPlaybackTime: 0

                        // Timer to poll preview playback position
                        Timer {
                            id: uploadPreviewPlayheadTimer
                            interval: 50
                            repeat: true
                            running: soundboardService?.isFilePreviewPlaying ?? false
                            onTriggered: {
                                uploadTab.uploadPreviewPlaybackTime = soundboardService?.getPreviewPlaybackPositionMs() ?? 0;
                            }
                            onRunningChanged: {
                                if (!running) {
                                    uploadTab.uploadPreviewPlaybackTime = 0;
                                }
                            }
                        }

                        onVisibleChanged: {
                            if (!visible) {
                                uploadAudioNameInput.focus = false;
                                // Stop any preview when leaving tab
                                if (soundboardService?.isFilePreviewPlaying) {
                                    soundboardService.stopFilePreview();
                                }
                            }
                        }

                    // Name Audio File Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Text {
                            text: "Name Audio File"
                            color: Colors.textOnPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Text Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: Colors.surfaceDark
                            radius: 8
                            border.color: Colors.border
                            border.width: 1

                            TextInput {
                                id: uploadAudioNameInput
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.textPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 0
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Enter a name for your audio file..."
                                    color: Colors.textDisabled
                                    font: parent.font
                                    visible: !parent.text && !parent.activeFocus
                                }
                            }
                        }
                    }

                    // Assign to Slot Section
                    // ColumnLayout {
                    //     Layout.fillWidth: true
                    //     Layout.leftMargin: 5
                    //     Layout.rightMargin: 5
                    //     spacing: 8

                    //     Text {
                    //         text: "Assign to Slot"
                    //         color: Colors.textOnPrimary
                    //         font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                    //         font.pixelSize: 14
                    //         font.weight: Font.DemiBold
                    //     }

                    //     // Dropdown selector
                    //     Rectangle {
                    //         Layout.fillWidth: true
                    //         Layout.preferredHeight: 44
                    //         color: Colors.surfaceDark
                    //         radius: 8
                    //         border.color: Colors.border
                    //         border.width: 1

                    //         RowLayout {
                    //             anchors.fill: parent
                    //             anchors.leftMargin: 15
                    //             anchors.rightMargin: 15

                    //             Text {
                    //                 text: "Select Available Slot"
                    //                 color: Colors.textSecondary
                    //                 font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                    //                 font.pixelSize: 13
                    //                 Layout.fillWidth: true
                    //             }

                    //             // Dropdown arrow
                    //             Text {
                    //                 text: "▼"
                    //                 color: Colors.textSecondary
                    //                 font.pixelSize: 10
                    //             }
                    //         }

                    //         MouseArea {
                    //             anchors.fill: parent
                    //             cursorShape: Qt.PointingHandCursor
                    //             onClicked: console.log("Slot dropdown clicked")
                    //         }
                    //     }
                    // }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 4
                    }

                    // File Upload Drop Area
                    FileDropArea {
                        id: fileDropArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5

                        onFileDropped: function (filePath, fileName) {
                            console.log("File dropped:", fileName, filePath);
                            // Always auto-fill the name input with the new file's name
                            // Remove extension from filename
                            var nameWithoutExt = fileName.replace(/\.[^/.]+$/, "");
                            uploadAudioNameInput.text = nameWithoutExt;

                            // Get duration for trim preview
                            fileDuration = soundboardService.getFileDuration(filePath);
                            console.log("File duration detected:", fileDuration);

                            // Reset trim sliders to full range for new file
                            uploadWaveform.resetTrimPositions();

                            // Defer waveform loading to avoid UI freeze
                            uploadTabContainer.isLoadingWaveform = true;
                            uploadTabContainer.pendingWaveformPath = filePath;
                            uploadWaveformLoadTimer.start();
                        }

                        onFileCleared: {
                            console.log("File cleared");
                            fileDuration = 0;
                            uploadAudioNameInput.text = "";
                            uploadWaveform.waveformData = [];
                            if (soundboardService?.isFilePreviewPlaying) {
                                soundboardService.stopFilePreview();
                            }
                        }

                        property real fileDuration: 0
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 4
                    }

                    // Trim Audio Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8
                        visible: fileDropArea.droppedFilePath !== ""

                        Text {
                            text: "Trim Audio"
                            color: Colors.textOnPrimary
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Waveform Display (without playback controls)
                        TrimWaveform {
                            id: uploadWaveform
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            currentTime: {
                                if (soundboardService?.isFilePreviewPlaying ?? false) {
                                    return uploadTab.uploadPreviewPlaybackTime / 1000.0;
                                }
                                return 0;
                            }
                            totalDuration: fileDropArea.fileDuration

                            property real trimStartMs: 0
                            property real trimEndMs: fileDropArea.fileDuration * 1000.0

                            onTrimStartMoved: function (pos) {
                                trimStart = pos;  // Update visual position
                                trimStartMs = pos * totalDuration * 1000.0;
                            }
                            onTrimEndMoved: function (pos) {
                                trimEnd = pos;  // Update visual position
                                trimEndMs = pos * totalDuration * 1000.0;
                            }
                        }

                        // Preview trimmed audio button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 8
                            color: (soundboardService?.isFilePreviewPlaying ?? false) ? Colors.error : Colors.accent
                            visible: fileDropArea.droppedFilePath !== ""

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: (soundboardService?.isFilePreviewPlaying ?? false) ? "■" : "▶"
                                    color: Colors.textOnPrimary
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: (soundboardService?.isFilePreviewPlaying ?? false) ? "Stop Preview" : "Preview Trim"
                                    color: Colors.textOnPrimary
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (soundboardService?.isFilePreviewPlaying) {
                                        soundboardService.stopFilePreview();
                                    } else {
                                        // Calculate trim times
                                        let startMs = uploadWaveform.trimStartMs;
                                        let endMs = uploadWaveform.trimEndMs;
                                        soundboardService.playFilePreviewTrimmed(fileDropArea.droppedFilePath, startMs, endMs);
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 6
                    }

                    // Cancel and Save buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        // Cancel button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: uploadCancelBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                            radius: 8

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: uploadCancelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("Upload Cancel clicked");
                                    fileDropArea.droppedFilePath = "";
                                    fileDropArea.droppedFileName = "";
                                    uploadAudioNameInput.text = "";
                                    if (soundboardService?.isFilePreviewPlaying) {
                                        soundboardService.stopFilePreview();
                                    }
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // Save button (gradient)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 8
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: uploadSaveBtnArea.containsMouse ? Colors.primaryLight : Colors.primary
                                }
                                GradientStop {
                                    position: 1.0
                                    color: uploadSaveBtnArea.containsMouse ? Colors.secondary : Colors.gradientPrimaryEnd
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: uploadSaveBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    console.log("Upload Save clicked");

                                    // Check if a file has been dropped/selected
                                    if (fileDropArea.droppedFilePath === "") {
                                        console.log("No file selected");
                                        return;
                                    }

                                    // Get the board ID
                                    const boardId = activeClipsModel.boardId;
                                    if (boardId < 0) {
                                        console.log("No board selected");
                                        return;
                                    }

                                    // Save the clip with the user-entered title (or auto-generated one)
                                    const filePath = "file:///" + fileDropArea.droppedFilePath;
                                    const title = uploadAudioNameInput.text;

                                    const success = soundboardService.addClipWithSettings(boardId, filePath, title, uploadWaveform.trimStartMs, uploadWaveform.trimEndMs);

                                    if (success) {
                                        console.log("Clip saved successfully with trim:", uploadWaveform.trimStartMs, uploadWaveform.trimEndMs);
                                        // Reload the clips model
                                        activeClipsModel.reload();

                                        // Clear the form
                                        fileDropArea.droppedFilePath = "";
                                        fileDropArea.droppedFileName = "";
                                        uploadAudioNameInput.text = "";

                                        // Return to Settings tab (main tab)
                                        rightSidebar.currentTabIndex = 0;
                                    } else {
                                        console.log("Failed to save clip");
                                    }
                                }
                            }
                        }
                    }

                    // Fill remaining space
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Loading overlay for waveform processing
                Rectangle {
                    id: waveformLoadingOverlay
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.7)
                    visible: uploadTabContainer.isLoadingWaveform
                    z: 100

                    // Block mouse events while loading
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        // Spinner animation
                        Rectangle {
                            id: spinnerContainer
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48
                            height: 48
                            color: "transparent"

                            Rectangle {
                                id: spinnerArc
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                radius: width / 2
                                color: "transparent"
                                border.width: 4
                                border.color: Colors.accent

                                // Create spinning effect with rotation
                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: waveformLoadingOverlay.visible
                                }

                                // Gradient mask to create arc effect
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.verticalCenter
                                    width: parent.width / 2 + 4
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Loading waveform..."
                            color: Colors.textOnPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                }
                }

                // Teleprompter Tab Content (Tab 3)
                ColumnLayout {
                    id: teleprompterTab
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 3

                    // Property to store teleprompter text
                    property string teleprompterText: ""

                    // Header
                    Text {
                        text: "Teleprompter"
                        color: Colors.textOnPrimary
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Layout.leftMargin: 5
                    }

                    // Main text area container
                    Rectangle {
                        id: teleprompterContainer
                        Layout.fillWidth: true
                        // Dynamic height based on content, with min/max constraints
                        // +24 for RowLayout margins (12px top + 12px bottom)
                        Layout.preferredHeight: {
                            var contentHeight = teleprompterTextEdit.implicitHeight + 24;
                            return Math.min(420, Math.max(140, contentHeight));
                        }
                        Layout.minimumHeight: 140
                        Layout.maximumHeight: 420
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        color: Colors.surfaceDark
                        radius: 12
                        border.color: Colors.border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Upload icon (left side)
                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignTop
                                color: "transparent"

                                Image {
                                    id: uploadIconImg
                                    anchors.fill: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_upload.svg"
                                    sourceSize: Qt.size(24, 24)
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: uploadIconImg
                                    source: uploadIconImg
                                    colorization: 1.0
                                    colorizationColor: Colors.currentTheme === "light" ? "#000000" : "#FFFFFF"
                                    opacity: uploadIconArea.containsMouse ? 1.0 : 0.6
                                }

                                MouseArea {
                                    id: uploadIconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        teleprompterFileDialog.open();
                                    }
                                }
                            }

                            // Scrollable text area
                            Flickable {
                                id: teleprompterFlickable
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: width
                                contentHeight: teleprompterTextEdit.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                TextEdit {
                                    id: teleprompterTextEdit
                                    width: teleprompterFlickable.width
                                    text: teleprompterTab.teleprompterText
                                    color: Colors.textPrimary
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    selectionColor: Colors.accent

                                    onTextChanged: {
                                        teleprompterTab.teleprompterText = text;
                                    }

                                    // Placeholder text
                                    Text {
                                        anchors.fill: parent
                                        text: "Enter your script here..."
                                        color: Colors.textDisabled
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }
                            }

                            // Microphone icon (right side)
                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignTop
                                color: "transparent"

                                Image {
                                    id: micIconImg
                                    anchors.fill: parent
                                    source: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_mic_outline.svg"
                                    sourceSize: Qt.size(24, 24)
                                    fillMode: Image.PreserveAspectFit
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: micIconImg
                                    source: micIconImg
                                    colorization: 1.0
                                    colorizationColor: Colors.currentTheme === "light" ? "#000000" : "#FFFFFF"
                                    opacity: micIconArea.containsMouse ? 1.0 : 0.6
                                }

                                MouseArea {
                                    id: micIconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("Microphone clicked - speech-to-text placeholder");
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        Layout.preferredHeight: 8
                    }

                    // Download button
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 36
                        Layout.leftMargin: 5
                        color: downloadBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                        radius: 8

                        Text {
                            anchors.centerIn: parent
                            text: "Download"
                            color: Colors.textOnPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: downloadBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                teleprompterSaveDialog.open();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // File dialog for importing text
                    FileDialog {
                        id: teleprompterFileDialog
                        title: "Import Text File"
                        nameFilters: ["Text files (*.txt)", "All files (*)"]
                        fileMode: FileDialog.OpenFile

                        onAccepted: {
                            if (selectedFile) {
                                var fileUrl = selectedFile.toString();
                                var filePath = fileUrl.replace(/^file:\/\//, "");
                                // Read file content via service (placeholder - would need backend support)
                                console.log("Import from:", filePath);
                            }
                        }
                    }

                    // File dialog for saving text
                    FileDialog {
                        id: teleprompterSaveDialog
                        title: "Save Teleprompter Text"
                        nameFilters: ["Text files (*.txt)"]
                        fileMode: FileDialog.SaveFile
                        defaultSuffix: "txt"

                        onAccepted: {
                            if (selectedFile) {
                                var fileUrl = selectedFile.toString();
                                var filePath = fileUrl.replace(/^file:\/\//, "");
                                // Save file content via service (placeholder - would need backend support)
                                console.log("Save to:", filePath);
                                console.log("Content:", teleprompterTab.teleprompterText);
                            }
                        }
                    }

                    // Fill remaining space
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Speaker Tab Content (Tab 4)
                ColumnLayout {
                    id: speakerTabContent
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 4

                    // --- Meters & Monitoring (Speaker Tab) ---
                    Text {
                        text: "Meters & Monitoring"
                        color: Colors.textOnPrimary
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        topPadding: 6
                    }

                    // Audio Monitoring Properties & Logic
                    property real rmsLevel: 0.0
                    property real micLevel: 0.0
                    property real rmsDb: -60.0
                    property real micDb: -60.0
                    property bool volumeTooHigh: (rmsLevel >= 0.90)

                    Timer {
                        interval: 50
                        running: rightSidebar.currentTabIndex === 4 && Qt.application.state === Qt.ApplicationActive
                        repeat: true
                        onTriggered: {
                            if (soundboardService) {
                                var out = soundboardService.getMasterPeakLevel();
                                var mic = soundboardService.getMicPeakLevel();

                                // Defensive: handle undefined / NaN
                                out = (out === undefined || isNaN(out)) ? 0.0 : out;
                                mic = (mic === undefined || isNaN(mic)) ? 0.0 : mic;

                                // Clamp to 0..1 (assuming service returns linear peak)
                                rmsLevel = Math.max(0.0, Math.min(1.0, out));
                                micLevel = Math.max(0.0, Math.min(1.0, mic));

                                // Convert to dBFS (min clamp avoids -Inf)
                                var outLin = Math.max(rmsLevel, 0.0001);
                                var micLin = Math.max(micLevel, 0.0001);

                                rmsDb = 20 * Math.log(outLin) / Math.LN10;
                                micDb = 20 * Math.log(micLin) / Math.LN10;
                            }
                        }
                    }

                    // Main meters row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        spacing: 16

                        // Left segmented meter (Real-time Output Level)
                        Item {
                            Layout.preferredWidth: 40
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                            }

                            Column {
                                id: outputMeterColumn
                                anchors.centerIn: parent
                                spacing: 4

                                readonly property int segmentCount: 25

                                // Map dBFS (-60..0) -> 0..1
                                readonly property real minDb: -60.0
                                readonly property real maxDb: 0.0
                                readonly property real norm: Math.max(0.0, Math.min(1.0, (speakerTabContent.rmsDb - minDb) / (maxDb - minDb)))

                                readonly property int activeCount: Math.round(norm * segmentCount)

                                Repeater {
                                    model: outputMeterColumn.segmentCount
                                    delegate: Rectangle {
                                        required property int index
                                        width: 24
                                        height: 5
                                        radius: 2

                                        property int idxFromBottom: (outputMeterColumn.segmentCount - 1) - index

                                        color: {
                                            var on = (idxFromBottom < outputMeterColumn.activeCount);
                                            if (!on)
                                                return Qt.rgba(1, 1, 1, 0.10);
                                            if (idxFromBottom >= 14)
                                                return "#FF3B30";  // red
                                            if (idxFromBottom >= 10)
                                                return "#FFD60A";  // yellow
                                            return "#34C759";                           // green
                                        }
                                    }
                                }
                            }
                        }

                        // Center: Master Gain Slider (Vertical)
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 40
                            spacing: 8

                            Slider {
                                id: masterVerticalSlider
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillHeight: true
                                Layout.preferredWidth: 40
                                orientation: Qt.Vertical
                                from: -60
                                to: 12
                                onMoved: if (soundboardService)
                                    soundboardService.masterGainDb = value
                                Binding on value {
                                    value: soundboardService?.masterGainDb ?? 0
                                    when: !masterVerticalSlider.pressed
                                }

                                background: Item {
                                    implicitWidth: 46

                                    // Track
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 32
                                        height: parent.height
                                        radius: width / 2
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                    }

                                    // Fill (Gradient Red)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: 32
                                        height: (1.0 - masterVerticalSlider.visualPosition) * parent.height
                                        radius: width / 2
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: "#FF453A"
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: "#FF3B30"
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    // Bubble Handle
                                    x: masterVerticalSlider.leftPadding + masterVerticalSlider.availableWidth / 2 - width / 2
                                    y: masterVerticalSlider.topPadding + masterVerticalSlider.availableHeight * masterVerticalSlider.visualPosition - height / 2
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: Colors.accent // Purple bubble
                                    border.color: "white"
                                    border.width: 2

                                    // Text inside bubble
                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(masterVerticalSlider.value) // + "db" (too small space)
                                        color: "white"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    // Shadow for gloss effect
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: "#80000000"
                                        shadowBlur: 8
                                        shadowVerticalOffset: 2
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "RMS Volume"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                            }
                        }

                        // Right: Mic Gain Slider (Vertical)
                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 40
                            spacing: 8

                            Slider {
                                id: micVerticalSlider
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillHeight: true
                                Layout.preferredWidth: 40
                                orientation: Qt.Vertical
                                from: -60
                                to: 12
                                onMoved: if (soundboardService)
                                    soundboardService.micGainDb = value
                                Binding on value {
                                    value: soundboardService?.micGainDb ?? 0
                                    when: !micVerticalSlider.pressed
                                }

                                background: Item {
                                    implicitWidth: 46

                                    // Track
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 32
                                        height: parent.height
                                        radius: width / 2
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                    }

                                    // Fill (Gradient Green)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: 32
                                        height: (1.0 - micVerticalSlider.visualPosition) * parent.height
                                        radius: width / 2
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: "#34C759"
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: '#16662a'
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    // Bubble Handle
                                    x: micVerticalSlider.leftPadding + micVerticalSlider.availableWidth / 2 - width / 2
                                    y: micVerticalSlider.topPadding + micVerticalSlider.availableHeight * micVerticalSlider.visualPosition - height / 2
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: Colors.accent // Purple bubble
                                    border.color: Colors.textPrimary
                                    border.width: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(micVerticalSlider.value) + "db"
                                        color: "white"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: "#80000000"
                                        shadowBlur: 8
                                        shadowVerticalOffset: 2
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Mic input"
                                color: Colors.textOnPrimary
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                            }
                        }
                    }

                    // // Warning row
                    // RowLayout {
                    //     Layout.fillWidth: true
                    //     spacing: 10
                    //     visible: volumeTooHigh

                    //     // simple warning icon
                    //     Canvas {
                    //         Layout.preferredWidth: 18
                    //         Layout.preferredHeight: 18
                    //         onPaint: {
                    //             var ctx = getContext("2d");
                    //             ctx.clearRect(0, 0, width, height);

                    //             ctx.beginPath();
                    //             ctx.moveTo(width / 2, 2);
                    //             ctx.lineTo(width - 2, height - 2);
                    //             ctx.lineTo(2, height - 2);
                    //             ctx.closePath();
                    //             ctx.fillStyle = "rgba(255, 214, 10, 0.95)";
                    //             ctx.fill();

                    //             ctx.fillStyle = "rgba(0,0,0,0.70)";
                    //             ctx.fillRect(width / 2 - 1, 6, 2, 6);
                    //             ctx.fillRect(width / 2 - 1, 13.5, 2, 2);
                    //         }
                    //     }

                    //     Text {
                    //         text: "Volume too high"
                    //         color: Colors.textSecondary
                    //         font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                    //         font.pixelSize: 12
                    //     }
                    // }
                }
            }
        }
    }

    // reusable button
    component ModeButton: Rectangle {
        required property int mode
        property bool selected: clipEditorTab.reproductionMode === mode

        width: 36
        height: 36
        radius: 8
        color: ma.containsMouse ? Colors.surfaceDark : Colors.surface
        border.width: 1

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 14
            visible: parent.selected
            color: Colors.gradientPrimaryStart
        }

        Image {
            anchors.centerIn: parent
            source: modeSelectorRow.modeIconSource(parent.mode)
            width: 18
            height: 18
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.selectedClipId !== -1) {
                    clipEditorTab.reproductionMode = parent.mode;
                    soundboardService.setClipReproductionMode(activeClipsModel.boardId, root.selectedClipId, parent.mode);
                    console.log("Reproduction mode changed to:", parent.mode, "- SAVED!");
                }
            }
        }
    }

    // Helper for tab buttons
    component TabButton: Rectangle {
        property int index: 0
        property string iconSource: ""
        property string emoji: ""
        property bool isActive: rightSidebar.currentTabIndex === index

        width: 32
        height: 32
        radius: 8
        color: isActive ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2) : (mouse.containsMouse ? Colors.surfaceLight : "transparent")
        border.color: isActive ? Colors.accent : "transparent"
        border.width: 1

        Image {
            anchors.centerIn: parent
            source: iconSource
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
            visible: iconSource !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: isActive ? Colors.accent : Colors.textSecondary
            }
        }

        Text {
            anchors.centerIn: parent
            text: emoji
            visible: emoji !== ""
            font.pixelSize: 16
            opacity: isActive ? 1.0 : 0.7
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rightSidebar.currentTabIndex = index
        }
    }
}
