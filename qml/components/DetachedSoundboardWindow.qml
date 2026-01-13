import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: win
    width: 1100
    height: 720
    visible: true
    title: "Soundboard"

    // IMPORTANT:
    // If you set transientParent to the main window, many OSes will minimize the child when parent minimizes.
    // So keep this NULL / unset.
    transientParent: null

    // IMPORTANT:
    // Use a normal Window, NOT Qt.Tool (tools often behave like owned windows).
    flags: Qt.Window
           | Qt.WindowTitleHint
           | Qt.WindowSystemMenuHint
           | Qt.WindowMinimizeButtonHint
           | Qt.WindowCloseButtonHint

    // identify which board this window is showing
    property int boardId: -1
    property string boardName: "Soundboard"

    // You must NOT use the *global* clipsModel here if you want multiple detached windows,
    // because they'd all fight over boardId.
    // Instead create a per-window model (best) or pass one in.
    //
    // Option A (recommended): ClipsModel is a QML-registered type.
    // ClipsModel { id: clipsModel; boardId: win.boardId }
    //
    // Option B: if clipsModel is only a context property from C++, then you need a C++ factory
    // to create one model per window and pass it in.

    property var clipsModel   // pass in from creator (C++ or QML)
    property var soundboardService
    property var soundboardsModel

    // Dock request back to main app (optional)
    signal requestDock(int boardId)

    // Your existing view, but now it’s hosted inside this Window:
    SoundboardView {
        anchors.fill: parent

        // Make SoundboardView configurable:
        // - use injected model/service instead of global context ones
        clipsModel: win.clipsModel
        soundboardService: win.soundboardService
        soundboardsModel: win.soundboardsModel

        // if you want the detach button to become "dock" in detached mode:
        isDetached: true
        onRequestDock: win.requestDock(win.boardId)

        // prevent re-detach loops:
        onRequestDetach: {} // no-op in detached window
    }

    onClosing: {
        // Optional: when user closes detached window, you can notify main to "dock"
        // or just destroy it
        // requestDock(boardId)
    }
}
