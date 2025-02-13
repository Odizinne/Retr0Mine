#ifndef GAMETIMER_H
#define GAMETIMER_H

#include <QObject>
#include <QTimer>
#include <QElapsedTimer>

class GameTimer : public QObject {
    Q_OBJECT
    Q_PROPERTY(qint64 centiseconds READ centiseconds WRITE setCentiseconds NOTIFY centisecondsChanged)

public:
    explicit GameTimer(QObject *parent = nullptr);
    qint64 centiseconds() const;
    void setCentiseconds(qint64 value);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void resumeFrom(qint64 centiseconds);

signals:
    void centisecondsChanged();

private:
    QElapsedTimer timer;
    QTimer updateTimer;
    qint64 m_centiseconds;
    qint64 m_baseTime;
};

#endif // GAMETIMER_H
