import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "qml/components"
import "qml/pages"
import "qml/styles"

ApplicationWindow {
    id: mainWindow        
    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    // Start in normal windowed mode, not fullscreen
    visibility: Window.Windowed
    title: qsTr("TalkLess")
    color: Colors.background

    // Link Backend Theme & Settings to UI Singleton
    Connections {
        target: soundboardService
        function onSettingsChanged() {
            Colors.setTheme(soundboardService.theme)
            Colors.setAccent(soundboardService.accentColor)
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
    
    Component.onCompleted: {
        // Store initial device lists for hotplug detection
        lastKnownInputDevices = soundboardService.getInputDevices();
        lastKnownOutputDevices = soundboardService.getOutputDevices();
        // Initialize Theme from Backend
        Colors.setTheme(soundboardService.theme)
        Colors.setAccent(soundboardService.accentColor)
        
        // Initialize first soundboard on startup
        var firstBoardId = soundboardService.activeBoardId();
        if (firstBoardId >= 0) {
            clipsModel.boardId = firstBoardId;
            clipsModel.reload();
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

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
                            isDetached: mainWindow.isSoundboardDetached
                            visible: !mainWindow.isSoundboardDetached

                            onRequestDetach: {
                                mainWindow.isSoundboardDetached = true;
                            }
                            onRequestDock: {
                                mainWindow.isSoundboardDetached = false;
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: mainWindow.isSoundboardDetached
                            color: Colors.background
                            radius: 10

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 20

                                Text {
                                    text: "Soundboard Detached"
                                    color: Colors.textSecondary
                                    font.pixelSize: 24
                                    Layout.alignment: Qt.AlignHCenter
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
                                            mainWindow.isSoundboardDetached = false;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Audio Playback Engine (placeholder)
                    Rectangle {
                        color: Colors.background
                        radius: 10
                        Text {
                            anchors.centerIn: parent
                            text: "Audio Playback Engine"
                            color: Colors.textSecondary
                            font.pixelSize: 32
                        }
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

    // ---- Detached Soundboard Window ----
    Window {
        id: detachedSoundboardWindow
        title: "Soundboard - Detached"
        width: 1000
        height: 700
        visible: mainWindow.isSoundboardDetached
        color: Colors.background

        onClosing: {
            mainWindow.isSoundboardDetached = false;
        }

        SoundboardView {
            anchors.fill: parent
            isDetached: true

            onRequestDock: {
                mainWindow.isSoundboardDetached = false;
            }
        }
    }
}
