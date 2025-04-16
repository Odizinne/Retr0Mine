#include <QQueue>
#include <QRandomGenerator>
#include <QMap>
#include "gridgenerator.h"

GridGenerator::GridGenerator(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}()) {
}

GridGenerator::~GridGenerator() {
}

bool GridGenerator::generateBoard(int width, int height, int mineCount, int firstClickX, int firstClickY,
                                  QVector<int>& mines, QVector<int>& numbers, const std::atomic<bool>& cancelFlag,
                                  std::function<void(int, int)> progressCallback) {
    if (cancelFlag.load()) {
        return false;
    }

    bool safeFirstClick = (firstClickX != -1 && firstClickY != -1);
    int firstClickIndex = safeFirstClick ? (firstClickY * width + firstClickX) : -1;

    BoardState board(width, height);
    int startIndex = safeFirstClick ? firstClickIndex : (width * height / 2);
    board.createSafeArea(startIndex);

    QVector<int> candidates = board.getMineCandidates();

    if (cancelFlag.load()) {
        return false;
    }

    // Shuffle candidates for randomness
    for (int i = candidates.size() - 1; i > 0; --i) {
        std::uniform_int_distribution<int> dist(0, i);
        int j = dist(m_rng);
        std::swap(candidates[i], candidates[j]);
    }

    // Calculate adaptive batch size based on mine density
    float mineDensity = static_cast<float>(mineCount) / (width * height);
    int batchSize = std::max(1, std::min(5, static_cast<int>(10 * (1.0f - mineDensity))));

    int placedMines = 0;
    int candidateIndex = 0;

    while (placedMines < mineCount && candidateIndex < candidates.size()) {
        if (cancelFlag.load()) {
            return false;
        }

        // Try to place a batch of mines
        int currentBatchSize = std::min(batchSize,
                                        std::min(mineCount - placedMines,
                                                 static_cast<int>(candidates.size() - candidateIndex)));

        if (currentBatchSize <= 0) break;

        BoardState testBoard = board;
        bool batchValid = true;

        // Place the batch of mines on the test board
        for (int i = 0; i < currentBatchSize; ++i) {
            testBoard.placeMine(candidates[candidateIndex + i]);
        }

        // Check if the board is still solvable with this batch
        if (testBoard.isFullySolvable(cancelFlag)) {
            // Apply the batch to the real board
            for (int i = 0; i < currentBatchSize; ++i) {
                board.placeMine(candidates[candidateIndex + i]);
            }

            placedMines += currentBatchSize;
            candidateIndex += currentBatchSize;

            if (progressCallback) {
                progressCallback(placedMines, mineCount);
            }
        } else {
            // Try placing mines one by one from this batch
            bool anyPlaced = false;
            for (int i = 0; i < currentBatchSize; ++i) {
                if (cancelFlag.load()) {
                    return false;
                }

                BoardState singleTestBoard = board;
                singleTestBoard.placeMine(candidates[candidateIndex]);

                if (singleTestBoard.isFullySolvable(cancelFlag)) {
                    board.placeMine(candidates[candidateIndex]);
                    placedMines++;
                    anyPlaced = true;

                    if (progressCallback && (placedMines % 5 == 0 || placedMines == 1 || placedMines == mineCount)) {
                        progressCallback(placedMines, mineCount);
                    }
                }

                candidateIndex++;
            }

            // If we couldn't place any mines from this batch, reduce the batch size
            if (!anyPlaced && batchSize > 1) {
                batchSize = std::max(1, batchSize / 2);
            }
        }
    }

    if (placedMines == mineCount) {
        if (progressCallback) {
            progressCallback(mineCount, mineCount);
        }

        mines = board.getMines();
        numbers = board.calculateNumbers();
        return true;
    }

    return false;
}

GridGenerator::BoardState::BoardState(int width, int height) : m_width(width), m_height(height) {
    m_cells.resize(width * height);

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

void GridGenerator::BoardState::createSafeArea(int center) {
    m_cells[center].safe = true;
    m_cells[center].revealed = true;

    for (int neighbor : std::as_const(m_cells[center].neighbors)) {
        m_cells[neighbor].safe = true;

        if (QRandomGenerator::global()->bounded(100) < 50) {
            for (int secondNeighbor : std::as_const(m_cells[neighbor].neighbors)) {
                m_cells[secondNeighbor].safe = true;
            }
        }
    }
}

void GridGenerator::BoardState::placeMine(int index) {
    m_cells[index].isMine = true;
    m_mines.append(index);

    for (int neighbor : std::as_const(m_cells[index].neighbors)) {
        m_cells[neighbor].adjacentMines++;
    }
}

QVector<int> GridGenerator::BoardState::getMines() const {
    return m_mines;
}

QVector<int> GridGenerator::BoardState::getMineCandidates() const {
    QVector<int> candidates;
    for (int i = 0; i < m_cells.size(); ++i) {
        if (!m_cells[i].safe && !m_cells[i].isMine) {
            candidates.append(i);
        }
    }
    return candidates;
}

bool GridGenerator::BoardState::isFullySolvable(const std::atomic<bool>& cancelFlag) {
    if (cancelFlag.load()) {
        return false;
    }

    BoardState simBoard = *this;

    for (int i = 0; i < simBoard.m_cells.size(); ++i) {
        if (simBoard.m_cells[i].safe) {
            simBoard.m_cells[i].revealed = true;
        }
    }

    return simBoard.solveCompletely(cancelFlag);
}

QVector<int> GridGenerator::BoardState::calculateNumbers() const {
    QVector<int> numbers(m_cells.size(), 0);

    for (int mine : m_mines) {
        numbers[mine] = -1;
    }

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
                    if (numbers[idx] != -1) {
                        numbers[idx]++;
                    }
                }
            }
        }
    }

    return numbers;
}

