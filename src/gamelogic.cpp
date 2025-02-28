#include "gamelogic.h"
#include <QDebug>
#include <QQueue>
#include <QRandomGenerator>

GameLogic::GameLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
    , m_cancelGeneration(false)
    , m_generationWatcher(new QFutureWatcher<void>(this))
    , m_currentAttempt(0)
    , m_totalAttempts(0)
    , m_minesPlaced(0)
{
    connect(m_generationWatcher, &QFutureWatcher<void>::finished, this, [this]() {
        // Only emit if not cancelled
        if (!m_cancelGeneration.load()) {
            // The future is already finished so we can check if it was successful
            // by testing if mines were generated
            emit boardGenerationCompleted(!m_mines.isEmpty());
        }
    });
}

GameLogic::~GameLogic()
{
    cancelGeneration();
}

bool GameLogic::initializeGame(int width, int height, int mineCount)
{
    if (width <= 0 || height <= 0 || mineCount <= 0 || mineCount >= width * height) {
        return false;
    }

    m_width = width;
    m_height = height;
    m_mineCount = mineCount;
    m_mines.clear();
    m_numbers.resize(width * height);

    // Reset progress counters
    updateProgress(0, 0, 0);

    // Emit totalMines signal since m_mineCount changed
    QMetaObject::invokeMethod(this, [this]() {
        emit totalMinesChanged();
    }, Qt::QueuedConnection);

    return true;
}

bool GameLogic::initializeFromSave(int width, int height, int mineCount, const QVector<int> &mines)
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

void GameLogic::calculateNumbers()
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

int GameLogic::findMineHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells)
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



QSet<int> GameLogic::getNeighbors(int pos) const
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

int GameLogic::solveForHint(const QVector<int> &revealedCells, const QVector<int> &flaggedCells)
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

