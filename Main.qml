import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import TalkLess.Models 1.0
import "qml/components"
import "qml/pages"
import "qml/styles"

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 800
    minimumWidth: 1200
    minimumHeight: 700
    visible: true
    // Start in normal windowed mode, not fullscreen
    visibility: Window.Windowed
    title: qsTr("TalkLess")
    color: Colors.background

    // Close all detached windows when main window closes
    onClosing: function (close) {
        closeAllDetachedWindows();
    }

    // Link Backend Theme & Settings to UI Singleton
    Connections {
        target: soundboardService
        function onSettingsChanged() {
            Colors.setTheme(soundboardService.theme);
            Colors.setAccent(soundboardService.accentColor);
        }
    }

    // ---- Global Audio Device Hotplug Detection ----
    // This runs globally so device changes are detected even when not in settings view
    property var lastKnownInputDevices: []
    property var lastKnownOutputDevices: []

    Timer {
        id: globalDevicePollTimer
        interval: 2000  // Check every 2 seconds
        running: true   // Always run
        repeat: true
        onTriggered: {
            var currentInputDevices = soundboardService.getInputDevices();
            var currentOutputDevices = soundboardService.getOutputDevices();

            var inputChanged = JSON.stringify(currentInputDevices) !== JSON.stringify(mainWindow.lastKnownInputDevices);
            var outputChanged = JSON.stringify(currentOutputDevices) !== JSON.stringify(mainWindow.lastKnownOutputDevices);

            if (inputChanged || outputChanged) {
                mainWindow.lastKnownInputDevices = currentInputDevices;
                mainWindow.lastKnownOutputDevices = currentOutputDevices;
                // This will rebuild context and refresh device ID structs
                soundboardService.refreshAudioDevices();
            }
        }
    }

    property bool isSoundboardDetached: false

    // ---- Hotkey Capture Popup ----
    HotkeyCapturePopup {
        id: hotkeyCapturePopup

        onHotkeyConfirmed: function (hotkeyText) {
            hotkeyManager.applyCapturedHotkey(hotkeyText);
        }

        onCancelled: {
            hotkeyManager.cancelCapture();
        }
    }

    // Connect to hotkeyManager signals
    Connections {
        target: hotkeyManager

        function onRequestCapture(title) {
            hotkeyCapturePopup.title = title;
            hotkeyCapturePopup.open();
        }

        function onShowMessageSignal(text) {
            toastMessage.text = text;
            toastMessage.show();
        }
    }

    // ---- Authentication State ----
    // Bind to apiClient state
    property bool isLoggedIn: apiClient.isLoggedIn
    property string userDisplayName: apiClient.displayName

    // Check for saved session on startup
    Component.onCompleted: {
        // Store initial device lists for hotplug detection
        lastKnownInputDevices = soundboardService.getInputDevices();
        lastKnownOutputDevices = soundboardService.getOutputDevices();
        // Initialize Theme from Backend
        Colors.setTheme(soundboardService.theme);
        Colors.setAccent(soundboardService.accentColor);

        // Initialize first soundboard on startup
        var firstBoardId = soundboardService.activeBoardId;
        if (firstBoardId >= 0) {
            clipsModel.boardId = firstBoardId;
            clipsModel.reload();
        }

        // Check for saved authentication session
        apiClient.checkSavedSession();
    }

    // Connect to apiClient for logout handling
    Connections {
        target: apiClient

        function onLogoutSuccess() {
            console.log("[Main] User logged out");
        }

        function onSessionRestored() {
            console.log("[Main] Session restored for:", apiClient.displayName);
        }

        function onSessionInvalid() {
            console.log("[Main] No valid session, showing login");
        }
    }

    // ---- Toast Notification ----
    Rectangle {
        id: toastMessage
        property string text: ""

        function show() {
            opacity = 1.0;
            toastTimer.restart();
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: toastText.implicitWidth + 40
        height: 48
        radius: 24
        color: Colors.cardBg
        border.width: 1
        border.color: Colors.border
        opacity: 0
        z: 999

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: toastMessage.text
            color: Colors.textPrimary
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Timer {
            id: toastTimer
            interval: 3000
            onTriggered: toastMessage.opacity = 0
        }
    }

    // ---- Authentication View ----
    AuthView {
        id: authView
        anchors.fill: parent
        z: 900 // Above main content, below splash screen
        visible: !isLoggedIn
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        visible: isLoggedIn // Only show main content when logged in

        // Main content row (sidebar + pages)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Sidebar {
                id: sidebar
                Layout.preferredWidth: isCollapsed ? 80 : 280
                Layout.fillHeight: true

                onSelected: route => {
                    switch (route) {
                    case "soundboard":
                        contentStack.currentIndex = 0;
                        break;
                    case "engine":
                        contentStack.currentIndex = 1;
                        break;
                    case "macros":
                        contentStack.currentIndex = 2;
                        break;
                    case "settings":
                        contentStack.currentIndex = 3;
                        break;
                    case "stats":
                        contentStack.currentIndex = 4;
                        break;
                    }
                }

                // When a soundboard is selected, load its clips
                onSoundboardSelected: boardId => {
                    // Switch to soundboard view
                    contentStack.currentIndex = 0;
                    // Don't activate the board - just view it
                    // Activation should only happen via checkbox
                    clipsModel.boardId = boardId;
                    clipsModel.reload();
                }

                // Call internalSoundboardView's open dialog function
                onAddSoundboardClicked: {
                    contentStack.currentIndex = 0; // Ensure soundboard view is visible
                    internalSoundboardView.showAddSoundboardDialog();
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
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        SoundboardView {
                            id: internalSoundboardView
                            anchors.fill: parent
                            // Always visible - users can detach multiple soundboards
                            visible: true
                            // Mark as detached only if THIS specific board is detached
                            isDetached: clipsModel ? mainWindow.isBoardDetached(clipsModel.boardId) : false

                            onRequestDetach: {
                                // Detach the currently displayed board
                                var currentBoardId = clipsModel ? clipsModel.boardId : -1;
                                if (currentBoardId >= 0) {
                                    mainWindow.detachBoard(currentBoardId);
                                }
                            }
                            onRequestDock: {
                                // Dock the currently displayed board
                                var currentBoardId = clipsModel ? clipsModel.boardId : -1;
                                if (currentBoardId >= 0) {
                                    mainWindow.dockBoard(currentBoardId);
                                }
                            }
                        }

                        // Overlay message when current board is detached
                        Rectangle {
                            anchors.fill: parent
                            visible: clipsModel ? mainWindow.isBoardDetached(clipsModel.boardId) : false
                            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.9)
                            radius: 10

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 20

                                Text {
                                    text: "This soundboard is detached"
                                    color: Colors.textSecondary
                                    font.pixelSize: 24
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: "Select another soundboard from the sidebar,\nor click below to dock this one back."
                                    color: Colors.textSecondary
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Rectangle {
                                    width: 180
                                    height: 44
                                    radius: 10
                                    color: Colors.surface
                                    border.color: Colors.border
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Re-dock Soundboard"
                                        color: Colors.textPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var currentBoardId = clipsModel ? clipsModel.boardId : -1;
                                            if (currentBoardId >= 0) {
                                                mainWindow.dockBoard(currentBoardId);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Audio Playback Engine
                    AudioPlaybackView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // Macros & Automation (placeholder)
                    Rectangle {
                        color: Colors.background
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Macros & Automation"
                            color: Colors.textSecondary
                            font.pixelSize: 32
                        }
                    }

                    // Application Settings
                    ApplicationSettingsView {}

                    // Statistics & Reporting (placeholder)
                    Rectangle {
                        color: Colors.background
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Statistics & Reporting"
                            color: Colors.textSecondary
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
        color: Colors.background
        visible: opacity > 0

        Image {
            anchors.fill: parent
            source: Colors.splashImage
            fillMode: Image.PreserveAspectCrop
        }

        // Fade out animation after delay
        Timer {
            id: splashTimer
            interval: 250  // Show splash for 2.5 seconds
            running: true
            onTriggered: {
                splashFadeOut.start();
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

    // ---- Detached Soundboard Windows ----
    // Track multiple detached soundboard instances by boardId
    property var detachedBoardIds: []  // Array of board IDs that are currently detached
    property var detachedWindows: ({})  // Map of boardId -> Window object

    // Helper function to check if a board is detached
    function isBoardDetached(boardId) {
        return detachedBoardIds.indexOf(boardId) !== -1;
    }

    // Helper function to detach a board - creates a new window
    function detachBoard(boardId) {
        if (isBoardDetached(boardId)) {
            console.log("Board", boardId, "is already detached");
            return;
        }

        // Create the window dynamically
        var component = detachedWindowComponent;
        var windowObj = component.createObject(null, {
            "windowBoardId": boardId,
            "windowBoardName": soundboardService.getBoardName(boardId) || ("Soundboard " + boardId)
        });

        if (windowObj) {
            // Store reference
            var newWindows = Object.assign({}, detachedWindows);
            newWindows[boardId] = windowObj;
            detachedWindows = newWindows;

            // Update the list
            var newList = detachedBoardIds.slice();
            newList.push(boardId);
            detachedBoardIds = newList;

            // Connect to window's dock request
            windowObj.dockRequested.connect(function () {
                mainWindow.dockBoard(boardId);
            });

            // NOTE: We do NOT change the global clipsModel here
            // The detached window uses overrideBoardId to display its specific board

            console.log("Detached board", boardId, "- window created");
        }
    }

    // Helper function to close ALL detached windows (called when main app closes)
    function closeAllDetachedWindows() {
        console.log("Closing all detached windows...");
        var boardIds = detachedBoardIds.slice(); // Make a copy
        for (var i = 0; i < boardIds.length; i++) {
            var boardId = boardIds[i];
            if (detachedWindows[boardId]) {
                detachedWindows[boardId].destroy();
            }
        }
        detachedWindows = {};
        detachedBoardIds = [];
    }

    // Helper function to dock a board (re-attach to main window)
    function dockBoard(boardId) {
        console.log("Docking board", boardId);

        // Remove from list first
        var idx = detachedBoardIds.indexOf(boardId);
        if (idx !== -1) {
            var newList = detachedBoardIds.slice();
            newList.splice(idx, 1);
            detachedBoardIds = newList;
        }

        // Destroy the window if it exists
        if (detachedWindows[boardId]) {
            var windowToDestroy = detachedWindows[boardId];
            var newWindows = Object.assign({}, detachedWindows);
            delete newWindows[boardId];
            detachedWindows = newWindows;

            // Destroy window after a short delay to avoid issues
            Qt.callLater(function () {
                if (windowToDestroy) {
                    windowToDestroy.destroy();
                }
            });
        }

        // Reset the legacy flag if no more detached windows
        if (detachedBoardIds.length === 0) {
            mainWindow.isSoundboardDetached = false;
        }

        console.log("Board", boardId, "docked back");
    }

    // Component for creating detached windows
    Component {
        id: detachedWindowComponent

        Window {
            id: detachedWin

            property int windowBoardId: -1
            property string windowBoardName: "Soundboard"

            // Signal to notify main window to dock
            signal dockRequested

            title: windowBoardName + " - Detached"
            width: 1000
            height: 700
            visible: true
            color: Colors.background

            // CRITICAL: Set transientParent to null so this window is independent
            // from the main window. This prevents it from minimizing when parent minimizes.
            transientParent: null

            // Use standard Window flags with minimize capability
            flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint

            // Create a per-window ClipsListModel so this window shows its specific board
            ClipsListModel {
                id: localClipsModel

                Component.onCompleted: {
                    // Set up the model with the service and board ID
                    localClipsModel.service = soundboardService;
                    localClipsModel.boardId = detachedWin.windowBoardId;
                    localClipsModel.reload();
                    console.log("Created local ClipsListModel for board:", detachedWin.windowBoardId);
                }
            }

            onClosing: function (close) {
                // Emit dock request when closing
                dockRequested();
            }

            SoundboardView {
                anchors.fill: parent
                isDetached: true

                // CRITICAL: Use overrideBoardId so this view shows THIS specific board
                overrideBoardId: detachedWin.windowBoardId

                // Use the local clips model specific to this window
                localClipsModel: localClipsModel

                onRequestDock: {
                    // Emit dock request signal
                    detachedWin.dockRequested();
                }

                // Prevent re-detaching from already detached window
                onRequestDetach: {
                    console.log("Re-detach prevented - already detached");
                }
            }
        }
    }

    // Legacy single-board detach support (for backward compatibility)
    // This connects to the existing isSoundboardDetached property from the inner view
    Connections {
        target: mainWindow
        function onIsSoundboardDetachedChanged() {
            var currentBoardId = clipsModel ? clipsModel.boardId : -1;
            if (currentBoardId < 0)
                return;

            if (mainWindow.isSoundboardDetached) {
                mainWindow.detachBoard(currentBoardId);
            }
            // Note: docking is now handled by the dockBoard function directly
        }
    }
}