bool GridGenerator::BoardState::solveCompletely(const std::atomic<bool>& cancelFlag) {
    QSet<int> processedCells;

    bool progress = true;
    while (progress) {
        if (cancelFlag.load()) {
            return false;
        }

        progress = false;

        for (int i = 0; i < m_cells.size(); ++i) {
            if (!m_cells[i].revealed || processedCells.contains(i)) continue;

            bool hasUnrevealedNeighbors = false;
            for (int neighbor : std::as_const(m_cells[i].neighbors)) {
                if (!m_cells[neighbor].revealed) {
                    hasUnrevealedNeighbors = true;
                    break;
                }
            }

            if (!hasUnrevealedNeighbors) {
                processedCells.insert(i);
                continue;
            }

            int flagCount = 0;
            QVector<int> unrevealed;

            for (int neighbor : std::as_const(m_cells[i].neighbors)) {
                if (m_cells[neighbor].flagged) {
                    flagCount++;
                } else if (!m_cells[neighbor].revealed) {
                    unrevealed.append(neighbor);
                }
            }

            if (flagCount == m_cells[i].adjacentMines && !unrevealed.isEmpty()) {
                for (int safeCell : unrevealed) {
                    m_cells[safeCell].revealed = true;
                    progress = true;
                }
            }
            else if (m_cells[i].adjacentMines - flagCount == unrevealed.size() && !unrevealed.isEmpty()) {
                for (int mineCell : unrevealed) {
                    m_cells[mineCell].flagged = true;
                    progress = true;
                }
            }
        }

        if (!progress) {
            progress = solveWithCSP(cancelFlag);
        }
    }

    for (int i = 0; i < m_cells.size(); ++i) {
        if (!m_cells[i].revealed && !m_cells[i].flagged && !m_cells[i].isMine) {
            return false;
        }
    }

    return true;
}

bool GridGenerator::BoardState::solveWithCSP(const std::atomic<bool>& cancelFlag) {
    if (cancelFlag.load()) {
        return false;
    }

    // Find boundary cells more efficiently
    QVector<int> boundaryCells;
    QSet<int> frontierCellsSet;

    for (int i = 0; i < m_cells.size(); ++i) {
        if (!m_cells[i].revealed) continue;

        bool hasBoundary = false;
        for (int neighbor : std::as_const(m_cells[i].neighbors)) {
            if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                hasBoundary = true;
                frontierCellsSet.insert(neighbor);
            }
        }

        if (hasBoundary) {
            boundaryCells.append(i);
        }
    }

    if (boundaryCells.isEmpty()) return false;
    QVector<int> frontierCells(frontierCellsSet.begin(), frontierCellsSet.end());

    // For smaller frontiers, use the standard approach
    if (frontierCells.size() <= 12) {
        // Limit the number of configurations to evaluate
        QVector<QVector<bool>> possibleConfigs;
        QVector<bool> currentConfig(frontierCells.size(), false);

        // Set a limit on configurations to explore
        const int maxConfigs = 500;
        generateValidConfigurations(boundaryCells, frontierCells, currentConfig, 0, possibleConfigs, cancelFlag, maxConfigs);

        if (cancelFlag.load() || possibleConfigs.isEmpty()) {
            return false;
        }

        // Process the results more efficiently
        QVector<bool> definitelyMines(frontierCells.size(), true);
        QVector<bool> definitelySafe(frontierCells.size(), true);

        for (const auto& config : std::as_const(possibleConfigs)) {
            for (int i = 0; i < config.size(); ++i) {
                if (!config[i]) definitelyMines[i] = false;
                if (config[i]) definitelySafe[i] = false;
            }
        }

        bool progress = false;
        for (int i = 0; i < frontierCells.size(); ++i) {
            int cellIndex = frontierCells[i];

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
    } else {
        // For larger frontiers, use the component-based approach
        return solveLargeCSP(boundaryCells, frontierCells, cancelFlag);
    }
}

