#include "GameTimer.h"

GameTimer::GameTimer(QObject *parent) : QObject(parent), m_centiseconds(0), m_baseTime(0) {
    connect(&updateTimer, &QTimer::timeout, this, [this]() {
        m_centiseconds = m_baseTime + (timer.elapsed() / 10);
        emit centisecondsChanged();
    });
    updateTimer.setInterval(10);
}

qint64 GameTimer::centiseconds() const {
    return m_centiseconds;
}

void GameTimer::setCentiseconds(qint64 value) {
    if (m_centiseconds != value) {
        m_centiseconds = value;
        emit centisecondsChanged();
    }
}

void GameTimer::start() {
    timer.start();
    updateTimer.start();
}

void GameTimer::stop() {
    updateTimer.stop();
}

void GameTimer::reset() {
    stop();
    m_baseTime = 0;
    m_centiseconds = 0;
    emit centisecondsChanged();
}

void GameTimer::resumeFrom(qint64 centiseconds) {
    stop();
    m_baseTime = centiseconds;
    m_centiseconds = centiseconds;
    timer.start();
    updateTimer.start();
    emit centisecondsChanged();
}
