#ifndef GAMELOGIC_H
#define GAMELOGIC_H
#include <QMap>
#include <QObject>
#include <QSet>
#include <QVector>
#include <QQmlEngine>
#include <QFuture>
#include <QtConcurrent>
#include <random>

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

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool initializeFromSave(int width, int height, int mineCount, const QVector<int> &mines);
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }
    Q_INVOKABLE bool generateBoard(int firstClickX, int firstClickY);
    Q_INVOKABLE int findMineHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);

    Q_INVOKABLE void generateBoardAsync(int firstClickX, int firstClickY);

signals:
    void boardGenerationCompleted(bool success);

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
    QSet<int> getNeighbors(int pos) const;
    void calculateNumbers();
    int solveForHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
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

#endif // GAMELOGIC_H
