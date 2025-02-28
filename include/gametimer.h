#pragma once

#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <QQmlEngine>

class GameTimer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString displayTime READ displayTime NOTIFY displayTimeChanged)
    Q_PROPERTY(qint64 centiseconds READ centiseconds WRITE setCentiseconds NOTIFY centisecondsChanged)
public:
    explicit GameTimer(QObject *parent = nullptr);

    Q_INVOKABLE QString getDetailedTime() const;
    QString displayTime() const { return m_displayTime; }
    qint64 centiseconds() const;

public slots:
    void setCentiseconds(qint64 value);
    void start();
    void stop();
    void reset();
    void resumeFrom(qint64 centiseconds);

signals:
    void displayTimeChanged();
    void secondChanged();
    void centisecondsChanged();

private:
    void updateDisplayTime();
    QTimer updateTimer;
    QElapsedTimer timer;
    qint64 m_centiseconds;
    qint64 m_baseTime;
    int m_lastSecond;
    QString m_displayTime;
};

struct GameTimerForeign
{
    Q_GADGET
    QML_FOREIGN(GameTimer)
    QML_SINGLETON
    QML_NAMED_ELEMENT(GameTimer)
public:
    inline static GameTimer* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;

    static GameTimer* create(QQmlEngine*, QJSEngine* engine)
    {
        Q_ASSERT(s_singletonInstance);
        Q_ASSERT(engine->thread() == s_singletonInstance->thread());
        if (s_engine)
            Q_ASSERT(engine == s_engine);
        else
            s_engine = engine;
        QJSEngine::setObjectOwnership(s_singletonInstance, QJSEngine::CppOwnership);
        return s_singletonInstance;
    }
};
