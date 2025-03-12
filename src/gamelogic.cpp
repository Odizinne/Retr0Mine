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
            // by testing if mines were generated, and include the seed value
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

QVector<int> GameLogic::calculateNumbersFromMines(int width, int height, const QVector<int> &mines)
{
    // Create a copy of the current width/height to restore later
    int originalWidth = m_width;
    int originalHeight = m_height;

    // Set the temporary dimensions
    m_width = width;
    m_height = height;

    // Create a temporary numbers vector with correct size
    QVector<int> numbers(width * height, 0);

    // Calculate adjacent mine counts (similar to calculateNumbers())
    for (int mine : mines) {
        if (mine < 0 || mine >= width * height) {
            continue; // Skip invalid mine positions
        }

        numbers[mine] = -1; // Mark mine position

        // Get neighbors and update their counts
        QSet<int> neighbors = getNeighbors(mine);
        for (int neighbor : neighbors) {
            if (neighbor < 0 || neighbor >= width * height) {
                continue;
            }

            if (numbers[neighbor] >= 0) {
                numbers[neighbor]++;
            }
        }
    }

    // Debug output
    int nonZeroCount = 0;
    for (int i = 0; i < numbers.size() && nonZeroCount < 10; i++) {
        if (numbers[i] != 0) {
            nonZeroCount++;
        }
    }

    // Restore original dimensions
    m_width = originalWidth;
    m_height = originalHeight;

    return numbers;
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
    qDebug() << "\nStarting logical deduction hint solver...";

    // Convert inputs to sets for faster lookup
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells)
        revealed.insert(cell);
    for (int cell : flaggedCells)
        flagged.insert(cell);

    // STEP 1: Basic deductions - Find obvious mines first
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0)
            continue; // Skip mines and zeros

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

    // STEP 2: Basic deductions - Find obvious safe spots
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0)
            continue; // Skip mines and zeros

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
                     << "\nReason: Cell at" << col << "," << row << "shows"
                     << m_numbers[pos] << "mines and already has"
                     << flagCount << "flags nearby."
                     << "\nSince flags count matches number, all other adjacent cells must be safe.";
            return safePos;
        }
    }

    // STEP 3: Build constraint set for more advanced analysis
    QVector<Constraint> constraints;
    QSet<int> frontier;

    // Find all boundary cells (revealed cells with unrevealed neighbors)
    for (int pos : revealed) {
        if (m_numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos);
        QSet<int> unknownNeighbors;
        int minesRequired = m_numbers[pos];

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                minesRequired--; // Account for already flagged mines
            } else if (!revealed.contains(neighbor)) {
                unknownNeighbors.insert(neighbor);
            }
        }

        if (!unknownNeighbors.isEmpty()) {
            Constraint c;
            c.cell = pos;
            c.minesRequired = minesRequired;
            c.unknowns = unknownNeighbors;
            constraints.append(c);

            // Add these unknown cells to the frontier
            for (int cell : unknownNeighbors) {
                frontier.insert(cell);
            }

            int row = pos / m_width;
            int col = pos % m_width;
            qDebug() << "Constraint from cell at" << col << "," << row
                     << "showing" << m_numbers[pos] << ": needs"
                     << minesRequired << "more mines in" << unknownNeighbors.size() << "cells";
        }
    }

    // STEP 4: Analyze overlapping constraints (like in your example)
    for (int i = 0; i < constraints.size(); i++) {
        for (int j = i + 1; j < constraints.size(); j++) {
            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            // Find the intersection of unknown cells
            QSet<int> shared;
            for (int cell : c1.unknowns) {
                if (c2.unknowns.contains(cell)) {
                    shared.insert(cell);
                }
            }

            if (shared.isEmpty()) continue;

            // Find cells unique to each constraint
            QSet<int> onlyInC1;
            for (int cell : c1.unknowns) {
                if (!shared.contains(cell)) {
                    onlyInC1.insert(cell);
                }
            }

            QSet<int> onlyInC2;
            for (int cell : c2.unknowns) {
                if (!shared.contains(cell)) {
                    onlyInC2.insert(cell);
                }
            }

            // Case matching your example: if a constraint (e.g., "3") has mines that
            // must overlap with another constraint (e.g., "2"), then the cells unique to
            // the second constraint might be deducible

            // If all of c1's mines must be in the shared area
            if (c1.minesRequired >= shared.size()) {
                int minesInShared = qMin(c1.minesRequired, (int)shared.size());
                // If this leaves no mines for c2's exclusive area, they must be safe
                if (c2.minesRequired - minesInShared <= 0 && !onlyInC2.isEmpty()) {
                    int safePos = *onlyInC2.begin();
                    int row1 = c1.cell / m_width;
                    int col1 = c1.cell % m_width;
                    int row2 = c2.cell / m_width;
                    int col2 = c2.cell % m_width;
                    int safeRow = safePos / m_width;
                    int safeCol = safePos % m_width;

                    qDebug() << "\nFound safe spot at" << safeCol << "," << safeRow
                             << "\nReason: Cell at" << col1 << "," << row1 << "needs at least"
                             << minesInShared << "mines in the overlap with cell at"
                             << col2 << "," << row2 << "which only needs" << c2.minesRequired
                             << "mines total. This means cells exclusive to the second constraint must be safe.";

                    return safePos;
                }
            }

            // And vice versa - if all of c2's mines must be in the shared area
            if (c2.minesRequired >= shared.size()) {
                int minesInShared = qMin(c2.minesRequired, (int)shared.size());
                if (c1.minesRequired - minesInShared <= 0 && !onlyInC1.isEmpty()) {
                    int safePos = *onlyInC1.begin();
                    int row1 = c1.cell / m_width;
                    int col1 = c1.cell % m_width;
                    int row2 = c2.cell / m_width;
                    int col2 = c2.cell % m_width;
                    int safeRow = safePos / m_width;
                    int safeCol = safePos % m_width;

                    qDebug() << "\nFound safe spot at" << safeCol << "," << safeRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "needs at least"
                             << minesInShared << "mines in the overlap with cell at"
                             << col1 << "," << row1 << "which only needs" << c1.minesRequired
                             << "mines total. This means cells exclusive to the first constraint must be safe.";

                    return safePos;
                }
            }

            // Case: If c1 must have exactly x mines in the shared area
            if (c1.minesRequired <= onlyInC1.size() + shared.size() &&
                c1.minesRequired >= onlyInC1.size()) {

                int c1MinesInShared = c1.minesRequired - onlyInC1.size();

                // If this forces all of c2's remaining mines to be in its exclusive area
                if (c2.minesRequired - c1MinesInShared == onlyInC2.size() && onlyInC2.size() > 0) {
                    int minePos = *onlyInC2.begin();
                    int row1 = c1.cell / m_width;
                    int col1 = c1.cell % m_width;
                    int row2 = c2.cell / m_width;
                    int col2 = c2.cell % m_width;
                    int mineRow = minePos / m_width;
                    int mineCol = minePos % m_width;

                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: After accounting for overlap between cell at"
                             << col1 << "," << row1 << "and cell at" << col2 << "," << row2
                             << ", all remaining unknown cells for the second constraint must be mines.";

                    return minePos;
                }
            }

            // And vice versa
            if (c2.minesRequired <= onlyInC2.size() + shared.size() &&
                c2.minesRequired >= onlyInC2.size()) {

                int c2MinesInShared = c2.minesRequired - onlyInC2.size();

                // If this forces all of c1's remaining mines to be in its exclusive area
                if (c1.minesRequired - c2MinesInShared == onlyInC1.size() && onlyInC1.size() > 0) {
                    int minePos = *onlyInC1.begin();
                    int row1 = c1.cell / m_width;
                    int col1 = c1.cell % m_width;
                    int row2 = c2.cell / m_width;
                    int col2 = c2.cell % m_width;
                    int mineRow = minePos / m_width;
                    int mineCol = minePos % m_width;

                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: After accounting for overlap between cell at"
                             << col1 << "," << row1 << "and cell at" << col2 << "," << row2
                             << ", all remaining unknown cells for the first constraint must be mines.";

                    return minePos;
                }
            }
        }
    }

    // STEP 5: Subset/superset analysis
    for (int i = 0; i < constraints.size(); i++) {
        for (int j = 0; j < constraints.size(); j++) {
            if (i == j) continue;

            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            // Check if c1's unknowns are a subset of c2's
            bool isSubset = true;
            for (int cell : c1.unknowns) {
                if (!c2.unknowns.contains(cell)) {
                    isSubset = false;
                    break;
                }
            }

            if (isSubset && c1.unknowns.size() < c2.unknowns.size()) {
                // Calculate the difference between the constraints
                QSet<int> diffCells;
                for (int cell : c2.unknowns) {
                    if (!c1.unknowns.contains(cell)) {
                        diffCells.insert(cell);
                    }
                }

                int diffMines = c2.minesRequired - c1.minesRequired;

                int row1 = c1.cell / m_width;
                int col1 = c1.cell % m_width;
                int row2 = c2.cell / m_width;
                int col2 = c2.cell % m_width;

                // If all cells in the difference must be mines
                if (diffMines == diffCells.size() && diffMines > 0) {
                    int mineCell = *diffCells.begin();
                    int mineRow = mineCell / m_width;
                    int mineCol = mineCell % m_width;

                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. The difference of" << diffMines << "mines must be in the remaining"
                             << diffCells.size() << "cells, forcing them all to be mines.";

                    return mineCell;
                }

                // If all cells in the difference must be safe
                if (diffMines == 0 && !diffCells.isEmpty()) {
                    int safeCell = *diffCells.begin();
                    int safeRow = safeCell / m_width;
                    int safeCol = safeCell % m_width;

                    qDebug() << "\nFound safe cell at" << safeCol << "," << safeRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. Since both need the same number of mines, the extra"
                             << diffCells.size() << "cells in the second constraint must be safe.";

                    return safeCell;
                }
            }
        }
    }

    // STEP 6: CSP solving (for smaller frontiers)
    if (frontier.size() <= 16) { // Limit for tractable analysis
        // Convert QSet to QVector for easier indexing
        QVector<int> frontierArray;
        for (int cell : frontier) {
            frontierArray.append(cell);
        }

        // Try all possible configurations (2^n)
        int numConfigs = 1 << frontier.size();

        qDebug() << "Testing" << numConfigs << "possible configurations for" << frontier.size() << "cells";

        // Track which cells are definitely mines or safe
        QVector<bool> definitelyMine(frontier.size(), true);
        QVector<bool> definitelySafe(frontier.size(), true);

        int validConfigs = 0;

        // Test every configuration
        for (int config = 0; config < numConfigs; config++) {
            // Create a configuration with mines represented as bits
            QVector<bool> mineConfig(frontier.size(), false);
            for (int i = 0; i < frontier.size(); i++) {
                mineConfig[i] = (config & (1 << i)) != 0;
            }

            // Check if this configuration satisfies all constraints
            bool valid = true;
            for (const Constraint &constraint : constraints) {
                int minesInConfig = 0;

                // Count mines in this configuration for this constraint
                for (int i = 0; i < frontier.size(); i++) {
                    int cell = frontierArray[i];
                    if (mineConfig[i] && constraint.unknowns.contains(cell)) {
                        minesInConfig++;
                    }
                }

                // If constraint not satisfied, configuration is invalid
                if (minesInConfig != constraint.minesRequired) {
                    valid = false;
                    break;
                }
            }

            if (valid) {
                validConfigs++;

                // Update our definitelyMine and definitelySafe trackers
                for (int i = 0; i < frontier.size(); i++) {
                    if (!mineConfig[i]) definitelyMine[i] = false;
                    if (mineConfig[i]) definitelySafe[i] = false;
                }
            }
        }

        if (validConfigs == 0) {
            qDebug() << "No valid configurations found - may be a logical contradiction";
            return -1;
        }

        qDebug() << "Found" << validConfigs << "valid configurations";

        // Return first definitely safe or definitely mine cell
        for (int i = 0; i < frontier.size(); i++) {
            if (definitelySafe[i]) {
                int row = frontierArray[i] / m_width;
                int col = frontierArray[i] % m_width;
                qDebug() << "\nFound definitely safe cell at" << col << "," << row
                         << "\nReason: This cell is safe in ALL" << validConfigs << "valid configurations";
                return frontierArray[i];
            }
        }

        for (int i = 0; i < frontier.size(); i++) {
            if (definitelyMine[i]) {
                int row = frontierArray[i] / m_width;
                int col = frontierArray[i] % m_width;
                qDebug() << "\nFound definitely mine cell at" << col << "," << row
                         << "\nReason: This cell is a mine in ALL" << validConfigs << "valid configurations";
                return frontierArray[i];
            }
        }
    } else {
        // For larger frontiers, find a localized area to analyze
        int mostConstrained = -1;
        int maxConstraints = 0;

        // Count how many constraints each cell participates in
        QMap<int, int> constraintCount;
        for (const Constraint &c : constraints) {
            for (int cell : c.unknowns) {
                constraintCount[cell]++;
                if (constraintCount[cell] > maxConstraints) {
                    maxConstraints = constraintCount[cell];
                    mostConstrained = cell;
                }
            }
        }

        if (mostConstrained != -1 && maxConstraints >= 2) {
            // Find the local subproblem around this cell
            QSet<int> localArea;
            QVector<Constraint> localConstraints;

            // First, get all constraints involving this cell
            for (const Constraint &c : constraints) {
                if (c.unknowns.contains(mostConstrained)) {
                    localConstraints.append(c);
                    for (int cell : c.unknowns) {
                        localArea.insert(cell);
                    }
                }
            }

            // If local area is small enough, solve it
            if (localArea.size() <= 16) {
                // Convert QSet to QVector
                QVector<int> localArray;
                for (int cell : localArea) {
                    localArray.append(cell);
                }

                // Run CSP on the local subproblem
                int numConfigs = 1 << localArea.size();
                QVector<bool> definitelyMine(localArea.size(), true);
                QVector<bool> definitelySafe(localArea.size(), true);
                int validConfigs = 0;

                for (int config = 0; config < numConfigs; config++) {
                    QVector<bool> mineConfig(localArea.size(), false);
                    for (int i = 0; i < localArea.size(); i++) {
                        mineConfig[i] = (config & (1 << i)) != 0;
                    }

                    bool valid = true;
                    for (const Constraint &constraint : localConstraints) {
                        int minesInConfig = 0;

                        for (int i = 0; i < localArea.size(); i++) {
                            int cell = localArray[i];
                            if (mineConfig[i] && constraint.unknowns.contains(cell)) {
                                minesInConfig++;
                            }
                        }

                        if (minesInConfig != constraint.minesRequired) {
                            valid = false;
                            break;
                        }
                    }

                    if (valid) {
                        validConfigs++;

                        for (int i = 0; i < localArea.size(); i++) {
                            if (!mineConfig[i]) definitelyMine[i] = false;
                            if (mineConfig[i]) definitelySafe[i] = false;
                        }
                    }
                }

                // Return first definite cell we find
                for (int i = 0; i < localArea.size(); i++) {
                    if (definitelySafe[i]) {
                        return localArray[i];
                    }
                }

                for (int i = 0; i < localArea.size(); i++) {
                    if (definitelyMine[i]) {
                        return localArray[i];
                    }
                }
            }
        }
    }

    // No solution found
    qDebug() << "No definite solution found through logical deduction";
    return -1;
}

