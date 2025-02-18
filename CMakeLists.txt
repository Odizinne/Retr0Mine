cmake_minimum_required(VERSION 3.16)
project(Retr0Mine VERSION 1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_DISABLE_FIND_PACKAGE_WrapVulkanHeaders TRUE)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    Multimedia
    QuickControls2
    LinguistTools
)

qt_standard_project_setup(REQUIRES 6.5)

qt_policy(SET QTP0004 NEW)

set(SOURCES
    src/main.cpp
    src/gametimer.cpp
    src/mainwindow.cpp
    src/minesweeperlogic.cpp
    src/steamintegration.cpp
)

set(HEADERS
    include/gametimer.h
    include/mainwindow.h
    include/minesweeperlogic.h
    include/steamintegration.h
)

# Create the executable
add_executable(appRetr0Mine
    ${SOURCES}
    ${HEADERS}
    resources/icons/icons.qrc
    resources/images/images.qrc
    resources/sounds/sounds.qrc
    resources/fonts/fonts.qrc
    resources/appicon.rc
)

qt_add_qml_module(appRetr0Mine
   URI Retr0Mine
   VERSION 1.0
   QML_FILES
       qml/Colors.qml
       qml/Retr0MineSettings.qml
       qml/AudioEffectsEngine.qml
       qml/Cell.qml
       qml/SettingsPage.qml
       qml/GameOverPopup.qml
       qml/AboutPage.qml
       qml/LoadWindow.qml
       qml/SaveWindow.qml
       qml/ErrorWindow.qml
       qml/TopBar.qml
       qml/LeaderboardPage.qml
       qml/TempScrollBar.qml
       qml/WelcomePage.qml
       qml/Main.qml
       qml/InfoIcon.qml
)

# Set include directories
target_include_directories(appRetr0Mine PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include/steam
)

# Link Qt libraries
target_link_libraries(appRetr0Mine PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Multimedia
    Qt6::QuickControls2
)

# Handle translations
qt_add_translations(appRetr0Mine
    TS_FILES
        translations/retr0mine_en.ts
        translations/retr0mine_fr.ts
    RESOURCE_PREFIX "/translations"
)

# Platform specific settings
if(WIN32)
    target_compile_definitions(appRetr0Mine PRIVATE
        *CRT*SECURE_NO_WARNINGS
    )
    target_compile_options(appRetr0Mine PRIVATE
        /wd4828
    )
    target_link_libraries(appRetr0Mine PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/win64/steam_api64.lib
    )
    set_target_properties(appRetr0Mine PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
elseif(UNIX AND NOT APPLE)
    target_link_libraries(appRetr0Mine PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/linux64/libsteam_api.so
    )
endif()
