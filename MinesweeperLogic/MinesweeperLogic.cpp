#include "MinesweeperLogic.h"
#include <QDebug>
#include <QQueue>

MinesweeperLogic::MinesweeperLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{}

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

bool MinesweeperLogic::initializeFromSave(int width,
                                          int height,
                                          int mineCount,
                                          const QVector<int> &mines)
{
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

void MinesweeperLogic::calculateNumbers()
{
    m_numbers.fill(0, m_width * m_height);

    for (int mine : m_mines) {
        m_numbers[mine] = -1; // Mark mine positions

        // Update adjacent cell counts
        QSet<int> neighbors = getNeighbors(mine);
        for (int neighbor : neighbors) {
            if (m_numbers[neighbor] >= 0) {
                m_numbers[neighbor]++;
            }
        }
    }
}

int MinesweeperLogic::placeMines(int firstClickX, int firstClickY, int seed)
{
    const int firstClickPos = firstClickY * m_width + firstClickX;
    // Initialize RNG with seed or random device
    std::mt19937 rng;
    if (seed >= 0) {
        rng.seed(static_cast<unsigned>(seed));
    } else {
        std::random_device rd;
        seed = static_cast<int>(rd()) & 0x7FFFFFFF; // Ensure positive value
        rng.seed(static_cast<unsigned>(seed));
    }

    // Setup safe zone around first click
    //int safeRadius = (m_width >= 30) ? 2 : 1;

    int safeRadius = 1;

    QSet<int> safeZone;
    int row = firstClickPos / m_width;
    int col = firstClickPos % m_width;
    for (int r = -safeRadius; r <= safeRadius; r++) {
        for (int c = -safeRadius; c <= safeRadius; c++) {
            int newRow = row + r;
            int newCol = col + c;
            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                safeZone.insert(newRow * m_width + newCol);
            }
        }
    }

    QVector<int> allPositions;
    for (int i = 0; i < m_width * m_height; i++) {
        if (!safeZone.contains(i))
            allPositions.append(i);
    }

    int attempts = 0;
    while (attempts != 1000) {
        attempts++;
        m_mines.clear();
        QVector<int> positions = allPositions;

        // Shuffle mine positions using the seeded RNG
        for (int i = positions.size() - 1; i > 0; i--) {
            int j = std::uniform_int_distribution<int>(0, i)(rng);
            std::swap(positions[i], positions[j]);
        }

        QSet<int> currentMines;
        for (int pos : positions) {
            if (currentMines.size() >= m_mineCount)
                break;
            if (canPlaceMineAt(currentMines, pos)) {
                currentMines.insert(pos);
                m_mines.append(pos);
            }
        }

        if (currentMines.size() == m_mineCount) {
            calculateNumbers();

            // Check for 50/50 ambiguous situations
            if (hasAmbiguousMinePlacement(currentMines)) {
                qDebug() << "Ambiguous mine placement detected, regenerating...";
                continue;
            }

            qDebug() << "Successfully generated grid with seed" << seed << "in" << attempts
                     << "attempts";

            return seed;
        }
    }

    qDebug() << "Failed to generate valid grid after" << attempts << "attempts";
    return -1;
}

