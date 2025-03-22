#include "gridgenerator.h"
#include <QQueue>
#include <QRandomGenerator>

GridGenerator::GridGenerator(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{
}

GridGenerator::~GridGenerator()
{
}

bool GridGenerator::generateBoard(int width, int height, int mineCount, int firstClickX, int firstClickY,
                                  QVector<int>& mines, QVector<int>& numbers, const std::atomic<bool>& cancelFlag)
{
    // Check for cancellation at the beginning
    if (cancelFlag.load()) {
        return false;
    }

    // Valid first click coordinates
    bool safeFirstClick = (firstClickX != -1 && firstClickY != -1);
    int firstClickIndex = safeFirstClick ? (firstClickY * width + firstClickX) : -1;

    // Try multiple times to generate a valid board
    const int MAX_ATTEMPTS = 1;

    for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
        // Check for cancellation at the start of each attempt
        if (cancelFlag.load()) {
            return false;
        }

        // Initialize a new board state
        BoardState board(width, height);

        // Start with first click area being safe
        int startIndex = safeFirstClick ? firstClickIndex : (width * height / 2);
        board.createSafeArea(startIndex);

        // Get candidates for mine placement
        QVector<int> candidates = board.getMineCandidates();

        // Check for cancellation before shuffling and mine placement
        if (cancelFlag.load()) {
            return false;
        }

        // Shuffle candidates
        for (int i = candidates.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> dist(0, i);
            int j = dist(m_rng);
            std::swap(candidates[i], candidates[j]);
        }

        // Place mines one by one, ensuring the board remains solvable
        int placedMines = 0;
        for (int i = 0; i < candidates.size() && placedMines < mineCount; ++i) {
            // Check for cancellation inside the mine placement loop
            if (cancelFlag.load()) {
                return false;
            }

            // Create a temporary board to test this mine placement
            BoardState testBoard = board;
            testBoard.placeMine(candidates[i]);

            // Check if the board is still solvable with this mine
            if (testBoard.isFullySolvable(cancelFlag)) {
                // Accept this mine placement
                board.placeMine(candidates[i]);
                placedMines++;
            }
        }

        // Check for cancellation before finalizing
        if (cancelFlag.load()) {
            return false;
        }

        // Check if we placed all mines
        if (placedMines == mineCount) {
            // Transfer the generated board to the output parameters
            mines = board.getMines();
            numbers = board.calculateNumbers();
            return true;
        }
    }

    // If we couldn't generate a valid board in any attempt
    return false;
}

// BoardState implementation
GridGenerator::BoardState::BoardState(int width, int height) : m_width(width), m_height(height)
{
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

void GridGenerator::BoardState::createSafeArea(int center)
{
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

void GridGenerator::BoardState::placeMine(int index)
{
    m_cells[index].isMine = true;
    m_mines.append(index);

    for (int neighbor : m_cells[index].neighbors) {
        m_cells[neighbor].adjacentMines++;
    }
}

QVector<int> GridGenerator::BoardState::getMines() const
{
    return m_mines;
}

QVector<int> GridGenerator::BoardState::getMineCandidates() const
{
    QVector<int> candidates;
    for (int i = 0; i < m_cells.size(); ++i) {
        if (!m_cells[i].safe && !m_cells[i].isMine) {
            candidates.append(i);
        }
    }
    return candidates;
}

bool GridGenerator::BoardState::isFullySolvable(const std::atomic<bool>& cancelFlag)
{
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

QVector<int> GridGenerator::BoardState::calculateNumbers() const
{
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

bool GridGenerator::BoardState::solveCompletely(const std::atomic<bool>& cancelFlag)
{
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

bool GridGenerator::BoardState::solveWithCSP(const std::atomic<bool>& cancelFlag)
{
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

bool GridGenerator::BoardState::solveLargeCSP(const QVector<int>& boundaryCells, const QVector<int>& frontierCells, const std::atomic<bool>& cancelFlag)
{
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

void GridGenerator::BoardState::generateValidConfigurations(
    const QVector<int>& boundaryCells,
    const QVector<int>& frontierCells,
    QVector<bool>& currentConfig,
    int index,
    QVector<QVector<bool>>& validConfigs,
    const std::atomic<bool>& cancelFlag,
    int maxConfigs)
{
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
