QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++20 silent lrelease embed_translations qtquickcompiler

QM_FILES_RESOURCE_PREFIX = /translations
STEAM_PATH = $$PWD/Dependencies/steam

INCLUDEPATH +=                                  \
    MainWindow                                  \
    Utils                                       \
    MinesweeperLogic                            \
    SteamIntegration                            \
    Dependencies/steam                          \

SOURCES +=                                      \
    MainWindow/MainWindow.cpp                   \
    MinesweeperLogic/MinesweeperLogic.cpp       \
    SteamIntegration/SteamIntegration.cpp       \
    Utils/Utils.cpp                             \
    main.cpp                                    \

HEADERS +=                                      \
    MainWindow/MainWindow.h                     \
    MinesweeperLogic/MinesweeperLogic.h         \
    SteamIntegration/SteamIntegration.h         \
    Utils/Utils.h                               \

TRANSLATIONS +=                                 \
    Resources/translations/Retr0Mine_fr.ts      \
    Resources/translations/Retr0Mine_en.ts      \

RESOURCES +=                                    \
    Resources/icons/icons.qrc                   \
    Resources/images/images.qrc                 \
    Resources/qml/qml.qrc                       \
    Resources/sounds/sounds.qrc                 \

win32 {
    QMAKE_CXXFLAGS += -D_CRT_SECURE_NO_WARNINGS
    QMAKE_CXXFLAGS += -wd4828
    LIBS += -L$$STEAM_PATH/lib/win64 -lsteam_api64
}

linux {
    LIBS += $$STEAM_PATH/lib/linux64/libsteam_api.so
}

RC_FILE = Resources/appicon.rc
