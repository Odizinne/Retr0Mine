#include "MinesweeperLogic.h"
#include <QDebug>

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

bool MinesweeperLogic::isValid(int x, int y) const
{
    return x >= 0 && x < m_width && y >= 0 && y < m_height;
}

int MinesweeperLogic::toIndex(int x, int y) const
{
    return y * m_width + x;
}

QPoint MinesweeperLogic::fromIndex(int index) const
{
    return QPoint(index % m_width, index / m_width);
}

QVector<int> MinesweeperLogic::getNeighbors(int index) const
{
    QVector<int> neighbors;
    QPoint pos = fromIndex(index);

    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            if (dx == 0 && dy == 0) continue;

            int newX = pos.x() + dx;
            int newY = pos.y() + dy;

            if (isValid(newX, newY)) {
                neighbors.append(toIndex(newX, newY));
            }
        }
    }

    return neighbors;
}

void MinesweeperLogic::calculateNumbers()
{
    m_numbers.fill(0);

    for (int mine : m_mines) {
        QPoint pos = fromIndex(mine);
        m_numbers[mine] = -1;

        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;

                int newX = pos.x() + dx;
                int newY = pos.y() + dy;

                if (isValid(newX, newY)) {
                    int idx = toIndex(newX, newY);
                    if (!m_mines.contains(idx)) {
                        m_numbers[idx]++;
                    }
                }
            }
        }
    }
}

struct Cell {
    bool revealed = false;
    bool flagged = false;
    int number = 0;
    QVector<int> neighbors;
};

bool MinesweeperLogic::hasUnavoidableGuess(QVector<int> numbers, QVector<bool> revealed)
{
    // Helper function to check if a cell has enough revealed neighbors to make a decision
    auto hasEnoughInfo = [&](int x, int y) -> bool {
        if (!isValid(x, y)) return false;
        int idx = toIndex(x, y);
        if (revealed[idx]) return true;

        int revealedNeighbors = 0;
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;
                int nx = x + dx;
                int ny = y + dy;
                if (isValid(nx, ny) && revealed[toIndex(nx, ny)]) {
                    revealedNeighbors++;
                }
            }
        }
        return revealedNeighbors >= 3;  // Cell has at least 3 revealed neighbors
    };

    // Helper function to check if we have a true 50/50 situation
    auto isTrue5050 = [&](int x1, int y1, int x2, int y2) -> bool {
        int idx1 = toIndex(x1, y1);
        int idx2 = toIndex(x2, y2);

        if (revealed[idx1] || revealed[idx2]) return false;

        // Get all revealed neighbors
        QSet<int> neighbors1, neighbors2;
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;

                if (isValid(x1 + dx, y1 + dy)) {
                    int nIdx = toIndex(x1 + dx, y1 + dy);
                    if (revealed[nIdx]) neighbors1.insert(nIdx);
                }

                if (isValid(x2 + dx, y2 + dy)) {
                    int nIdx = toIndex(x2 + dx, y2 + dy);
                    if (revealed[nIdx]) neighbors2.insert(nIdx);
                }
            }
        }

        // Check if both cells share the exact same revealed neighbors
        // and those neighbors provide no distinguishing information
        if (neighbors1 == neighbors2) {
            bool allSameNumber = true;
            int firstNum = -1;
            for (int nIdx : neighbors1) {
                if (firstNum == -1) {
                    firstNum = numbers[nIdx];
                } else if (numbers[nIdx] != firstNum) {
                    allSameNumber = false;
                    break;
                }
            }
            return allSameNumber && firstNum > 0;
        }
        return false;
    };

    // Check for real 50/50 situations
    // Only consider cells that have no additional information available
    for (int y = 0; y < m_height; ++y) {
        for (int x = 0; x < m_width; ++x) {
            // Skip if current cell has enough information
            if (hasEnoughInfo(x, y)) continue;

            // Check horizontally adjacent cells
            if (x < m_width - 1 && !hasEnoughInfo(x + 1, y)) {
                if (isTrue5050(x, y, x + 1, y)) {
                    qDebug() << "Found horizontal 50/50 at" << x << y;
                    return true;
                }
            }

            // Check vertically adjacent cells
            if (y < m_height - 1 && !hasEnoughInfo(x, y + 1)) {
                if (isTrue5050(x, y, x, y + 1)) {
                    qDebug() << "Found vertical 50/50 at" << x << y;
                    return true;
                }
            }
        }
    }

    // Check for isolations (unreachable cells)
    for (int i = 0; i < numbers.size(); ++i) {
        if (revealed[i]) continue;

        QPoint pos = fromIndex(i);
        bool hasPathToRevealed = false;

        // Check if there's any path to a revealed cell
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                if (dx == 0 && dy == 0) continue;
                int nx = pos.x() + dx;
                int ny = pos.y() + dy;
                if (isValid(nx, ny)) {
                    int nIdx = toIndex(nx, ny);
                    if (revealed[nIdx] || hasEnoughInfo(nx, ny)) {
                        hasPathToRevealed = true;
                        break;
                    }
                }
            }
            if (hasPathToRevealed) break;
        }

        if (!hasPathToRevealed) {
            qDebug() << "Found isolated cell at" << pos.x() << pos.y();
            return true;
        }
    }

    return false;
}

