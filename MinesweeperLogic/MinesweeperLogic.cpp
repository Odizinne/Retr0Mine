#include "MinesweeperLogic.h"
#include <QDebug>
#include <QQueue>

MinesweeperLogic::MinesweeperLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{
}

bool MinesweeperLogic::initializeGame(int width, int height, int mineCount)
{
    if (width <= 0 || height <= 0 || mineCount <= 0 || mineCount >= width * height) {
        return false;
    }

    m_width = width;
    m_height = height;
    m_mineCount = mineCount;
    m_mines.clear();
    m_numbers.resize(width * height);

    return true;
}

bool MinesweeperLogic::placeMines(int firstClickX, int firstClickY)
{
    const int firstClickPos = firstClickY * m_width + firstClickX;
    qDebug() << "Starting mine placement at position:" << firstClickPos
             << "(x:" << firstClickX << ", y:" << firstClickY << ")";
    qDebug() << "Grid size:" << m_width << "x" << m_height << "mines:" << m_mineCount;

    // Create grid representation
    std::vector<Cell> grid(m_width * m_height);
    for (int i = 0; i < m_width * m_height; ++i) {
        grid[i].pos = i;
        grid[i].isMine = false;
        grid[i].isRevealed = false;
        grid[i].adjacentMines = 0;

        // Pre-calculate neighbors for each cell
        int row = i / m_width;
        int col = i % m_width;
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    grid[i].neighbors.push_back(newRow * m_width + newCol);
                }
            }
        }
    }

    // Create safe zone around first click (3x3)
    const int firstClickRow = firstClickPos / m_width;
    const int firstClickCol = firstClickPos % m_width;
    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            int newRow = firstClickRow + r;
            int newCol = firstClickCol + c;

            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {
                int pos = newRow * m_width + newCol;
                grid[pos].isRevealed = true;
            }
        }
    }

    qDebug() << "Created safe zone around first click";

    // Collect boundary and available positions
    std::vector<int> boundary;
    std::vector<int> availablePositions;

    for (int i = 0; i < grid.size(); ++i) {
        if (!grid[i].isRevealed) {
            bool hasSafePath = false;
            for (int neighbor : grid[i].neighbors) {
                if (grid[neighbor].isRevealed) {
                    hasSafePath = true;
                    break;
                }
            }
            if (hasSafePath) {
                boundary.push_back(i);
            } else {
                availablePositions.push_back(i);
            }
        }
    }

    qDebug() << "Initial boundary size:" << boundary.size()
             << "available positions:" << availablePositions.size();

    // Place mines ensuring deducible patterns
    int minesPlaced = 0;
    int attempts = 0;
    const int maxAttempts = m_width * m_height * 2;

    while (minesPlaced < m_mineCount && attempts < maxAttempts) {
        attempts++;
        bool placedMine = false;

        if (!boundary.empty()) {
            std::uniform_int_distribution<int> dist(0, boundary.size() - 1);
            int index = dist(m_rng);
            int pos = boundary[index];

            if (canPlaceMineAt(grid, pos)) {
                grid[pos].isMine = true;
                minesPlaced++;
                placedMine = true;

                for (int neighbor : grid[pos].neighbors) {
                    grid[neighbor].adjacentMines++;
                }

                boundary.erase(boundary.begin() + index);
                qDebug() << "Placed mine at boundary position:" << pos
                         << "mines placed:" << minesPlaced;
            }
        }

        if (!placedMine && !availablePositions.empty()) {
            std::uniform_int_distribution<int> dist(0, availablePositions.size() - 1);
            int index = dist(m_rng);
            int pos = availablePositions[index];

            grid[pos].isMine = true;
            minesPlaced++;

            for (int neighbor : grid[pos].neighbors) {
                grid[neighbor].adjacentMines++;
            }

            availablePositions.erase(availablePositions.begin() + index);
            qDebug() << "Placed mine at available position:" << pos
                     << "mines placed:" << minesPlaced;
        }

        updateBoundary(grid, boundary, availablePositions);
    }

    if (minesPlaced < m_mineCount) {
        qDebug() << "Failed to place all mines! Only placed:" << minesPlaced;
        return false;
    }

    // Transfer final mine positions and calculate numbers
    m_mines.clear();
    for (const Cell& cell : grid) {
        if (cell.isMine) {
            m_mines.append(cell.pos);
        }
    }

    calculateNumbers();

    qDebug() << "Successfully placed all" << minesPlaced << "mines";
    qDebug() << "Mine positions:" << m_mines;
    return true;
}

