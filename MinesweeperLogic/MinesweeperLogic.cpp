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

void MinesweeperLogic::calculateNumbers()
{
    m_numbers.fill(0);

    for (int i = 0; i < m_width * m_height; ++i) {
        if (m_mines.contains(i)) {
            m_numbers[i] = -1;
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
                if (m_mines.contains(pos)) count++;
            }
        }

        m_numbers[i] = count;
    }
}

QVector<int> MinesweeperLogic::calculateNumbersForValidation(const QVector<int>& mines)
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

bool MinesweeperLogic::canDeduce(int pos, const QSet<int>& revealed,
                                 const QVector<int>& mines,
                                 const QVector<int>& numbers)
{
    int row = pos / m_width;
    int col = pos % m_width;

    // Check all revealed neighbors
    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int checkRow = row + r;
            int checkCol = col + c;

            if (checkRow < 0 || checkRow >= m_height ||
                checkCol < 0 || checkCol >= m_width) continue;

            int checkPos = checkRow * m_width + checkCol;

            if (revealed.contains(checkPos)) {
                int surroundingMines = 0;
                QVector<int> hiddenCells;

                // Count surrounding mines and hidden cells
                for (int dr = -1; dr <= 1; ++dr) {
                    for (int dc = -1; dc <= 1; ++dc) {
                        if (dr == 0 && dc == 0) continue;

                        int adjacentRow = checkRow + dr;
                        int adjacentCol = checkCol + dc;

                        if (adjacentRow < 0 || adjacentRow >= m_height ||
                            adjacentCol < 0 || adjacentCol >= m_width) continue;

                        int adjacentPos = adjacentRow * m_width + adjacentCol;

                        if (mines.contains(adjacentPos)) {
                            ++surroundingMines;
                        } else if (!revealed.contains(adjacentPos)) {
                            hiddenCells.append(adjacentPos);
                        }
                    }
                }

                // If all mines are found, remaining cells are safe
                if (numbers[checkPos] == surroundingMines &&
                    hiddenCells.contains(pos)) {
                    return true;
                }

                // If remaining hidden cells equal remaining mines, all are mines
                int remainingMines = numbers[checkPos] - surroundingMines;
                if (remainingMines == hiddenCells.size() &&
                    hiddenCells.contains(pos)) {
                    return mines.contains(pos);
                }
            }
        }
    }

    return false;
}

MinesweeperLogic::SolvabilityResult MinesweeperLogic::testSolvability(
    const QVector<int>& testMines, int firstClickIndex)
{
    QSet<int> revealed;
    QSet<int> flagged;
    bool changed = true;

    // Calculate numbers for the test configuration
    QVector<int> testNumbers = calculateNumbersForValidation(testMines);

    // Recursive reveal function
    std::function<void(int)> revealCell = [&](int pos) {
        if (revealed.contains(pos) || flagged.contains(pos) || testMines.contains(pos)) {
            return;
        }

        revealed.insert(pos);

        if (testNumbers[pos] == 0) {
            int row = pos / m_width;
            int col = pos % m_width;

            for (int r = -1; r <= 1; ++r) {
                for (int c = -1; c <= 1; ++c) {
                    if (r == 0 && c == 0) continue;

                    int newRow = row + r;
                    int newCol = col + c;

                    if (newRow >= 0 && newRow < m_height &&
                        newCol >= 0 && newCol < m_width) {
                        int newPos = newRow * m_width + newCol;
                        if (!revealed.contains(newPos)) {
                            revealCell(newPos);
                        }
                    }
                }
            }
        }
    };

    // First click
    revealCell(firstClickIndex);

    // Keep applying logical rules until no more progress can be made
    while (changed) {
        changed = false;
        for (int i = 0; i < m_width * m_height; ++i) {
            if (!revealed.contains(i) && !flagged.contains(i) && !testMines.contains(i)) {
                if (canDeduce(i, revealed, testMines, testNumbers)) {
                    revealCell(i);
                    changed = true;
                }
            }
        }
    }

    // Count solvable cells
    int solvableCells = 0;
    for (int i = 0; i < m_width * m_height; ++i) {
        if (!testMines.contains(i) && revealed.contains(i)) {
            ++solvableCells;
        }
    }

    // Calculate solvability percentage
    int totalNonMineCells = m_width * m_height - testMines.size();
    float percentage = (static_cast<float>(solvableCells) / totalNonMineCells) * 100.0f;

    qDebug() << "Solvability Test:";
    qDebug() << "- Solvable cells:" << solvableCells;
    qDebug() << "- Total non-mine cells:" << totalNonMineCells;
    qDebug() << "- Solvability percentage:" << percentage;

    return {solvableCells, percentage};
}

