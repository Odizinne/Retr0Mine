#ifndef MINESWEEPERLOGIC_H
#define MINESWEEPERLOGIC_H

#include <QObject>
#include <QVector>
#include <QPoint>
#include <QSet>
#include <random>
#include <algorithm>
#include <cmath>

class MinesweeperLogic : public QObject {
    Q_OBJECT

public:
    explicit MinesweeperLogic(QObject *parent = nullptr);

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool placeMines(int firstClickX, int firstClickY);
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }

private:
    int m_width;
    int m_height;
    int m_mineCount;
    QVector<int> m_mines;
    QVector<int> m_numbers;
    std::mt19937 m_rng;

    void calculateNumbers();
    struct SolvabilityResult {
        int solvableCells;
        float percentage;
    };

    bool isCornerPosition(int pos);
    bool wouldCreateCornerProblem(int pos, const QVector<int>& currentMines);
    SolvabilityResult testSolvability(const QVector<int>& testMines, int firstClickIndex);
    bool canDeduce(int pos, const QSet<int>& revealed, const QVector<int>& mines, const QVector<int>& numbers);
    QVector<int> calculateNumbersForValidation(const QVector<int>& mines);
    bool hasUnsolvablePattern(const QVector<int>& testMines, const QSet<int>& revealed);

    bool checkDoubleCornerPattern(const QVector<int>& testMines, const QSet<int>& revealed);
    bool checkLinearPattern(const QVector<int>& testMines, const QSet<int>& revealed);
    bool checkDiagonalPattern(const QVector<int>& testMines, const QSet<int>& revealed);
    bool checkBasicUnsolvablePattern(const QVector<int>& testMines, const QSet<int>& revealed);
    bool requiresOneMineBetween(int pos1, int pos2, const QVector<int>& testMines, const QSet<int>& revealed);
    bool isLinearUnsolvablePattern(int num1, int num2, int num3, int pos1, int pos2, int pos3, const QVector<int>& testMines);

    // Board validation methods
    bool canLogicallySolve(int pos, const QSet<int>& revealed, const QVector<int>& mines);
    void addNewFrontierCells(int pos, const QSet<int>& revealed, QSet<int>& frontier);
    bool isEdgePosition(int pos) const;
    int countConfirmedMines(int pos, const QVector<int>& mines);
    bool checkCornerDeadEndPattern(const QVector<int>& testMines, const QSet<int>& revealed);
    bool simulateLogicalPlay(const QVector<int>& testMines, int firstClickIndex);
};

#endif // MINESWEEPERLOGIC_H
