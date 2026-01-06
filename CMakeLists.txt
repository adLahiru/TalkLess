cmake_minimum_required(VERSION 3.16)

project(TalkLess VERSION 0.1 LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Multimedia QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appTalkLess
    src/main_ui_only.cpp
    # Models
    # src/models/audioclip.h
    # src/models/audioclip.cpp
    # src/models/soundboardsection.h
    # src/models/soundboardsection.cpp
    # src/models/audioEngine.h
    # src/models/audioEngine.cpp
    # src/controllers/maincontroller.h
    # src/controllers/maincontroller.cpp
    # Controllers
    # src/controllers/audiomanager.h
    # src/controllers/audiomanager.cpp
    # src/controllers/hotkeymanager.h
    # src/controllers/hotkeymanager.cpp
    # src/controllers/settingsmanager.h
    # src/controllers/settingsmanager.cpp
    # Views
    # src/view/soundboardview.h
    # src/view/soundboardview.cpp
    # src/view/audioplayerview.h
    # src/view/audioplayerview.cpp
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
        qml/components/SideBar.qml
        qml/components/HeaderBar.qml
        qml/components/BackgroundBanner.qml
        qml/components/SettingsTabSelector.qml
        # qml/components/SoundboardListItem.qml
        # qml/components/HeaderBar.qml
        # qml/components/SettingsTabBar.qml
        # qml/components/SettingsHeader.qml
        # qml/components/ToggleSwitch.qml
        # qml/components/DropdownSelect.qml
        # qml/components/ActionButton.qml
        # qml/components/HotkeyItem.qml
        # qml/components/FeatureToggleItem.qml
        # qml/components/AudioCard.qml
        # qml/components/AddAudioCard.qml
        # qml/components/AudioTag.qml
        # qml/components/WaveformDisplay.qml
        # qml/components/SettingsImportExport.qml
        # qml/components/AudioPlayer.qml
        # qml/components/VolumeMeter.qml
        # qml/components/AudioDetailsPanel.qml
        # qml/components/AddAudioPanel.qml
        # qml/components/MetersPanel.qml
        # qml/components/TeleprompterPanel.qml
        # qml/components/AudioPanelTabs.qml
        # qml/components/AddAudioContent.qml
        # qml/components/RecordAudioContent.qml
        # Pages
        qml/pages/ApplicationSettingsView.qml
        qml/pages/SoundboardView.qml
        # qml/pages/AudioDevicesTab.qml
        # qml/pages/HotkeysTab.qml
        # qml/pages/FeaturesTab.qml
        # qml/pages/UIDisplayTab.qml
        # qml/pages/UpdatesTab.qml
        # qml/pages/SoundboardPage.qml
        # qml/pages/VolumeMixerPage.qml
        # qml/pages/SettingsManagementPage.qml
        # Styles (singletons)
        # qml/styles/Colors.qml
        # qml/styles/Typography.qml
        # qml/styles/Theme.qml
        # Utils (singleton)
        # qml/utils/Functions.qml
    SOURCES
        # src/view/soundboardview.h
        # src/view/soundboardview.cpp
        # src/view/audioplayerview.h
        # src/view/audioplayerview.cpp
    RESOURCES
        resources/icons/sound.svg
        resources/icons/play.svg
        resources/icons/macro.svg
        resources/icons/gear.svg
        resources/icons/stats.svg
        resources/icons/title.png
        resources/icons/sidebarline.svg
        resources/images/background.png
        QML_FILES qml/components/DotMeter.qml
)

# Add include directories for QML type registration
target_include_directories(appTalkLess PRIVATE 
                        src/view
                        lib
                    )

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
