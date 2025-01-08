#ifndef MINESWEEPERLOGIC_H
#define MINESWEEPERLOGIC_H

#include <QObject>
#include <QVector>
#include <QSet>
#include <QMap>
#include <random>

struct MineSolverInfo {
    QSet<int> spaces;
    int count;

    bool operator==(const MineSolverInfo& other) const {
        return spaces == other.spaces && count == other.count;
    }
};

inline uint qHash(const MineSolverInfo& info, uint seed = 0) {
    uint hashValue = qHash(info.count, seed);
    for (int space : info.spaces) {
        hashValue ^= qHash(space, seed);
    }
    return hashValue;
}

class MinesweeperLogic : public QObject {
    Q_OBJECT

public:
    struct Cell {
        int index;
        bool isMine;
        bool isRevealed;
        int adjacentMines;
        QSet<int> neighbors;
    };

    explicit MinesweeperLogic(QObject *parent = nullptr);

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool placeMines(int firstClickX, int firstClickY);
    Q_INVOKABLE int findMineHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells);

    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }

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

    bool canPlaceMineAt(const QSet<int>& mines, int pos);
    QSet<int> getNeighbors(int pos) const;
    void calculateNumbers();
    bool trySolve(const QSet<int>& mines);
    void solve();

    // Helper methods for mine hints
    void findBasicDeductions(const QSet<int>& revealed,
                             const QSet<int>& flagged,
                             QSet<int>& logicalMines,
                             QSet<int>& logicalSafe);

    QSet<int> getFrontier(const QSet<int>& revealed, const QSet<int>& flagged);

    void getNeighborInfo(int pos,
                         const QSet<int>& flagged,
                         const QSet<int>& frontier,
                         QSet<int>& unknownNeighbors,
                         int& flagCount);

    void buildConstraintsForCell(int pos,
                                 const QSet<int>& revealed,
                                 const QSet<int>& flagged,
                                 QMap<int, QSet<int>>& numberConstraints);

    QSet<int> findSafeThroughExhaustiveCheck(const QSet<int>& revealed,
                                             const QSet<int>& flagged,
                                             const QSet<int>& frontier);

    bool tryAllCombinations(const QMap<int, QSet<int>>& constraints,
                            int testPos,
                            const QSet<int>& flagged,
                            QVector<QSet<int>>& validConfigurations);

    int solveForHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells);
};

#endif // MINESWEEPERLOGIC_H
