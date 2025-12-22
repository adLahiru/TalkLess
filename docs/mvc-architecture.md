# TalkLess MVC Architecture

## Overview
TalkLess follows the **Model-View-Controller (MVC)** architectural pattern with Qt/QML integration.

## Architecture Layers

### 1. Models (`src/models/`)
**Purpose**: Data structures and business logic

#### AudioClip (`audioclip.h/cpp`)
- **Description**: Represents a single audio clip with all its properties
- **Properties**:
  - `id`: Unique identifier
  - `title`: Display name
  - `hotkey`: Keyboard shortcut
  - `filePath`: Audio file location
  - `imagePath`: Thumbnail/artwork path
  - `tagLabel`, `tagColor`: Visual categorization
  - `duration`, `trimStart`, `trimEnd`: Playback parameters
  - `volume`: Individual clip volume
  - `isPlaying`: Current playback state
- **Signals**: Property change notifications
- **Used by**: AudioManager, SoundboardView

### 2. Controllers (`src/controllers/`)
**Purpose**: Business logic and state management

#### AudioManager (`audiomanager.h/cpp`)
- **Description**: Core audio playback engine using Qt Multimedia
- **Responsibilities**:
  - Load and manage audio files
  - Control playback (play/pause/stop/seek)
  - Track current position and duration
  - Handle multiple audio clips
  - Volume control
- **Key Methods**:
  - `addClip()`: Add new audio clip
  - `removeClip()`: Remove audio clip
  - `playClip()`: Start playback
  - `pauseClip()`: Pause playback
  - `stopClip()`: Stop playback
  - `stopAll()`: Stop all playback
  - `seekTo()`: Seek to position
- **Properties**:
  - `audioClips`: List of all clips
  - `currentClip`: Currently playing clip
  - `currentPosition`: Playback position
  - `currentDuration`: Total duration
  - `isPlaying`: Playback state
  - `volume`: Master volume
- **Uses**: QMediaPlayer, QAudioOutput, AudioClip
- **Used by**: Views, QML components

#### HotkeyManager (`hotkeymanager.h/cpp`)
- **Description**: Global keyboard shortcut management
- **Responsibilities**:
  - Register/unregister hotkeys
  - Detect hotkey conflicts
  - Trigger audio clips via keyboard
- **Key Methods**:
  - `registerHotkey()`: Assign hotkey to clip
  - `unregisterHotkey()`: Remove hotkey
  - `handleKeyPress()`: Process keyboard input
  - `isHotkeyAvailable()`: Check availability
- **Signals**:
  - `hotkeyTriggered(clipId)`: Emitted when hotkey pressed
- **Used by**: Views, connected to AudioManager

### 3. Views (`src/view/`)
**Purpose**: Bridge between QML UI and C++ backend

#### SoundboardView (`soundboardview.h/cpp`)
- **Description**: View layer for soundboard page
- **Responsibilities**:
  - Expose AudioManager to QML
  - Expose HotkeyManager to QML
  - Provide UI-specific convenience methods
  - Handle UI events and route to controllers
- **Properties**:
  - `audioManager`: Reference to AudioManager
  - `hotkeyManager`: Reference to HotkeyManager
- **Methods**:
  - `playAudioInSlot()`: Play clip by index
  - `stopAllAudio()`: Stop all playback
  - `getAudioClipInfo()`: Get clip details
- **Signals**:
  - `audioClipAdded(slotIndex)`
  - `audioClipRemoved(slotIndex)`
  - `playbackStateChanged(slotIndex, isPlaying)`
- **Connected to**: AudioManager signals
- **Used by**: SoundboardPage.qml

#### AudioPlayerView (`audioplayerview.h/cpp`)
- **Description**: View layer for audio player component
- **Responsibilities**:
  - Expose player controls to QML
  - Format time displays
  - Handle play/pause/stop actions
  - Manage mute state
- **Properties**:
  - `currentTitle`: Current clip title
  - `currentPosition`: Playback position
  - `currentDuration`: Total duration
  - `isPlaying`: Playing state
  - `volume`: Volume level
- **Methods**:
  - `play()`: Start playback
  - `pause()`: Pause playback
  - `stop()`: Stop playback
  - `seekTo()`: Seek to position
  - `togglePlayPause()`: Toggle play/pause
  - `toggleMute()`: Toggle mute
  - `formatTime()`: Format seconds to MM:SS.ms
- **Connected to**: AudioManager signals
- **Used by**: AudioPlayer.qml

## QML Components → C++ Linkage

### AudioCard.qml → AudioManager
```qml
AudioCard {
    audioClipId: audioManager.audioClips[index].id
    title: audioManager.audioClips[index].title
    isPlaying: audioManager.audioClips[index].isPlaying
    
    onPlayClicked: {
        if (isPlaying) {
            audioManager.pauseClip(audioClipId)
        } else {
            audioManager.playClip(audioClipId)
        }
    }
    onDeleteClicked: audioManager.removeClip(audioClipId)
}
```

### AudioPlayer.qml → AudioPlayerView
```qml
AudioPlayer {
    title: audioPlayerView.currentTitle
    currentTime: audioPlayerView.currentPosition
    totalTime: audioPlayerView.currentDuration
    isPlaying: audioPlayerView.isPlaying
    
    onPlayPauseClicked: audioPlayerView.togglePlayPause()
    onSeekTo: audioPlayerView.seekTo(position)
}
```

