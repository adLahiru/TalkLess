cmake_minimum_required(VERSION 3.16)

project(TalkLess VERSION 0.1 LANGUAGES CXX)

include(FetchContent)
include(GNUInstallDirs)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(QT_DEFAULT_MAJOR_VERSION 6 CACHE STRING "" FORCE)

# Require Qt 6.5+ (matches qt_standard_project_setup below)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Quick Qml Multimedia QuickControls2 Svg)
qt_standard_project_setup(REQUIRES 6.5)

# ---- FIX: QTP0004 only exists in newer Qt versions (not in 6.5.x) ----
# Silence QTP0004 warning (no qmldir required) when available.
if (QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 OLD)
endif()

add_compile_definitions(NOMINMAX)

# ----------------------------
# QHotkey
# ----------------------------
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE) # for older QHotkey cmake
set(QHOTKEY_GIT_TAG "master" CACHE STRING "QHotkey git tag/commit to use")

FetchContent_Declare(QHotkey
  GIT_REPOSITORY https://github.com/Skycoder42/QHotkey.git
  GIT_TAG        ${QHOTKEY_GIT_TAG}
)
FetchContent_MakeAvailable(QHotkey)

# ----------------------------
# Executable
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
    src/miniaudio_impl.cpp

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

# QML singletons
set_source_files_properties(qml/styles/Colors.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Typography.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/styles/Theme.qml      PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/utils/Functions.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# ----------------------------
# Resources (fix absolute /resources/... issue)
# ----------------------------
set(TALKLESS_RESOURCES
    resources/icons/sidebar/ic_logo.png
    resources/icons/sidebar/ic_nav_soundboard.svg
    resources/icons/sidebar/ic_play.svg
    resources/icons/sidebar/ic_nav_macros.svg
    resources/icons/sidebar/ic_nav_settings.svg
    resources/icons/sidebar/ic_nav_stats.svg

    resources/icons/decorations/ic_sidebar_divider.svg

    resources/icons/panel/ic_tab_settings.svg
    resources/icons/panel/ic_tab_add.svg
    resources/icons/panel/ic_tab_record.svg
    resources/icons/panel/ic_tab_speaker.svg
    resources/icons/panel/ic_clipboard.svg
    resources/icons/panel/ic_scissors.svg

    resources/icons/actions/ic_mic.svg
    resources/icons/actions/ic_mic_test.svg
    resources/icons/actions/ic_refresh.svg

    resources/icons/uil_edit.svg

    resources/images/background.png
    resources/images/background_light.png
    resources/images/splashScreen.png
    resources/images/splashScreen_light.png
    resources/images/audioClipDefaultBackground.png
    resources/images/addAudioBackground.png
    resources/images/sondboard.jpg
    resources/images/Subtract.svg

    resources/icons/reproduction/loop_dark.svg
    resources/icons/reproduction/loop_light.svg
    resources/icons/reproduction/overlay_dark.svg
    resources/icons/reproduction/overlay_light.svg
    resources/icons/reproduction/play-pause_dark.svg
    resources/icons/reproduction/play-pause_light.svg
    resources/icons/reproduction/restart_dark.svg
    resources/icons/reproduction/restart_light.svg
    resources/icons/reproduction/play-stop_dark.svg
    resources/icons/reproduction/play-stop_light.svg
)

# Force every resource to be accessible with a RELATIVE alias.
foreach(_res IN LISTS TALKLESS_RESOURCES)
    set(_alias "${_res}")
    string(REGEX REPLACE "^/+" "" _alias "${_alias}")
    set_source_files_properties("${_res}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
endforeach()

qt_add_qml_module(appTalkLess
    URI TalkLess
    VERSION 1.0
    QML_FILES
        Main.qml
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
        ${TALKLESS_RESOURCES}
)

target_include_directories(appTalkLess PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/lib
)

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
# FFmpeg (optional: avoids config failing)
# ----------------------------
option(TALKLESS_ENABLE_FFMPEG "Enable FFmpeg integration" ON)
set(FFMPEG_ROOT "${CMAKE_SOURCE_DIR}/lib/ffmpeg" CACHE PATH "FFmpeg root (include/, lib/ or bin/)")

if(TALKLESS_ENABLE_FFMPEG)
    set(_ffmpeg_lib_paths
        "${FFMPEG_ROOT}/lib"
        "${FFMPEG_ROOT}/lib64"
        "${FFMPEG_ROOT}/bin"
    )

    find_library(FFMPEG_AVFORMAT_LIB   NAMES avformat   libavformat   PATHS ${_ffmpeg_lib_paths} NO_DEFAULT_PATH)
    find_library(FFMPEG_AVCODEC_LIB    NAMES avcodec    libavcodec    PATHS ${_ffmpeg_lib_paths} NO_DEFAULT_PATH)
    find_library(FFMPEG_AVUTIL_LIB     NAMES avutil     libavutil     PATHS ${_ffmpeg_lib_paths} NO_DEFAULT_PATH)
    find_library(FFMPEG_SWRESAMPLE_LIB NAMES swresample libswresample PATHS ${_ffmpeg_lib_paths} NO_DEFAULT_PATH)

    if(FFMPEG_AVFORMAT_LIB AND FFMPEG_AVCODEC_LIB AND FFMPEG_AVUTIL_LIB AND FFMPEG_SWRESAMPLE_LIB
       AND EXISTS "${FFMPEG_ROOT}/include")
        target_include_directories(appTalkLess PRIVATE "${FFMPEG_ROOT}/include")
        target_link_libraries(appTalkLess PRIVATE
            ${FFMPEG_AVFORMAT_LIB}
            ${FFMPEG_AVCODEC_LIB}
            ${FFMPEG_AVUTIL_LIB}
            ${FFMPEG_SWRESAMPLE_LIB}
        )
        target_compile_definitions(appTalkLess PRIVATE TALKLESS_HAS_FFMPEG=1)
    else()
        message(WARNING
            "FFmpeg not found under FFMPEG_ROOT='${FFMPEG_ROOT}'. Continuing without FFmpeg. "
            "Either fix the path/put MSVC .lib files in lib/ or configure with -DTALKLESS_ENABLE_FFMPEG=OFF."
        )
        target_compile_definitions(appTalkLess PRIVATE TALKLESS_HAS_FFMPEG=0)
    endif()
endif()

# ----------------------------
# Platform stuff
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

# ----------------------------
# Install
# ----------------------------
install(TARGETS appTalkLess
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
 
 #   - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
 #   D e p l o y m e n t   ( P o s t - B u i l d )  
 #   - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
 i f ( W I N 3 2 )  
         #   A t t e m p t   t o   f i n d   w i n d e p l o y q t  
         f i n d _ p a c k a g e ( Q t 6   C O M P O N E N T S   C o r e   R E Q U I R E D )  
         g e t _ t a r g e t _ p r o p e r t y ( _ q m a k e _ e x e c u t a b l e   Q t 6 : : q m a k e   I M P O R T E D _ L O C A T I O N )  
         g e t _ f i l e n a m e _ c o m p o n e n t ( _ q t _ b i n _ d i r   " $ { _ q m a k e _ e x e c u t a b l e } "   D I R E C T O R Y )  
         f i n d _ p r o g r a m ( W I N D E P L O Y Q T _ E X E C U T A B L E   w i n d e p l o y q t   H I N T S   " $ { _ q t _ b i n _ d i r } " )  
  
         i f ( W I N D E P L O Y Q T _ E X E C U T A B L E )  
                 m e s s a g e ( S T A T U S   " F o u n d   w i n d e p l o y q t :   $ { W I N D E P L O Y Q T _ E X E C U T A B L E } " )  
                 a d d _ c u s t o m _ c o m m a n d ( T A R G E T   a p p T a l k L e s s   P O S T _ B U I L D  
                         C O M M A N D   " $ { W I N D E P L O Y Q T _ E X E C U T A B L E } "  
                                 - - q m l d i r   " $ { C M A K E _ S O U R C E _ D I R } / q m l "  
                                 - - d i r   " $ < T A R G E T _ F I L E _ D I R : a p p T a l k L e s s > "  
                                 - - n o - c o m p i l e r - r u n t i m e  
                                 " $ < T A R G E T _ F I L E : a p p T a l k L e s s > "  
                         C O M M E N T   " R u n n i n g   w i n d e p l o y q t   t o   d e p l o y   Q t   d e p e n d e n c i e s . . . "  
                 )  
         e l s e ( )  
                 m e s s a g e ( W A R N I N G   " w i n d e p l o y q t   n o t   f o u n d !   Y o u   m a y   n e e d   t o   r u n   i t   m a n u a l l y . " )  
         e n d i f ( )  
 e n d i f ( )  
 