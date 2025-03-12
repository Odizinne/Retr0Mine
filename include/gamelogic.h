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

struct MineSolverInfo
{
    QSet<int> spaces;
    int count;
    bool operator==(const MineSolverInfo &other) const
    {
        return spaces == other.spaces && count == other.count;
    }
};

inline size_t qHash(const MineSolverInfo &info, size_t seed = 0)
{
    size_t hashValue = qHash(info.count, seed);
    for (int space : info.spaces) {
        hashValue ^= qHash(space, seed);
    }
    return hashValue;
}

class GameLogic : public QObject
{
    Q_OBJECT
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

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool initializeFromSave(int width, int height, int mineCount, const QVector<int> &mines);
    Q_INVOKABLE QVector<int> calculateNumbersFromMines(int width, int height, const QVector<int> &mines);
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }
    Q_INVOKABLE int findMineHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
    Q_INVOKABLE void generateBoardAsync(int firstClickX, int firstClickY);
    Q_INVOKABLE QVariantMap findMineHintWithReasoning(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
    Q_INVOKABLE void cancelGeneration();

    // Progress information accessors
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
    QSet<MineSolverInfo> m_information;
    QMap<int, QSet<MineSolverInfo>> m_informationsForSpace;
    QMap<int, bool> m_solvedSpaces;
    std::atomic<bool> m_cancelGeneration;
    QFutureWatcher<void>* m_generationWatcher;

    // Progress tracking
    std::atomic<int> m_currentAttempt;
    std::atomic<int> m_totalAttempts;
    std::atomic<int> m_minesPlaced;

    QSet<int> getNeighbors(int pos) const;
    void calculateNumbers();
    int solveForHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
    void updateProgress(int attempt, int totalAttempts, int minesPlaced);
    bool generateBoard(int firstClickX, int firstClickY);

    struct Constraint {
        int cell;              // The boundary cell
        int minesRequired;     // Number of mines required around this cell
        QSet<int> unknowns;    // Unknown cells around this cell
    };

    int solveFrontierCSP(const QVector<Constraint> &constraints, const QList<int> &frontier);
    int solveWithConstraintIntersection(const QVector<Constraint> &constraints, const QList<int> &frontier);
};

struct GameLogicForeign
{
    Q_GADGET
    QML_FOREIGN(GameLogic)
    QML_SINGLETON
    QML_NAMED_ELEMENT(GameLogic)
public:
    inline static GameLogic* s_singletonInstance = nullptr;
    inline static QJSEngine* s_engine = nullptr;

    static GameLogic* create(QQmlEngine*, QJSEngine* engine)
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
