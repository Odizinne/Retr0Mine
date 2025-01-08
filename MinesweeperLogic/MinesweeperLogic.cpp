#include "MinesweeperLogic.h"
#include <QDebug>
#include <QQueue>

MinesweeperLogic::MinesweeperLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{
}

bool MinesweeperLogic::initializeGame(int width, int height, int mineCount) {
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
// MinesweeperLogic.cpp


bool MinesweeperLogic::trySolve(const QSet<int>& mines) {
    // Reset solver state
    m_information.clear();
    m_informationsForSpace.clear();
    m_solvedSpaces.clear();

    // Add initial information based on numbers
    for (int i = 0; i < m_width * m_height; i++) {
        if (mines.contains(i)) {
            m_solvedSpaces[i] = true; // Mark mines as known
            continue;
        }

        // Calculate number for this cell
        QSet<int> neighbors = getNeighbors(i);
        int mineCount = 0;
        for (int neighbor : neighbors) {
            if (mines.contains(neighbor)) {
                mineCount++;
            }
        }

        // Add as information if it has a number
        if (mineCount > 0) {
            MineSolverInfo info;
            info.spaces = neighbors;
            info.count = mineCount;
            m_information.insert(info);
            m_solvedSpaces[i] = false; // Mark revealed number as known safe

            for (int space : info.spaces) {
                m_informationsForSpace[space].insert(info);
            }
        }
    }

    try {
        solve();
        // Success if we solved all cells or found all mines
        int solvedCount = 0;
        int foundMines = 0;
        for (auto it = m_solvedSpaces.begin(); it != m_solvedSpaces.end(); ++it) {
            if (it.value()) foundMines++;
            solvedCount++;
        }

        qDebug() << "Solve attempt - Found mines:" << foundMines
                 << "Total solved:" << solvedCount
                 << "Expected mines:" << m_mineCount;

        // Configuration is valid if we found some solutions and they're consistent
        return solvedCount > 0 && foundMines == m_mineCount;
    }
    catch (...) {
        return false;
    }
}

void MinesweeperLogic::solve() {
    bool changed = true;
    while (changed) {
        changed = false;

        // Process each piece of information
        for (const MineSolverInfo& info : m_information) {
            // Count already solved spaces
            int knownMines = 0;
            int knownSafe = 0;
            QSet<int> unknownSpaces;

            for (int space : info.spaces) {
                if (m_solvedSpaces.contains(space)) {
                    if (m_solvedSpaces[space]) knownMines++;
                    else knownSafe++;
                } else {
                    unknownSpaces.insert(space);
                }
            }

            // Simple deductions
            if (info.count == knownMines) {
                // All remaining spaces must be safe
                for (int space : unknownSpaces) {
                    if (!m_solvedSpaces.contains(space)) {
                        m_solvedSpaces[space] = false;
                        changed = true;
                    }
                }
            }
            else if (info.count - knownMines == unknownSpaces.size()) {
                // All remaining spaces must be mines
                for (int space : unknownSpaces) {
                    if (!m_solvedSpaces.contains(space)) {
                        m_solvedSpaces[space] = true;
                        changed = true;
                    }
                }
            }
        }
    }
}

void MinesweeperLogic::calculateNumbers() {
    m_numbers.fill(0, m_width * m_height);

    for (int mine : m_mines) {
        m_numbers[mine] = -1;  // Mark mine positions

        // Update adjacent cell counts
        QSet<int> neighbors = getNeighbors(mine);
        for (int neighbor : neighbors) {
            if (m_numbers[neighbor] >= 0) {
                m_numbers[neighbor]++;
            }
        }
    }
}

bool MinesweeperLogic::placeMines(int firstClickX, int firstClickY) {
    const int firstClickPos = firstClickY * m_width + firstClickX;
    qDebug() << "Placing mines, first click at:" << firstClickPos;

    // Create safe zone around first click
    QSet<int> safeZone;
    int row = firstClickPos / m_width;
    int col = firstClickPos % m_width;

    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            int newRow = row + r;
            int newCol = col + c;
            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {
                safeZone.insert(newRow * m_width + newCol);
            }
        }
    }

    // Create list of available positions
    QVector<int> allPositions;
    for (int i = 0; i < m_width * m_height; i++) {
        if (!safeZone.contains(i)) {
            allPositions.append(i);
        }
    }

    // Try placing mines until we find a valid configuration
    int maxAttempts = 1000;
    int attemptCount = 0;

    while (maxAttempts--) {
        attemptCount++;    // Increment counter each attempt
        m_mines.clear();

        // Shuffle all positions
        QVector<int> positions = allPositions;
        for (int i = positions.size() - 1; i > 0; i--) {
            std::uniform_int_distribution<int> dist(0, i);
            int j = dist(m_rng);
            std::swap(positions[i], positions[j]);
        }

        // Try to place mines in shuffled order
        for (int pos : positions) {
            if (m_mines.size() >= m_mineCount) break;

            QSet<int> currentMines;
            for (int mine : m_mines) {
                currentMines.insert(mine);
            }

            if (canPlaceMineAt(currentMines, pos)) {
                m_mines.append(pos);
            }
        }

        if (m_mines.size() == m_mineCount) {
            calculateNumbers();

            // Convert m_mines to QSet for solver
            QSet<int> mineSet;
            for (int mine : m_mines) {
                mineSet.insert(mine);
            }

            if (trySolve(mineSet)) {
                qDebug() << "Successfully placed" << m_mineCount << "mines after" << attemptCount << "attempts";
                qDebug() << "Mine positions:" << m_mines;
                return true;
            }
            qDebug() << "Configuration not solvable, retrying...";
        } else {
            qDebug() << "Could only place" << m_mines.size() << "mines, retrying...";
        }
    }

    qDebug() << "Failed to generate valid mine configuration after" << maxAttempts << "attempts";
    return false;
}

