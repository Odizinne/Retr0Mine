cmake_minimum_required(VERSION 3.16)
project(Retr0Mine VERSION 1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(QT_QML_GENERATE_QMLLS_INI ON)
set(CMAKE_DISABLE_FIND_PACKAGE_WrapVulkanHeaders TRUE)
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    Multimedia
    QuickControls2
    LinguistTools
    Concurrent
)
qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)
set(SOURCES
    src/main.cpp
    src/gametimer.cpp
    src/gamecore.cpp
    src/gamelogic.cpp
    src/steamintegration.cpp
)
set(HEADERS
    include/gametimer.h
    include/gamecore.h
    include/gamelogic.h
    include/steamintegration.h
)
set(QML_FILES
    qml/Main.qml
    qml/Cell.qml
    qml/SettingsWindow.qml
    qml/ErrorWindow.qml
    qml/TopBar.qml
    qml/TempScrollBar.qml
    qml/InfoIcon.qml
    qml/GameGrid.qml
    qml/GameAudio.qml
    qml/GameView.qml
    qml/MainMenu.qml
    qml/SettingsPanes/AccessibilityPane.qml
    qml/SettingsPanes/AdvancedPane.qml
    qml/SettingsPanes/DifficultyPane.qml
    qml/SettingsPanes/GameplayPane.qml
    qml/SettingsPanes/LanguagePane.qml
    qml/SettingsPanes/ShortcutsPane.qml
    qml/SettingsPanes/SoundsPane.qml
    qml/SettingsPanes/VisualsPane.qml
    qml/Popups/RestorePopup.qml
    qml/Popups/PostgamePopup.qml
    qml/Popups/AboutPopup.qml
    qml/Popups/LoadPopup.qml
    qml/Popups/SavePopup.qml
    qml/Popups/LeaderboardPopup.qml
    qml/Popups/WelcomePopup.qml
    qml/Popups/GenerationPopup.qml
    qml/Popups/RulesPopup.qml
)
set(QML_SINGLETONS
    qml/Singletons/GameSettings.qml
    qml/Singletons/GameConstants.qml
    qml/Singletons/GameState.qml
    qml/Singletons/SaveManager.qml
    qml/Singletons/GridBridge.qml
    qml/Singletons/ComponentsContext.qml
)
set_source_files_properties(${QML_SINGLETONS}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)
add_executable(${CMAKE_PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    resources/icons/icons.qrc
    resources/images/images.qrc
    resources/sounds/sounds.qrc
    resources/fonts/fonts.qrc
    resources/appicon.rc
)
qt_add_qml_module(${CMAKE_PROJECT_NAME}
    URI net.odizinne.retr0mine
    VERSION 1.0
    QML_FILES ${QML_FILES} ${QML_SINGLETONS}
)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include/steam
)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Multimedia
    Qt6::QuickControls2
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
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
        *CRT*SECURE_NO_WARNINGS
    )
    target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE
        /wd4828
    )
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/win64/steam_api64.lib
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
