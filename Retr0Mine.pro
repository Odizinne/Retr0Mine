QT       += core gui qml quick multimedia

CONFIG += c++17

INCLUDEPATH +=                              \
    MainWindow                              \
    Utils                                   \

SOURCES +=                                  \
    MainWindow/MainWindow.cpp               \
    Utils/Utils.cpp                         \
    main.cpp                                \

HEADERS +=                                  \
    MainWindow/MainWindow.h                 \
    Utils/Utils.h                           \

RESOURCES += Resources/resources.qrc

LIBS += -ladvapi32

RC_FILE = Resources/appicon.rc
