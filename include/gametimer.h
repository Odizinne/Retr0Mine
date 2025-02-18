#ifndef GAMETIMER_H
#define GAMETIMER_H

#include <QObject>
#include <QTimer>
#include <QElapsedTimer>

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

#endif // GAMETIMER_H
