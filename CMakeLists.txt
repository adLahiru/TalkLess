cmake_minimum_required(VERSION 3.16)

project(TalkLess VERSION 0.1 LANGUAGES CXX)

# ----------------------------
# Global build settings
# ----------------------------
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(QT_DEFAULT_MAJOR_VERSION 6 CACHE STRING "" FORCE)

include(FetchContent)

# Fix for QHotkey's outdated cmake_minimum_required with newer CMake versions
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE)

# ----------------------------
# Qt
# ----------------------------
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Quick
    Qml
    Multimedia
    QuickControls2
    Svg
)

qt_standard_project_setup(REQUIRES 6.5)

# Optional: silence QML policy warning (QTP0004). Remove if you want to enforce qmldir layout.
if(COMMAND qt_policy)
    qt_policy(SET QTP0004 OLD)
endif()

# ----------------------------
# QHotkey (FetchContent)
# ----------------------------
FetchContent_Declare(QHotkey
  GIT_REPOSITORY https://github.com/Skycoder42/QHotkey.git
  GIT_TAG master
)
FetchContent_MakeAvailable(QHotkey)

# ----------------------------
# App target
# ----------------------------
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

    # Services
    src/services/storageRepository.h
    src/services/storageRepository.cpp
    src/services/soundboardService.h
    src/services/soundboardService.cpp
)

# Mark singleton files before adding the QML module
set_source_files_properties(qml/styles/Colors.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Typography.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Theme.qml      PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/utils/Functions.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appTalkLess
    URI TalkLess
    VERSION 1.0
    QML_FILES
        Main.qml

        # Components
        qml/components/SideBar.qml
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

        # Pages
        qml/pages/ApplicationSettingsView.qml
        qml/pages/SoundboardView.qml

        # Styles (singletons)
        qml/styles/Colors.qml
        qml/styles/Typography.qml
        qml/styles/Theme.qml

        # Utils (singleton)
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
        resources/images/splashScreen.png
        resources/images/audioClipDefaultBackground.png
        resources/images/addAudioBackground.png
        resources/images/sondboard.jpg
        resources/images/Subtract.svg
)

# Your own headers
target_include_directories(appTalkLess PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/lib
)

# ----------------------------
# FFmpeg (from vcpkg)
# ----------------------------
# vcpkg's ffmpeg port provides module-style integration (not CONFIG):
#   find_package(FFMPEG REQUIRED)
find_package(FFMPEG REQUIRED)

target_include_directories(appTalkLess PRIVATE ${FFMPEG_INCLUDE_DIRS})
# Some setups provide full paths in FFMPEG_LIBRARIES; linking directories is harmless.
if(DEFINED FFMPEG_LIBRARY_DIRS)
    target_link_directories(appTalkLess PRIVATE ${FFMPEG_LIBRARY_DIRS})
endif()
target_link_libraries(appTalkLess PRIVATE ${FFMPEG_LIBRARIES})

# ----------------------------
# Link libraries (Qt + QHotkey)
# ----------------------------
target_link_libraries(appTalkLess PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Multimedia
    Qt6::QuickControls2
    Qt6::Svg
    QHotkey::QHotkey
)

# ----------------------------
# Runtime dependency deployment (FFmpeg) for Qt Creator Run
# ----------------------------
# Ensures the app runs from Qt Creator on Windows & macOS without editing PATH/DYLD_LIBRARY_PATH.
if(DEFINED VCPKG_INSTALLED_DIR AND DEFINED VCPKG_TARGET_TRIPLET)

  # Windows: copy vcpkg DLLs (FFmpeg etc.) next to the .exe
  if(WIN32)
    set(_vcpkg_bin      "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")
    set(_vcpkg_debugbin "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin")

    add_custom_command(TARGET appTalkLess POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<IF:$<CONFIG:Debug>,${_vcpkg_debugbin},${_vcpkg_bin}>"
        "$<TARGET_FILE_DIR:appTalkLess>"
      COMMENT "Copying vcpkg runtime DLLs next to appTalkLess.exe"
    )
  endif()

  # macOS: copy FFmpeg dylibs into the .app bundle + set rpath to Frameworks
  if(APPLE)
    set(_vcpkg_lib      "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib")
    set(_vcpkg_debuglib "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/lib")

    set_target_properties(appTalkLess PROPERTIES
      # During build/run from build dir:
      BUILD_RPATH "$<IF:$<CONFIG:Debug>,${_vcpkg_debuglib},${_vcpkg_lib}>"
      # When bundled:
      INSTALL_RPATH "@executable_path/../Frameworks"
    )

    file(GLOB _ffmpeg_dylibs_release
      "${_vcpkg_lib}/libavcodec*.dylib*"
      "${_vcpkg_lib}/libavformat*.dylib*"
      "${_vcpkg_lib}/libavutil*.dylib*"
      "${_vcpkg_lib}/libswresample*.dylib*"
    )

    file(GLOB _ffmpeg_dylibs_debug
      "${_vcpkg_debuglib}/libavcodec*.dylib*"
      "${_vcpkg_debuglib}/libavformat*.dylib*"
      "${_vcpkg_debuglib}/libavutil*.dylib*"
      "${_vcpkg_debuglib}/libswresample*.dylib*"
    )

    add_custom_command(TARGET appTalkLess POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_BUNDLE_DIR:appTalkLess>/Contents/Frameworks"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<IF:$<CONFIG:Debug>,${_ffmpeg_dylibs_debug},${_ffmpeg_dylibs_release}>"
        "$<TARGET_BUNDLE_DIR:appTalkLess>/Contents/Frameworks"
      COMMENT "Copying FFmpeg dylibs into app bundle (Contents/Frameworks)"
    )
  endif()

endif()

# ----------------------------
# Platform specifics
# ----------------------------
set_target_properties(appTalkLess PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

if(APPLE)
    target_link_libraries(appTalkLess PRIVATE "-framework Carbon")
    set_target_properties(appTalkLess PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/macos/Info.plist"
    )
endif()

# NOTE:
# Do NOT call qt_finalize_executable(appTalkLess) here.
# In your setup Qt finalizes automatically; calling it again causes "finalize twice" warnings.

# ----------------------------
# Install
# ----------------------------
include(GNUInstallDirs)

install(TARGETS appTalkLess
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
