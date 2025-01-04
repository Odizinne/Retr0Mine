QT       += core gui qml quick multimedia quickcontrols2

CONFIG += c++17

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

RESOURCES += Resources/resources.qrc

win32:LIBS += -ladvapi32

RC_FILE = Resources/appicon.rc