void MinesweeperLogic::calculateNumbers()
{
    m_numbers.fill(0);

    qDebug() << "Calculating numbers for" << m_width * m_height << "cells";

    for (int i = 0; i < m_width * m_height; ++i) {
        if (m_mines.contains(i)) {
            m_numbers[i] = -1;
            continue;
        }

        int count = countAdjacentMines(i);
        m_numbers[i] = count;
    }

    qDebug() << "Numbers calculated:" << m_numbers;
}

int MinesweeperLogic::countAdjacentMines(int pos) const
{
    int row = pos / m_width;
    int col = pos % m_width;
    int count = 0;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow < 0 || newRow >= m_height ||
                newCol < 0 || newCol >= m_width) continue;

            int checkPos = newRow * m_width + newCol;
            if (m_mines.contains(checkPos)) count++;
        }
    }

    return count;
}

struct Cell {
    int pos;
    int adjacentMines;
    bool isMine;
    bool isRevealed;
    std::vector<int> neighbors;
};

bool MinesweeperLogic::canPlaceMineAt(const std::vector<Cell>& grid, int pos)
{
    // Check if placing a mine here would create a 50/50 pattern
    const Cell& cell = grid[pos];

    // Don't place if it would create too many adjacent mines
    for (int neighbor : cell.neighbors) {
        if (grid[neighbor].adjacentMines >= 5) return false;
    }

    // Check for potential 50/50 patterns
    for (int neighbor : cell.neighbors) {
        if (grid[neighbor].isRevealed) {
            // Count revealed neighbors that would have same number
            int sameNumberCount = 0;
            for (int n2 : grid[neighbor].neighbors) {
                if (grid[n2].isRevealed &&
                    grid[n2].adjacentMines == grid[neighbor].adjacentMines) {
                    sameNumberCount++;
                }
            }

            // If too many same numbers, might create ambiguous pattern
            if (sameNumberCount > 2) return false;
        }
    }

    return true;
}

void MinesweeperLogic::updateBoundary(const std::vector<Cell>& grid,
                                      std::vector<int>& boundary,
                                      std::vector<int>& availablePositions)
{
    // Find new boundary cells
    std::vector<int> newBoundary;
    for (int pos : availablePositions) {
        if (!grid[pos].isMine) {
            bool hasSafePath = false;
            bool hasRevealedNeighbor = false;

            for (int neighbor : grid[pos].neighbors) {
                if (grid[neighbor].isRevealed) {
                    hasRevealedNeighbor = true;
                    if (!grid[neighbor].isMine) {
                        hasSafePath = true;
                        break;
                    }
                }
            }

            if (hasRevealedNeighbor && hasSafePath) {
                newBoundary.push_back(pos);
            }
        }
    }

    // Update boundary with new cells
    boundary = std::move(newBoundary);

    // Remove boundary cells from available positions
    for (int pos : boundary) {
        auto it = std::find(availablePositions.begin(), availablePositions.end(), pos);
        if (it != availablePositions.end()) {
            availablePositions.erase(it);
        }
    }
}

QVector<int> MinesweeperLogic::calculateNumbersForValidation(const QVector<int>& mines) const
{
    QVector<int> numbers(m_width * m_height, 0);

    for (int i = 0; i < m_width * m_height; ++i) {
        if (mines.contains(i)) {
            numbers[i] = -1;
            continue;
        }

        int row = i / m_width;
        int col = i % m_width;
        int count = 0;

        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow < 0 || newRow >= m_height ||
                    newCol < 0 || newCol >= m_width) continue;

                int pos = newRow * m_width + newCol;
                if (mines.contains(pos)) count++;
            }
        }

        numbers[i] = count;
    }

    return numbers;
}

int MinesweeperLogic::findMineHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells)
{
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells) revealed.insert(cell);
    for (int cell : flaggedCells) flagged.insert(cell);

    // First try to find definite mines through basic logic
    QSet<int> logicalMines;
    QSet<int> logicalSafe;
    findBasicDeductions(revealed, flagged, logicalMines, logicalSafe);

    // If we found a definite mine, return it
    for (int pos : logicalMines) {
        if (!flagged.contains(pos)) {
            qDebug() << "Found logical mine at:" << pos;
            return pos;
        }
    }

    // Try to find a safe spot through exhaustive checking
    QSet<int> frontier = getFrontier(revealed, flagged);

    // Check each frontier cell until we find a safe one
    for (int testPos : frontier) {
        if (m_mines.contains(testPos)) {
            continue;  // Skip known mines regardless of logical deduction
        }

        QVector<QSet<int>> validConfigurations;
        QMap<int, QSet<int>> numberConstraints;

        buildConstraintsForCell(testPos, revealed, flagged, numberConstraints);

        if (!tryAllCombinations(numberConstraints, testPos, flagged, validConfigurations)) {
            qDebug() << "Found definite safe cell at" << testPos;
            return testPos;
        }
    }

    // Last resort - use actual mine positions
    qDebug() << "WARNING: No logical deductions possible, using actual mine positions";
    for (int pos : m_mines) {
        if (!flagged.contains(pos)) return pos;
    }

    return -1;
}

