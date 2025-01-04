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
};

#endif // MINESWEEPERLOGIC_H
