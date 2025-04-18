cmake_minimum_required(VERSION 3.21)
project(Retr0Mine VERSION 1.0 LANGUAGES CXX)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Installation directory" FORCE)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(QT_QML_GENERATE_QMLLS_INI ON)
set(CMAKE_DISABLE_FIND_PACKAGE_WrapVulkanHeaders TRUE)

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    Multimedia
    LinguistTools
    Concurrent
)

qt_standard_project_setup(REQUIRES 6.8)

set(SOURCES
    src/main.cpp
    src/gametimer.cpp
    src/gamecore.cpp
    src/gamelogic.cpp
    src/steamintegration.cpp
    src/gridgenerator.cpp
    src/minesweepersolver.cpp
)

set(HEADERS
    include/gametimer.h
    include/gamecore.h
    include/gamelogic.h
    include/steamintegration.h
    include/gridgenerator.h
    include/minesweepersolver.h
)

set(QML_FILES
    qml/Main.qml
    qml/Cell.qml
    qml/SettingsWindow.qml
    qml/LogWindow.qml
    qml/ErrorWindow.qml
    qml/TopBar.qml
    qml/InfoIcon.qml
    qml/GameGrid.qml
    qml/ScrollingArea.qml
    qml/MainMenu.qml
    qml/GridLoadingIndicator.qml
    qml/SignalIndicator.qml
    qml/MultiplayerChat.qml
    qml/Common/NfButton.qml
    qml/Common/NfRadioButton.qml
    qml/Common/NfSwitch.qml
    qml/Common/NfComboBox.qml
    qml/Common/NfSlider.qml
    qml/Common/NfSpinBox.qml
    qml/Common/AnimatedPopup.qml
    qml/Common/CustomDelegate.qml
    qml/Common/CustomMenuItem.qml
    qml/Common/ImageProgressBar.qml
    qml/Debug/DebugFrame.qml
    qml/SettingsPanes/AccessibilityPane.qml
    qml/SettingsPanes/AdvancedPane.qml
    qml/SettingsPanes/DifficultyPane.qml
    qml/SettingsPanes/GameplayPane.qml
    qml/SettingsPanes/LanguagePane.qml
    qml/SettingsPanes/ShortcutsPane.qml
    qml/SettingsPanes/SoundsPane.qml
    qml/SettingsPanes/VisualsPane.qml
    qml/SettingsPanes/MultiplayerPane.qml
    qml/Popups/RestorePopup.qml
    qml/Popups/PostgamePopup.qml
    qml/Popups/AboutPopup.qml
    qml/Popups/LoadPopup.qml
    qml/Popups/SavePopup.qml
    qml/Popups/LeaderboardPopup.qml
    qml/Popups/WelcomePopup.qml
    qml/Popups/RulesPopup.qml
    qml/Popups/PausePopup.qml
    qml/Popups/PrivateSessionPopup.qml
    qml/Popups/MultiplayerErrorPopup.qml
    qml/Popups/InviteReceivedPopup.qml
    qml/Popups/PlayerLeftPopup.qml
)

set(QML_SINGLETONS
    qml/Singletons/UserSettings.qml
    qml/Singletons/Constants.qml
    qml/Singletons/GameState.qml
    qml/Singletons/SaveManager.qml
    qml/Singletons/GridBridge.qml
    qml/Singletons/ComponentsContext.qml
    qml/Singletons/NetworkManager.qml
    qml/Singletons/SteamInputHandler.qml
    qml/Singletons/AudioEngine.qml
    qml/Singletons/LogManager.qml
)

set_source_files_properties(${QML_SINGLETONS}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_executable(${CMAKE_PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    resources/icons/icons.qrc
    resources/images/images.qrc
    resources/sounds/sounds.qrc
    resources/fonts/fonts.qrc
    resources/cursors/cursors.qrc
    resources/appicon.rc
)

qt_add_qml_module(${CMAKE_PROJECT_NAME}
    URI Odizinne.Retr0Mine
    VERSION 1.0
    QML_FILES ${QML_FILES} ${QML_SINGLETONS}
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include/steam
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    Qt6::Quick
    Qt6::Multimedia
    Qt6::Concurrent
)

qt_add_translations(${CMAKE_PROJECT_NAME}
    TS_FILES
        i18n/Retr0Mine_en.ts
        i18n/Retr0Mine_fr.ts
    RESOURCE_PREFIX "/i18n"
    LUPDATE_OPTIONS "-no-obsolete"
)

#add_dependencies(${CMAKE_PROJECT_NAME} update_translations)

if(WIN32)
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/win64/steam_api64.lib
        dwmapi
    )
    set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
elseif(UNIX AND NOT APPLE)
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/linux64/libsteam_api.so
    )
elseif(APPLE)
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/osx/libsteam_api.dylib
    )
endif()

include(GNUInstallDirs)

install(TARGETS ${CMAKE_PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(WIN32)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/win64/steam_api64.dll
            DESTINATION ${CMAKE_INSTALL_BINDIR})
elseif(UNIX AND NOT APPLE)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/linux64/libsteam_api.so
            DESTINATION ${CMAKE_INSTALL_BINDIR})
elseif(APPLE)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/osx/libsteam_api.dylib
            DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

qt_generate_deploy_qml_app_script(
    TARGET ${CMAKE_PROJECT_NAME}
    OUTPUT_SCRIPT deploy_script
    NO_TRANSLATIONS
    DEPLOY_TOOL_OPTIONS --no-compiler-runtime --no-opengl-sw --no-system-dxc-compiler --no-system-d3d-compiler --skip-plugin-types imageformats,designer,iconengines,qmllint,generic,networkinformation,help,qmltooling,sqldrivers,tls,qmlls
)

install(SCRIPT ${deploy_script})