QSet<int> MinesweeperLogic::findSafeThroughExhaustiveCheck(const QSet<int>& revealed,
                                                           const QSet<int>& flagged,
                                                           const QSet<int>& frontier)
{
    QSet<int> safeCells;
    QMap<int, QSet<int>> numberConstraints; // For each revealed number, its unknown neighbors

    // Build constraints for each revealed number
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> unknownNeighbors;
        int flagCount = 0;
        getNeighborInfo(pos, flagged, frontier, unknownNeighbors, flagCount);

        if (!unknownNeighbors.isEmpty()) {
            numberConstraints[pos] = unknownNeighbors;
        }
    }

    // Check each frontier cell if it could be safe
    for (int testPos : frontier) {
        bool mustBeMine = false;
        bool mustBeSafe = false;

        // Try both possibilities for this cell
        QVector<QSet<int>> validConfigurations;
        if (tryAllCombinations(numberConstraints, testPos, flagged, validConfigurations)) {
            // If we found valid configurations where this cell is both mine and not mine,
            // we can't determine anything
            qDebug() << "Cell" << testPos << "could be either mine or safe";
        } else {
            // If we only found configurations with this cell as safe, it must be safe
            safeCells.insert(testPos);
            qDebug() << "Found definite safe cell at" << testPos;
        }
    }

    return safeCells;
}

bool MinesweeperLogic::tryAllCombinations(const QMap<int, QSet<int>>& constraints,
                                          int testPos,
                                          const QSet<int>& flagged,
                                          QVector<QSet<int>>& validConfigurations)
{
    QSet<int> allUnknowns;
    for (const QSet<int>& unknowns : constraints) {
        allUnknowns.unite(unknowns);
    }

    bool couldBeMine = false;
    bool couldBeSafe = false;

    // Try all possible mine combinations
    int totalUnknowns = allUnknowns.size();
    for (int i = 0; i < (1 << totalUnknowns); i++) {
        QSet<int> testMines = flagged;
        int bit = 0;

        // Build test configuration
        for (int pos : allUnknowns) {
            if (i & (1 << bit)) {
                testMines.insert(pos);
            }
            bit++;
        }

        // Check if this configuration satisfies all constraints
        bool valid = true;
        for (auto it = constraints.begin(); it != constraints.end(); ++it) {
            int pos = it.key();
            const QSet<int>& unknowns = it.value();

            int mineCount = 0;
            for (int neighbor : unknowns) {
                if (testMines.contains(neighbor)) mineCount++;
            }

            if (mineCount != m_numbers[pos]) {
                valid = false;
                break;
            }
        }

        if (valid) {
            if (testMines.contains(testPos)) {
                couldBeMine = true;
            } else {
                couldBeSafe = true;
            }

            if (couldBeMine && couldBeSafe) {
                break;  // Cell could be either, no need to check further
            }
        }
    }

    // Return true if cell could be either mine or safe
    // Return false only if cell MUST be safe
    return couldBeMine;
}

