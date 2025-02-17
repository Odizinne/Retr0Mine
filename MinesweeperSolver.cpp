#include "MinesweeperSolver.h"
#include <QDebug>

bool MinesweeperSolver::validateGrid(const QVector<int>& numbers, int width, int height)
{
    m_width = width;
    m_height = height;
    m_safeMoves.clear();
    m_grid.resize(width * height);

    // Initialize grid with ONLY the numbers, no mine information
    for (int i = 0; i < m_grid.size(); i++) {
        m_grid[i].number = numbers[i];
        m_grid[i].isMine = false;  // We don't know this anymore
        m_grid[i].isKnown = false;
    }

    bool progress;
    do {
        progress = false;

        for (int pos = 0; pos < m_grid.size(); pos++) {
            if (solveSingleCell(pos)) {
                progress = true;
            }
            if (solvePattern(pos)) {
                progress = true;
            }
            if (solveTanking(pos)) {
                progress = true;
            }
        }
    } while (progress);

    // Check if we managed to determine the state of all cells
    for (int i = 0; i < m_grid.size(); i++) {
        if (!m_grid[i].isKnown) {
            return false;  // If any cell remains unknown, the puzzle isn't logically solvable
        }
    }

    return true;
}
bool MinesweeperSolver::solveSingleCell(int pos)
{
    if (m_grid[pos].isKnown || m_grid[pos].isMine) {
        return false;
    }

    QSet<int> neighbors = getNeighbors(pos);
    int number = m_grid[pos].number;

    if (number == 0) {
        // If cell is 0, all neighbors are safe
        for (int neighbor : neighbors) {
            if (!m_grid[neighbor].isKnown && !m_grid[neighbor].isMine) {
                m_grid[neighbor].isKnown = true;
                m_safeMoves.insert(neighbor);
                return true;
            }
        }
    }

    // Count known mines and unknown cells around
    int knownMines = 0;
    int unknownCells = 0;
    for (int neighbor : neighbors) {
        if (m_grid[neighbor].isMine) {
            knownMines++;
        }
        else if (!m_grid[neighbor].isKnown) {
            unknownCells++;
        }
    }

    if (knownMines == number) {
        // All remaining unknown cells must be safe
        bool found = false;
        for (int neighbor : neighbors) {
            if (!m_grid[neighbor].isKnown && !m_grid[neighbor].isMine) {
                m_grid[neighbor].isKnown = true;
                m_safeMoves.insert(neighbor);
                found = true;
            }
        }
        return found;
    }

    // If remaining mines equals remaining unknown cells, they must all be mines
    if (unknownCells == number - knownMines) {
        bool found = false;
        for (int neighbor : neighbors) {
            if (!m_grid[neighbor].isKnown && !m_grid[neighbor].isMine) {
                m_grid[neighbor].isMine = true;
                m_grid[neighbor].isKnown = true;
                found = true;
            }
        }
        return found;
    }

    return false;
}

QSet<int> MinesweeperSolver::getNeighbors(int pos) const
{
    QSet<int> neighbors;
    int row = pos / m_width;
    int col = pos % m_width;

    for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;

            int newRow = row + dr;
            int newCol = col + dc;

            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {
                neighbors.insert(newRow * m_width + newCol);
            }
        }
    }
    return neighbors;
}

bool MinesweeperSolver::solvePattern(int pos)
{
    if (m_grid[pos].isKnown || m_grid[pos].isMine) {
        return false;
    }

    QSet<int> neighbors = getNeighbors(pos);

    // Find adjacent numbered cells
    QVector<int> adjacentNumbers;
    for (int neighbor : neighbors) {
        if (!m_grid[neighbor].isMine && m_grid[neighbor].number > 0) {
            adjacentNumbers.append(neighbor);
        }
    }

    // 1-1 pattern
    for (int num1 : adjacentNumbers) {
        for (int num2 : adjacentNumbers) {
            if (num1 == num2) continue;

            if (m_grid[num1].number == 1 && m_grid[num2].number == 1) {
                QSet<int> shared = getNeighbors(num1).intersect(getNeighbors(num2));
                if (shared.size() == 1) {
                    int sharedCell = *shared.begin();
                    if (!m_grid[sharedCell].isKnown) {
                        m_grid[sharedCell].isMine = true;
                        m_grid[sharedCell].isKnown = true;
                        return true;
                    }
                }
            }
        }
    }

    // 1-2-1 pattern
    for (int num1 : adjacentNumbers) {
        if (m_grid[num1].number != 2) continue;

        QSet<int> num1Neighbors = getNeighbors(num1);
        QVector<int> ones;

        for (int neighbor : num1Neighbors) {
            if (!m_grid[neighbor].isMine && m_grid[neighbor].number == 1) {
                ones.append(neighbor);
            }
        }

        if (ones.size() == 2) {
            QSet<int> shared = getNeighbors(ones[0]).intersect(getNeighbors(ones[1]));
            if (shared.size() == 2 && shared.contains(num1)) {
                bool progress = false;
                for (int neighbor : num1Neighbors) {
                    if (!shared.contains(neighbor) && !m_grid[neighbor].isKnown) {
                        m_grid[neighbor].isKnown = true;
                        m_safeMoves.insert(neighbor);
                        progress = true;
                    }
                }
                if (progress) return true;
            }
        }
    }

    return false;
}