bool GameLogic::generateBoard(int firstClickX, int firstClickY) {
    // Check for cancellation at the beginning
    if (m_cancelGeneration.load()) {
        return false;
    }

    // Valid first click coordinates
    bool safeFirstClick = (firstClickX != -1 && firstClickY != -1);
    int firstClickIndex = safeFirstClick ? (firstClickY * m_width + firstClickX) : -1;

    // Represents a complete board state for solving
    class BoardState {
    public:
        struct Cell {
            bool isMine = false;
            bool revealed = false;
            bool flagged = false;
            bool safe = false;
            int adjacentMines = 0;
            QSet<int> neighbors;
        };

        BoardState(int width, int height) : m_width(width), m_height(height) {
            m_cells.resize(width * height);

            // Initialize neighbor information
            for (int i = 0; i < m_cells.size(); ++i) {
                int row = i / width;
                int col = i % width;

                for (int dr = -1; dr <= 1; ++dr) {
                    for (int dc = -1; dc <= 1; ++dc) {
                        if (dr == 0 && dc == 0) continue;

                        int newRow = row + dr;
                        int newCol = col + dc;

                        if (newRow >= 0 && newRow < height &&
                            newCol >= 0 && newCol < width) {
                            m_cells[i].neighbors.insert(newRow * width + newCol);
                        }
                    }
                }
            }
        }

        // Create a safe opening area around a cell
        void createSafeArea(int center) {
            m_cells[center].safe = true;
            m_cells[center].revealed = true;

            for (int neighbor : m_cells[center].neighbors) {
                m_cells[neighbor].safe = true;

                // 50% chance for second-level neighbors to be safe too
                if (QRandomGenerator::global()->bounded(100) < 50) {
                    for (int secondNeighbor : m_cells[neighbor].neighbors) {
                        m_cells[secondNeighbor].safe = true;
                    }
                }
            }
        }

        // Place a mine and update adjacent mine counts
        void placeMine(int index) {
            m_cells[index].isMine = true;
            m_mines.append(index);

            for (int neighbor : m_cells[index].neighbors) {
                m_cells[neighbor].adjacentMines++;
            }
        }

        // Get the list of currently placed mines
        QVector<int> getMines() const {
            return m_mines;
        }

        // Get candidates for mine placement
        QVector<int> getMineCandidates() const {
            QVector<int> candidates;
            for (int i = 0; i < m_cells.size(); ++i) {
                if (!m_cells[i].safe && !m_cells[i].isMine) {
                    candidates.append(i);
                }
            }
            return candidates;
        }

        // Check if the board is fully solvable without guessing
        bool isFullySolvable(const std::atomic<bool>& cancelFlag) {
            // Check for cancellation
            if (cancelFlag.load()) {
                return false;
            }

            // Create a copy of the board for simulation
            BoardState simBoard = *this;

            // Reveal the safe area
            for (int i = 0; i < simBoard.m_cells.size(); ++i) {
                if (simBoard.m_cells[i].safe) {
                    simBoard.m_cells[i].revealed = true;
                }
            }

            // Try to solve the board
            return simBoard.solveCompletely(cancelFlag);
        }

        // Calculate numbers for generating the final board
        QVector<int> calculateNumbers() const {
            QVector<int> numbers(m_cells.size(), 0);

            // Mark mine positions
            for (int mine : m_mines) {
                numbers[mine] = -1;
            }

            // Calculate adjacent mine counts
            for (int mine : m_mines) {
                int row = mine / m_width;
                int col = mine % m_width;

                for (int dr = -1; dr <= 1; ++dr) {
                    for (int dc = -1; dc <= 1; ++dc) {
                        if (dr == 0 && dc == 0) continue;

                        int newRow = row + dr;
                        int newCol = col + dc;

                        if (newRow >= 0 && newRow < m_height &&
                            newCol >= 0 && newCol < m_width) {
                            int idx = newRow * m_width + newCol;
                            if (numbers[idx] != -1) { // Only increment if not a mine
                                numbers[idx]++;
                            }
                        }
                    }
                }
            }

            return numbers;
        }

    private:
        QVector<Cell> m_cells;
        QVector<int> m_mines;
        int m_width;
        int m_height;

        // Use a constraint solver approach to determine if the board is solvable
        bool solveCompletely(const std::atomic<bool>& cancelFlag) {
            // Keep track of which cells have been processed
            QSet<int> processedCells;

            // Keep trying to make progress until we can't anymore
            bool progress = true;
            while (progress) {
                // Check for cancellation
                if (cancelFlag.load()) {
                    return false;
                }

                progress = false;

                // For each revealed cell, check if we can make logical deductions
                for (int i = 0; i < m_cells.size(); ++i) {
                    if (!m_cells[i].revealed || processedCells.contains(i)) continue;

                    // If this cell has no unrevealed neighbors, skip it
                    bool hasUnrevealedNeighbors = false;
                    for (int neighbor : m_cells[i].neighbors) {
                        if (!m_cells[neighbor].revealed) {
                            hasUnrevealedNeighbors = true;
                            break;
                        }
                    }

                    if (!hasUnrevealedNeighbors) {
                        processedCells.insert(i);
                        continue;
                    }

                    // Count flagged neighbors and list unrevealed ones
                    int flagCount = 0;
                    QVector<int> unrevealed;

                    for (int neighbor : m_cells[i].neighbors) {
                        if (m_cells[neighbor].flagged) {
                            flagCount++;
                        } else if (!m_cells[neighbor].revealed) {
                            unrevealed.append(neighbor);
                        }
                    }

                    // If all mines are accounted for, all other neighbors are safe
                    if (flagCount == m_cells[i].adjacentMines && !unrevealed.isEmpty()) {
                        for (int safeCell : unrevealed) {
                            m_cells[safeCell].revealed = true;
                            progress = true;
                        }
                    }
                    // If all unrevealed neighbors must be mines, flag them
                    else if (m_cells[i].adjacentMines - flagCount == unrevealed.size() && !unrevealed.isEmpty()) {
                        for (int mineCell : unrevealed) {
                            m_cells[mineCell].flagged = true;
                            progress = true;
                        }
                    }
                }

                // If we can't make progress with basic rules, try more advanced solving
                if (!progress) {
                    progress = solveWithCSP(cancelFlag);
                }
            }

            // Check if the board is fully solved or if we need to guess
            for (int i = 0; i < m_cells.size(); ++i) {
                if (!m_cells[i].revealed && !m_cells[i].flagged && !m_cells[i].isMine) {
                    // There's an unrevealed cell that we couldn't determine - needs guessing
                    return false;
                }
            }

            return true;
        }

        // Constraint Satisfaction Problem (CSP) solver for more complex patterns
        bool solveWithCSP(const std::atomic<bool>& cancelFlag) {
            // Check for cancellation
            if (cancelFlag.load()) {
                return false;
            }

            // Find all boundary cells (revealed cells with unrevealed neighbors)
            QVector<int> boundaryCells;
            for (int i = 0; i < m_cells.size(); ++i) {
                if (!m_cells[i].revealed) continue;

                bool hasBoundary = false;
                for (int neighbor : m_cells[i].neighbors) {
                    if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                        hasBoundary = true;
                        break;
                    }
                }

                if (hasBoundary) {
                    boundaryCells.append(i);
                }
            }

            if (boundaryCells.isEmpty()) return false;

            // Find all frontier cells (unrevealed cells adjacent to revealed ones)
            QSet<int> frontierCells;
            for (int cell : boundaryCells) {
                for (int neighbor : m_cells[cell].neighbors) {
                    if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                        frontierCells.insert(neighbor);
                    }
                }
            }

            // Check for cancellation before potentially long operations
            if (cancelFlag.load()) {
                return false;
            }

            // If frontier is too large, partial solving might be needed
            if (frontierCells.size() > 12) { // Limit for tractable solving
                return solveLargeCSP(boundaryCells, QVector<int>(frontierCells.begin(), frontierCells.end()), cancelFlag);
            }

            // Generate all possible mine configurations for the frontier
            QVector<QVector<bool>> possibleConfigs;
            QVector<bool> currentConfig(frontierCells.size(), false);
            QVector<int> frontierList(frontierCells.begin(), frontierCells.end());

            // Use a constraint-based approach to find all valid configurations
            generateValidConfigurations(boundaryCells, frontierList, currentConfig, 0, possibleConfigs, cancelFlag);

            // Check for cancellation after potentially long operations
            if (cancelFlag.load()) {
                return false;
            }

            if (possibleConfigs.isEmpty()) {
                return false; // No valid configurations - board is unsolvable
            }

            // Find cells that are mines or safe in all configurations
            QVector<bool> definitelyMines(frontierList.size(), true);
            QVector<bool> definitelySafe(frontierList.size(), true);

            for (const auto& config : possibleConfigs) {
                for (int i = 0; i < config.size(); ++i) {
                    if (!config[i]) definitelyMines[i] = false;
                    if (config[i]) definitelySafe[i] = false;
                }
            }

            // Apply what we've learned
            bool progress = false;
            for (int i = 0; i < frontierList.size(); ++i) {
                int cellIndex = frontierList[i];

                if (definitelyMines[i]) {
                    m_cells[cellIndex].flagged = true;
                    progress = true;
                }
                else if (definitelySafe[i]) {
                    m_cells[cellIndex].revealed = true;
                    progress = true;
                }
            }

            return progress;
        }

        // Solve large CSP problems by breaking them into subproblems
        bool solveLargeCSP(const QVector<int>& boundaryCells, const QVector<int>& frontierCells, const std::atomic<bool>& cancelFlag) {
            // Check for cancellation
            if (cancelFlag.load()) {
                return false;
            }

            // Find connected components in the boundary
            QVector<QSet<int>> components;
            QSet<int> visitedBoundary;

            for (int cell : boundaryCells) {
                // Check for cancellation in the loop
                if (cancelFlag.load()) {
                    return false;
                }

                if (visitedBoundary.contains(cell)) continue;

                // Find a connected component
                QSet<int> component;
                QQueue<int> queue;
                queue.enqueue(cell);
                visitedBoundary.insert(cell);

                while (!queue.isEmpty()) {
                    // Check for cancellation in nested loop
                    if (cancelFlag.load()) {
                        return false;
                    }

                    int current = queue.dequeue();
                    component.insert(current);

                    // Find connected boundary cells through shared frontier cells
                    QSet<int> currentFrontier;
                    for (int neighbor : m_cells[current].neighbors) {
                        if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                            currentFrontier.insert(neighbor);
                        }
                    }

                    for (int otherCell : boundaryCells) {
                        if (visitedBoundary.contains(otherCell)) continue;

                        bool connected = false;
                        for (int neighbor : m_cells[otherCell].neighbors) {
                            if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged &&
                                currentFrontier.contains(neighbor)) {
                                connected = true;
                                break;
                            }
                        }

                        if (connected) {
                            queue.enqueue(otherCell);
                            visitedBoundary.insert(otherCell);
                        }
                    }
                }

                components.append(component);
            }

            // Solve each component separately
            bool progress = false;
            for (const auto& component : components) {
                // Check for cancellation in component loop
                if (cancelFlag.load()) {
                    return false;
                }

                // Get frontier cells for this component
                QSet<int> componentFrontier;
                for (int cell : component) {
                    for (int neighbor : m_cells[cell].neighbors) {
                        if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                            componentFrontier.insert(neighbor);
                        }
                    }
                }

                if (componentFrontier.size() <= 12) { // Small enough to solve directly
                    QVector<int> compBoundary(component.begin(), component.end());
                    QVector<int> compFrontier(componentFrontier.begin(), componentFrontier.end());

                    // Generate possible configurations for this component
                    QVector<QVector<bool>> possibleConfigs;
                    QVector<bool> currentConfig(compFrontier.size(), false);

                    generateValidConfigurations(compBoundary, compFrontier, currentConfig, 0, possibleConfigs, cancelFlag);

                    // Check for cancellation after potentially long operations
                    if (cancelFlag.load()) {
                        return false;
                    }

                    if (possibleConfigs.isEmpty()) {
                        return false; // No valid configurations - component is unsolvable
                    }

                    // Find cells that are mines or safe in all configurations
                    QVector<bool> definitelyMines(compFrontier.size(), true);
                    QVector<bool> definitelySafe(compFrontier.size(), true);

                    for (const auto& config : possibleConfigs) {
                        for (int i = 0; i < config.size(); ++i) {
                            if (!config[i]) definitelyMines[i] = false;
                            if (config[i]) definitelySafe[i] = false;
                        }
                    }

                    // Apply what we've learned
                    for (int i = 0; i < compFrontier.size(); ++i) {
                        int cellIndex = compFrontier[i];

                        if (definitelyMines[i]) {
                            m_cells[cellIndex].flagged = true;
                            progress = true;
                        }
                        else if (definitelySafe[i]) {
                            m_cells[cellIndex].revealed = true;
                            progress = true;
                        }
                    }
                }
            }

            return progress;
        }

        // Generate all valid mine configurations for a frontier
        void generateValidConfigurations(
            const QVector<int>& boundaryCells,
            const QVector<int>& frontierCells,
            QVector<bool>& currentConfig,
            int index,
            QVector<QVector<bool>>& validConfigs,
            const std::atomic<bool>& cancelFlag,
            int maxConfigs = 500
            ) {
            // Check for cancellation or max configs reached
            if (cancelFlag.load() || validConfigs.size() >= maxConfigs) return;

            if (index == frontierCells.size()) {
                // Check if this configuration satisfies all constraints
                bool valid = true;
                for (int boundaryCell : boundaryCells) {
                    int flagCount = 0;
                    int expectedMines = m_cells[boundaryCell].adjacentMines;

                    for (int neighbor : m_cells[boundaryCell].neighbors) {
                        if (m_cells[neighbor].flagged) {
                            flagCount++;
                        } else if (!m_cells[neighbor].revealed) {
                            // Check if this frontier cell is a mine in the current configuration
                            int frontierIndex = frontierCells.indexOf(neighbor);
                            if (frontierIndex != -1 && currentConfig[frontierIndex]) {
                                flagCount++;
                            }
                        }
                    }

                    if (flagCount != expectedMines) {
                        valid = false;
                        break;
                    }
                }

                if (valid) {
                    validConfigs.append(currentConfig);
                }
                return;
            }

            // Try both options for this cell: mine or not mine
            // First, not a mine
            currentConfig[index] = false;
            generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);

            // Check cancellation before continuing
            if (cancelFlag.load()) return;

            // Then a mine
            currentConfig[index] = true;
            generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);
        }
    };

    // Try multiple times to generate a valid board
    const int MAX_ATTEMPTS = 1;

    for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
        // Check for cancellation at the start of each attempt
        if (m_cancelGeneration.load()) {
            return false;
        }

        // Initialize a new board state
        BoardState board(m_width, m_height);

        // Start with first click area being safe
        int startIndex = safeFirstClick ? firstClickIndex : (m_width * m_height / 2);
        board.createSafeArea(startIndex);

        // Get candidates for mine placement
        QVector<int> candidates = board.getMineCandidates();

        // Check for cancellation before shuffling and mine placement
        if (m_cancelGeneration.load()) {
            return false;
        }

        // Shuffle candidates
        for (int i = candidates.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> dist(0, i);
            int j = dist(m_rng);
            std::swap(candidates[i], candidates[j]);
        }

        // Reset mines placed counter for this attempt
        updateProgress(m_currentAttempt.load(), m_totalAttempts.load(), 0);

        // Place mines one by one, ensuring the board remains solvable
        int placedMines = 0;
        for (int i = 0; i < candidates.size() && placedMines < m_mineCount; ++i) {
            // Check for cancellation inside the mine placement loop
            if (m_cancelGeneration.load()) {
                return false;
            }

            // Create a temporary board to test this mine placement
            BoardState testBoard = board;
            testBoard.placeMine(candidates[i]);

            // Check if the board is still solvable with this mine
            if (testBoard.isFullySolvable(m_cancelGeneration)) {
                // Accept this mine placement
                board.placeMine(candidates[i]);
                placedMines++;

                // Update placed mines progress - update every few mines or on significant milestones
                if (placedMines % 5 == 0 || placedMines == 1 || placedMines == m_mineCount) {
                    updateProgress(m_currentAttempt.load(), m_totalAttempts.load(), placedMines);
                }
            }
        }

        // Check for cancellation before finalizing
        if (m_cancelGeneration.load()) {
            return false;
        }

        // Check if we placed all mines
        if (placedMines == m_mineCount) {
            // Make sure we show all mines are placed
            updateProgress(m_currentAttempt.load(), m_totalAttempts.load(), m_mineCount);

            // Transfer the generated board to the game state
            m_mines = board.getMines();
            m_numbers = board.calculateNumbers();
            return true;
        }
    }

    // If we couldn't generate a valid board in any attempt
    return false;
}

