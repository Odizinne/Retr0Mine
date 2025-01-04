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

bool MinesweeperLogic::simulateGame(int firstClickIndex, const QVector<int>& testMines)
{
    int totalCells = m_width * m_height;
    QVector<Cell> cells(totalCells);

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

        // Second pass: Pattern recognition
        if (!changed) {
            for (int i = 0; i < totalCells; ++i) {
                if (!cells[i].revealed || testMines.contains(i)) continue;

                // Check for 1-2-1 pattern
                if (cells[i].number == 1) {
                    for (int n1 : cells[i].neighbors) {
                        if (cells[n1].revealed && cells[n1].number == 2) {
                            for (int n2 : cells[n1].neighbors) {
                                if (cells[n2].revealed && cells[n2].number == 1) {
                                    // Found 1-2-1 pattern, analyze shared cells
                                    QSet<int> shared;
                                    QSet<int> set1(cells[i].neighbors.begin(), cells[i].neighbors.end());
                                    QSet<int> set2(cells[n2].neighbors.begin(), cells[n2].neighbors.end());
                                    for (int n : cells[n1].neighbors) {
                                        if (set1.contains(n) || set2.contains(n)) {
                                            shared.insert(n);
                                        }
                                    }
                                    // Apply 1-2-1 solving logic
                                    if (shared.size() == 3) {
                                        int unknownCount = 0;
                                        for (int s : shared) {
                                            if (!cells[s].revealed && !cells[s].flagged) unknownCount++;
                                        }
                                        if (unknownCount == 2) {
                                            changed = true;
                                            // Apply appropriate flags or reveals based on pattern
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    } while (changed && iterations < MAX_ITERATIONS);

    // Count unsolved cells that require guessing
    int unsolvableCells = 0;
    for (int i = 0; i < totalCells; ++i) {
        if (!testMines.contains(i) && !cells[i].revealed) {
            bool hasLogicalSolution = false;
            // Check if cell can be logically determined
            for (int neighbor : cells[i].neighbors) {
                if (cells[neighbor].revealed) {
                    // Complex check for logical solvability
                    hasLogicalSolution = true;
                    break;
                }
            }
            if (!hasLogicalSolution) unsolvableCells++;
        }
    }

    // Only accept configurations that are 100% solvable by logic
    return unsolvableCells == 0;
}

float MinesweeperLogic::calculateSolvabilityScore(const QVector<bool>& revealed, const QVector<int>& testMines) const
{
    int totalNonMines = m_width * m_height - testMines.size();
    int revealedNonMines = 0;

    for (int i = 0; i < revealed.size(); ++i) {
        if (revealed[i] && !testMines.contains(i)) {
            revealedNonMines++;
        }
    }

    return static_cast<float>(revealedNonMines) / totalNonMines;
}

bool MinesweeperLogic::testSolvability(int firstClickIndex)
{
    // Create a test configuration with current mines
    return simulateGame(firstClickIndex, m_mines);
}

bool MinesweeperLogic::placeMines(int firstClickX, int firstClickY)
{
    int firstClickIndex = toIndex(firstClickX, firstClickY);
    QVector<int> availableCells;
    availableCells.reserve(m_width * m_height);

    // Create safe zone around first click
    QSet<int> safeZone;
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            int newX = firstClickX + dx;
            int newY = firstClickY + dy;
            if (isValid(newX, newY)) {
                safeZone.insert(toIndex(newX, newY));
            }
        }
    }

    // Fill available cells excluding safe zone
    for (int i = 0; i < m_width * m_height; ++i) {
        if (!safeZone.contains(i)) {
            availableCells.append(i);
        }
    }

    const int MAX_ATTEMPTS = 50;
    for (int attempt = 0; attempt < MAX_ATTEMPTS; ++attempt) {
        // Shuffle available cells
        for (int i = availableCells.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> dist(0, i);
            int j = dist(m_rng);
            std::swap(availableCells[i], availableCells[j]);
        }

        // Take first mineCount cells as mines
        QVector<int> testMines(availableCells.begin(), availableCells.begin() + m_mineCount);
        std::sort(testMines.begin(), testMines.end());

        if (simulateGame(firstClickIndex, testMines)) {
            m_mines = testMines;
            calculateNumbers();
            return true;
        }
    }

    // If no good configuration found, use the last attempted one
    m_mines = QVector<int>(availableCells.begin(), availableCells.begin() + m_mineCount);
    std::sort(m_mines.begin(), m_mines.end());
    calculateNumbers();
    return false;
}
