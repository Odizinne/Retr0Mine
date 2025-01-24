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
        // Count solved spaces and mines
        int solvedCount = 0;
        int foundMines = 0;
        for (auto it = m_solvedSpaces.begin(); it != m_solvedSpaces.end(); ++it) {
            if (it.value()) foundMines++;
            solvedCount++;
        }

        // If we found all mines, mark remaining cells as safe
        if (foundMines == m_mineCount) {
            for (int i = 0; i < m_width * m_height; i++) {
                if (!m_solvedSpaces.contains(i)) {
                    m_solvedSpaces[i] = false;
                    solvedCount++;
                }
            }
        }

        qDebug() << "Solve attempt - Found mines:" << foundMines
                 << "Total solved:" << solvedCount
                 << "Expected mines:" << m_mineCount;

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
            QSet<int> unknownSpaces;

            for (int space : info.spaces) {
                if (m_solvedSpaces.contains(space)) {
                    if (m_solvedSpaces[space]) knownMines++;
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

    // Adjust safe zone size based on board size
    int safeRadius = 1;  // Default for 9x9
    if (m_width >= 30) safeRadius = 2;  // For largest board
    else if (m_width >= 16) safeRadius = 1;  // Keep default for medium

    // Create safe zone around first click
    QSet<int> safeZone;
    int row = firstClickPos / m_width;
    int col = firstClickPos % m_width;

    for (int r = -safeRadius; r <= safeRadius; r++) {
        for (int c = -safeRadius; c <= safeRadius; c++) {
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

    // Adjust maximum attempts based on board size
    int maxAttempts = 1000;
    if (m_width >= 30) maxAttempts = 2000;
    else if (m_width >= 16) maxAttempts = 1500;

    int attemptCount = 0;

    while (maxAttempts--) {
        attemptCount++;
        m_mines.clear();

        // Shuffle all positions
        QVector<int> positions = allPositions;
        for (int i = positions.size() - 1; i > 0; i--) {
            std::uniform_int_distribution<int> dist(0, i);
            int j = dist(m_rng);
            std::swap(positions[i], positions[j]);
        }

        // Try to place mines in shuffled order
        QSet<int> currentMines;  // Keep track of placed mines in a set for faster lookups

        for (int pos : positions) {
            if (currentMines.size() >= m_mineCount) break;

            if (canPlaceMineAt(currentMines, pos)) {
                currentMines.insert(pos);
                m_mines.append(pos);
            }
        }

        if (currentMines.size() == m_mineCount) {
            calculateNumbers();

            // First quick check: ensure no isolated areas
            bool hasIsolatedAreas = false;
            {
                QSet<int> visited;
                QQueue<int> queue;
                queue.enqueue(firstClickPos);
                visited.insert(firstClickPos);

                while (!queue.isEmpty()) {
                    int current = queue.dequeue();
                    QSet<int> neighbors = getNeighbors(current);

                    for (int neighbor : neighbors) {
                        if (!currentMines.contains(neighbor) && !visited.contains(neighbor)) {
                            visited.insert(neighbor);
                            queue.enqueue(neighbor);
                        }
                    }
                }

                // Check if all non-mine cells are reachable
                for (int i = 0; i < m_width * m_height; i++) {
                    if (!currentMines.contains(i) && !visited.contains(i)) {
                        hasIsolatedAreas = true;
                        break;
                    }
                }
            }

            if (!hasIsolatedAreas && trySolve(currentMines)) {
                qDebug() << "Successfully placed" << m_mineCount << "mines after" << attemptCount << "attempts";
                return true;
            }
            qDebug() << "Configuration not solvable or has isolated areas, retrying...";
        } else {
            qDebug() << "Could only place" << m_mines.size() << "mines, retrying...";
        }
    }

    qDebug() << "Failed to generate valid mine configuration after" << maxAttempts << "attempts";
    return false;
}

bool MinesweeperLogic::canPlaceMineAt(const QSet<int>& mines, int pos) {
    QSet<int> neighbors = getNeighbors(pos);

    // Count existing adjacent mines
    int adjacentMines = 0;
    for (int neighbor : neighbors) {
        if (mines.contains(neighbor)) {
            adjacentMines++;
        }
    }

    // Stricter adjacent mine check for larger boards
    int maxAdjacent = 3;  // Default for 9x9
    if (m_width >= 30) maxAdjacent = 4;  // For largest board
    else if (m_width >= 16) maxAdjacent = 3;  // For medium boards

    if (adjacentMines >= maxAdjacent) return false;

    // Check for patterns that create ambiguity
    for (int neighbor : neighbors) {
        QSet<int> neighborNeighbors = getNeighbors(neighbor);

        // Count mines around this neighbor
        int neighborMines = 0;
        for (int nn : neighborNeighbors) {
            if (mines.contains(nn) || nn == pos) {
                neighborMines++;
            }
        }

        // Prevent creating isolated high numbers
        if (neighborMines >= 5) return false;
    }

    if (!isValidDensity(mines, pos)) return false;

    // New check: Look for potential forced 50/50 situations
    int row = pos / m_width;
    int col = pos % m_width;

    // Check all adjacent cells
    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height &&
                newCol >= 0 && newCol < m_width) {

                // For each cell, check if placing mine here would create a 50/50
                if (wouldCreate5050(mines, pos, newRow, newCol)) {
                    return false;
                }
            }
        }
    }

    return true;
}

