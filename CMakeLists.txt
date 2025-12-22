cmake_minimum_required(VERSION 3.16)

project(TalkLess VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appTalkLess
    src/main.cpp
    # Models
    src/models/audioclip.h
    src/models/audioclip.cpp
    # Controllers
    src/controllers/audiomanager.h
    src/controllers/audiomanager.cpp
    src/controllers/hotkeymanager.h
    src/controllers/hotkeymanager.cpp
    # Views
    src/view/soundboardview.h
    src/view/soundboardview.cpp
    src/view/audioplayerview.h
    src/view/audioplayerview.cpp
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
        qml/components/SidebarItem.qml
        qml/components/SoundboardListItem.qml
        qml/components/HeaderBar.qml
        qml/components/SettingsTabBar.qml
        qml/components/SettingsHeader.qml
        qml/components/ToggleSwitch.qml
        qml/components/DropdownSelect.qml
        qml/components/ActionButton.qml
        qml/components/HotkeyItem.qml
        qml/components/FeatureToggleItem.qml
        qml/components/AudioCard.qml
        qml/components/AddAudioCard.qml
        qml/components/AudioTag.qml
        qml/components/WaveformDisplay.qml
        qml/components/AudioPlayer.qml
        qml/components/VolumeMeter.qml
        qml/components/AudioDetailsPanel.qml
        qml/components/AddAudioPanel.qml
        qml/components/MetersPanel.qml
        qml/components/TeleprompterPanel.qml
        # Pages
        qml/pages/SystemSettingsPage.qml
        qml/pages/AudioDevicesTab.qml
        qml/pages/HotkeysTab.qml
        qml/pages/FeaturesTab.qml
        qml/pages/UIDisplayTab.qml
        qml/pages/UpdatesTab.qml
        qml/pages/SoundboardPage.qml
        # Styles (singletons)
        qml/styles/Colors.qml
        qml/styles/Typography.qml
        qml/styles/Theme.qml
        # Utils (singleton)
        qml/utils/Functions.qml
    RESOURCES
        resources/images/background-51.png
        resources/images/background-52.png
        resources/images/background-53.png
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
    PRIVATE Qt6::Quick
    PRIVATE Qt6::Multimedia
)

include(GNUInstallDirs)
install(TARGETS appTalkLess
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