void GameLogic::generateBoardAsync(int firstClickX, int firstClickY) {
    // Cancel any ongoing generation
    cancelGeneration();

    // Set initial progress values
    const int MAX_ATTEMPTS = 100; // Maximum number of attempts
    updateProgress(1, MAX_ATTEMPTS, 0);

    // Create a new future
    QFuture<void> future = QtConcurrent::run([this, firstClickX, firstClickY, MAX_ATTEMPTS]() {
        // Run the board generation in a separate thread
        bool success = false;
        int attempt = 1;

        // Try repeatedly until success or cancellation
        while (!success && attempt <= MAX_ATTEMPTS && !m_cancelGeneration.load()) {
            // Update attempt counter
            updateProgress(attempt, MAX_ATTEMPTS, 0);

            // Try to generate board
            success = this->generateBoard(firstClickX, firstClickY);

            if (!success && !m_cancelGeneration.load()) {
                attempt++;
            }
        }

        // Clear data if cancelled or failed
        if (m_cancelGeneration.load() || !success) {
            m_mines.clear();
            m_numbers.clear();
        }
    });

    // Set the future to be watched
    m_generationWatcher->setFuture(future);
}

void GameLogic::updateProgress(int attempt, int totalAttempts, int minesPlaced)
{
    // Update the atomic values
    m_currentAttempt.store(attempt);
    m_totalAttempts.store(totalAttempts);
    m_minesPlaced.store(minesPlaced);

    // Emit signals using queued connection to ensure thread safety
    QMetaObject::invokeMethod(this, [this]() {
        emit currentAttemptChanged();
        emit totalAttemptsChanged();
        emit minesPlacedChanged();
    }, Qt::QueuedConnection);
}

// Update cancelGeneration to reset progress
void GameLogic::cancelGeneration()
{
    // Set atomic flag to signal threads to stop
    m_cancelGeneration.store(true);

    // Wait for any running generation to complete
    if (m_generationWatcher->isRunning()) {
        m_generationWatcher->waitForFinished();
    }

    // Reset the flag and progress
    m_cancelGeneration.store(false);
    updateProgress(0, 0, 0);
}