bool MinesweeperLogic::hasAmbiguousMinePlacement(const QSet<int> &currentMines)
{
    // Check for 1-3 patterns and their variations
    for (int y = 0; y < m_height; y++) {
        for (int x = 0; x < m_width; x++) {
            int pos = y * m_width + x;
            int number = m_numbers.value(pos);

            // Look for cells with specific values that might create 50/50s
            if (number == 1 || number == 2 || number == 3 || number == 4) {
                QSet<int> neighbors = getNeighbors(pos);

                // For each neighbor that is also a number
                for (int neighbor : neighbors) {
                    int neighborNum = m_numbers.value(neighbor);
                    if (neighborNum <= 0)
                        continue;

                    // Find shared unknown cells between these numbers
                    QSet<int> pos1Unknowns;
                    QSet<int> pos2Unknowns;

                    for (int n : getNeighbors(pos)) {
                        if (!currentMines.contains(n) && m_numbers.value(n) == -1) {
                            pos1Unknowns.insert(n);
                        }
                    }

                    for (int n : getNeighbors(neighbor)) {
                        if (!currentMines.contains(n) && m_numbers.value(n) == -1) {
                            pos2Unknowns.insert(n);
                        }
                    }

                    // Get shared unknown cells
                    QSet<int> sharedUnknowns;
                    for (int u : pos1Unknowns) {
                        if (pos2Unknowns.contains(u)) {
                            sharedUnknowns.insert(u);
                        }
                    }

                    // Check for known 50/50 patterns
                    bool is5050Pattern = false;

                    // 1-3 pattern
                    if ((number == 1 && neighborNum == 3) || (number == 3 && neighborNum == 1)) {
                        if (sharedUnknowns.size() == 2) {
                            is5050Pattern = true;
                        }
                    }

                    // 2-4 pattern
                    if ((number == 2 && neighborNum == 4) || (number == 4 && neighborNum == 2)) {
                        if (sharedUnknowns.size() == 2) {
                            is5050Pattern = true;
                        }
                    }

                    if (is5050Pattern) {
                        qDebug() << "Found 50/50 pattern between" << pos << "(" << number << ") and"
                                 << neighbor << "(" << neighborNum << ")";
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

bool MinesweeperLogic::canPlaceMineAt(const QSet<int> &mines, int pos)
{
    QSet<int> neighbors = getNeighbors(pos);

    // Count existing adjacent mines
    int adjacentMines = 0;
    for (int neighbor : neighbors) {
        if (mines.contains(neighbor)) {
            adjacentMines++;
        }
    }

    // Stricter adjacent mine check for larger boards
    int maxAdjacent = 3; // Default for 9x9
    if (m_width >= 30)
        maxAdjacent = 4; // For largest board
    else if (m_width >= 16)
        maxAdjacent = 3; // For medium boards

    if (adjacentMines >= maxAdjacent)
        return false;

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
        if (neighborMines >= 5)
            return false;
    }

    if (!isValidDensity(mines, pos))
        return false;

    // New check: Look for potential forced 50/50 situations
    int row = pos / m_width;
    int col = pos % m_width;

    // Check all adjacent cells
    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0)
                continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                // For each cell, check if placing mine here would create a 50/50
                if (wouldCreate5050(mines, pos)) {
                    return false;
                }
            }
        }
    }

    return true;
}

bool MinesweeperLogic::wouldCreate5050(const QSet<int> &mines, int newMinePos)
{
    // Calculate what the numbers would be after placing this mine
    QVector<int> tempNumbers(m_width * m_height, 0);
    // First count existing mines
    for (int mine : mines) {
        QSet<int> neighbors = getNeighbors(mine);
        for (int n : neighbors) {
            tempNumbers[n]++;
        }
    }
    // Add the new mine's contribution
    QSet<int> newMineNeighbors = getNeighbors(newMinePos);
    for (int n : newMineNeighbors) {
        tempNumbers[n]++;
    }

    // Check every cell affected by the new mine
    for (int pos : newMineNeighbors) {
        QSet<int> neighbors = getNeighbors(pos);

        // Look for 1-3 patterns
        if (tempNumbers[pos] == 1 || tempNumbers[pos] == 3) {
            for (int neighbor : neighbors) {
                // Skip if it would be a mine
                if (mines.contains(neighbor) || neighbor == newMinePos)
                    continue;

                if ((tempNumbers[pos] == 1 && tempNumbers[neighbor] == 3)
                    || (tempNumbers[pos] == 3 && tempNumbers[neighbor] == 1)) {
                    // Count shared unknown cells
                    QSet<int> unknownCells;
                    QSet<int> neighborNeighbors = getNeighbors(neighbor);
                    for (int cell : neighbors) {
                        if (neighborNeighbors.contains(cell) && !mines.contains(cell)
                            && cell != newMinePos) {
                            unknownCells.insert(cell);
                        }
                    }
                    if (unknownCells.size() == 2) {
                        return true; // Would create a 1-3 pattern
                    }
                }
            }
        }

        // Look for 2-4 patterns
        if (tempNumbers[pos] == 2 || tempNumbers[pos] == 4) {
            for (int neighbor : neighbors) {
                // Skip if it would be a mine
                if (mines.contains(neighbor) || neighbor == newMinePos)
                    continue;

                if ((tempNumbers[pos] == 2 && tempNumbers[neighbor] == 4)
                    || (tempNumbers[pos] == 4 && tempNumbers[neighbor] == 2)) {
                    // Count shared unknown cells
                    QSet<int> unknownCells;
                    QSet<int> neighborNeighbors = getNeighbors(neighbor);
                    for (int cell : neighbors) {
                        if (neighborNeighbors.contains(cell) && !mines.contains(cell)
                            && cell != newMinePos) {
                            unknownCells.insert(cell);
                        }
                    }
                    if (unknownCells.size() == 2) {
                        return true; // Would create a 2-4 pattern
                    }
                }
            }
        }
    }

    return false;
}

int MinesweeperLogic::findMineHint(const QVector<int> &revealedCells,
                                   const QVector<int> &flaggedCells)
{
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells)
        revealed.insert(cell);
    for (int cell : flaggedCells)
        flagged.insert(cell);

    // First check each revealed number for basic deductions
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0)
            continue;

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
                             << "\nReason: Cell at" << col << "," << row << "shows"
                             << m_numbers[pos] << "mines, has" << flagCount << "flags nearby"
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
        if (m_numbers[pos] <= 0)
            continue;

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
            qDebug()
                << "\nFound safe spot at" << safeCol << "," << safeRow << "\nReason: Cell at" << col
                << "," << row << "shows" << m_numbers[pos] << "mines"
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
                    rowStr += "M "; // Mine
                } else {
                    rowStr += QString::number(m_numbers[pos]) + " "; // Number
                }
            } else if (flagged.contains(pos)) {
                rowStr += "F "; // Flag
            } else {
                rowStr += ". "; // Hidden
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

bool MinesweeperLogic::isValidDensity(const QSet<int> &mines, int pos)
{
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
    double maxDensity = 0.3; // Default for 9x9
    if (m_width >= 30)
        maxDensity = 0.25;
    else if (m_width >= 16)
        maxDensity = 0.28;

    return (static_cast<double>(localMines) / areaSize) <= maxDensity;
}

QSet<int> MinesweeperLogic::getNeighbors(int pos) const
{
    QSet<int> neighbors;
    int row = pos / m_width;
    int col = pos % m_width;

    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0)
                continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                neighbors.insert(newRow * m_width + newCol);
            }
        }
    }

    return neighbors;
}

