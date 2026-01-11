cmake_minimum_required(VERSION 3.16)

project(TalkLess VERSION 0.1 LANGUAGES CXX)

include(FetchContent)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(QT_DEFAULT_MAJOR_VERSION 6 CACHE STRING "" FORCE) 
set(FFMPEG_ROOT "${CMAKE_SOURCE_DIR}/lib/ffmpeg")

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Multimedia QuickControls2 Svg )

# Fix for QHotkey's outdated cmake_minimum_required with newer CMake versions
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE)

FetchContent_Declare(QHotkey
  GIT_REPOSITORY https://github.com/Skycoder42/QHotkey.git
  GIT_TAG master
)
FetchContent_MakeAvailable(QHotkey)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appTalkLess
    src/main.cpp

    # Models
    src/models/clip.h
    src/models/soundboard.h
    src/models/soundboardInfo.h
    src/models/AppSettings.h
    src/models/AppState.h

    # Audio Engine
    src/audioEngine.h
    src/audioEngine.cpp

    # Controllers
    src/controllers/hotkeyManager.h 
    src/controllers/hotkeyManager.cpp
    src/controllers/hotkeyvalidator.h
    src/controllers/hotkeyvalidator.cpp

    # QML Models
    src/qmlmodels/soundboardsListModel.h
    src/qmlmodels/soundboardsListModel.cpp
    src/qmlmodels/clipsListModel.h
    src/qmlmodels/clipsListModel.cpp
    src/qmlmodels/hotkeysModel.h
    src/qmlmodels/hotkeysModel.cpp


    # services
    src/services/storageRepository.h
    src/services/storageRepository.cpp
    src/services/soundboardService.h
    src/services/soundboardService.cpp
)

# Mark singleton files before adding the QML module
set_source_files_properties(qml/styles/Colors.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Typography.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/utils/Functions.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appTalkLess
    URI TalkLess
    VERSION 1.0
    QML_FILES
        Main.qml
        # Components
        qml/components/Sidebar.qml
        qml/components/HeaderBar.qml
        qml/components/BackgroundBanner.qml
        qml/components/SettingsTabSelector.qml
        qml/components/ToggleSwitch.qml
        qml/components/LabeledSlider.qml
        qml/components/DropdownSelector.qml
        qml/components/VolumeMeter.qml
        qml/components/StepIndicator.qml
        qml/components/ActionButton.qml
        qml/components/SettingsPanel.qml
        qml/components/TriangleSlider.qml
        qml/components/BalanceSlider.qml
        qml/components/VolumeMeterSlider.qml
        qml/components/SettingsDropdown.qml
        qml/components/SettingsToggle.qml
        qml/components/GradientButton.qml
        qml/components/DotMeter.qml
        qml/components/HotkeysTable.qml
        qml/components/HotkeyCapturePopup.qml
        qml/components/ClipTile.qml
        qml/components/AddAudioTile.qml
        qml/components/AudioClipPanel.qml
        qml/components/WaveformDisplay.qml
        qml/components/FileDropArea.qml
        qml/components/TrimWaveform.qml
        qml/components/AudioPlayerCard.qml
        qml/pages/ApplicationSettingsView.qml
        qml/pages/SoundboardView.qml
        qml/styles/Colors.qml
        qml/styles/Typography.qml
        qml/styles/Theme.qml
        qml/utils/Functions.qml

    RESOURCES
        # Sidebar navigation icons
        resources/icons/sidebar/ic_logo.png
        resources/icons/sidebar/ic_nav_soundboard.svg
        resources/icons/sidebar/ic_play.svg
        resources/icons/sidebar/ic_nav_macros.svg
        resources/icons/sidebar/ic_nav_settings.svg
        resources/icons/sidebar/ic_nav_stats.svg
        # Decorations
        resources/icons/decorations/ic_sidebar_divider.svg
        # Panel tab icons
        resources/icons/panel/ic_tab_settings.svg
        resources/icons/panel/ic_tab_add.svg
        resources/icons/panel/ic_tab_record.svg
        resources/icons/panel/ic_tab_speaker.svg
        resources/icons/panel/ic_clipboard.svg
        resources/icons/panel/ic_scissors.svg
        # Action icons
        resources/icons/actions/ic_mic.svg
        resources/icons/actions/ic_mic_test.svg
        resources/icons/actions/ic_refresh.svg
        # Edit icon
        resources/icons/uil_edit.svg
        # Images
        resources/images/background.png
        resources/images/background_light.png
        resources/images/splashScreen.png
        resources/images/Splash_Screen_light.png
        resources/images/audioClipDefaultBackground.png
        resources/images/addAudioBackground.png
        resources/images/sondboard.jpg
        resources/images/Subtract.svg
)

# Add include directories for QML type registration
target_include_directories(appTalkLess PRIVATE 
                        ${CMAKE_SOURCE_DIR}/src
                        lib
                        "${FFMPEG_ROOT}/include"
                    )

find_library(FFMPEG_AVFORMAT_LIB   NAMES avformat   libavformat   PATHS "${FFMPEG_ROOT}/lib" NO_DEFAULT_PATH)
find_library(FFMPEG_AVCODEC_LIB    NAMES avcodec    libavcodec    PATHS "${FFMPEG_ROOT}/lib" NO_DEFAULT_PATH)
find_library(FFMPEG_AVUTIL_LIB     NAMES avutil     libavutil     PATHS "${FFMPEG_ROOT}/lib" NO_DEFAULT_PATH)
find_library(FFMPEG_SWRESAMPLE_LIB NAMES swresample libswresample PATHS "${FFMPEG_ROOT}/lib" NO_DEFAULT_PATH)


# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appTalkLess PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appTalkLess
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appTalkLess
    PRIVATE Qt6::Core
    PRIVATE Qt6::Quick
    PRIVATE Qt6::Qml
    PRIVATE Qt6::Multimedia
    PRIVATE Qt6::QuickControls2
    PRIVATE Qt6::Svg
    PRIVATE QHotkey::QHotkey
)

# Link Carbon framework for global hotkeys on macOS
if(APPLE)
    target_link_libraries(appTalkLess PRIVATE "-framework Carbon")
    
    # Set custom Info.plist
    set_target_properties(appTalkLess PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/macos/Info.plist"
    )
endif()

include(GNUInstallDirs)
install(TARGETS appTalkLess
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