bool MinesweeperLogic::isCornerPosition(int pos) {
    int row = pos / m_width;
    int col = pos % m_width;

    // Check if position is in any corner
    return (row == 0 && col == 0) ||                    // Top-left
           (row == 0 && col == m_width - 1) ||          // Top-right
           (row == m_height - 1 && col == 0) ||         // Bottom-left
           (row == m_height - 1 && col == m_width - 1); // Bottom-right
}

bool MinesweeperLogic::wouldCreateCornerProblem(int pos, const QVector<int>& currentMines) {
    int row = pos / m_width;
    int col = pos % m_width;

    // If this position is in a corner, check adjacent positions for mines
    if (isCornerPosition(pos)) {
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    int checkPos = newRow * m_width + newCol;
                    if (currentMines.contains(checkPos)) {
                        return true;
                    }
                }
            }
        }
    } else {
        // If this is adjacent to a corner, check if the corner has a mine
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    int checkPos = newRow * m_width + newCol;
                    if (isCornerPosition(checkPos) && currentMines.contains(checkPos)) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

bool MinesweeperLogic::placeMines(int firstClickX, int firstClickY) {
    int firstClickIndex = firstClickY * m_width + firstClickX;
    int maxAttempts = 100; // Increased attempts since we have more constraints

    qDebug() << "Starting mine placement...";
    qDebug() << "Grid size:" << m_width << "x" << m_height;
    qDebug() << "Mine count:" << m_mineCount;
    qDebug() << "First click:" << firstClickX << "," << firstClickY;

    for (int attempt = 0; attempt < maxAttempts; ++attempt) {
        QVector<int> currentMines;

        // Create safe zone around first click
        QSet<int> safeZone;
        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                int newRow = firstClickY + r;
                int newCol = firstClickX + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    safeZone.insert(newRow * m_width + newCol);
                }
            }
        }

        // Place mines randomly with corner constraints
        std::uniform_int_distribution<int> dist(0, m_width * m_height - 1);
        int placementAttempts = 0;
        const int maxPlacementAttempts = m_width * m_height * 10; // Prevent infinite loops

        while (currentMines.size() < m_mineCount && placementAttempts < maxPlacementAttempts) {
            int pos = dist(m_rng);
            if (!safeZone.contains(pos) &&
                !currentMines.contains(pos) &&
                !wouldCreateCornerProblem(pos, currentMines)) {
                currentMines.append(pos);
            }
            placementAttempts++;
        }

        // If we couldn't place all mines, try again
        if (currentMines.size() < m_mineCount) {
            qDebug() << "Failed to place all mines with corner constraints, retrying...";
            continue;
        }

        // Test configuration solvability
        auto solvabilityResult = testSolvability(currentMines, firstClickIndex);
        qDebug() << "Solvability percentage:" << solvabilityResult.percentage;

        if (solvabilityResult.percentage == 100.0f) {
            qDebug() << "Found perfect configuration!";
            m_mines = currentMines;
            calculateNumbers();
            return true;
        }

        if (attempt < maxAttempts - 1) {
            qDebug() << "Configuration not perfectly solvable, trying again...";
        }
    }

    qDebug() << "Failed to find perfectly solvable configuration";
    return false;
}
