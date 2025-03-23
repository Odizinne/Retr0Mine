#include <QQueue>
#include <QRandomGenerator>
#include <QtConcurrent>
#include <QThreadPool>
#include <QMutex>
#include <QSemaphore>
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
    // Start timing
    QElapsedTimer timer;
    timer.start();

    if (cancelFlag.load()) {
        return false;
    }

    bool safeFirstClick = (firstClickX != -1 && firstClickY != -1);
    int firstClickIndex = safeFirstClick ? (firstClickY * width + firstClickX) : -1;

    BoardState board(width, height);
    int startIndex = safeFirstClick ? firstClickIndex : (width * height / 2);
    board.createSafeArea(startIndex);

    QVector<int> candidates = board.getMineCandidates();
    if (candidates.isEmpty() || cancelFlag.load()) {
        return false;
    }

    // Shuffle candidates
    for (int i = candidates.size() - 1; i > 0; --i) {
        std::uniform_int_distribution<int> dist(0, i);
        int j = dist(m_rng);
        std::swap(candidates[i], candidates[j]);
    }

    QMutex mutex;
    QAtomicInt validatedCount(0);
    QAtomicInt validFoundCount(0);
    QVector<bool> validMines(candidates.size(), false);

    // Report initial progress state
    if (progressCallback) {
        progressCallback(0, mineCount);
    }

    // Validate all potential mine positions in parallel
    QThreadPool::globalInstance()->setMaxThreadCount(QThread::idealThreadCount());

    QtConcurrent::blockingMap(candidates, [&](int candidatePos) {
        if (cancelFlag.load() || validFoundCount >= mineCount) {
            return;
        }

        BoardState testBoard = board;
        testBoard.placeMine(candidatePos);

        if (testBoard.isFullySolvable(cancelFlag)) {
            QMutexLocker locker(&mutex);
            int idx = candidates.indexOf(candidatePos);
            if (idx >= 0) {
                validMines[idx] = true;
                int found = validFoundCount.fetchAndAddRelaxed(1) + 1;

                // Update progress based on how many valid mines we've found
                if (progressCallback && (found % 5 == 0 || found == 1 || found == mineCount)) {
                    progressCallback(found, mineCount);
                }
            }
        }

        // Update total validations counter for debugging
        validatedCount.fetchAndAddRelaxed(1);
    });

    // Place mines sequentially based on pre-validated positions
    int placed = 0;
    for (int i = 0; i < candidates.size() && placed < mineCount; ++i) {
        if (validMines[i]) {
            board.placeMine(candidates[i]);
            placed++;
        }
    }

    if (cancelFlag.load()) {
        return false;
    }

    if (placed == mineCount) {
        if (progressCallback) {
            progressCallback(mineCount, mineCount);
        }

        mines = board.getMines();
        numbers = board.calculateNumbers();

        // Calculate elapsed time and print it
        qint64 elapsed = timer.elapsed();
        qint64 seconds = elapsed / 1000;
        qint64 milliseconds = elapsed % 1000;
        qDebug() << "Board generation completed in" << seconds << "seconds and"
                 << milliseconds << "milliseconds. Validated " << validatedCount
                 << " positions to find " << validFoundCount << " valid mines.";

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

    for (int neighbor : m_cells[center].neighbors) {
        m_cells[neighbor].safe = true;

        if (QRandomGenerator::global()->bounded(100) < 50) {
            for (int secondNeighbor : m_cells[neighbor].neighbors) {
                m_cells[secondNeighbor].safe = true;
            }
        }
    }
}

void GridGenerator::BoardState::placeMine(int index) {
    m_cells[index].isMine = true;
    m_mines.append(index);

    for (int neighbor : m_cells[index].neighbors) {
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

            int flagCount = 0;
            QVector<int> unrevealed;

            for (int neighbor : m_cells[i].neighbors) {
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

    QSet<int> frontierCells;
    for (int cell : boundaryCells) {
        for (int neighbor : m_cells[cell].neighbors) {
            if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                frontierCells.insert(neighbor);
            }
        }
    }

    if (cancelFlag.load()) {
        return false;
    }

    if (frontierCells.size() > 12) {
        return solveLargeCSP(boundaryCells, QVector<int>(frontierCells.begin(), frontierCells.end()), cancelFlag);
    }

    QVector<QVector<bool>> possibleConfigs;
    QVector<bool> currentConfig(frontierCells.size(), false);
    QVector<int> frontierList(frontierCells.begin(), frontierCells.end());

    generateValidConfigurations(boundaryCells, frontierList, currentConfig, 0, possibleConfigs, cancelFlag);

    if (cancelFlag.load()) {
        return false;
    }

    if (possibleConfigs.isEmpty()) {
        return false;
    }

    QVector<bool> definitelyMines(frontierList.size(), true);
    QVector<bool> definitelySafe(frontierList.size(), true);

    for (const auto& config : possibleConfigs) {
        for (int i = 0; i < config.size(); ++i) {
            if (!config[i]) definitelyMines[i] = false;
            if (config[i]) definitelySafe[i] = false;
        }
    }

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

bool GridGenerator::BoardState::solveLargeCSP(const QVector<int>& boundaryCells, const QVector<int>& frontierCells, const std::atomic<bool>& cancelFlag) {
    if (cancelFlag.load()) {
        return false;
    }

    QVector<QSet<int>> components;
    QSet<int> visitedBoundary;

    for (int cell : boundaryCells) {
        if (cancelFlag.load()) {
            return false;
        }

        if (visitedBoundary.contains(cell)) continue;

        QSet<int> component;
        QQueue<int> queue;
        queue.enqueue(cell);
        visitedBoundary.insert(cell);

        while (!queue.isEmpty()) {
            if (cancelFlag.load()) {
                return false;
            }

            int current = queue.dequeue();
            component.insert(current);

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

    bool progress = false;
    for (const auto& component : components) {
        if (cancelFlag.load()) {
            return false;
        }

        QSet<int> componentFrontier;
        for (int cell : component) {
            for (int neighbor : m_cells[cell].neighbors) {
                if (!m_cells[neighbor].revealed && !m_cells[neighbor].flagged) {
                    componentFrontier.insert(neighbor);
                }
            }
        }

        if (componentFrontier.size() <= 12) {
            QVector<int> compBoundary(component.begin(), component.end());
            QVector<int> compFrontier(componentFrontier.begin(), componentFrontier.end());

            QVector<QVector<bool>> possibleConfigs;
            QVector<bool> currentConfig(compFrontier.size(), false);

            generateValidConfigurations(compBoundary, compFrontier, currentConfig, 0, possibleConfigs, cancelFlag);

            if (cancelFlag.load()) {
                return false;
            }

            if (possibleConfigs.isEmpty()) {
                return false;
            }

            QVector<bool> definitelyMines(compFrontier.size(), true);
            QVector<bool> definitelySafe(compFrontier.size(), true);

            for (const auto& config : possibleConfigs) {
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
    if (cancelFlag.load() || validConfigs.size() >= maxConfigs) return;

    if (index == frontierCells.size()) {
        bool valid = true;
        for (int boundaryCell : boundaryCells) {
            int flagCount = 0;
            int expectedMines = m_cells[boundaryCell].adjacentMines;

            for (int neighbor : m_cells[boundaryCell].neighbors) {
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

    currentConfig[index] = false;
    generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);

    if (cancelFlag.load()) return;

    currentConfig[index] = true;
    generateValidConfigurations(boundaryCells, frontierCells, currentConfig, index + 1, validConfigs, cancelFlag, maxConfigs);
}
