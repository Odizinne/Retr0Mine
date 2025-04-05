#pragma once

#include <QObject>
#include <QSet>
#include <QVector>
#include <atomic>
#include <random>

class GridGenerator : public QObject
{
    Q_OBJECT

public:
    explicit GridGenerator(QObject *parent = nullptr);
    ~GridGenerator();

    bool generateBoard(int width, int height, int mineCount, int firstClickX, int firstClickY,
                       QVector<int>& mines, QVector<int>& numbers, const std::atomic<bool>& cancelFlag,
                       std::function<void(int, int)> progressCallback = nullptr);

private:
    std::mt19937 m_rng;

    class BoardState {
    public:
        struct Cell {
            bool isMine = false;
            bool revealed = false;
            bool flagged = false;
            bool safe = false;
            int adjacentMines = 0;
            QSet<int> neighbors;
        };

        BoardState(int width, int height);
        void createSafeArea(int center);
        void placeMine(int index);
        QVector<int> getMines() const;
        QVector<int> getMineCandidates() const;
        bool isFullySolvable(const std::atomic<bool>& cancelFlag);
        QVector<int> calculateNumbers() const;

    private:
        QVector<Cell> m_cells;
        QVector<int> m_mines;
        int m_width;
        int m_height;

        bool solveCompletely(const std::atomic<bool>& cancelFlag);
        bool solveWithCSP(const std::atomic<bool>& cancelFlag);
        bool solveLargeCSP(const QVector<int>& boundaryCells, const QVector<int>& frontierCells,
                           const std::atomic<bool>& cancelFlag);
        void generateValidConfigurations(const QVector<int>& boundaryCells, const QVector<int>& frontierCells,
                                         QVector<bool>& currentConfig, int index,
                                         QVector<QVector<bool>>& validConfigs,
                                         const std::atomic<bool>& cancelFlag,
                                         int maxConfigs = 500);
    };
};