bool GridGenerator::BoardState::solveLargeCSP(const QVector<int>& boundaryCells, const QVector<int>& frontierCells, const std::atomic<bool>& cancelFlag) {
    if (cancelFlag.load()) {
        return false;
    }

    // Find connected components of the boundary cells
    QVector<QSet<int>> components;
    QSet<int> visitedBoundary;
    QMap<int, QSet<int>> frontierByBoundary;

    // Pre-compute frontier cells for each boundary cell
    for (int cell : boundaryCells) {
        QSet<int> cellFrontier;
        for (int neighbor : std::as_const(m_cells[cell].neighbors)) {
            if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                cellFrontier.insert(neighbor);
            }
        }
        frontierByBoundary[cell] = cellFrontier;
    }

    // Build connected components
    for (int cell : boundaryCells) {
        if (cancelFlag.load()) return false;
        if (visitedBoundary.contains(cell)) continue;

        QSet<int> component;
        QQueue<int> queue;
        queue.enqueue(cell);
        visitedBoundary.insert(cell);

        while (!queue.isEmpty()) {
            int current = queue.dequeue();
            component.insert(current);

            for (int otherCell : boundaryCells) {
                if (visitedBoundary.contains(otherCell)) continue;

                // Check if these boundary cells share any frontier cells
                if (!frontierByBoundary[current].isEmpty() &&
                    !frontierByBoundary[otherCell].isEmpty() &&
                    !frontierByBoundary[current].intersect(frontierByBoundary[otherCell]).isEmpty()) {
                    queue.enqueue(otherCell);
                    visitedBoundary.insert(otherCell);
                }
            }
        }

        components.append(component);
    }

    // Process each component separately
    bool progress = false;
    for (const auto& component : components) {
        if (cancelFlag.load()) return false;

        // Get frontier for this component
        QSet<int> componentFrontier;
        for (int cell : component) {
            componentFrontier.unite(frontierByBoundary[cell]);
        }

        // Only solve small enough components
        if (componentFrontier.size() <= 12) {
            QVector<int> compBoundary(component.begin(), component.end());
            QVector<int> compFrontier(componentFrontier.begin(), componentFrontier.end());

            QVector<QVector<bool>> possibleConfigs;
            QVector<bool> currentConfig(compFrontier.size(), false);

            generateValidConfigurations(compBoundary, compFrontier, currentConfig, 0, possibleConfigs, cancelFlag);

            if (cancelFlag.load() || possibleConfigs.isEmpty()) continue;

            QVector<bool> definitelyMines(compFrontier.size(), true);
            QVector<bool> definitelySafe(compFrontier.size(), true);

            for (const auto& config : std::as_const(possibleConfigs)) {
                for (int i = 0; i < config.size(); ++i) {
                    if (!config[i]) definitelyMines[i] = false;
                    if (config[i]) definitelySafe[i] = false;
                }
            }

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
    int maxConfigs) {

    // Early exit conditions
    if (cancelFlag.load() || validConfigs.size() >= maxConfigs) return;

    // Reached the end, check if configuration is valid
    if (index == frontierCells.size()) {
        bool valid = true;
        for (int boundaryCell : boundaryCells) {
            int flagCount = 0;
            int expectedMines = m_cells[boundaryCell].adjacentMines;

            for (int neighbor : std::as_const(m_cells[boundaryCell].neighbors)) {
                if (m_cells[neighbor].flagged) {
                    flagCount++;
                } else if (!m_cells[neighbor].revealed) {
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

    // Early pruning: check every few steps if we can already rule out this path
    if (index > 0 && index % 3 == 0) {
        for (int boundaryCell : boundaryCells) {
            int flagCount = 0;
            int possibleFlags = 0;
            int expectedMines = m_cells[boundaryCell].adjacentMines;

            for (int neighbor : std::as_const(m_cells[boundaryCell].neighbors)) {
                if (m_cells[neighbor].flagged) {
                    flagCount++;
                } else if (!m_cells[neighbor].revealed) {
                    int frontierIndex = frontierCells.indexOf(neighbor);
                    if (frontierIndex != -1) {
                        if (frontierIndex < index) {
                            if (currentConfig[frontierIndex]) flagCount++;
                        } else {
                            possibleFlags++;
                        }
                    }
                }
            }

            // Already too many flags or not enough potential flags remaining
            if (flagCount > expectedMines || (flagCount + possibleFlags) < expectedMines) {
                return; // Prune this branch
            }
        }
    }

    // Try setting current cell as not a mine
    currentConfig[index] = false;
    generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);

    if (cancelFlag.load()) return;

    // Try setting current cell as a mine
    currentConfig[index] = true;
    generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);
}
