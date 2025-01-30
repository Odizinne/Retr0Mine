QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++17 silent lrelease embed_translations

# Silence steam_api warnings
QMAKE_CXXFLAGS += -D_CRT_SECURE_NO_WARNINGS
QMAKE_CXXFLAGS += -wd4828

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
    Resources/translations/Retr0Mine_de.ts      \
    Resources/translations/Retr0Mine_es.ts      \
    Resources/translations/Retr0Mine_it.ts      \
    Resources/translations/Retr0Mine_ja.ts      \
    Resources/translations/Retr0Mine_zh_CN.ts   \
    Resources/translations/Retr0Mine_zh_TW.ts   \
    Resources/translations/Retr0Mine_ko.ts      \
    Resources/translations/Retr0Mine_ru.ts      \

RESOURCES += Resources/resources.qrc

win32:LIBS += -L$$STEAM_PATH/lib/win64 -lsteam_api64

linux:LIBS += $$STEAM_PATH/lib/linux64/libsteam_api.so

RC_FILE = Resources/appicon.rc