### AddAudioPanel.qml → AudioManager
```qml
AddAudioPanel {
    onAudioAdded: function(name, filePath) {
        audioManager.addClip(name, filePath, "")
    }
}
```

## Data Flow Diagrams

### Adding Audio Clip
```
User → AddAudioPanel.qml → audioAdded signal
  ↓
audioManager.addClip(name, filePath)
  ↓
AudioClip model created
  ↓
audioClipsChanged signal
  ↓
UI grid updates
```

### Playing Audio
```
User clicks play on AudioCard
  ↓
audioManager.playClip(clipId)
  ↓
QMediaPlayer.play()
  ↓
isPlayingChanged signal
  ↓
AudioClip.isPlaying = true
  ↓
UI updates (button changes)
  ↓
currentPositionChanged signal
  ↓
AudioPlayer updates progress bar
```

### Hotkey Trigger
```
User presses Alt+F1
  ↓
hotkeyManager.handleKeyPress()
  ↓
hotkeyTriggered(clipId) signal
  ↓
[Connected to audioManager.playClip()]
  ↓
Audio plays
```

## Component Relationship Diagram

```
┌─────────────────────────────────────────────────────┐
│                   QML Layer (UI)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ AudioCard.qml│  │AudioPlayer   │  │AddAudio   │ │
│  │              │  │.qml          │  │Panel.qml  │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
└─────────┼──────────────────┼─────────────────┼──────┘
          │                  │                 │
          └──────────────────┼─────────────────┘
                             │
┌────────────────────────────┼──────────────────────────┐
│                      View Layer (C++)                 │
│  ┌─────────────────────┐  │  ┌───────────────────┐   │
│  │ SoundboardView      │◄─┴─►│ AudioPlayerView   │   │
│  │ (soundboardview.*)  │     │ (audioplayerview.*)│  │
│  └──────────┬──────────┘     └─────────┬─────────┘   │
└─────────────┼────────────────────────────┼────────────┘
              │                            │
┌─────────────┼────────────────────────────┼────────────┐
│                 Controller Layer (C++)                │
│  ┌────────▼─────────┐  ┌──────────────┐  │           │
│  │ AudioManager     │  │ HotkeyManager│  │           │
│  │ (audiomanager.*) │  │ (hotkey...)  │  │           │
│  └────────┬─────────┘  └──────────────┘  │           │
└───────────┼────────────────────────────────────────────┘
            │
┌───────────┼────────────────────────────────────────────┐
│                  Model Layer (C++)                     │
│  ┌─────▼─────────┐                                     │
│  │  AudioClip    │                                     │
│  │ (audioclip.*) │                                     │
│  └───────────────┘                                     │
└────────────────────────────────────────────────────────┘
```

## File Organization

```
src/
├── models/                    # Data models
│   ├── audioclip.h           # Audio clip data model
│   ├── audioclip.cpp
│   └── audioEngine.h         # Low-level audio engine
│
├── controllers/               # Business logic
│   ├── audiomanager.h        # Audio playback controller
│   ├── audiomanager.cpp
│   ├── hotkeymanager.h       # Hotkey controller
│   ├── hotkeymanager.cpp
│   └── maincontroller.h      # Main app controller
│
├── view/                      # View layer (QML bridges)
│   ├── soundboardview.h      # Soundboard page view
│   ├── soundboardview.cpp
│   ├── audioplayerview.h     # Audio player view
│   └── audioplayerview.cpp
│
└── main.cpp                   # Application entry & wiring
```

## Initialization Flow (main.cpp)

```cpp
// 1. Create Controllers
AudioManager audioManager;
HotkeyManager hotkeyManager;

// 2. Create Views (linked to controllers)
SoundboardView soundboardView(&audioManager, &hotkeyManager);
AudioPlayerView audioPlayerView(&audioManager);

// 3. Register to QML Context
engine.rootContext()->setContextProperty("audioManager", &audioManager);
engine.rootContext()->setContextProperty("soundboardView", &soundboardView);
engine.rootContext()->setContextProperty("audioPlayerView", &audioPlayerView);

// 4. Connect Controllers
connect(&hotkeyManager, &HotkeyManager::hotkeyTriggered,
        &audioManager, &AudioManager::playClip);

// 5. Load QML
engine.loadFromModule("TalkLess", "Main");
```

## Key Design Principles

1. **Separation of Concerns**: UI (QML) ↔ View (C++) ↔ Controller (C++) ↔ Model (C++)
2. **Qt Signals/Slots**: Loose coupling between layers
3. **Context Properties**: Global QML access to C++ objects
4. **Property Bindings**: Automatic UI updates via Qt's property system
5. **View Layer Pattern**: C++ views provide QML-friendly facades to controllers
6. **Organized Structure**: models/, controllers/, view/ folders

## Benefits of This Architecture

- ✅ **Testability**: Each layer can be tested independently
- ✅ **Maintainability**: Clear responsibilities per class
- ✅ **Reusability**: Models and controllers can be reused
- ✅ **Scalability**: Easy to add new features
- ✅ **Type Safety**: C++ backend with QML UI
- ✅ **Performance**: Heavy logic in C++, lightweight UI in QML
