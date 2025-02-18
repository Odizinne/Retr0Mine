cmake_minimum_required(VERSION 3.16)
project(Retr0Mine VERSION 1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
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

qt_policy(SET QTP0001 NEW)
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
   NO_RESOURCE_TARGET_PATH
   QML_FILES
       qml/Main.qml
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
       qml/CellFrame.qml
       qml/SidebarDelegate.qml
       qml/SidebarSeparator.qml
       qml/DifficultyLayout.qml
       qml/MainWindow.qml
       qml/GameArea.qml
       qml/InfoIcon.qml
       qml/+Universal/CellFrame.qml
       qml/+Universal/MainWindow.qml
       qml/+Fusion/CellFrame.qml
       qml/+FluentWinUI3/CellFrame.qml
       qml/+FluentWinUI3/SidebarDelegate.qml
       qml/+FluentWinUI3/GameArea.qml
       qml/+FluentWinUI3/SidebarSeparator.qml
       qml/+FluentWinUI3/DifficultyLayout.qml
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
    TS_FILES ${TS_FILES}
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
elseif(UNIX AND NOT APPLE)
    target_link_libraries(appRetr0Mine PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lib/steam/linux64/libsteam_api.so
    )
endif()
