#include "gamelogic.h"
#include <QDebug>
#include <QQueue>
#include <QRandomGenerator>

GameLogic::GameLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
    , m_cancelGeneration(false)
    , m_generationWatcher(new QFutureWatcher<void>(this))
    , m_gridGenerator(new GridGenerator(this))
    , m_solver(new MinesweeperSolver(this))
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

void GameLogic::generateBoardAsync(int firstClickX, int firstClickY) {
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

            // Try to generate board using the GridGenerator with progress callback
            success = m_gridGenerator->generateBoard(
                m_width, m_height, m_mineCount, firstClickX, firstClickY,
                m_mines, m_numbers, m_cancelGeneration,
                [this](int minesPlaced, int totalMines) {
                    // Update mines placed progress
                    updateProgress(m_currentAttempt.load(), m_totalAttempts.load(), minesPlaced);
                }
                );

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

    // Get result with explanation from solver
    SolverResult solverResult = m_solver->solveForHint(m_width, m_height, m_numbers, revealedCells, flaggedCells);

    // Create user-friendly explanation
    QString explanation = solverResult.reason;

    if (solverResult.cell != -1) {
        int row = solverResult.cell / m_width;
        int col = solverResult.cell % m_width;

        // Determine if it's likely a mine or safe cell
        bool isMine = false;

        // Check if it's likely a mine based on reasoning text
        if (explanation.contains(tr("contain mines")) ||
            explanation.contains(tr("mines must")) ||
            explanation.contains(tr("must contain")) ||
            explanation.contains(tr("must all contain"))) {
            isMine = true;
        }

        // Add introducer text based on mine/safe status
        if (isMine) {
            result["explanation"] = tr("I think there's a mine at position (%1,%2). %3")
            .arg(col+1).arg(row+1).arg(explanation);
        } else {
            result["explanation"] = tr("I believe the cell at position (%1,%2) is safe. %3")
            .arg(col+1).arg(row+1).arg(explanation);
        }
    } else {
        result["explanation"] = explanation;
    }

    result["cell"] = solverResult.cell;
    return result;
}