int GameLogic::solveFrontierCSP(const QVector<Constraint> &constraints, const QList<int> &frontier)
{
    qDebug() << "Running CSP solver for" << frontier.size() << "frontier cells...";
    QVector<int> frontierArray = frontier.toVector();

    // Try all possible configurations of mines in the frontier
    int numConfigs = 1 << frontier.size(); // 2^n configurations

    qDebug() << "Testing" << numConfigs << "possible configurations";

    // For each frontier cell, track if it's always mine, always safe, or uncertain
    QVector<bool> definitelyMine(frontier.size(), true);
    QVector<bool> definitelySafe(frontier.size(), true);

    int validConfigs = 0;

    // Test every possible configuration of mines in the frontier
    for (int config = 0; config < numConfigs; config++) {
        // Create a bit vector representing this configuration
        QVector<bool> mineConfig(frontier.size(), false);
        for (int i = 0; i < frontier.size(); i++) {
            mineConfig[i] = (config & (1 << i)) != 0;
        }

        // Check if this configuration satisfies all constraints
        bool valid = true;
        for (const Constraint &constraint : constraints) {
            int minesInConfig = 0;

            // Count mines in this configuration that affect this constraint
            for (int i = 0; i < frontier.size(); i++) {
                int cell = frontierArray[i];
                if (mineConfig[i] && constraint.unknowns.contains(cell)) {
                    minesInConfig++;
                }
            }

            // If this constraint isn't satisfied, this configuration is invalid
            if (minesInConfig != constraint.minesRequired) {
                valid = false;
                break;
            }
        }

        if (valid) {
            validConfigs++;

            // Update our definitelyMine and definitelySafe trackers
            for (int i = 0; i < frontier.size(); i++) {
                if (!mineConfig[i]) definitelyMine[i] = false;
                if (mineConfig[i]) definitelySafe[i] = false;
            }
        }
    }

    if (validConfigs == 0) {
        qDebug() << "No valid configurations found - the board may be unsolvable or have a logical contradiction";
        return -1;
    }

    qDebug() << "Found" << validConfigs << "valid configurations out of" << numConfigs << "possibilities";

    // Return the first definitely safe or definitely mine cell we find
    for (int i = 0; i < frontier.size(); i++) {
        if (definitelySafe[i]) {
            int row = frontierArray[i] / m_width;
            int col = frontierArray[i] % m_width;
            qDebug() << "\nFound definitely safe cell at" << col << "," << row
                     << "\nReason: This cell is safe in ALL" << validConfigs << "valid configurations"
                     << "\nThis means no matter how the other cells are arranged, this cell cannot be a mine";
            return frontierArray[i];
        }
    }

    for (int i = 0; i < frontier.size(); i++) {
        if (definitelyMine[i]) {
            int row = frontierArray[i] / m_width;
            int col = frontierArray[i] % m_width;
            qDebug() << "\nFound definitely mine cell at" << col << "," << row
                     << "\nReason: This cell is a mine in ALL" << validConfigs << "valid configurations"
                     << "\nThis means no matter how the other cells are arranged, this cell must be a mine";
            return frontierArray[i];
        }
    }

    qDebug() << "No cells were definitively safe or mines in all configurations";
    return -1; // No definite conclusions
}

