#ifndef MINESWEEPERLOGIC_H
#define MINESWEEPERLOGIC_H

#include <QMap>
#include <QObject>
#include <QSet>
#include <QVector>
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

class MinesweeperLogic : public QObject
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

    explicit MinesweeperLogic(QObject *parent = nullptr);

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool placeMines(int firstClickX, int firstClickY);
    Q_INVOKABLE int findMineHint(const QVector<int> &revealedCells,
                                 const QVector<int> &flaggedCells);
    Q_INVOKABLE bool initializeFromSave(int width,
                                        int height,
                                        int mineCount,
                                        const QVector<int> &mines);

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

    bool canPlaceMineAt(const QSet<int> &mines, int pos);
    QSet<int> getNeighbors(int pos) const;
    void calculateNumbers();

    int solveForHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells);
    bool isValidDensity(const QSet<int> &mines, int pos);
    bool wouldCreate5050(const QSet<int> &mines, int newMinePos, int checkRow, int checkCol);
    void printGrid(const QSet<int> &currentMines);
    bool isValidGrid(const QSet<int> &currentMines);
    bool hasAmbiguousMinePlacement(const QSet<int> &currentMines);
    bool isAmbiguous(int pos,
                     int number,
                     const QSet<int> &unknownCells,
                     const QSet<int> &currentMines);
    bool satisfiesNumber(int number, const QSet<int> &placement, const QSet<int> &currentMines);
};

#endif // MINESWEEPERLOGIC_H