bool MinesweeperLogic::wouldCreate5050(const QSet<int>& mines, int newMinePos, int checkRow, int checkCol) {
    // First check the original 50/50 patterns
    // Get the position we're checking
    int twoSpacesPos = checkRow * m_width + checkCol;
    // Check all adjacent pairs of cells
    QSet<int> neighbors = getNeighbors(twoSpacesPos);
    for (int neighbor : neighbors) {
        // Skip if it's a mine or the new mine position
        if (mines.contains(neighbor) || neighbor == newMinePos) continue;
        // For each pair of cells, check if they form a 50/50
        QSet<int> sharedConstraints;
        // Get all numbers that see both cells
        QSet<int> cell1Numbers = getNeighbors(twoSpacesPos);
        QSet<int> cell2Numbers = getNeighbors(neighbor);
        // Look for numbers that constrain both cells
        for (int num1 : cell1Numbers) {
            if (cell2Numbers.contains(num1)) {
                // Check if this number would create a constraining pattern
                QSet<int> numNeighbors = getNeighbors(num1);
                int mineCount = 0;
                for (int n : numNeighbors) {
                    if (mines.contains(n) || n == newMinePos) {
                        mineCount++;
                    }
                }
                // If this number would force exactly one mine between our two cells
                if (mineCount == numNeighbors.size() - 2) {
                    sharedConstraints.insert(num1);
                }
            }
        }
        // If we found multiple shared constraints that would force a 50/50
        if (sharedConstraints.size() >= 2) {
            return true;
        }
    }

    // Now check for the new pattern with adjacent mines
    // For each neighbor of our new mine position
    for (int neighbor : getNeighbors(newMinePos)) {
        // If this neighbor is already a mine
        if (mines.contains(neighbor)) {
            // Check cells adjacent to both mines for potential '3' cells
            QSet<int> mine1Neighbors = getNeighbors(newMinePos);
            QSet<int> mine2Neighbors = getNeighbors(neighbor);

            // Find cells that are adjacent to both mines
            for (int sharedCell : mine1Neighbors) {
                if (mine2Neighbors.contains(sharedCell)) {
                    // Get neighbors of this potentially constraining cell
                    QSet<int> constraintNeighbors = getNeighbors(sharedCell);
                    int mineCount = 0;
                    int unknownCount = 0;

                    // Count mines and unknown cells around it
                    for (int n : constraintNeighbors) {
                        if (mines.contains(n) || n == newMinePos) {
                            mineCount++;
                        } else if (!mines.contains(n)) {
                            unknownCount++;
                        }
                    }

                    // If we have 2 mines and exactly 2 unknown cells around a potential '3'
                    if (mineCount == 2 && unknownCount == 2) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

int MinesweeperLogic::findMineHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells)
{
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells) revealed.insert(cell);
    for (int cell : flaggedCells) flagged.insert(cell);

    // First check each revealed number for basic deductions
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int flagCount = 0;
        QSet<int> unrevealedCells;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unrevealedCells.insert(neighbor);
            }
        }

        // If remaining mines equals remaining unrevealed cells, they must all be mines
        int remainingMines = m_numbers[pos] - flagCount;
        if (remainingMines > 0 && remainingMines == unrevealedCells.size()) {
            // Return first unflagged mine
            for (int minePos : unrevealedCells) {
                if (!flagged.contains(minePos)) {
                    int row = pos / m_width;
                    int col = pos % m_width;
                    int mineRow = minePos / m_width;
                    int mineCol = minePos % m_width;
                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: Cell at" << col << "," << row
                             << "shows" << m_numbers[pos]
                             << "mines, has" << flagCount << "flags nearby"
                             << "and" << unrevealedCells.size() << "unrevealed cells."
                             << "\nSince remaining mines (" << remainingMines
                             << ") equals unrevealed cells, they must all be mines.";
                    return minePos;
                }
            }
        }
    }

    // Then look for basic deductions - safe spots
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int flagCount = 0;
        QSet<int> unknowns;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unknowns.insert(neighbor);
            }
        }

        // If number matches flag count, all other unknowns are safe
        if (m_numbers[pos] == flagCount && !unknowns.isEmpty()) {
            int safePos = *unknowns.begin();
            int row = pos / m_width;
            int col = pos % m_width;
            int safeRow = safePos / m_width;
            int safeCol = safePos % m_width;
            qDebug() << "\nFound safe spot at" << safeCol << "," << safeRow
                     << "\nReason: Cell at" << col << "," << row
                     << "shows" << m_numbers[pos] << "mines"
                     << "and already has" << flagCount << "flags nearby."
                     << "\nSince flags count matches number, all other adjacent cells must be safe.";
            return safePos;
        }
    }

    // Try solveForHint for more advanced pattern detection
    int solverHint = solveForHint(revealedCells, flaggedCells);
    if (solverHint != -1) {
        qDebug() << "Found hint through solver at:" << solverHint;
        return solverHint;
    } else {
        qDebug() << "solver failed";
    }

    qDebug() << "\nGrid state when falling back to actual mine positions:";
    QString gridStr;
    for (int row = 0; row < m_height; row++) {
        QString rowStr;
        for (int col = 0; col < m_width; col++) {
            int pos = row * m_width + col;
            if (revealed.contains(pos)) {
                if (m_numbers[pos] == -1) {
                    rowStr += "M ";  // Mine
                } else {
                    rowStr += QString::number(m_numbers[pos]) + " ";  // Number
                }
            } else if (flagged.contains(pos)) {
                rowStr += "F ";  // Flag
            } else {
                rowStr += ". ";  // Hidden
            }
        }
        gridStr += rowStr.trimmed() + "\n";
    }
    qDebug().noquote() << gridStr;

    // Last resort: use actual mine positions
    qDebug() << "WARNING: Using actual mine positions for hint";
    for (int pos : m_mines) {
        if (!flagged.contains(pos)) {
            qDebug() << "Found mine hint from actual positions at:" << pos;
            return pos;
        }
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
        // Try both possibilities for this cell
        QVector<QSet<int>> validConfigurations;
        if (tryAllCombinations(numberConstraints, testPos, flagged)) {
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

bool MinesweeperLogic::isValidDensity(const QSet<int>& mines, int pos) {
    // Calculate local mine density in a 5x5 area
    int row = pos / m_width;
    int col = pos % m_width;

    int minRow = std::max(0, row - 2);
    int maxRow = std::min(m_height - 1, row + 2);
    int minCol = std::max(0, col - 2);
    int maxCol = std::min(m_width - 1, col + 2);

    int areaSize = (maxRow - minRow + 1) * (maxCol - minCol + 1);
    int localMines = 0;

    for (int r = minRow; r <= maxRow; r++) {
        for (int c = minCol; c <= maxCol; c++) {
            if (mines.contains(r * m_width + c)) {
                localMines++;
            }
        }
    }

    // Maximum allowed density depends on board size
    double maxDensity = 0.3;  // Default for 9x9
    if (m_width >= 30) maxDensity = 0.25;
    else if (m_width >= 16) maxDensity = 0.28;

    return (static_cast<double>(localMines) / areaSize) <= maxDensity;
}

bool MinesweeperLogic::tryAllCombinations(const QMap<int, QSet<int>>& constraints,
                                          int testPos,
                                          const QSet<int>& flagged)
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

int MinesweeperLogic::solveForHint(const QVector<int>& revealedCells, const QVector<int>& flaggedCells)
{
    struct CellConstraint {
        int pos;
        int cellsNeeded;
        QSet<int> unknowns;
        bool isSafety;
    };

    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells) revealed.insert(cell);
    for (int cell : flaggedCells) flagged.insert(cell);

    QVector<int> visibleNumbers(m_width * m_height, -2);
    for (int pos : revealed) {
        visibleNumbers[pos] = m_numbers[pos];
    }
    qDebug() << "\nTrying to find hint using only revealed numbers:";

    m_information.clear();
    m_informationsForSpace.clear();
    m_solvedSpaces.clear();

    for (int i = 0; i < m_width * m_height; i++) {
        if (flagged.contains(i)) {
            m_solvedSpaces[i] = true;
            qDebug() << "Position" << i % m_width << "," << i / m_width << "is marked as flag";
            continue;
        }
        if (!revealed.contains(i)) {
            continue;
        }

        if (visibleNumbers[i] <= 0) continue;

        QSet<int> neighbors = getNeighbors(i);
        int mineCount = 0;
        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                mineCount++;
            }
        }

        if (mineCount > 0) {
            MineSolverInfo info;
            info.spaces = neighbors;
            info.count = mineCount;
            m_information.insert(info);
            m_solvedSpaces[i] = false;

            qDebug() << "Cell at" << i % m_width << "," << i / m_width
                     << "shows" << visibleNumbers[i] << "mines"
                     << "and has" << mineCount << "flags nearby";

            for (int space : info.spaces) {
                m_informationsForSpace[space].insert(info);
            }
        }
    }

    QVector<CellConstraint> constraints;

    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int flagCount = 0;
        QSet<int> unknowns;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unknowns.insert(neighbor);
            }
        }

        int minesNeeded = m_numbers[pos] - flagCount;

        if (minesNeeded > 0) {
            constraints.append({pos, minesNeeded, unknowns, false});
            qDebug() << "Cell at" << pos % m_width << "," << pos / m_width
                     << "needs" << minesNeeded << "mines among"
                     << unknowns.size() << "unknowns";
        }

        if (minesNeeded < unknowns.size()) {
            int safeNeeded = unknowns.size() - minesNeeded;
            constraints.append({pos, safeNeeded, unknowns, true});
            qDebug() << "Cell at" << pos % m_width << "," << pos / m_width
                     << "needs" << safeNeeded << "safe cells among"
                     << unknowns.size() << "unknowns";
        }
    }

    // Look for cells that uniquely satisfy multiple constraints
    QMap<int, QVector<int>> satisfiesConstraints; // cell -> constraint indices

    for (int i = 0; i < constraints.size(); i++) {
        for (int cell : constraints[i].unknowns) {
            satisfiesConstraints[cell].append(i);
        }
    }

    // Find cells that satisfy the most constraints
    int maxConstraints = 0;
    QVector<int> bestCells;

    for (auto it = satisfiesConstraints.begin(); it != satisfiesConstraints.end(); ++it) {
        int constraintCount = it.value().size();
        if (constraintCount > maxConstraints) {
            maxConstraints = constraintCount;
            bestCells.clear();
            bestCells.append(it.key());
        } else if (constraintCount == maxConstraints) {
            bestCells.append(it.key());
        }
    }

    if (maxConstraints >= 2 && !bestCells.isEmpty()) {
        for (int cell : bestCells) {
            bool uniqueSolution = true;
            bool isSafe = false;
            bool firstConstraint = true;

            for (int constraintIdx : satisfiesConstraints[cell]) {
                const CellConstraint& constraint = constraints[constraintIdx];

                if (constraint.cellsNeeded == constraint.unknowns.size()) {
                    if (firstConstraint) {
                        isSafe = constraint.isSafety;
                        firstConstraint = false;
                    } else if (constraint.isSafety != isSafe) {
                        uniqueSolution = false;
                        break;
                    }
                }
            }

            if (uniqueSolution) {
                qDebug() << "Found cell at" << cell % m_width << "," << cell / m_width
                         << "that uniquely satisfies" << maxConstraints << "constraints";
                return cell;
            }
        }
    }

    bool changed = true;
    while (changed) {
        changed = false;

        for (const MineSolverInfo& info : m_information) {
            int knownMines = 0;
            QSet<int> unknownSpaces;

            for (int space : info.spaces) {
                if (m_solvedSpaces.contains(space)) {
                    if (m_solvedSpaces[space]) knownMines++;
                } else {
                    unknownSpaces.insert(space);
                }
            }

            if (info.count - knownMines == unknownSpaces.size()) {
                for (int space : unknownSpaces) {
                    if (!m_solvedSpaces.contains(space) && !flagged.contains(space)) {
                        qDebug() << "\nFound definite mine at" << space % m_width << "," << space / m_width
                                 << "\nReason: Space connects to a number requiring exactly"
                                 << unknownSpaces.size() << "more mines among"
                                 << unknownSpaces.size() << "unknown spaces";
                        return space;
                    }
                }
            }

            if (info.count == knownMines) {
                for (int space : unknownSpaces) {
                    if (!m_solvedSpaces.contains(space)) {
                        m_solvedSpaces[space] = false;
                        qDebug() << "Marked" << space % m_width << "," << space / m_width
                                 << "as safe - number has all required mines flagged";
                        changed = true;
                    }
                }
            }
        }
    }

    qDebug() << "\nLooking for forced mine patterns:";
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        int flagCount = 0;
        QSet<int> unknowns;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unknowns.insert(neighbor);
            }
        }

        int minesNeeded = m_numbers[pos] - flagCount;

        if (minesNeeded == 1 && unknowns.size() == 1) {
            int forcedMine = *unknowns.begin();
            int mineRow = forcedMine / m_width;
            int mineCol = forcedMine % m_width;
            qDebug() << "Found forced mine at" << mineCol << "," << mineRow;

            QSet<int> mineNeighbors = getNeighbors(forcedMine);
            for (int adjPos : mineNeighbors) {
                if (!revealed.contains(adjPos) || m_numbers[adjPos] <= 0) continue;

                QSet<int> adjNeighbors = getNeighbors(adjPos);
                int adjFlagCount = 0;
                QSet<int> adjUnknowns;

                for (int neighbor : adjNeighbors) {
                    if (flagged.contains(neighbor)) {
                        adjFlagCount++;
                    } else if (!revealed.contains(neighbor)) {
                        adjUnknowns.insert(neighbor);
                    }
                }

                int adjMinesNeeded = m_numbers[adjPos] - adjFlagCount;

                if (adjMinesNeeded == 1) {
                    adjUnknowns.remove(forcedMine);
                    if (!adjUnknowns.isEmpty()) {
                        int safeCell = *adjUnknowns.begin();
                        int safeRow = safeCell / m_width;
                        int safeCol = safeCell % m_width;
                        qDebug() << "Found safe cell at" << safeCol << "," << safeRow
                                 << "\nBecause adjacent cell had a forced mine and needs exactly one more mine";
                        return safeCell;
                    }
                }
            }
        }
    }

    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        int row = pos / m_width;
        int col = pos % m_width;

        if (m_numbers[pos] == 2) {
            if (col > 0 && col < m_width - 1) {
                int left = pos - 1;
                int right = pos + 1;
                if (revealed.contains(left) && revealed.contains(right) &&
                    m_numbers[left] == 1 && m_numbers[right] == 1) {
                    for (int offset : {-m_width, m_width}) {
                        int checkPos = pos + offset;
                        if (checkPos >= 0 && checkPos < m_width * m_height &&
                            !revealed.contains(checkPos) && !flagged.contains(checkPos)) {
                            return checkPos;
                        }
                    }
                }
            }

            if (row > 0 && row < m_height - 1) {
                int up = pos - m_width;
                int down = pos + m_width;
                if (revealed.contains(up) && revealed.contains(down) &&
                    m_numbers[up] == 1 && m_numbers[down] == 1) {
                    for (int offset : {-1, 1}) {
                        int checkPos = pos + offset;
                        if ((checkPos / m_width) == row &&
                            !revealed.contains(checkPos) && !flagged.contains(checkPos)) {
                            return checkPos;
                        }
                    }
                }
            }
        }

        if (m_numbers[pos] == 1 && row < m_height - 1 && col < m_width - 1) {
            int right = pos + 1;
            int down = pos + m_width;
            int diagonal = pos + m_width + 1;

            if (revealed.contains(right) && revealed.contains(down) && revealed.contains(diagonal) &&
                m_numbers[right] == 1 && m_numbers[down] == 1 && m_numbers[diagonal] == 1) {
                for (int offset : {-m_width-1, -m_width+1, m_width-1, m_width+1}) {
                    int checkPos = pos + offset;
                    if (checkPos >= 0 && checkPos < m_width * m_height &&
                        abs((checkPos % m_width) - col) == 1 &&
                        !revealed.contains(checkPos) && !flagged.contains(checkPos)) {
                        return checkPos;
                    }
                }
            }
        }
    }

    for (auto it = m_solvedSpaces.begin(); it != m_solvedSpaces.end(); ++it) {
        if (!it.value() && !revealed.contains(it.key()) && !flagged.contains(it.key())) {
            qDebug() << "\nFalling back to previously marked safe cell at"
                     << it.key() % m_width << "," << it.key() / m_width;
            return it.key();
        }
    }

    qDebug() << "No hint found!";
    return -1;
}

bool MinesweeperLogic::initializeFromSave(int width, int height, int mineCount, const QVector<int>& mines) {
    if (width <= 0 || height <= 0 || mineCount <= 0 || mineCount >= width * height) {
        return false;
    }

    m_width = width;
    m_height = height;
    m_mineCount = mineCount;
    m_mines = mines;
    m_numbers.resize(width * height);

    // Recalculate numbers for the loaded mine positions
    calculateNumbers();

    return true;
}
