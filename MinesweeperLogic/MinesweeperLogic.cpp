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

bool MinesweeperLogic::hasUnsolvablePattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    // Check all pattern types
    if (checkBasicUnsolvablePattern(testMines, revealed)) {
        return true;
    }

    if (checkDoubleCornerPattern(testMines, revealed)) {
        return true;
    }

    if (checkLinearPattern(testMines, revealed)) {
        return true;
    }

    if (checkDiagonalPattern(testMines, revealed)) {
        return true;
    }

    if (checkCornerDeadEndPattern(testMines, revealed)) {
        return true;
    }

    return false;
}

bool MinesweeperLogic::checkCornerDeadEndPattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    for (int row = 0; row < m_height - 1; ++row) {
        for (int col = 0; col < m_width - 1; ++col) {
            // Get positions in the 2x2 pattern
            int threePos = row * m_width + col;      // Position of 3
            int rightPos = threePos + 1;             // Right of 3
            int bottomLeft = (row + 1) * m_width + col;  // Position of 1
            int bottomRight = bottomLeft + 1;        // Bottom right ?

            // Check for revealed 3 and 1 pattern
            if (revealed.contains(threePos) && revealed.contains(bottomLeft) &&
                !revealed.contains(bottomRight)) {

                auto numbers = calculateNumbersForValidation(testMines);

                // Check if we have 3 and 1 pattern where:
                // - The 3 already has all its mines accounted for
                // - The 1 needs exactly one mine
                // - There are two possible positions for that one mine
                if (numbers[threePos] == 3 && numbers[bottomLeft] == 1) {
                    int minesAroundThree = countConfirmedMines(threePos, testMines);
                    int minesAroundOne = countConfirmedMines(bottomLeft, testMines);

                    if (minesAroundThree == 3 && // 3 has all its mines
                        minesAroundOne == 0 &&   // 1 has no mines yet
                        !revealed.contains(bottomRight)) { // Last position unrevealed
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

bool MinesweeperLogic::checkBasicUnsolvablePattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    for (int row = 0; row < m_height; ++row) {
        for (int col = 0; col < m_width; ++col) {
            int pos = row * m_width + col;

            if (revealed.contains(pos)) {
                continue;
            }

            QVector<int> unrevealedNeighbors;
            QVector<int> revealedNumbers;
            int confirmedMines = 0;

            // Check all neighbors
            for (int r = -1; r <= 1; ++r) {
                for (int c = -1; c <= 1; ++c) {
                    if (r == 0 && c == 0) continue;

                    int newRow = row + r;
                    int newCol = col + c;

                    if (newRow < 0 || newRow >= m_height ||
                        newCol < 0 || newCol >= m_width) continue;

                    int neighborPos = newRow * m_width + newCol;

                    if (revealed.contains(neighborPos)) {
                        revealedNumbers.append(neighborPos);
                    } else if (!testMines.contains(neighborPos)) {
                        unrevealedNeighbors.append(neighborPos);
                    } else {
                        confirmedMines++;
                    }
                }
            }

            // Basic 50-50 pattern check
            if (unrevealedNeighbors.size() == 1 && !testMines.contains(pos)) {
                int otherCell = unrevealedNeighbors.first();
                if (!testMines.contains(otherCell) && !revealedNumbers.isEmpty() &&
                    requiresOneMineBetween(pos, otherCell, testMines, revealed)) {
                    return true;
                }
            }
        }
    }
    return false;
}

bool MinesweeperLogic::checkDoubleCornerPattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    for (int row = 0; row < m_height - 1; ++row) {
        for (int col = 0; col < m_width - 1; ++col) {
            int pos1 = row * m_width + col;
            int pos2 = pos1 + 1;
            int pos3 = (row + 1) * m_width + col;
            int pos4 = pos3 + 1;

            // Check for 2x2 pattern with unrevealed top cells
            if (!revealed.contains(pos1) && !revealed.contains(pos2) &&
                revealed.contains(pos3) && revealed.contains(pos4)) {

                auto numbers = calculateNumbersForValidation(testMines);
                int num3 = numbers[pos3];
                int num4 = numbers[pos4];

                // Check if this forms a forcing pattern
                if (num3 > 0 && num4 > 0 &&
                    !testMines.contains(pos1) && !testMines.contains(pos2)) {
                    if (requiresOneMineBetween(pos1, pos2, testMines, revealed)) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

bool MinesweeperLogic::checkLinearPattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    for (int row = 0; row < m_height - 1; ++row) {
        for (int col = 0; col < m_width - 2; ++col) {
            int top1 = row * m_width + col;
            int top2 = top1 + 1;
            int top3 = top2 + 1;
            int bottom1 = (row + 1) * m_width + col;
            int bottom2 = bottom1 + 1;
            int bottom3 = bottom2 + 1;

            if (revealed.contains(top1) && revealed.contains(top2) && revealed.contains(top3) &&
                !revealed.contains(bottom1) && !revealed.contains(bottom2) && !revealed.contains(bottom3)) {

                auto numbers = calculateNumbersForValidation(testMines);
                if (isLinearUnsolvablePattern(numbers[top1], numbers[top2], numbers[top3],
                                              bottom1, bottom2, bottom3, testMines)) {
                    return true;
                }
            }
        }
    }
    return false;
}

bool MinesweeperLogic::checkDiagonalPattern(const QVector<int>& testMines, const QSet<int>& revealed) {
    for (int row = 0; row < m_height - 1; ++row) {
        for (int col = 0; col < m_width - 1; ++col) {
            int pos1 = row * m_width + col;
            int pos2 = row * m_width + (col + 1);
            int pos3 = (row + 1) * m_width + col;
            int pos4 = (row + 1) * m_width + (col + 1);

            // Check diagonal pattern
            if (revealed.contains(pos1) && !revealed.contains(pos2) &&
                !revealed.contains(pos3) && revealed.contains(pos4)) {

                if (!testMines.contains(pos2) && !testMines.contains(pos3)) {
                    auto numbers = calculateNumbersForValidation(testMines);
                    if (numbers[pos1] == 1 && numbers[pos4] == 1 &&
                        requiresOneMineBetween(pos2, pos3, testMines, revealed)) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

bool MinesweeperLogic::isLinearUnsolvablePattern(int num1, int num2, int num3,
                                                 int pos1, int pos2, int pos3,
                                                 const QVector<int>& testMines) {
    // Check if the pattern forms a "1 2 1" or similar configuration
    // that would force a guess
    if (num1 > 0 && num2 > 0 && num3 > 0) {
        if (!testMines.contains(pos1) && !testMines.contains(pos2) && !testMines.contains(pos3)) {
            int totalMines = countConfirmedMines(pos1, testMines) +
                             countConfirmedMines(pos2, testMines) +
                             countConfirmedMines(pos3, testMines);

            // If the total number of mines needed equals the remaining spaces
            // but we can't determine which positions they should be in
            return (num1 + num2 + num3 - totalMines) > 0 &&
                   (num1 + num2 + num3 - totalMines) <= 3;
        }
    }
    return false;
}

bool MinesweeperLogic::canLogicallySolve(int pos, const QSet<int>& revealed, const QVector<int>& mines) {
    if (revealed.contains(pos) || mines.contains(pos)) {
        return false;
    }

    int row = pos / m_width;
    int col = pos % m_width;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                int checkPos = newRow * m_width + newCol;
                if (revealed.contains(checkPos)) {
                    auto numbers = calculateNumbersForValidation(mines);
                    if (canDeduce(pos, revealed, mines, numbers)) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

void MinesweeperLogic::addNewFrontierCells(int pos, const QSet<int>& revealed, QSet<int>& frontier) {
    int row = pos / m_width;
    int col = pos % m_width;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                int newPos = newRow * m_width + newCol;
                if (!revealed.contains(newPos)) {
                    frontier.insert(newPos);
                }
            }
        }
    }
}

bool MinesweeperLogic::isEdgePosition(int pos) const {
    int row = pos / m_width;
    int col = pos % m_width;
    return row == 0 || row == m_height - 1 || col == 0 || col == m_width - 1;
}

int MinesweeperLogic::countConfirmedMines(int pos, const QVector<int>& mines) {
    int row = pos / m_width;
    int col = pos % m_width;
    int count = 0;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < m_height && newCol >= 0 && newCol < m_width) {
                int checkPos = newRow * m_width + newCol;
                if (mines.contains(checkPos)) {
                    count++;
                }
            }
        }
    }

    return count;
}

// [Rest of the original implementation remains unchanged]


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

    //if (hasUnsolvablePattern(testMines, revealed)) {
    //    return {0, 0.0f};
    //}

    qDebug() << "Solvability Test:";
    qDebug() << "- Solvable cells:" << solvableCells;
    qDebug() << "- Total non-mine cells:" << totalNonMineCells;
    qDebug() << "- Solvability percentage:" << percentage;

    return {solvableCells, percentage};
}

bool MinesweeperLogic::requiresOneMineBetween(int pos1, int pos2,
                                              const QVector<int>& testMines,
                                              const QSet<int>& revealed) {
    QSet<int> surroundingRevealed;

    // Get all revealed cells around both positions
    int row1 = pos1 / m_width;
    int col1 = pos1 % m_width;
    int row2 = pos2 / m_width;
    int col2 = pos2 % m_width;

    // Check surrounding cells for both positions
    for (int pos : {pos1, pos2}) {
        int row = pos / m_width;
        int col = pos % m_width;

        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                if (r == 0 && c == 0) continue;

                int newRow = row + r;
                int newCol = col + c;

                if (newRow >= 0 && newRow < m_height &&
                    newCol >= 0 && newCol < m_width) {
                    int checkPos = newRow * m_width + newCol;
                    if (revealed.contains(checkPos)) {
                        surroundingRevealed.insert(checkPos);
                    }
                }
            }
        }
    }

    // Check if any revealed number forces one of these positions to be a mine
    for (int revealedPos : surroundingRevealed) {
        int number = calculateNumbersForValidation(testMines)[revealedPos];
        int confirmedMines = countConfirmedMines(revealedPos, testMines);

        // If this number has all its mines accounted for except one,
        // and it only touches our two positions as unrevealed cells,
        // then one of our positions must be a mine
        if (number - confirmedMines == 1) {
            int unrevealedCount = 0;
            int row = revealedPos / m_width;
            int col = revealedPos % m_width;

            for (int r = -1; r <= 1; ++r) {
                for (int c = -1; c <= 1; ++c) {
                    if (r == 0 && c == 0) continue;

                    int newRow = row + r;
                    int newCol = col + c;

                    if (newRow >= 0 && newRow < m_height &&
                        newCol >= 0 && newCol < m_width) {
                        int checkPos = newRow * m_width + newCol;
                        if (!revealed.contains(checkPos) && !testMines.contains(checkPos)) {
                            unrevealedCount++;
                            if (checkPos != pos1 && checkPos != pos2) {
                                // Found another unrevealed cell, so this number
                                // doesn't force our positions
                                unrevealedCount = 999;
                                break;
                            }
                        }
                    }
                }
            }

            if (unrevealedCount == 2) {
                return true; // Found a forcing number
            }
        }
    }

    return false;
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
    int maxAttempts = 1000; // Increased attempts since we have more constraints

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
            // Add the new logical simulation test
            if (simulateLogicalPlay(currentMines, firstClickIndex)) {
                qDebug() << "Found perfect configuration with logical solution!";
                m_mines = currentMines;
                calculateNumbers();
                return true;
            } else {
                qDebug() << "Configuration requires guessing, trying again...";
                continue;
            }
        }

        if (attempt < maxAttempts - 1) {
            qDebug() << "Configuration not perfectly solvable, trying again...";
        } else {
            qDebug() << "Failed to find perfectly solvable configuration after:" << placementAttempts;

        }
    }

    return false;
}

bool MinesweeperLogic::simulateLogicalPlay(const QVector<int>& testMines, int firstClickIndex) {
    QSet<int> revealed;
    QSet<int> flagged;
    QVector<int> testNumbers = calculateNumbersForValidation(testMines);

    // Reveal a cell and its surrounding if it's a 0
    std::function<void(int)> revealCell = [&](int pos) {
        if (revealed.contains(pos) || flagged.contains(pos) || testMines.contains(pos)) {
            return;
        }

        revealed.insert(pos);

        // If it's a zero, reveal all adjacent cells
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

    // Keep trying to find logical moves until we can't anymore
    bool foundLogicalMove = true;
    while (foundLogicalMove) {
        foundLogicalMove = false;

        // Check all revealed numbers
        for (int pos = 0; pos < m_width * m_height; ++pos) {
            if (!revealed.contains(pos)) continue;

            int row = pos / m_width;
            int col = pos % m_width;

            // Count unrevealed and flagged cells around this number
            int surroundingUnrevealed = 0;
            int surroundingFlagged = 0;
            QVector<int> unrevealedPositions;

            for (int r = -1; r <= 1; ++r) {
                for (int c = -1; c <= 1; ++c) {
                    if (r == 0 && c == 0) continue;

                    int newRow = row + r;
                    int newCol = col + c;

                    if (newRow >= 0 && newRow < m_height &&
                        newCol >= 0 && newCol < m_width) {
                        int checkPos = newRow * m_width + newCol;

                        if (flagged.contains(checkPos)) {
                            surroundingFlagged++;
                        }
                        else if (!revealed.contains(checkPos)) {
                            surroundingUnrevealed++;
                            unrevealedPositions.append(checkPos);
                        }
                    }
                }
            }

            // If number equals flagged + unrevealed, all unrevealed must be mines
            if (testNumbers[pos] == surroundingFlagged + surroundingUnrevealed && surroundingUnrevealed > 0) {
                for (int minePos : unrevealedPositions) {
                    if (!flagged.contains(minePos)) {
                        flagged.insert(minePos);
                        foundLogicalMove = true;
                    }
                }
            }
            // If number equals flagged mines, all other cells are safe
            else if (testNumbers[pos] == surroundingFlagged && surroundingUnrevealed > 0) {
                for (int safePos : unrevealedPositions) {
                    revealCell(safePos);
                    foundLogicalMove = true;
                }
            }
        }
    }

    // Check if all mines were found
    bool allMinesFound = true;
    for (int mine : testMines) {
        if (!flagged.contains(mine)) {
            allMinesFound = false;
            break;
        }
    }

    // Check if no extra cells were flagged
    bool noExtraFlags = true;
    for (int flag : flagged) {
        if (!testMines.contains(flag)) {
            noExtraFlags = false;
            break;
        }
    }

    // Debug output
    qDebug() << "Logical simulation results:";
    qDebug() << "- Revealed cells:" << revealed.size();
    qDebug() << "- Flagged mines:" << flagged.size() << "out of" << testMines.size();
    qDebug() << "- All mines found:" << allMinesFound;
    qDebug() << "- No wrong flags:" << noExtraFlags;

    return allMinesFound && noExtraFlags;
}
