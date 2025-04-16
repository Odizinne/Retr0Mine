#include <QDebug>
#include <QQueue>
#include <QRandomGenerator>
#include "gamelogic.h"

GameLogic::GameLogic(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
    , m_cancelGeneration(false)
    , m_generationWatcher(new QFutureWatcher<void>(this))
    , m_gridGenerator(new GridGenerator(this))
    , m_solver(new MinesweeperSolver(this))
    , m_currentAttempt(0)
    , m_totalAttempts(0)
    , m_minesPlaced(0) {
    connect(m_generationWatcher, &QFutureWatcher<void>::finished, this, [this]() {
        if (!m_cancelGeneration.load()) {
            emit boardGenerationCompleted(!m_mines.isEmpty());
        }
    });
}

GameLogic::~GameLogic() {
    cancelGeneration();
}

bool GameLogic::initializeGame(int width, int height, int mineCount) {
    if (width <= 0 || height <= 0 || mineCount <= 0 || mineCount >= width * height) {
        return false;
    }

    m_width = width;
    m_height = height;
    m_mineCount = mineCount;
    m_mines.clear();
    m_numbers.resize(width * height);

    updateProgress(0, 0, 0);

    QMetaObject::invokeMethod(this, [this]() {
        emit totalMinesChanged();
    }, Qt::QueuedConnection);

    return true;
}

bool GameLogic::initializeFromSave(int width, int height, int mineCount, const QVector<int> &mines) {
    if (width <= 0 || height <= 0 || mineCount <= 0 || mineCount >= width * height) {
        return false;
    }

    m_width = width;
    m_height = height;
    m_mineCount = mineCount;
    m_mines = mines;
    m_numbers.resize(width * height);

    calculateNumbers();

    return true;
}

QVector<int> GameLogic::calculateNumbersFromMines(int width, int height, const QVector<int> &mines) {
    int originalWidth = m_width;
    int originalHeight = m_height;

    m_width = width;
    m_height = height;

    QVector<int> numbers(width * height, 0);

    for (int mine : mines) {
        if (mine < 0 || mine >= width * height) {
            continue;
        }

        numbers[mine] = -1;

        QSet<int> neighbors = getNeighbors(mine);
        for (int neighbor : std::as_const(neighbors)) {
            if (neighbor < 0 || neighbor >= width * height) {
                continue;
            }

            if (numbers[neighbor] >= 0) {
                numbers[neighbor]++;
            }
        }
    }

    int nonZeroCount = 0;
    for (int i = 0; i < numbers.size() && nonZeroCount < 10; i++) {
        if (numbers[i] != 0) {
            nonZeroCount++;
        }
    }

    m_width = originalWidth;
    m_height = originalHeight;

    return numbers;
}

void GameLogic::calculateNumbers() {
    m_numbers.fill(0, m_width * m_height);

    for (int mine : std::as_const(m_mines)) {
        m_numbers[mine] = -1;

        QSet<int> neighbors = getNeighbors(mine);
        for (int neighbor : std::as_const(neighbors)) {
            if (m_numbers[neighbor] >= 0) {
                m_numbers[neighbor]++;
            }
        }
    }
}

QSet<int> GameLogic::getNeighbors(int pos) const {
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

    const int MAX_ATTEMPTS = 100;
    updateProgress(1, MAX_ATTEMPTS, 0);

    QFuture<void> future = QtConcurrent::run([this, firstClickX, firstClickY, MAX_ATTEMPTS]() {
        bool success = false;
        int attempt = 1;

        while (!success && attempt <= MAX_ATTEMPTS && !m_cancelGeneration.load()) {
            updateProgress(attempt, MAX_ATTEMPTS, 0);

            success = m_gridGenerator->generateBoard(
                m_width, m_height, m_mineCount, firstClickX, firstClickY,
                m_mines, m_numbers, m_cancelGeneration,
                [this](int minesPlaced, int totalMines) {
                    updateProgress(m_currentAttempt.load(), m_totalAttempts.load(), minesPlaced);
                }
                );

            if (!success && !m_cancelGeneration.load()) {
                attempt++;
            }
        }

        if (m_cancelGeneration.load() || !success) {
            m_mines.clear();
            m_numbers.clear();
        }
    });

    m_generationWatcher->setFuture(future);
}

void GameLogic::updateProgress(int attempt, int totalAttempts, int minesPlaced) {
    m_currentAttempt.store(attempt);
    m_totalAttempts.store(totalAttempts);
    m_minesPlaced.store(minesPlaced);

    QMetaObject::invokeMethod(this, [this]() {
        emit currentAttemptChanged();
        emit totalAttemptsChanged();
        emit minesPlacedChanged();
    }, Qt::QueuedConnection);
}

void GameLogic::cancelGeneration() {
    m_cancelGeneration.store(true);

    if (m_generationWatcher->isRunning()) {
        m_generationWatcher->waitForFinished();
    }

    m_cancelGeneration.store(false);
    updateProgress(0, 0, 0);
}

QVariantMap GameLogic::findMineHintWithReasoning(const QVector<int> &revealedCells, const QVector<int> &flaggedCells) {
    QVariantMap result;

    SolverResult solverResult = m_solver->solveForHint(m_width, m_height, m_numbers, revealedCells, flaggedCells);

    QString explanation = solverResult.reason;

    if (solverResult.cell != -1) {
        int row = solverResult.cell / m_width;
        int col = solverResult.cell % m_width;

        bool isMine = false;

        if (explanation.contains(tr("contain mines")) ||
            explanation.contains(tr("mines must")) ||
            explanation.contains(tr("must contain")) ||
            explanation.contains(tr("must all contain"))) {
            isMine = true;
        }

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
