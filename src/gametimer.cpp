#include "gametimer.h"
#include <QDebug>
GameTimer::GameTimer(QObject *parent)
    : QObject(parent)
    , m_centiseconds(0)
    , m_baseTime(0)
    , m_pausedElapsedTime(0)
    , m_lastSecond(-1)
    , m_displayTime("00:00")
    , m_isPaused(false)
{
    connect(&updateTimer, &QTimer::timeout, this, [this]() {
        if (!timer.isValid()) {
            return;
        }
        m_centiseconds = m_baseTime + (timer.elapsed() / 10);
        int currentSecond = m_centiseconds / 100;
        if (currentSecond != m_lastSecond) {
            m_lastSecond = currentSecond;
            updateDisplayTime();
            emit secondChanged();
        }
    });
    updateTimer.setInterval(10);
}
void GameTimer::updateDisplayTime()
{
    int totalSeconds = m_centiseconds / 100;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    m_displayTime = QString("%1:%2")
                        .arg(minutes, 2, 10, QChar('0'))
                        .arg(seconds, 2, 10, QChar('0'));
    emit displayTimeChanged();
}
QString GameTimer::getDetailedTime() const
{
    int totalSeconds = m_centiseconds / 100;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    int centis = m_centiseconds % 100;
    return QString("%1:%2.%3")
        .arg(minutes, 2, 10, QChar('0'))
        .arg(seconds, 2, 10, QChar('0'))
        .arg(centis, 2, 10, QChar('0'));
}
qint64 GameTimer::centiseconds() const
{
    return m_centiseconds;
}
void GameTimer::setCentiseconds(qint64 value)
{
    if (m_centiseconds != value) {
        m_centiseconds = value;
        int currentSecond = m_centiseconds / 100;
        if (currentSecond != m_lastSecond) {
            m_lastSecond = currentSecond;
            emit secondChanged();
        }
    }
}
void GameTimer::start()
{
    m_isPaused = false;
    timer.start();
    updateTimer.start();
}
void GameTimer::stop()
{
    updateTimer.stop();
}
void GameTimer::reset()
{
    stop();
    timer.invalidate();
    m_baseTime = 0;
    m_centiseconds = 0;
    m_lastSecond = -1;
    m_isPaused = false;
    updateDisplayTime();
    emit secondChanged();
    emit isPausedChanged();
}
void GameTimer::resumeFrom(qint64 centiseconds)
{
    stop();
    m_baseTime = centiseconds;
    m_centiseconds = centiseconds;
    m_lastSecond = centiseconds / 100;
    m_isPaused = false;
    updateDisplayTime();
    timer.start();
    updateTimer.start();
    emit secondChanged();
    emit displayTimeChanged();
    emit isPausedChanged();
}

void GameTimer::pause()
{
    if (!m_isPaused && timer.isValid()) {
        m_pausedElapsedTime = timer.elapsed();
        updateTimer.stop();
        m_isPaused = true;
        emit isPausedChanged();
    }
}

void GameTimer::resume()
{
    if (m_isPaused) {
        // Update the base time to include the elapsed time before pause
        m_baseTime = m_centiseconds;
        timer.restart();
        updateTimer.start();
        m_isPaused = false;
        emit isPausedChanged();
    }
}