bool MinesweeperLogic::canPlaceMineAt(const QSet<int>& mines, int pos) {
    // Get neighbors
    QSet<int> neighbors = getNeighbors(pos);

    // Count existing adjacent mines
    int adjacentMines = 0;
    for (int neighbor : neighbors) {
        if (mines.contains(neighbor)) {
            adjacentMines++;
        }
    }

    // Make the adjacent mine check less restrictive
    if (adjacentMines >= 4) return false; // Changed from 5 to 4

    // Simplify the 50/50 pattern check
    int unsafeNeighbors = 0;
    for (int neighbor : neighbors) {
        QSet<int> neighborNeighbors = getNeighbors(neighbor);
        if (neighborNeighbors.intersect(mines).size() >= 3) {
            unsafeNeighbors++;
        }
    }

    return unsafeNeighbors <= 2;
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
    QSet<int> relevantUnknowns;
    for (const QSet<int>& unknowns : constraints) {
        relevantUnknowns.unite(unknowns);
    }

    if (!relevantUnknowns.contains(testPos)) {
        return true;
    }

    int totalMinesNeeded = 0;
    int maxPossibleMines = relevantUnknowns.size();

    for (auto it = constraints.begin(); it != constraints.end(); ++it) {
        int pos = it.key();
        totalMinesNeeded += m_numbers[pos];
    }

    if (totalMinesNeeded > maxPossibleMines) {
        return false;
    }

    bool couldBeMine = false;
    bool couldBeSafe = false;

    // Try all possible mine combinations
    int totalUnknowns = relevantUnknowns.size();
    for (int i = 0; i < (1 << totalUnknowns); i++) {
        QSet<int> testMines = flagged;
        int bit = 0;

        // Build test configuration
        for (int pos : relevantUnknowns) {
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
                break;
            }
        }
    }

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

QSet<int> MinesweeperLogic::getNeighbors(int pos) const {
    QSet<int> neighbors;
    int row = pos / m_width;
    int col = pos % m_width;

    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {
                neighbors.insert(newRow * m_width + newCol);
            }
        }
    }

    return neighbors;
}
