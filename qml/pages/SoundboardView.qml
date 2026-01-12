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

    property bool isDetached: false
    signal requestDetach
    signal requestDock

    // Helper function to find clip data by ID in the model
    function getClipDataById(clipId) {
        if (clipId === -1)
            return null;

        // Use the new backend function for more reliable and efficient data retrieval
        const data = soundboardService.getClipData(clipsModel.boardId, clipId);
        if (!data || Object.keys(data).length === 0)
            return null;

        return {
            clipId: data.id,
            title: data.title,
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

        console.log("pushToEditor: Updating editor with clip", data.clipId, "mode:", data.reproductionMode, "volume:", data.clipVolume);

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
        if (typeof modeSelectorRow !== 'undefined' && modeSelectorRow !== null) {
            modeSelectorRow.ignoreNextChange = true;
            modeSelectorRow.selectedMode = newMode;
        }

        // Playback behavior options
        clipEditorTab.stopOtherSounds = data.stopOtherSounds || false;
        clipEditorTab.muteOtherSounds = data.muteOtherSounds || false;
        clipEditorTab.muteMicDuringPlayback = data.muteMicDuringPlayback || false;

        clipEditorTab.durationSec = data.durationSec || 0.0;
        clipEditorTab.trimStartMs = data.trimStartMs || 0.0;
        clipEditorTab.trimEndMs = data.trimEndMs || 0.0;

        clipTitleInput.text = data.title || "";
    }

    // Refresh when core IDs change
    onSelectedClipIdChanged: updateDisplayedClipData()
    onPlayingClipIdChanged: updateDisplayedClipData()

    // Refresh editor when model data changes (e.g., after saving settings)
    Connections {
        target: clipsModel
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
            console.log("File selected:", selectedFile);
            const boardId = clipsModel.boardId;
            if (boardId >= 0) {
                const success = soundboardService.addClip(boardId, selectedFile.toString());
                if (success) {
                    clipsModel.reload();
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
            console.log("Image selected:", selectedFile, "for clip:", root.clipToEditImageId);
            if (root.clipToEditImageId >= 0) {
                const success = clipsModel.updateClipImage(root.clipToEditImageId, selectedFile.toString());
                if (success) {
                    console.log("Background image updated successfully");
                    clipsModel.reload();  // Reload to show new image
                } else {
                    console.log("Failed to update background image");
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
        target: clipsModel
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
            root.updateDisplayedClipData();
        }


        function onClipPlaybackPaused(clipId) {
            // Update the UI when a clip is paused (but keep it as the displayed clip)
            root.updateDisplayedClipData();
        }

        function onClipPlaybackStopped(clipId) {
            if (root.playingClipId === clipId) {
                // Find if any other clip is still playing
                let foundPlaying = -1;
                for (let i = 0; i < clipsModel.count; i++) {
                    const index = clipsModel.index(i, 0);
                    if (clipsModel.data(index, 263)) { // IsPlayingRole
                        foundPlaying = clipsModel.data(index, 257); // IdRole
                        break;
                    }
                }
                root.playingClipId = foundPlaying;
            }
            root.updateDisplayedClipData();
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

    // Main 3-column layout
    RowLayout {
        anchors.fill: parent
        spacing: 15

        // LEFT COLUMN: Banner and Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Removed maximumWidth to allow pushing sidebar to the right
            spacing: 20

            // Background Banner
            Rectangle {
                id: bannerContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 145
                Layout.maximumHeight: 145
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
                    color: "#000000"
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
                                color: "#FFFFFF"
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
                            color: "#1F1F1F"
                            radius: 8
                            border.color: "#333333"
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
                                    color: menuItemMouse.containsMouse ? "#333333" : "transparent"

                                    required property string modelData

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: menuItem.modelData
                                        color: menuItem.modelData === "Delete" ? "#FF6B6B" : "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 14
                                        font.weight: Font.Normal
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
                            text: clipsModel.boardName || "Soundboard"
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
                                color: addMouseArea.containsMouse ? Colors.secondary : "#D214FD"
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
                                console.log("Add Soundboard clicked");
                                soundboardService.createBoard("New Soundboard");
                                soundboardsModel.reload();
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
                        color: disconnectMouseArea.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.1) : Colors.surfaceDark
                        border.color: disconnectMouseArea.containsMouse ? Colors.error : Colors.border
                        border.width: 1

                        MouseArea {
                            id: disconnectMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isDetached) {
                                    console.log("Docking Soundboard...");
                                    root.requestDock();
                                } else {
                                    console.log("Detaching Soundboard...");
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

            // Spacer between banner and content
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
            }

            // Soundboard content area
            Rectangle {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0d0d0d"
                radius: 12

                // Tile sizing properties - responsive layout with scale factor
                readonly property real tileSpacing: 15
                readonly property real tilePadding: 20
                // Base size range, scaled by slotSizeScale (0.5 to 1.5)
                readonly property real baseMinTileWidth: 120
                readonly property real baseMaxTileWidth: 180
                readonly property real minTileWidth: baseMinTileWidth * soundboardService.slotSizeScale
                readonly property real maxTileWidth: baseMaxTileWidth * soundboardService.slotSizeScale

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

                // Dummy clips data - REMOVED, now using real clipsModel
                // The clipsModel is exposed from C++ and updated when a soundboard is selected

                // Flickable area for scrolling
                Flickable {
                    id: clipsFlickable
                    anchors.fill: parent
                    anchors.margins: contentArea.tilePadding
                    contentWidth: width
                    contentHeight: clipsGrid.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    // DropArea for adding new files via drag and drop
                    DropArea {
                        id: gridFileDropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"] // Standard for file drops

                        onDropped: function (drop) {
                            if (drop.hasUrls) {
                                let urls = [];
                                for (let i = 0; i < drop.urls.length; i++) {
                                    urls.push(drop.urls[i].toString());
                                }

                                const boardId = clipsModel.boardId;
                                if (boardId !== -1) {
                                    console.log("Adding clips from drop:", urls);
                                    const success = soundboardService.addClips(boardId, urls);
                                    if (success) {
                                        clipsModel.reload();
                                    }
                                }
                                drop.accept();
                            }
                        }

                        // Visual feedback for file dragging
                        Rectangle {
                            anchors.fill: parent
                            color: "#2a00ff00"
                            visible: parent.containsDrag
                            border.color: "#00ff00"
                            border.width: 3
                            radius: 12

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                // Large plus icon
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "+"
                                    color: "#00ff00"
                                    font.pixelSize: 64
                                    font.weight: Font.Light

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        colorization: 1.0
                                        colorizationColor: "#00ff00"
                                        blurEnabled: true
                                        blur: 0.5
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Drop audio files to add to soundboard"
                                    color: "#00ff00"
                                    font.pixelSize: 22
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

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
                            enabled: soundboardService.canPaste
                            onTriggered: {
                                const bId = clipsModel.boardId;
                                if (bId !== -1 && soundboardService.pasteClip(bId)) {
                                    clipsModel.reload();
                                }
                            }
                        }
                    }

                    // Grid layout for tiles
                    Flow {
                        id: clipsGrid
                        width: parent.width
                        spacing: contentArea.tileSpacing

                        // Add Audio Tile (first item)
                        AddAudioTile {
                            id: addAudioTile
                            width: contentArea.tileWidth
                            height: contentArea.tileHeight
                            enabled: true
                            onClicked: {
                                console.log("Add Audio clicked - opening add audio panel");
                                rightSidebar.currentTabIndex = 1;
                                audioFileDialog.open()
                            }
                        }

                        // Real Clip Tiles from clipsModel with drag-and-drop reordering
                        Repeater {
                            id: clipsRepeater
                            model: clipsModel

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

                                // For drag-drop visual feedback
                                Drag.active: dragHandler.active
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                ClipTile {
                                    id: clipTile
                                    anchors.fill: parent

                                    title: clipWrapper.clipTitle.length > 0 ? clipWrapper.clipTitle : ("Clip " + (clipWrapper.index + 1))
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

                                    // Make tile semi-transparent when dragging
                                    opacity: dragHandler.active ? 0.7 : 1.0

                                    onClicked: {
                                        // Selecting the clip updates the sidebar
                                        console.log("ClipTile clicked - index:", clipWrapper.index, "clipId:", clipWrapper.clipId, "title:", clipWrapper.clipTitle);
                                        soundboardService.setCurrentlySelectedClip(clipWrapper.clipId);
                                        soundboardService.playClip(clipWrapper.clipId);
                                    }

                                    onPlayClicked: {
                                        console.log("ClipTile playClicked - clipId:", clipWrapper.clipId, "title:", clipWrapper.clipTitle, "filePath:", clipWrapper.filePath);
                                        soundboardService.playClip(clipWrapper.clipId);
                                    }
                                    onStopClicked: {
                                        soundboardService.stopClip(clipWrapper.clipId);
                                    }
                                    onDeleteClicked: {
                                        if (soundboardService.deleteClip(clipsModel.boardId, clipWrapper.clipId)) {
                                            if (root.selectedClipId === clipWrapper.clipId)
                                                root.selectedClipId = -1;
                                            clipsModel.reload();
                                        }
                                    }
                                    onEditClicked: {
                                        soundboardService.setCurrentlySelectedClip(clipWrapper.clipId);
                                        rightSidebar.currentTabIndex = 0; // Focus the editor tab
                                    }
                                    onWebClicked: {
                                        console.log("Web clicked for clip:", clipWrapper.clipId);
                                        // Open sharing URL?
                                    }
                                    onCopyClicked: {
                                        soundboardService.copyClip(clipWrapper.clipId);
                                    }
                                    onPasteClicked: {
                                        if (soundboardService.pasteClip(clipsModel.boardId)) {
                                            clipsModel.reload();
                                        }
                                    }
                                    onEditBackgroundClicked: {
                                        console.log("Edit background clicked:", clipWrapper.clipId, clipWrapper.clipTitle);
                                        root.clipToEditImageId = clipWrapper.clipId;
                                        imageFileDialog.open();
                                    }
                                    onHotkeyClicked: {
                                        console.log("Hotkey clicked for clip:", clipWrapper.clipId);
                                        root.hotkeyEditingClipId = clipWrapper.clipId;
                                        clipHotkeyPopup.open();
                                    }
                                }

                                // Drag handler for reordering
                                DragHandler {
                                    id: dragHandler
                                    target: clipWrapper.parent === clipsGrid ? null : clipWrapper

                                    onActiveChanged: {
                                        if (active) {
                                            // Store the starting position
                                            clipWrapper.startX = clipWrapper.x;
                                            clipWrapper.startY = clipWrapper.y;
                                            // Reparent to root for dragging above other items
                                            clipWrapper.parent = clipsFlickable;
                                            clipWrapper.z = 100;
                                        } else {
                                            // Find drop target based on position
                                            var dropIndex = -1;
                                            var centerX = clipWrapper.x + clipWrapper.width / 2;
                                            var centerY = clipWrapper.y + clipWrapper.height / 2;

                                            for (var i = 0; i < clipsRepeater.count; i++) {
                                                if (i === clipWrapper.index)
                                                    continue;
                                                var item = clipsRepeater.itemAt(i);
                                                if (item) {
                                                    var itemPos = item.mapToItem(clipsFlickable, 0, 0);
                                                    if (centerX >= itemPos.x && centerX <= itemPos.x + item.width && centerY >= itemPos.y && centerY <= itemPos.y + item.height) {
                                                        dropIndex = i;
                                                        break;
                                                    }
                                                }
                                            }

                                            // Reparent back to grid
                                            clipWrapper.parent = clipsGrid;
                                            clipWrapper.z = 0;

                                            // If dropped on a valid position, reorder
                                            if (dropIndex >= 0 && dropIndex !== clipWrapper.index) {
                                                console.log("Moving clip from", clipWrapper.index, "to", dropIndex);
                                                soundboardService.moveClip(soundboardService.activeBoardId, clipWrapper.index, dropIndex);
                                                clipsModel.reload();
                                            }
                                        }
                                    }
                                }

                                // Drop area for receiving dragged items
                                DropArea {
                                    anchors.fill: parent

                                    Rectangle {
                                        anchors.fill: parent
                                        color: parent.containsDrag ? "#4400FF00" : "transparent"
                                        radius: 16
                                        border.width: parent.containsDrag ? 2 : 0
                                        border.color: "#00FF00"
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
            }

            // Audio Player Card - below the clips grid
            AudioPlayerCard {
                id: audioPlayerCard
                Layout.preferredWidth: 228
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10

                // Visible only when a clip is selected or playing
                visible: root.displayedClipData !== null

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

                // Play/Pause the displayed clip
                onPlayClicked: {
                    if (root.displayedClipData) {
                        soundboardService.playClip(root.displayedClipData.clipId);
                    }
                }
                onPauseClicked: {
                    if (root.displayedClipData) {
                        soundboardService.stopClip(root.displayedClipData.clipId);
                    }
                }

                // Navigate to previous/next clip in the list
                onPreviousClicked: {
                    console.log("Audio Player: Previous clicked");
                    if (clipsModel.count === 0)
                        return;

                    // Find current index and go to previous
                    let currentIndex = -1;
                    for (let i = 0; i < clipsModel.count; i++) {
                        const index = clipsModel.index(i, 0);
                        const id = clipsModel.data(index, 257);
                        if (id === root.selectedClipId) {
                            currentIndex = i;
                            break;
                        }
                    }

                    if (currentIndex > 0) {
                        const prevIndex = clipsModel.index(currentIndex - 1, 0);
                        root.selectedClipId = clipsModel.data(prevIndex, 257);
                    } else if (currentIndex === 0 && clipsModel.count > 0) {
                        // Wrap to last clip
                        const lastIndex = clipsModel.index(clipsModel.count - 1, 0);
                        root.selectedClipId = clipsModel.data(lastIndex, 257);
                    }
                }
                onNextClicked: {
                    console.log("Audio Player: Next clicked");
                    if (clipsModel.count === 0)
                        return;

                    // Find current index and go to next
                    let currentIndex = -1;
                    for (let i = 0; i < clipsModel.count; i++) {
                        const index = clipsModel.index(i, 0);
                        const id = clipsModel.data(index, 257);
                        if (id === root.selectedClipId) {
                            currentIndex = i;
                            break;
                        }
                    }

                    if (currentIndex >= 0 && currentIndex < clipsModel.count - 1) {
                        const nextIndex = clipsModel.index(currentIndex + 1, 0);
                        root.selectedClipId = clipsModel.data(nextIndex, 257);
                    } else if (currentIndex === clipsModel.count - 1) {
                        // Wrap to first clip
                        const firstIndex = clipsModel.index(0, 0);
                        root.selectedClipId = clipsModel.data(firstIndex, 257);
                    }
                }
                isMuted: !soundboardService.isMicEnabled()
                onMuteClicked: {
                    console.log("Audio Player: Mute toggled, muted:", isMuted);
                    soundboardService.setMicEnabled(!isMuted);
                }
            }
        }

        // RIGHT COLUMN: Modern Sidebar with Premium Styling
        Rectangle {
            id: rightSidebar
            Layout.preferredWidth: 300
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
            property int currentTabIndex: 0  // Default to Record tab
            property var tabState: ["Clip Editor", "Add Audio", "Recording", "Teleprompter", "Speaker"]
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

                        // Current Tab Title
                        Text {
                            text: tabState[currentTabIndex]
                            color: Colors.textPrimary
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
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
                            }
                            TabButton {
                                index: 1
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_add.svg"
                            }
                            TabButton {
                                index: 2
                                iconSource: "qrc:/qt/qml/TalkLess/resources/icons/panel/ic_tab_record.svg"
                            }
                            TabButton {
                                index: 3
                                emoji: "📄"
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
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

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
                                    colorizationColor: "#FFFFFF"
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
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 4

                                Text {
                                    text: "Enter Name Here:"
                                    color: "#808080"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    visible: recordingNameInput.text === ""
                                }

                                TextInput {
                                    id: recordingNameInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        text: "_ _ _ _ _ _ _ _ _ _ _ _ _ _"
                                        color: "#666666"
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }
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
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        DropdownSelector {
                            id: inputDeviceDropdown
                            Layout.fillWidth: true
                            icon: "🔴"
                            placeholder: "Select Mic Device"
                            selectedId: "-1"
                            model: []

                            onAboutToOpen: {
                                const list = soundboardService.getInputDevices()
                                list.unshift({ id: "-1", name: "None", isDefault: false })
                                model = list
                            }

                            onItemSelected: function (id, name) {
                                console.log("Recording input device selected:", name, "(id:", id, ")");
                                soundboardService.setRecordingInputDevice(id);
                            }
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 4 }

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
                            color: micButtonArea.containsMouse
                                   ? (soundboardService.isRecording ? "#7F1D1D" : "#4A4A4A")
                                   : (soundboardService.isRecording ? "#991B1B" : "#3A3A3A")

                            border.color: soundboardService.isRecording ? "#EF4444" : "#4A4A4A"
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
                                visible: soundboardService.isRecording

                                SequentialAnimation on opacity {
                                    running: soundboardService.isRecording
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 450 }
                                    NumberAnimation { to: 0.05; duration: 450 }
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
                                colorizationColor: soundboardService.isRecording ? "#EF4444" : "#FFFFFF"
                            }

                            MouseArea {
                                id: micButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (soundboardService.isRecording) {
                                        soundboardService.stopRecording()
                                    } else {
                                        // If your C++ startRecording needs a name/path, change this call accordingly.
                                        // Example: soundboardService.startRecording(recordingNameInput.text)
                                        soundboardService.startRecording()
                                    }
                                }
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            text: soundboardService.isRecording ? "Stop Recording" : "Start Recording"
                            color: "#888888"
                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 8 }

                    // ============================================================
                    // Trim Audio Section
                    // ============================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

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
                                    colorizationColor: "#FFFFFF"
                                }
                            }

                            Text {
                                text: "Trim Audio"
                                color: "#FFFFFF"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        WaveformDisplay {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            currentTime: soundboardService.recordingDuration
                            totalDuration: Math.max(soundboardService.recordingDuration, 10)
                        }
                    }

                    // Spacer
                    Item { Layout.preferredHeight: 6 }

                    // ============================================================
                    // Cancel and Save buttons
                    // ============================================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        // Cancel button
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            color: cancelBtnArea.containsMouse ? "#4A4A4A" : "#3A3A3A"
                            radius: 8

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#FFFFFF"
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
                                    rightSidebar.currentTabIndex = 0;
                                }
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Save button
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 36
                            radius: 8
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: saveBtnArea.containsMouse ? "#4A9AF7" : "#3B82F6" }
                                GradientStop { position: 1.0; color: saveBtnArea.containsMouse ? "#E040FB" : "#D214FD" }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: "#FFFFFF"
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
                                    const boardId = clipsModel.boardId;

                                    if (boardId >= 0 && soundboardService.lastRecordingPath !== "") {
                                        const title = recordingNameInput.text.trim() || "New Recording";
                                        const success = soundboardService.addClipWithTitle(
                                            boardId,
                                            "file:///" + soundboardService.lastRecordingPath,
                                            title
                                        );

                                        if (success) {
                                            clipsModel.reload();
                                            recordingNameInput.text = "";
                                            rightSidebar.currentTabIndex = 0;
                                        }
                                    } else {
                                        console.log("Cannot save: Board ID", boardId, "Recording Path", soundboardService.lastRecordingPath);
                                    }
                                }
                            }
                        }
                    }

                    // Fill remaining space
                    Item { Layout.fillHeight: true }
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

                        // Update when selected clip changes
                        Connections {
                            target: root
                            function onSelectedClipIdChanged() {
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
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            visible: root.selectedClipId === -1
                            spacing: 8

                            Item {
                                Layout.fillHeight: true
                            }

                            Text {
                                text: "No Clip Selected"
                                color: "#888888"
                                font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "Select a clip to edit its\nsettings and properties"
                                color: "#666666"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Item {
                                Layout.fillHeight: true
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
                                        width: 100
                                        height: 100
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
                                spacing: 8

                                TextInput {
                                    id: clipTitleInput
                                    Layout.preferredWidth: implicitWidth + 20
                                    Layout.maximumWidth: 180
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Colors.textPrimary // was #FFFFFF
                                    font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    clip: true
                                    selectByMouse: true

                                    onTextChanged: {
                                        if (text !== clipEditorTab.editingClipName) {
                                            clipEditorTab.hasUnsavedChanges = true;
                                        }
                                    }

                                    // Auto-save on Enter key
                                    Keys.onReturnPressed: {
                                        if (root.selectedClipId !== -1 && text.length > 0) {
                                            clipsModel.updateClip(root.selectedClipId, text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                            clipEditorTab.editingClipName = text;
                                            clipsModel.reload();
                                        }
                                        focus = false; // Remove focus after saving
                                    }

                                    // Auto-save on focus loss
                                    onActiveFocusChanged: {
                                        if (!activeFocus && root.selectedClipId !== -1 && text.length > 0 && text !== clipEditorTab.editingClipName) {
                                            clipsModel.updateClip(root.selectedClipId, text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                            clipEditorTab.editingClipName = text;
                                            clipsModel.reload();
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Enter title..."
                                        color: Colors.textSecondary // was #666666
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
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
                                        onClicked: clipTitleInput.forceActiveFocus()
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

        //                     // ===== PLAYBACK CONTROLS =====
        //                     RowLayout {
        //                         Layout.alignment: Qt.AlignHCenter
        //                         spacing: 6

        //                         // Previous button
        //                         Rectangle {
        //                             width: 28
        //                             height: 28
        //                             radius: 6
        //                             color: prevBtnArea.containsMouse ? "#3A3A3A" : "transparent"

        //                             Text {
        //                                 anchors.centerIn: parent
        //                                 text: "◀"
        //                                 color: "#FFFFFF"
        //                                 font.pixelSize: 10
        //                             }

        //                             MouseArea {
        //                                 id: prevBtnArea
        //                                 anchors.fill: parent
        //                                 hoverEnabled: true
        //                                 cursorShape: Qt.PointingHandCursor
        //                                 onClicked: console.log("Previous clicked")
        //                             }
        //                         }

        //                         // Skip backward button
        //                         Rectangle {
        //                             width: 28
        //                             height: 28
        //                             radius: 6
        //                             color: skipBackArea.containsMouse ? "#3A3A3A" : "transparent"

        //                             Text {
        //                                 anchors.centerIn: parent
        //                                 text: "⏮"
        //                                 color: "#FFFFFF"
        //                                 font.pixelSize: 12
        //                             }

        //                             MouseArea {
        //                                 id: skipBackArea
        //                                 anchors.fill: parent
        //                                 hoverEnabled: true
        //                                 cursorShape: Qt.PointingHandCursor
        //                                 onClicked: console.log("Skip backward clicked")
        //                             }
        //                         }

        //                         // Main Play Button (larger, gradient)
        //                         Rectangle {
        //                             width: 36
        //                             height: 36
        //                             radius: 18

        //                             gradient: Gradient {
        //                                 orientation: Gradient.Horizontal
        //                                 GradientStop {
        //                                     position: 0.0
        //                                     color: "#3B82F6"
        //                                 }
        //                                 GradientStop {
        //                                     position: 1.0
        //                                     color: "#8B5CF6"
        //                                 }
        //                             }

        //                             Text {
        //                                 anchors.centerIn: parent
        //                                 text: root.displayedClipData && root.displayedClipData.isPlaying ? "⏸" : "▶"
        //                                 color: "#FFFFFF"
        //                                 font.pixelSize: 14
        //                             }

        //                             MouseArea {
        //                                 anchors.fill: parent
        //                                 cursorShape: Qt.PointingHandCursor
        //                                 onClicked: {
        //                                     if (root.selectedClipId !== -1) {
        //                                         if (soundboardService.isClipPlaying(root.selectedClipId)) {
        //                                             soundboardService.stopClip(root.selectedClipId);
        //                                         } else {
        //                                             soundboardService.playClip(root.selectedClipId);
        //                                         }
        //                                     }
        //                                 }
        //                             }
        //                         }

        //                         // Skip forward button
        //                         Rectangle {
        //                             width: 28
        //                             height: 28
        //                             radius: 6
        //                             color: skipFwdArea.containsMouse ? "#3A3A3A" : "transparent"

        //                             Text {
        //                                 anchors.centerIn: parent
        //                                 text: "⏭"
        //                                 color: "#FFFFFF"
        //                                 font.pixelSize: 12
        //                             }

        //                             MouseArea {
        //                                 id: skipFwdArea
        //                                 anchors.fill: parent
        //                                 hoverEnabled: true
        //                                 cursorShape: Qt.PointingHandCursor
        //                                 onClicked: console.log("Skip forward clicked")
        //                             }
        //                         }

        //                         // Loop button - toggles repeat for selected clip
        //                         Rectangle {
        //                             width: 28
        //                             height: 28
        //                             radius: 6
        //                             color: {
        //                                 // Active when repeat is on
        //                                 if (clipEditorTab.clipIsRepeat) {
        //                                     return loopBtnArea.containsMouse ? "#7C3AED" : "#8B5CF6";
        //                                 }
        //                                 return loopBtnArea.containsMouse ? "#3A3A3A" : "transparent";
        //                             }

        //                             Text {
        //                                 anchors.centerIn: parent
        //                                 text: "🔁"
        //                                 color: clipEditorTab.clipIsRepeat ? "#FFFFFF" : "#888888"
        //                                 font.pixelSize: 12
        //                             }

        //                             MouseArea {
        //                                 id: loopBtnArea
        //                                 anchors.fill: parent
        //                                 hoverEnabled: true
        //                                 cursorShape: Qt.PointingHandCursor
        //                                 onClicked: {
        //                                     // Toggle repeat for selected clip
        //                                     if (root.selectedClipId !== -1) {
        //                                         clipEditorTab.clipIsRepeat = !clipEditorTab.clipIsRepeat;
        //                                         clipsModel.setClipRepeat(root.selectedClipId, clipEditorTab.clipIsRepeat);
        //                                     }
        //                                 }
        //                             }
        //                         }
        //                     }

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
                                            clipsModel.setClipVolume(root.selectedClipId, Math.round(value));
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
                                                    color: "#3B82F6"
                                                }
                                                GradientStop {
                                                    position: 1.0
                                                    color: "#8B5CF6"
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
                                        color: "#FFFFFF"
                                    }
                                }
                            }

                            // ===== SPEED SLIDER =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Speed"
                                        color: Colors.textPrimary // was #FFFFFF
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: clipEditorTab.clipSpeed.toFixed(1) + "x"
                                        color: Colors.textSecondary // was #AAAAAA
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 11
                                    }
                                }

                                Slider {
                                    id: speedSlider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    from: 0.5
                                    to: 2.0
                                    value: clipEditorTab.clipSpeed
                                    stepSize: 0.1

                                    onValueChanged: {
                                        clipEditorTab.clipSpeed = value;
                                        // Auto-save speed changes
                                        if (root.selectedClipId !== -1) {
                                            clipsModel.updateClipAudioSettings(root.selectedClipId, Math.round(clipEditorTab.clipVolume), value);
                                        }
                                    }

                                    background: Rectangle {
                                        x: speedSlider.leftPadding
                                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                                        width: speedSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: Colors.surfaceLight // was #3A3A3A

                                        Rectangle {
                                            width: speedSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop {
                                                    position: 0.0
                                                    color: "#3B82F6"
                                                }
                                                GradientStop {
                                                    position: 1.0
                                                    color: "#8B5CF6"
                                                }
                                            }
                                        }
                                    }

                                    handle: Rectangle {
                                        x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: "#FFFFFF"
                                    }
                                }
                            }

                            // ===== TRIM AUDIO SECTION =====
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                RowLayout {
                                    spacing: 6

                                    Text {
                                        text: "✂"
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: "Trim Audio"
                                        color: Colors.textPrimary // was #FFFFFF
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }

                                // Waveform display
                                TrimWaveform {
                                    id: waveform
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                    currentTime: 0
                                    totalDuration: clipEditorTab.durationSec
                                    trimStart: clipEditorTab.durationSec > 0 ? (clipEditorTab.trimStartMs / 1000.0) / clipEditorTab.durationSec : 0.0
                                    trimEnd: (clipEditorTab.durationSec > 0 && clipEditorTab.trimEndMs > 0) ? (clipEditorTab.trimEndMs / 1000.0) / clipEditorTab.durationSec : 1.0

                                    onTrimStartMoved: function (pos) {
                                        if (root.selectedClipId !== -1 && clipEditorTab.durationSec > 0) {
                                            var newStartMs = pos * clipEditorTab.durationSec * 1000.0;
                                            clipEditorTab.trimStartMs = newStartMs;
                                            soundboardService.setClipTrim(clipsModel.boardId, root.selectedClipId, newStartMs, clipEditorTab.trimEndMs);
                                        }
                                    }
                                    onTrimEndMoved: function (pos) {
                                        if (root.selectedClipId !== -1 && clipEditorTab.durationSec > 0) {
                                            var newEndMs = pos * clipEditorTab.durationSec * 1000.0;
                                            clipEditorTab.trimEndMs = newEndMs;
                                            soundboardService.setClipTrim(clipsModel.boardId, root.selectedClipId, clipEditorTab.trimStartMs, newEndMs);
                                        }
                                    }
                                    onSeekRequested: function (pos) {
                                        if (root.selectedClipId !== -1 && clipEditorTab.durationSec > 0) {
                                            var seekMs = pos * clipEditorTab.durationSec * 1000.0;

                                            // If playing, seek audio
                                            if (soundboardService.isClipPlaying(root.selectedClipId)) {
                                                soundboardService.seekClip(clipsModel.boardId, root.selectedClipId, seekMs);
                                            } else {
                                                // If not playing, just update visual cursor
                                                waveform.currentTime = seekMs / 1000.0;
                                            }
                                        }
                                    }

                                    Timer {
                                        id: playbackTimer
                                        interval: 50
                                        running: root.selectedClipId !== -1 && soundboardService.isClipPlaying(root.selectedClipId)
                                        repeat: true
                                        onTriggered: {
                                            waveform.currentTime = soundboardService.getClipPlaybackPositionMs(root.selectedClipId) / 1000.0;
                                        }
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
                                    property bool isLightTheme: false

                                    // helper: pick correct svg for mode + theme
                                    function modeIconSource(mode) {
                                        const base = "qrc:/qt/qml/TalkLess/resources/icons/reproduction/"
                                        const suffix = isLightTheme ? "_light.svg" : "_dark.svg"
                                        switch (mode) {
                                        case 0: return base + "overlay" + suffix
                                        case 1: return base + "play-pause" + suffix
                                        case 2: return base + "play-stop" + suffix
                                        case 3: return base + "restart" + suffix
                                        case 4: return base + "loop" + suffix
                                        default: return ""
                                        }
                                    }

                                    // reusable button
                                    component ModeButton: Rectangle {
                                        required property int mode
                                        property bool selected: clipEditorTab.reproductionMode === mode

                                        width: 36
                                        height: 36
                                        radius: 8
                                        color: ma.containsMouse ? "#2A2A2A" : "#1A1A1A"
                                        border.width: 1

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            radius: 14
                                            visible: parent.selected
                                            color: "#00D9FF"
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
                                                    clipEditorTab.reproductionMode = parent.mode
                                                    soundboardService.setClipReproductionMode(clipsModel.boardId, root.selectedClipId, parent.mode)
                                                    console.log("Reproduction mode changed to:", parent.mode, "- SAVED!")
                                                }
                                            }
                                        }
                                    }

                                    ModeButton { mode: 0 }
                                    ModeButton { mode: 1 }
                                    ModeButton { mode: 2 }
                                    ModeButton { mode: 3 }
                                    ModeButton { mode: 4 }
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
                                    color: "#888888"
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
                                    color: "#FFFFFF"
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
                                        // Disabled when mode is Play/Stop (mode 2) or Play/Pause (mode 1)
                                        property bool isReadOnly: clipEditorTab.reproductionMode === 1 || clipEditorTab.reproductionMode === 2
                                        opacity: isReadOnly ? 0.5 : 1.0

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            // Force checked when mode is Play/Stop (mode 2), force unchecked when Play/Pause (mode 1)
                                            property bool effectiveValue: clipEditorTab.reproductionMode === 2 ? true : (clipEditorTab.reproductionMode === 1 ? false : clipEditorTab.stopOtherSounds)
                                            color: effectiveValue ? "#8B5CF6" : "#3A3A3A"
                                            border.color: effectiveValue ? "#8B5CF6" : "#4A4A4A"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.effectiveValue ? "✓" : ""
                                                color: "#FFFFFF"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: parent.parent.isReadOnly ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                enabled: !parent.parent.isReadOnly
                                                onClicked: {
                                                    if (root.selectedClipId !== -1) {
                                                        clipEditorTab.stopOtherSounds = !clipEditorTab.stopOtherSounds;
                                                        soundboardService.setClipStopOtherSounds(clipsModel.boardId, root.selectedClipId, clipEditorTab.stopOtherSounds);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: clipEditorTab.reproductionMode === 2 ? "Stop other sounds on play (auto)" : clipEditorTab.reproductionMode === 1 ? "Stop other sounds on play (disabled)" : "Stop other sounds on play"
                                            color: parent.isReadOnly ? "#888888" : "#CCCCCC"
                                            font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Mute other sounds
                                    RowLayout {
                                        spacing: 8

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 4
                                            color: clipEditorTab.muteOtherSounds ? "#8B5CF6" : "#3A3A3A"
                                            border.color: clipEditorTab.muteOtherSounds ? "#8B5CF6" : "#4A4A4A"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: clipEditorTab.muteOtherSounds ? "✓" : ""
                                                color: "#FFFFFF"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.selectedClipId !== -1) {
                                                        clipEditorTab.muteOtherSounds = !clipEditorTab.muteOtherSounds;
                                                        soundboardService.setClipMuteOtherSounds(clipsModel.boardId, root.selectedClipId, clipEditorTab.muteOtherSounds);
                                                        // If muteOtherSounds is enabled, also enable muteMicDuringPlayback
                                                        if (clipEditorTab.muteOtherSounds) {
                                                            clipEditorTab.muteMicDuringPlayback = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Mute other sounds"
                                            color: "#CCCCCC"
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
                                            color: effectiveValue ? "#8B5CF6" : "#3A3A3A"
                                            border.color: effectiveValue ? "#8B5CF6" : "#4A4A4A"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.effectiveValue ? "✓" : ""
                                                color: "#FFFFFF"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: clipEditorTab.muteOtherSounds ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                enabled: !clipEditorTab.muteOtherSounds
                                                onClicked: {
                                                    if (root.selectedClipId !== -1) {
                                                        clipEditorTab.muteMicDuringPlayback = !clipEditorTab.muteMicDuringPlayback;
                                                        soundboardService.setClipMuteMicDuringPlayback(clipsModel.boardId, root.selectedClipId, clipEditorTab.muteMicDuringPlayback);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: clipEditorTab.muteOtherSounds ? "Mute mic during playback (auto)" : "Mute mic during playback"
                                            color: clipEditorTab.muteOtherSounds ? "#888888" : "#CCCCCC"
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
                                            color: clipEditorTab.persistentSettings ? "#8B5CF6" : "#3A3A3A"
                                            border.color: clipEditorTab.persistentSettings ? "#8B5CF6" : "#4A4A4A"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: clipEditorTab.persistentSettings ? "✓" : ""
                                                color: "#FFFFFF"
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
                                            color: "#CCCCCC"
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
                                            color: clipEditorTab.clipIsRepeat ? "#8B5CF6" : "#3A3A3A"
                                            border.color: clipEditorTab.clipIsRepeat ? "#8B5CF6" : "#4A4A4A"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: clipEditorTab.clipIsRepeat ? "✓" : ""
                                                color: "#FFFFFF"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    // Toggle repeat - real-time update, saved immediately
                                                    if (root.selectedClipId !== -1) {
                                                        clipEditorTab.clipIsRepeat = !clipEditorTab.clipIsRepeat;
                                                        clipsModel.setClipRepeat(root.selectedClipId, clipEditorTab.clipIsRepeat);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Loop playback"
                                            color: "#CCCCCC"
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
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: "#1A1A1A"
                                    radius: 18
                                    border.color: addTagInput.activeFocus ? "#8B5CF6" : "#3A3A3A"
                                    border.width: 1

                                    TextInput {
                                        id: addTagInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "#FFFFFF"
                                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                        font.pixelSize: 12
                                        clip: true
                                        selectByMouse: true

                                        Keys.onReturnPressed: {
                                            if (text.trim().length > 0) {
                                                clipEditorTab.editingClipTags.push(text.trim());
                                                // Auto-save tags
                                                if (root.selectedClipId !== -1) {
                                                    clipsModel.updateClip(root.selectedClipId, clipTitleInput.text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                                    clipsModel.reload();
                                                }
                                                text = "";
                                            }
                                        }

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            verticalAlignment: Text.AlignVCenter
                                            text: "Add tag and press enter"
                                            color: "#666666"
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
                                            color: "#3A3A3A"

                                            Text {
                                                id: tagText
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: "#CCCCCC"
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
                                                        clipsModel.updateClip(root.selectedClipId, clipTitleInput.text, clipEditorTab.editingClipHotkey, clipEditorTab.editingClipTags);
                                                        clipsModel.reload();
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
                                clipsModel.updateClip(root.hotkeyEditingClipId, data.title, hotkeyText, data.tags);
                                clipsModel.reload();
                            }
                            root.hotkeyEditingClipId = -1;
                        } else {
                            // Standard editor behavior - AUTO-SAVE hotkey
                            clipEditorTab.editingClipHotkey = hotkeyText;
                            if (root.selectedClipId !== -1) {
                                clipsModel.updateClip(root.selectedClipId, clipTitleInput.text, hotkeyText, clipEditorTab.editingClipTags);
                                clipsModel.reload();
                            }
                        }
                    }

                    onCancelled: {
                        console.log("Hotkey capture cancelled");
                        root.hotkeyEditingClipId = -1;
                    }
                }

                // Add Tab Content (Tab 1)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    visible: rightSidebar.currentTabIndex === 1

                    // Name Audio File Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Text {
                            text: "Name Audio File"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Text Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 4

                                Text {
                                    text: "Enter Name Here:"
                                    color: "#808080"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    visible: uploadAudioNameInput.text === ""
                                }

                                TextInput {
                                    id: uploadAudioNameInput
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        text: "_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _"
                                        color: "#666666"
                                        font.family: parent.font.family
                                        font.pixelSize: parent.font.pixelSize
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }
                            }
                        }
                    }

                    // Assign to Slot Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        spacing: 8

                        Text {
                            text: "Assign to Slot"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Dropdown selector
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            color: "#1A1A1A"
                            radius: 8
                            border.color: "#3A3A3A"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15

                                Text {
                                    text: "Select Available Slot"
                                    color: "#AAAAAA"
                                    font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                // Dropdown arrow
                                Text {
                                    text: "▼"
                                    color: "#808080"
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Slot dropdown clicked")
                            }
                        }
                    }

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
                            // Auto-fill the name input if empty
                            if (uploadAudioNameInput.text === "") {
                                // Remove extension from filename
                                var nameWithoutExt = fileName.replace(/\.[^/.]+$/, "");
                                uploadAudioNameInput.text = nameWithoutExt;
                            }

                            // Get duration for trim preview
                            fileDuration = soundboardService.getFileDuration(filePath);
                            console.log("File duration detected:", fileDuration);
                        }

                        onFileCleared: {
                            console.log("File cleared");
                            fileDuration = 0;
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

                        Text {
                            text: "Trim Audio"
                            color: "#FFFFFF"
                            font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Waveform Display (without playback controls)
                        TrimWaveform {
                            id: uploadWaveform
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            currentTime: 0
                            totalDuration: fileDropArea.fileDuration
                            trimStart: 0.0
                            trimEnd: 1.0

                            property real trimStartMs: 0
                            property real trimEndMs: fileDropArea.fileDuration * 1000.0

                            onTrimStartMoved: function (pos) {
                                trimStartMs = pos * totalDuration * 1000.0;
                            }
                            onTrimEndMoved: function (pos) {
                                trimEndMs = pos * totalDuration * 1000.0;
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
                                color: "#FFFFFF"
                                font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: uploadCancelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Upload Cancel clicked")
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
                                    color: uploadSaveBtnArea.containsMouse ? "#4A9AF7" : "#3B82F6"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: uploadSaveBtnArea.containsMouse ? "#E040FB" : "#D214FD"
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: "#FFFFFF"
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
                                    const boardId = clipsModel.boardId;
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
                                        clipsModel.reload();

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

                // Teleprompter Tab Content (Tab 3)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 3

                    Text {
                        text: "Teleprompter"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Teleprompter content will appear here"
                        color: "#666666"
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Speaker Tab Content (Tab 4)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: rightSidebar.currentTabIndex === 4

                    Text {
                        text: "Audio Output"
                        color: "#FFFFFF"
                        font.family: poppinsFont.status === FontLoader.Ready ? poppinsFont.name : "Arial"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Speaker and output settings here"
                        color: "#666666"
                        font.family: interFont.status === FontLoader.Ready ? interFont.name : "Arial"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillHeight: true
                    }
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