int MinesweeperLogic::solveForHint(const QVector<int> &revealedCells,
                                   const QVector<int> &flaggedCells)
{
    struct CellConstraint
    {
        int pos;
        int cellsNeeded;
        QSet<int> unknowns;
        bool isSafety;
    };

    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells)
        revealed.insert(cell);
    for (int cell : flaggedCells)
        flagged.insert(cell);

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

        if (visibleNumbers[i] <= 0)
            continue;

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

            qDebug() << "Cell at" << i % m_width << "," << i / m_width << "shows"
                     << visibleNumbers[i] << "mines"
                     << "and has" << mineCount << "flags nearby";

            for (int space : info.spaces) {
                m_informationsForSpace[space].insert(info);
            }
        }
    }

    QVector<CellConstraint> constraints;

    for (int pos : revealed) {
        if (m_numbers[pos] <= 0)
            continue;

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
            qDebug() << "Cell at" << pos % m_width << "," << pos / m_width << "needs" << minesNeeded
                     << "mines among" << unknowns.size() << "unknowns";
        }

        if (minesNeeded < unknowns.size()) {
            int safeNeeded = unknowns.size() - minesNeeded;
            constraints.append({pos, safeNeeded, unknowns, true});
            qDebug() << "Cell at" << pos % m_width << "," << pos / m_width << "needs" << safeNeeded
                     << "safe cells among" << unknowns.size() << "unknowns";
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
                const CellConstraint &constraint = constraints[constraintIdx];

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

        for (const MineSolverInfo &info : m_information) {
            int knownMines = 0;
            QSet<int> unknownSpaces;

            for (int space : info.spaces) {
                if (m_solvedSpaces.contains(space)) {
                    if (m_solvedSpaces[space])
                        knownMines++;
                } else {
                    unknownSpaces.insert(space);
                }
            }

            if (info.count - knownMines == unknownSpaces.size()) {
                for (int space : unknownSpaces) {
                    if (!m_solvedSpaces.contains(space) && !flagged.contains(space)) {
                        qDebug() << "\nFound definite mine at" << space % m_width << ","
                                 << space / m_width
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
        if (m_numbers[pos] <= 0)
            continue;

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
                if (!revealed.contains(adjPos) || m_numbers[adjPos] <= 0)
                    continue;

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
                                 << "\nBecause adjacent cell had a forced mine and needs exactly "
                                    "one more mine";
                        return safeCell;
                    }
                }
            }
        }
    }

    for (int pos : revealed) {
        if (m_numbers[pos] <= 0)
            continue;

        int row = pos / m_width;
        int col = pos % m_width;

        if (m_numbers[pos] == 2) {
            if (col > 0 && col < m_width - 1) {
                int left = pos - 1;
                int right = pos + 1;
                if (revealed.contains(left) && revealed.contains(right) && m_numbers[left] == 1
                    && m_numbers[right] == 1) {
                    for (int offset : {-m_width, m_width}) {
                        int checkPos = pos + offset;
                        if (checkPos >= 0 && checkPos < m_width * m_height
                            && !revealed.contains(checkPos) && !flagged.contains(checkPos)) {
                            return checkPos;
                        }
                    }
                }
            }

            if (row > 0 && row < m_height - 1) {
                int up = pos - m_width;
                int down = pos + m_width;
                if (revealed.contains(up) && revealed.contains(down) && m_numbers[up] == 1
                    && m_numbers[down] == 1) {
                    for (int offset : {-1, 1}) {
                        int checkPos = pos + offset;
                        if ((checkPos / m_width) == row && !revealed.contains(checkPos)
                            && !flagged.contains(checkPos)) {
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

            if (revealed.contains(right) && revealed.contains(down) && revealed.contains(diagonal)
                && m_numbers[right] == 1 && m_numbers[down] == 1 && m_numbers[diagonal] == 1) {
                for (int offset : {-m_width - 1, -m_width + 1, m_width - 1, m_width + 1}) {
                    int checkPos = pos + offset;
                    if (checkPos >= 0 && checkPos < m_width * m_height
                        && abs((checkPos % m_width) - col) == 1 && !revealed.contains(checkPos)
                        && !flagged.contains(checkPos)) {
                        return checkPos;
                    }
                }
            }
        }
    }

    for (auto it = m_solvedSpaces.begin(); it != m_solvedSpaces.end(); ++it) {
        if (!it.value() && !revealed.contains(it.key()) && !flagged.contains(it.key())) {
            qDebug() << "\nFalling back to previously marked safe cell at" << it.key() % m_width
                     << "," << it.key() / m_width;
            return it.key();
        }
    }

    qDebug() << "No hint found!";
    return -1;
}
