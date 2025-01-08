#ifndef MINESWEEPERLOGIC_H
#define MINESWEEPERLOGIC_H

#include <QObject>
#include <QVector>
#include <QSet>
#include <random>

class MinesweeperLogic : public QObject
{
    Q_OBJECT

public:
    explicit MinesweeperLogic(QObject *parent = nullptr);

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool placeMines(int firstClickX, int firstClickY);
    Q_INVOKABLE int findMineHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells);

    // Add getters for QML
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }

private:
    struct Cell {
        int pos;
        int adjacentMines;
        bool isMine;
        bool isRevealed;
        std::vector<int> neighbors;
    };

    struct NeighborInfo {
        QSet<int> neighbors;
        bool calculated = false;
    };
    QVector<NeighborInfo> m_neighborCache;
    QSet<int> getNeighbors(int pos);

    void calculateNumbers();
    int countAdjacentMines(int pos) const;

    // Helper functions for mine placement
    bool canPlaceMineAt(const std::vector<Cell>& grid, int pos);
    void updateBoundary(const std::vector<Cell>& grid,
                        std::vector<int>& boundary,
                        std::vector<int>& availablePositions);

    void findBasicDeductions(const QSet<int>& revealed,
                                  const QSet<int>& flagged,
                                  QSet<int>& logicalMines,
                                  QSet<int>& logicalSafe);

    QVector<int> calculateNumbersForValidation(const QVector<int>& mines) const;

    QSet<int> findSafeThroughExhaustiveCheck(const QSet<int>& revealed,
                                   const QSet<int>& flagged,
                                             const QSet<int>& frontier);

    bool tryAllCombinations(const QMap<int, QSet<int>>& constraints,
                            int testPos,
                            const QSet<int>& flagged,
                            QVector<QSet<int>>& validConfigurations);

    void getNeighborInfo(int pos,
                         const QSet<int>& flagged,
                         const QSet<int>& frontier,
                         QSet<int>& unknownNeighbors,
                         int& flagCount);

    QSet<int> getFrontier(const QSet<int>& revealed, const QSet<int>& flagged);


    void buildConstraintsForCell(int pos,
                                 const QSet<int>& revealed,
                                 const QSet<int>& flagged,
                                 QMap<int, QSet<int>>& numberConstraints);

    // Member variables
    int m_width;
    int m_height;
    int m_mineCount;
    QVector<int> m_mines;
    QVector<int> m_numbers;
    std::mt19937 m_rng;

    // Add Cell struct definition

};

#endif // MINESWEEPERLOGIC_H