bool MinesweeperLogic::isEdge5050Pattern(int x, int y, QVector<int> numbers, QVector<bool> revealed)
{
    QVector<int> neighbors = getNeighbors(toIndex(x, y));
    QVector<int> revealedNeighbors;

    for (int neighbor : neighbors) {
        if (revealed[neighbor]) {
            revealedNeighbors.append(neighbor);
        }
    }

    // Look for patterns that force guessing
    if (revealedNeighbors.size() >= 2) {
        // Check for 1-1 pattern
        int onesCount = 0;
        for (int neighbor : revealedNeighbors) {
            if (numbers[neighbor] == 1) onesCount++;
        }
        if (onesCount >= 2) return true;

        // Check for 1-2 pattern with no additional information
        bool hasOne = false;
        bool hasTwo = false;
        for (int neighbor : revealedNeighbors) {
            if (numbers[neighbor] == 1) hasOne = true;
            if (numbers[neighbor] == 2) hasTwo = true;
        }
        if (hasOne && hasTwo) {
            // Check if there's no additional information available
            bool hasExtraInfo = false;
            for (int neighbor : revealedNeighbors) {
                QVector<int> secondaryNeighbors = getNeighbors(neighbor);
                for (int secondary : secondaryNeighbors) {
                    if (revealed[secondary] && !neighbors.contains(secondary)) {
                        hasExtraInfo = true;
                        break;
                    }
                }
                if (hasExtraInfo) break;
            }
            if (!hasExtraInfo) return true;
        }
    }

    return false;
}

bool MinesweeperLogic::simulateGame(int firstClickIndex, const QVector<int>& testMines)
{
    int totalCells = m_width * m_height;
    QVector<Cell> cells(totalCells);

    qDebug() << "Starting simulation with first click at index:" << firstClickIndex;
    qDebug() << "Total mines:" << testMines.size();

    // Initialize cell numbers and neighbors
    for (int i = 0; i < totalCells; ++i) {
        if (testMines.contains(i)) {
            cells[i].number = -1;
            continue;
        }

        cells[i].neighbors = getNeighbors(i);
        int count = 0;
        for (int neighbor : cells[i].neighbors) {
            if (testMines.contains(neighbor)) count++;
        }
        cells[i].number = count;
    }

    // Recursive reveal function
    std::function<void(int)> revealCell = [&](int index) {
        if (cells[index].revealed || cells[index].flagged || testMines.contains(index)) {
            return;
        }

        cells[index].revealed = true;
        if (cells[index].number == 0) {
            for (int neighbor : cells[index].neighbors) {
                revealCell(neighbor);
            }
        }
    };

    // Start with first click
    revealCell(firstClickIndex);

    bool changed;
    int iterations = 0;
    const int MAX_ITERATIONS = 100;

    do {
        changed = false;
        iterations++;

        // First pass: Basic logic
        for (int i = 0; i < totalCells; ++i) {
            if (!cells[i].revealed || testMines.contains(i)) continue;

            int hiddenCount = 0;
            int flaggedCount = 0;
            QVector<int> hiddenCells;

            for (int neighbor : cells[i].neighbors) {
                if (!cells[neighbor].revealed) {
                    hiddenCount++;
                    hiddenCells.append(neighbor);
                }
                if (cells[neighbor].flagged) flaggedCount++;
            }

            // Basic rule 1: All mines found
            if (cells[i].number == flaggedCount && hiddenCount > flaggedCount) {
                for (int neighbor : hiddenCells) {
                    if (!cells[neighbor].flagged) {
                        revealCell(neighbor);
                        changed = true;
                    }
                }
            }

            // Basic rule 2: All remaining hidden must be mines
            if (cells[i].number - flaggedCount == hiddenCount - flaggedCount) {
                for (int neighbor : hiddenCells) {
                    if (!cells[neighbor].flagged) {
                        cells[neighbor].flagged = true;
                        changed = true;
                    }
                }
            }
        }

    } while (changed && iterations < MAX_ITERATIONS);

    // Create revealed state vector for scoring
    QVector<bool> revealed(totalCells, false);
    int revealedCount = 0;
    for (int i = 0; i < totalCells; ++i) {
        revealed[i] = cells[i].revealed;
        if (cells[i].revealed) revealedCount++;
    }

    float score = calculateSolvabilityScore(revealed, testMines);
    qDebug() << "Final solvability score:" << score;
    qDebug() << "Total revealed cells:" << revealedCount;
    qDebug() << "Total safe cells:" << (totalCells - testMines.size());

    // Check for unavoidable guesses
    QVector<int> numbers(totalCells);
    for (int i = 0; i < totalCells; ++i) {
        numbers[i] = cells[i].number;
    }
    bool hasGuess = hasUnavoidableGuess(numbers, revealed);
    qDebug() << "Has unavoidable guess:" << hasGuess;

    return score > 0.99 && !hasGuess;  // Allow for small floating-point errors
}