int GameLogic::solveWithConstraintIntersection(const QVector<Constraint> &constraints, const QList<int> &frontier)
{
    qDebug() << "Using constraint intersection methods for large frontier";

    // Look for cells that satisfy special conditions across constraints

    // First, look for "subset" constraints
    // If one constraint's unknowns are a subset of another's, we can deduce things
    qDebug() << "Checking for subset relationships between constraints...";
    for (int i = 0; i < constraints.size(); i++) {
        for (int j = 0; j < constraints.size(); j++) {
            if (i == j) continue;

            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            // Check if c1's unknowns are a subset of c2's
            bool isSubset = true;
            for (int cell : c1.unknowns) {
                if (!c2.unknowns.contains(cell)) {
                    isSubset = false;
                    break;
                }
            }

            if (isSubset && c1.unknowns.size() < c2.unknowns.size()) {
                // Calculate the difference between the constraints
                QSet<int> diffCells = c2.unknowns - c1.unknowns;
                int diffMines = c2.minesRequired - c1.minesRequired;

                int row1 = c1.cell / m_width;
                int col1 = c1.cell % m_width;
                int row2 = c2.cell / m_width;
                int col2 = c2.cell % m_width;

                qDebug() << "Found subset relationship: Cell" << col1 << "," << row1
                         << "is a subset of cell" << col2 << "," << row2
                         << "with" << diffCells.size() << "different cells and" << diffMines << "mine difference";

                // If all cells in the difference must be mines
                if (diffMines == diffCells.size() && diffMines > 0) {
                    int mineCell = *diffCells.begin();
                    int mineRow = mineCell / m_width;
                    int mineCol = mineCell % m_width;
                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. The difference of" << diffMines << "mines must be in the remaining"
                             << diffCells.size() << "cells, forcing them all to be mines.";
                    return mineCell;
                }

                // If all cells in the difference must be safe
                if (diffMines == 0 && !diffCells.isEmpty()) {
                    int safeCell = *diffCells.begin();
                    int safeRow = safeCell / m_width;
                    int safeCol = safeCell % m_width;
                    qDebug() << "\nFound safe cell at" << safeCol << "," << safeRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. Since both need the same number of mines, the extra"
                             << diffCells.size() << "cells in the second constraint must be safe.";
                    return safeCell;
                }
            }
        }
    }

    // Look for "most constrained" cells
    qDebug() << "Looking for cells involved in multiple constraints...";

    QMap<int, int> cellConstraintCount;
    QMap<int, QSet<int>> cellsToConstraints;

    for (int i = 0; i < constraints.size(); i++) {
        const Constraint &c = constraints[i];
        for (int cell : c.unknowns) {
            cellConstraintCount[cell]++;
            cellsToConstraints[cell].insert(i);
        }
    }

    // Find the cell involved in the most constraints
    int mostConstrainedCell = -1;
    int maxConstraints = 0;
    for (auto it = cellConstraintCount.begin(); it != cellConstraintCount.end(); ++it) {
        if (it.value() > maxConstraints) {
            mostConstrainedCell = it.key();
            maxConstraints = it.value();
        }
    }

    // If we found a highly constrained cell, try it as a hint
    if (mostConstrainedCell != -1 && maxConstraints >= 3) {
        int row = mostConstrainedCell / m_width;
        int col = mostConstrainedCell % m_width;

        QStringList constraintDescriptions;
        for (int constraintIdx : cellsToConstraints[mostConstrainedCell]) {
            const Constraint &c = constraints[constraintIdx];
            int cRow = c.cell / m_width;
            int cCol = c.cell % m_width;
            constraintDescriptions.append(QString("Cell at %1,%2 (needs %3 mines in %4 cells)")
                                              .arg(cCol).arg(cRow)
                                              .arg(c.minesRequired).arg(c.unknowns.size()));
        }

        qDebug() << "\nSuggesting highly constrained cell at" << col << "," << row
                 << "\nReason: This cell is involved in" << maxConstraints << "different constraints:"
                 << "\n" << constraintDescriptions.join("\n")
                 << "\nResolving this cell will provide the most information about the board.";
        return mostConstrainedCell;
    }

    // If all else fails, just return a random frontier cell, but with explanation
    if (!frontier.isEmpty()) {
        int randomCell = frontier.first();
        int row = randomCell / m_width;
        int col = randomCell % m_width;
        qDebug() << "\nSuggesting frontier cell at" << col << "," << row
                 << "\nReason: No definite solution found with current information."
                 << "\nThis cell is on the frontier (adjacent to revealed cells) and may help uncover more information.";
        return randomCell;
    }

    qDebug() << "No viable hint found";
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

QVariantMap GameLogic::findMineHintWithReasoning(const QVector<int> &revealedCells, const QVector<int> &flaggedCells)
{
    QVariantMap result;
    QString explanation;

    // First check for basic deductions
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells)
        revealed.insert(cell);
    for (int cell : flaggedCells)
        flagged.insert(cell);

    // Check basic scenarios first with explanations
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

                    explanation = tr("I think there's a mine at position (%1,%2). The cell at (%3,%4) shows %5 mines and already has %6 flags nearby. With %7 unrevealed cells remaining, they must all be mines.")
                                      .arg(mineCol+1).arg(mineRow+1).arg(col+1).arg(row+1)
                                      .arg(m_numbers[pos]).arg(flagCount).arg(unrevealedCells.size());

                    result["cell"] = minePos;
                    result["explanation"] = explanation;
                    return result;
                }
            }
        }
    }

    // Check for safe cells
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

            explanation = tr("The cell at position (%1,%2) should be safe. I see that position (%3,%4) has %5 mines around it and already has exactly %5 flags placed nearby. This means all other adjacent cells must be safe.")
                              .arg(safeCol+1).arg(safeRow+1).arg(col+1).arg(row+1)
                              .arg(m_numbers[pos]);

            result["cell"] = safePos;
            result["explanation"] = explanation;
            return result;
        }
    }

    // Call the original solver logic without capturing logs
    int solverResult = solveForHint(revealedCells, flaggedCells);

    // If we found a result but don't have an explanation yet, provide a generic one
    if (solverResult != -1 && explanation.isEmpty()) {
        int row = solverResult / m_width;
        int col = solverResult % m_width;

        // Try to determine if it's a mine or safe cell by checking against mines list
        bool isMine = false;
        for (int mine : m_mines) {
            if (mine == solverResult) {
                isMine = true;
                break;
            }
        }

        if (isMine) {
            explanation = tr("Based on the pattern of numbers, I believe there's a mine at position (%1,%2).")
            .arg(col+1).arg(row+1);
        } else {
            explanation = tr("Looking at the surrounding numbers, the cell at position (%1,%2) appears to be safe.")
            .arg(col+1).arg(row+1);
        }
    }

    result["cell"] = solverResult;
    result["explanation"] = explanation;
    return result;
}
