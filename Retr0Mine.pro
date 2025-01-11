QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++17 silent lrelease embed_translations

QM_FILES_RESOURCE_PREFIX = /translations

INCLUDEPATH +=                                  \
    MainWindow                                  \
    Utils                                       \
    MinesweeperLogic                            \

SOURCES +=                                      \
    MainWindow/MainWindow.cpp                   \
    MinesweeperLogic/MinesweeperLogic.cpp       \
    Utils/Utils.cpp                             \
    main.cpp                                    \

HEADERS +=                                      \
    MainWindow/MainWindow.h                     \
    MinesweeperLogic/MinesweeperLogic.h         \
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

win32:LIBS += -ladvapi32

RC_FILE = Resources/appicon.rc
