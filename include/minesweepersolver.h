// include/minesweepersolver.h
#pragma once

#include <QObject>
#include <QSet>
#include <QVector>
#include <QDebug>

struct SolverResult {
    int cell;
    QString reason;
};

class MinesweeperSolver : public QObject
{
    Q_OBJECT

public:
    explicit MinesweeperSolver(QObject *parent = nullptr);
    ~MinesweeperSolver();

    // Main solving method
    SolverResult solveForHint(int width, int height, const QVector<int> &numbers,
                              const QVector<int> &revealedCells, const QVector<int> &flaggedCells);

private:
    struct Constraint {
        int cell;
        int minesRequired;
        QSet<int> unknowns;
    };

    // Helper methods
    QSet<int> getNeighbors(int pos, int width, int height) const;
    int solveFrontierCSP(int width, int height,
                         const QVector<Constraint> &constraints,
                         const QList<int> &frontier);
    int solveWithConstraintIntersection(int width, int height,
                                        const QVector<Constraint> &constraints,
                                        const QList<int> &frontier);
};