void MinesweeperLogic::findBasicDeductions(const QSet<int>& revealed,
                                           const QSet<int>& flagged,
                                           QSet<int>& logicalMines,
                                           QSet<int>& logicalSafe)
{
    // First pass: find satisfied numbers and their implications
    QSet<int> satisfiedNumbers;
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> unknownNeighbors;
        int flagCount = 0;
        getNeighborInfo(pos, flagged, getFrontier(revealed, flagged), unknownNeighbors, flagCount);

        // If number is satisfied by flags, all other unknowns are safe
        if (m_numbers[pos] == flagCount) {
            logicalSafe.unite(unknownNeighbors);
            satisfiedNumbers.insert(pos);
        }
        // If remaining mines equals remaining unknowns, all unknowns are mines
        else if (m_numbers[pos] - flagCount == unknownNeighbors.size()) {
            logicalMines.unite(unknownNeighbors);
        }
    }

    // Second pass: propagate implications from satisfied numbers
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> unknownNeighbors;
        int flagCount = 0;
        getNeighborInfo(pos, flagged, getFrontier(revealed, flagged), unknownNeighbors, flagCount);

        // Check neighbors of this number
        int row = pos / m_width;
        int col = pos % m_width;

        bool hasAdjacentSatisfied = false;
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {

                    int adjPos = newRow * m_width + newCol;
                    if (satisfiedNumbers.contains(adjPos)) {
                        hasAdjacentSatisfied = true;
                        break;
                    }
                }
            }
        }

        // If this number shares area with a satisfied number,
        // we can deduce more information
        if (hasAdjacentSatisfied) {
            // Re-check this number's constraints considering satisfied neighbors
            QSet<int> sharedWithSatisfied;
            for (int unknown : unknownNeighbors) {
                // Check if this unknown is adjacent to a satisfied number
                int uRow = unknown / m_width;
                int uCol = unknown % m_width;

                for (int r = -1; r <= 1; ++r) {
                    for (int c = -1; c <= 1; ++c) {
                        int checkRow = uRow + r;
                        int checkCol = uCol + c;

                        if (checkRow >= 0 && checkRow < m_height &&
                            checkCol >= 0 && checkCol < m_width) {

                            int checkPos = checkRow * m_width + checkCol;
                            if (satisfiedNumbers.contains(checkPos)) {
                                sharedWithSatisfied.insert(unknown);
                                break;
                            }
                        }
                    }
                }
            }

            // These cells must be safe as they're shared with satisfied numbers
            logicalSafe.unite(sharedWithSatisfied);

            // Recalculate constraints for remaining unknowns
            unknownNeighbors.subtract(sharedWithSatisfied);
            if (m_numbers[pos] - flagCount == unknownNeighbors.size()) {
                logicalMines.unite(unknownNeighbors);
            }
        }
    }
}

QSet<int> MinesweeperLogic::getFrontier(const QSet<int>& revealed, const QSet<int>& flagged)
{
    QSet<int> frontier;

    // For each revealed cell
    for (int pos : revealed) {
        int row = pos / m_width;
        int col = pos % m_width;

        // Check all neighbors
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    int neighborPos = newRow * m_width + newCol;

                    // Add to frontier if not revealed and not flagged
                    if (!revealed.contains(neighborPos) && !flagged.contains(neighborPos)) {
                        frontier.insert(neighborPos);
                    }
                }
            }
        }
    }

    return frontier;
}

void MinesweeperLogic::getNeighborInfo(int pos,
                                       const QSet<int>& flagged,
                                       const QSet<int>& frontier,
                                       QSet<int>& unknownNeighbors,
                                       int& flagCount)
{
    int row = pos / m_width;
    int col = pos % m_width;

    flagCount = 0;
    unknownNeighbors.clear();

    // Check all neighbors
    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {
                int neighborPos = newRow * m_width + newCol;

                if (flagged.contains(neighborPos)) {
                    flagCount++;
                } else if (frontier.contains(neighborPos)) {
                    unknownNeighbors.insert(neighborPos);
                }
            }
        }
    }
}

void MinesweeperLogic::buildConstraintsForCell(int pos,
                                               const QSet<int>& revealed,
                                               const QSet<int>& flagged,
                                               QMap<int, QSet<int>>& numberConstraints)
{
    QSet<int> relevantCells;
    QQueue<int> toProcess;
    toProcess.enqueue(pos);

    // Do a breadth-first search to find all relevant revealed numbers
    while (!toProcess.isEmpty()) {
        int currentPos = toProcess.dequeue();
        if (relevantCells.contains(currentPos)) continue;
        relevantCells.insert(currentPos);

        int row = currentPos / m_width;
        int col = currentPos % m_width;

        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    int neighborPos = newRow * m_width + newCol;

                    if (revealed.contains(neighborPos) && m_numbers[neighborPos] > 0) {
                        QSet<int> unknownNeighbors;
                        int flagCount = 0;
                        getNeighborInfo(neighborPos, flagged, getFrontier(revealed, flagged),
                                        unknownNeighbors, flagCount);

                        if (!unknownNeighbors.isEmpty()) {
                            numberConstraints[neighborPos] = unknownNeighbors;
                            // Add unknown neighbors to process queue to find connected constraints
                            for (int unknown : unknownNeighbors) {
                                toProcess.enqueue(unknown);
                            }
                        }
                    }
                }
            }
        }
    }
}