bool MinesweeperSolver::solveTanking(int pos)
{
    if (m_grid[pos].isKnown || m_grid[pos].isMine) {
        return false;
    }

    // Get all numbered cells in a 3x3 area around pos
    QSet<int> area;
    int row = pos / m_width;
    int col = pos % m_width;

    for (int r = row - 1; r <= row + 1; r++) {
        for (int c = col - 1; c <= col + 1; c++) {
            if (r >= 0 && r < m_height && c >= 0 && c < m_width) {
                int cellPos = r * m_width + c;
                if (!m_grid[cellPos].isMine && m_grid[cellPos].number > 0) {
                    area.insert(cellPos);
                }
            }
        }
    }

    // Build equation system for the area
    QVector<QSet<int>> equations;
    QVector<int> remainingMines;

    for (int cell : area) {
        QSet<int> unknownNeighbors;
        int remainingMineCount = m_grid[cell].number;

        for (int neighbor : getNeighbors(cell)) {
            if (m_grid[neighbor].isMine) {
                remainingMineCount--;
            }
            else if (!m_grid[neighbor].isKnown) {
                unknownNeighbors.insert(neighbor);
            }
        }

        if (!unknownNeighbors.isEmpty()) {
            equations.append(unknownNeighbors);
            remainingMines.append(remainingMineCount);
        }
    }

    // Solve the equation system using subset comparison
    for (int i = 0; i < equations.size(); i++) {
        for (int j = 0; j < equations.size(); j++) {
            if (i == j) continue;

            if (equations[i].contains(equations[j])) {
                QSet<int> diff = equations[i].subtract(equations[j]);
                int mineDiff = remainingMines[i] - remainingMines[j];

                if (mineDiff == 0 && !diff.isEmpty()) {
                    // All cells in diff must be safe
                    bool progress = false;
                    for (int cell : diff) {
                        if (!m_grid[cell].isKnown) {
                            m_grid[cell].isKnown = true;
                            m_safeMoves.insert(cell);
                            progress = true;
                        }
                    }
                    if (progress) return true;
                }
                else if (mineDiff == diff.size() && !diff.isEmpty()) {
                    // All cells in diff must be mines
                    bool progress = false;
                    for (int cell : diff) {
                        if (!m_grid[cell].isKnown) {
                            m_grid[cell].isMine = true;
                            m_grid[cell].isKnown = true;
                            progress = true;
                        }
                    }
                    if (progress) return true;
                }
            }
        }
    }

    return false;
}

int MinesweeperSolver::findHint(const QVector<int>& numbers,
                                const QVector<int>& revealedCells,
                                const QVector<int>& flaggedCells,
                                int width,
                                int height)
{
    m_width = width;
    m_height = height;
    m_grid.resize(numbers.size());
    m_safeMoves.clear();

    // Initialize with current game state
    for (int i = 0; i < m_grid.size(); i++) {
        m_grid[i].number = numbers[i];
        m_grid[i].isKnown = revealedCells.contains(i);
        m_grid[i].isFlagged = flaggedCells.contains(i);
    }

    // 1. First priority: obvious unflagged mines
    for (int pos = 0; pos < m_grid.size(); pos++) {
        if (!revealedCells.contains(pos) || numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int remainingMines = numbers[pos];
        int unknownCells = 0;
        QSet<int> unknownPositions;

        for (int neighbor : neighbors) {
            if (flaggedCells.contains(neighbor)) {
                remainingMines--;
            }
            else if (!revealedCells.contains(neighbor)) {
                unknownCells++;
                unknownPositions.insert(neighbor);
            }
        }

        if (unknownCells > 0 && remainingMines == unknownCells) {
            // Find first unflagged mine position
            for (int cell : unknownPositions) {
                if (!flaggedCells.contains(cell)) {
                    return cell;
                }
            }
        }
    }

    // 2. Second priority: obvious safe cells around completed numbers
    for (int pos = 0; pos < m_grid.size(); pos++) {
        if (!revealedCells.contains(pos) || numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int flagCount = 0;
        QSet<int> unknownCells;

        for (int neighbor : neighbors) {
            if (flaggedCells.contains(neighbor)) {
                flagCount++;
            }
            else if (!revealedCells.contains(neighbor)) {
                unknownCells.insert(neighbor);
            }
        }

        if (flagCount == numbers[pos] && !unknownCells.isEmpty()) {
            // Find first unrevealed and unflagged cell
            for (int cell : unknownCells) {
                if (!flaggedCells.contains(cell) && !revealedCells.contains(cell)) {
                    return cell;
                }
            }
        }
    }

    // 3. Last priority: more complex solving techniques
    for (int pos = 0; pos < m_grid.size(); pos++) {
        if (solveSingleCell(pos) || solvePattern(pos) || solveTanking(pos)) {
            if (!m_safeMoves.isEmpty()) {
                // Find first safe move that isn't flagged or revealed
                for (int move : m_safeMoves) {
                    if (!flaggedCells.contains(move) && !revealedCells.contains(move)) {
                        return move;
                    }
                }
            }
        }
    }

    return -1;
}