float MinesweeperLogic::calculateSolvabilityScore(const QVector<bool>& revealed, const QVector<int>& testMines) const
{
    int totalNonMines = m_width * m_height - testMines.size();
    int revealedNonMines = 0;
    int totalRevealed = 0;

    for (int i = 0; i < revealed.size(); ++i) {
        if (revealed[i]) {
            totalRevealed++;
            if (!testMines.contains(i)) {
                revealedNonMines++;
            }
        }
    }

    qDebug() << "Solvability calculation:";
    qDebug() << "- Total non-mine cells:" << totalNonMines;
    qDebug() << "- Total revealed cells:" << totalRevealed;
    qDebug() << "- Revealed non-mine cells:" << revealedNonMines;

    if (totalNonMines == 0) {
        qDebug() << "Warning: No non-mine cells!";
        return 0.0f;
    }

    float score = static_cast<float>(revealedNonMines) / totalNonMines;
    qDebug() << "- Final score:" << score;
    return score;
}

bool MinesweeperLogic::testSolvability(int firstClickIndex)
{
    // Create a test configuration with current mines
    return simulateGame(firstClickIndex, m_mines);
}

bool MinesweeperLogic::placeMines(int firstClickX, int firstClickY)
{
    int firstClickIndex = toIndex(firstClickX, firstClickY);
    float mineDensity = static_cast<float>(m_mineCount) / (m_width * m_height);

    qDebug() << "Grid size:" << m_width << "x" << m_height;
    qDebug() << "Mine count:" << m_mineCount;
    qDebug() << "Mine density:" << (mineDensity * 100.0f) << "%";

    // Define segment size based on grid dimensions
    const int SEGMENT_SIZE = (m_width >= 40 || m_height >= 30) ? 6 : 8;
    const int SAFE_RADIUS = 3;

    // Create safe zone around first click
    QSet<int> safeZone;
    for (int dy = -SAFE_RADIUS; dy <= SAFE_RADIUS; ++dy) {
        for (int dx = -SAFE_RADIUS; dx <= SAFE_RADIUS; ++dx) {
            int newX = firstClickX + dx;
            int newY = firstClickY + dy;
            if (isValid(newX, newY)) {
                safeZone.insert(toIndex(newX, newY));
            }
        }
    }

    // Calculate segments
    int numSegmentsX = (m_width + SEGMENT_SIZE - 1) / SEGMENT_SIZE;
    int numSegmentsY = (m_height + SEGMENT_SIZE - 1) / SEGMENT_SIZE;

    // Function to get segment index
    auto getSegmentIndex = [&](int x, int y) -> int {
        int segX = x / SEGMENT_SIZE;
        int segY = y / SEGMENT_SIZE;
        return segY * numSegmentsX + segX;
    };

    // Function to check if a position is on the segment boundary
    auto isSegmentBoundary = [&](int x, int y) -> bool {
        return (x % SEGMENT_SIZE == 0) || (y % SEGMENT_SIZE == 0);
    };

    // Function to calculate preferred mine count for a segment
    auto getPreferredMineCount = [&](int segX, int segY) -> int {
        int baseCount = (m_mineCount * SEGMENT_SIZE * SEGMENT_SIZE) / (m_width * m_height);

        // Reduce mines on edges
        if (segX == 0 || segX == numSegmentsX - 1 || segY == 0 || segY == numSegmentsY - 1) {
            baseCount = baseCount * 2 / 3;
        }

        // Increase mines in center segments
        float distToCenter = std::sqrt(
            std::pow(segX - numSegmentsX/2.0f, 2) +
            std::pow(segY - numSegmentsY/2.0f, 2)
            );
        float centerBonus = 1.0f + 0.3f * (1.0f - distToCenter / std::max(numSegmentsX, numSegmentsY));

        return static_cast<int>(baseCount * centerBonus);
    };

    QVector<int> availableCells;
    for (int i = 0; i < m_width * m_height; ++i) {
        if (!safeZone.contains(i)) {
            availableCells.append(i);
        }
    }

    // Parameters for pattern-based placement
    const float BOUNDARY_MINE_CHANCE = 0.3f;  // Chance to place mine on segment boundary
    const int MAX_SEGMENT_ATTEMPTS = 10;      // Attempts to place mines in each segment
    const int MAX_TOTAL_ATTEMPTS = 1000;      // Total generation attempts

    for (int attempt = 0; attempt < MAX_TOTAL_ATTEMPTS; ++attempt) {
        QVector<int> testMines;
        QVector<QVector<int>> segmentMines(numSegmentsX * numSegmentsY);
        QVector<int> currentAvailable = availableCells;

        // First pass: Place mines on segment boundaries
        if (mineDensity > 0.15f) {  // Only for high density boards
            for (int i = currentAvailable.size() - 1; i >= 0; --i) {
                QPoint pos = fromIndex(currentAvailable[i]);
                if (isSegmentBoundary(pos.x(), pos.y())) {
                    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
                    if (dist(m_rng) < BOUNDARY_MINE_CHANCE) {
                        int segIdx = getSegmentIndex(pos.x(), pos.y());
                        segmentMines[segIdx].append(currentAvailable[i]);
                        testMines.append(currentAvailable[i]);
                        currentAvailable.remove(i);
                    }
                }
            }
        }

        // Second pass: Fill segments
        for (int segY = 0; segY < numSegmentsY; ++segY) {
            for (int segX = 0; segX < numSegmentsX; ++segX) {
                int segIdx = segY * numSegmentsX + segX;
                int targetMines = getPreferredMineCount(segX, segY);
                int currentMines = segmentMines[segIdx].size();

                // Filter available cells for this segment
                QVector<int> segmentAvailable;
                for (int cell : currentAvailable) {
                    QPoint pos = fromIndex(cell);
                    if (getSegmentIndex(pos.x(), pos.y()) == segIdx) {
                        segmentAvailable.append(cell);
                    }
                }

                // Place remaining mines for this segment
                int attemptsLeft = MAX_SEGMENT_ATTEMPTS;
                while (currentMines < targetMines && !segmentAvailable.isEmpty() && attemptsLeft > 0) {
                    std::uniform_int_distribution<int> dist(0, segmentAvailable.size() - 1);
                    int idx = dist(m_rng);

                    testMines.append(segmentAvailable[idx]);
                    currentMines++;

                    // Remove from available cells
                    int globalIdx = currentAvailable.indexOf(segmentAvailable[idx]);
                    if (globalIdx >= 0) {
                        currentAvailable.remove(globalIdx);
                    }
                    segmentAvailable.remove(idx);
                    attemptsLeft--;
                }
            }
        }

        // Fill remaining mines if needed
        while (testMines.size() < m_mineCount && !currentAvailable.isEmpty()) {
            std::uniform_int_distribution<int> dist(0, currentAvailable.size() - 1);
            int idx = dist(m_rng);
            testMines.append(currentAvailable[idx]);
            currentAvailable.remove(idx);
        }

        std::sort(testMines.begin(), testMines.end());

        if (simulateGame(firstClickIndex, testMines)) {
            m_mines = testMines;
            calculateNumbers();
            qDebug() << "Found valid configuration on attempt" << (attempt + 1);
            return true;
        }

        if ((attempt + 1) % 50 == 0) {
            qDebug() << "Completed" << (attempt + 1) << "attempts";
        }
    }

    qDebug() << "Failed to find perfectly solvable configuration after" << MAX_TOTAL_ATTEMPTS << "attempts";
    calculateNumbers();
    return false;
}
