QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++17 lrelease embed_translations

QM_FILES_RESOURCE_PREFIX = /translations

INCLUDEPATH +=                              \
    MainWindow                              \
    Utils                                   \
    MinesweeperLogic                        \

SOURCES +=                                  \
    MainWindow/MainWindow.cpp               \
    MinesweeperLogic/MinesweeperLogic.cpp   \
    Utils/Utils.cpp                         \
    main.cpp                                \

HEADERS +=                                  \
    MainWindow/MainWindow.h                 \
    MinesweeperLogic/MinesweeperLogic.h     \
    Utils/Utils.h                           \

TRANSLATIONS +=                             \
    Resources/translations/Retr0Mine_fr.ts  \
    Resources/translations/Retr0Mine_en.ts  \

RESOURCES += Resources/resources.qrc

win32:LIBS += -ladvapi32

RC_FILE = Resources/appicon.rc
