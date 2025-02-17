QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++20 silent lrelease embed_translations qtquickcompiler

QM_FILES_RESOURCE_PREFIX = /translations
STEAM_PATH = $$PWD/Dependencies/steam

INCLUDEPATH +=                                  \
    GameTimer                                   \
    MainWindow                                  \
    MinesweeperLogic                            \
    SteamIntegration                            \
    Dependencies/steam                          \

SOURCES +=                                      \
    GameTimer/GameTimer.cpp                     \
    MainWindow/MainWindow.cpp                   \
    MinesweeperLogic/MinesweeperLogic.cpp       \
    SteamIntegration/SteamIntegration.cpp       \
    main.cpp                                    \

HEADERS +=                                      \
    GameTimer/GameTimer.h                       \
    MainWindow/MainWindow.h                     \
    MinesweeperLogic/MinesweeperLogic.h         \
    SteamIntegration/SteamIntegration.h         \

TRANSLATIONS +=                                 \
    Resources/translations/Retr0Mine_fr.ts      \
    Resources/translations/Retr0Mine_en.ts      \

RESOURCES +=                                    \
    Resources/icons/icons.qrc                   \
    Resources/images/images.qrc                 \
    Resources/qml/qml.qrc                       \
    Resources/sounds/sounds.qrc                 \
    Resources/fonts/fonts.qrc                   \

win32 {
    QMAKE_CXXFLAGS += -D_CRT_SECURE_NO_WARNINGS
    QMAKE_CXXFLAGS += -wd4828
    LIBS += -L$$STEAM_PATH/lib/win64 -lsteam_api64
}

linux {
    LIBS += $$STEAM_PATH/lib/linux64/libsteam_api.so
}

RC_FILE = Resources/appicon.rc
