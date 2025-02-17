#ifndef MINESWEEPERSOLVER_H
#define MINESWEEPERSOLVER_H

#include <QVector>
#include <QSet>

class MinesweeperSolver {
public:
    MinesweeperSolver() = default;

    // Main solving function - returns true if grid is solvable without guessing
    bool validateGrid(const QVector<int>& numbers, int width, int height);

    // Returns cells that are guaranteed to be safe
    QSet<int> getSafeMoves() const { return m_safeMoves; }
    int findHint(const QVector<int>& numbers,
                 const QVector<int>& revealedCells,
                 const QVector<int>& flaggedCells,
                 int width,
                 int height);
private:
    struct Cell {
        bool isMine = false;
        bool isKnown = false;
        bool isFlagged = false;
        int number = 0;
    };

    int m_width = 0;
    int m_height = 0;
    QVector<Cell> m_grid;
    QSet<int> m_safeMoves;

    bool solveSingleCell(int pos);
    bool solvePattern(int pos);
    bool solveTanking(int pos);
    QSet<int> getNeighbors(int pos) const;
};

#endif // MINESWEEPERSOLVER_H
