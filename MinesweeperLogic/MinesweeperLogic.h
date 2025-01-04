#ifndef MINESWEEPERLOGIC_H
#define MINESWEEPERLOGIC_H

#include <QObject>
#include <QVector>
#include <QPoint>
#include <random>
#include <queue>

class MinesweeperLogic : public QObject {
    Q_OBJECT

public:
    explicit MinesweeperLogic(QObject *parent = nullptr);

    Q_INVOKABLE bool initializeGame(int width, int height, int mineCount);
    Q_INVOKABLE bool placeMines(int firstClickX, int firstClickY);
    Q_INVOKABLE QVector<int> getNumbers() const { return m_numbers; }
    Q_INVOKABLE QVector<int> getMines() const { return m_mines; }
    Q_INVOKABLE bool testSolvability(int firstClickIndex);

private:
    int m_width;
    int m_height;
    int m_mineCount;
    QVector<int> m_mines;
    QVector<int> m_numbers;
    std::mt19937 m_rng;

    bool isValid(int x, int y) const;
    int toIndex(int x, int y) const;
    QPoint fromIndex(int index) const;
    void calculateNumbers();
    QVector<int> getNeighbors(int index) const;
    bool simulateGame(int firstClickIndex, const QVector<int>& testMines);
    float calculateSolvabilityScore(const QVector<bool>& revealed, const QVector<int>& testMines) const;
    bool isEdge5050Pattern(int x, int y, QVector<int> numbers, QVector<bool> revealed);
    bool hasUnavoidableGuess(QVector<int> numbers, QVector<bool> revealed);
};

#endif // MINESWEEPERLOGIC_H
