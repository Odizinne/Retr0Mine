// include/gamelogic.h
#pragma once

#include <QMap>
#include <QObject>
#include <QSet>
#include <QVector>
#include <QQmlEngine>
#include <QFuture>
#include <QFutureWatcher>
#include <QtConcurrent>
#include <random>
#include <atomic>
#include "gridgenerator.h"
#include "minesweepersolver.h"

struct SolverResult;

class GameLogic : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT
    Q_PROPERTY(int currentAttempt READ currentAttempt NOTIFY currentAttemptChanged)
    Q_PROPERTY(int totalAttempts READ totalAttempts NOTIFY totalAttemptsChanged)
    Q_PROPERTY(int minesPlaced READ minesPlaced NOTIFY minesPlacedChanged)
    Q_PROPERTY(int totalMines READ totalMines NOTIFY totalMinesChanged)

public:
    struct Cell
    {
        int index;
        bool isMine;
        bool isRevealed;
        int adjacentMines;
        QSet<int> neighbors;
    };

    explicit GameLogic(QObject *parent = nullptr);
    ~GameLogic() override;

    static GameLogic* create(QQmlEngine* engine, QJSEngine* jsEngine) {
        Q_UNUSED(engine)
        Q_UNUSED(jsEngine)

        static GameLogic* instance = new GameLogic();
        QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
        return instance;
    }

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool initializeFromSave(int width, int height, int mineCount, const QVector<int> &mines);
    Q_INVOKABLE QVector<int> calculateNumbersFromMines(int width, int height, const QVector<int> &mines);
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }
    Q_INVOKABLE void generateBoardAsync(int firstClickX, int firstClickY);
    Q_INVOKABLE QVariantMap findMineHintWithReasoning(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
    Q_INVOKABLE void cancelGeneration();

    int currentAttempt() const { return m_currentAttempt; }
    int totalAttempts() const { return m_totalAttempts; }
    int minesPlaced() const { return m_minesPlaced; }
    int totalMines() const { return m_mineCount; }

signals:
    void boardGenerationCompleted(bool success);
    void currentAttemptChanged();
    void totalAttemptsChanged();
    void minesPlacedChanged();
    void totalMinesChanged();

private:
    int m_width;
    int m_height;
    int m_mineCount;
    QVector<int> m_mines;
    QVector<int> m_numbers;
    std::mt19937 m_rng;
    QMap<int, bool> m_solvedSpaces;
    std::atomic<bool> m_cancelGeneration;
    QFutureWatcher<void>* m_generationWatcher;
    GridGenerator* m_gridGenerator;
    MinesweeperSolver* m_solver;

    std::atomic<int> m_currentAttempt;
    std::atomic<int> m_totalAttempts;
    std::atomic<int> m_minesPlaced;

    QSet<int> getNeighbors(int pos) const;
    void calculateNumbers();
    void updateProgress(int attempt, int totalAttempts, int minesPlaced);
};
