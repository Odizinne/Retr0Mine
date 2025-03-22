#include <QStringList>
#include "minesweepersolver.h"

MinesweeperSolver::MinesweeperSolver(QObject *parent)
    : QObject(parent) {
}

MinesweeperSolver::~MinesweeperSolver() {
}

QSet<int> MinesweeperSolver::getNeighbors(int pos, int width, int height) const {
    QSet<int> neighbors;
    int row = pos / width;
    int col = pos % width;

    for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0)
                continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow >= 0 && newRow < height && newCol >= 0 && newCol < width) {
                neighbors.insert(newRow * width + newCol);
            }
        }
    }

    return neighbors;
}

SolverResult MinesweeperSolver::solveForHint(int width, int height, const QVector<int> &numbers,
                                             const QVector<int> &revealedCells,
                                             const QVector<int> &flaggedCells) {
    QSet<int> revealed;
    QSet<int> flagged;
    for (int cell : revealedCells)
        revealed.insert(cell);
    for (int cell : flaggedCells)
        flagged.insert(cell);

    for (int pos : revealed) {
        if (numbers[pos] <= 0)
            continue;

        QSet<int> neighbors = getNeighbors(pos, width, height);
        int flagCount = 0;
        QSet<int> unrevealedCells;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unrevealedCells.insert(neighbor);
            }
        }

        int remainingMines = numbers[pos] - flagCount;
        if (remainingMines > 0 && remainingMines == unrevealedCells.size()) {
            for (int minePos : unrevealedCells) {
                if (!flagged.contains(minePos)) {
                    int row = pos / width;
                    int col = pos % width;
                    int mineRow = minePos / width;
                    int mineCol = minePos % width;

                    QString reason = tr("The number %1 at %2,%3 shows there are %n mine(s) left to find. Since there are exactly %n hidden cell(s) next to it, all of these cells must contain mines.", "", remainingMines)
                                         .arg(numbers[pos])
                                         .arg(col+1).arg(row+1)
                                         .arg(unrevealedCells.size());

                    return {minePos, reason};
                }
            }
        }
    }

    for (int pos : revealed) {
        if (numbers[pos] <= 0)
            continue;

        QSet<int> neighbors = getNeighbors(pos, width, height);
        int flagCount = 0;
        QSet<int> unknowns;

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                flagCount++;
            } else if (!revealed.contains(neighbor)) {
                unknowns.insert(neighbor);
            }
        }

        if (numbers[pos] == flagCount && !unknowns.isEmpty()) {
            int safePos = *unknowns.begin();
            int row = pos / width;
            int col = pos % width;
            int safeRow = safePos / width;
            int safeCol = safePos % width;

            QString reason = tr("The number %1 at %2,%3 already has all its %n mine(s) flagged. This means all remaining hidden cells around it must be safe.", "", numbers[pos])
                                 .arg(numbers[pos])
                                 .arg(col+1).arg(row+1);

            return {safePos, reason};
        }
    }

    QVector<Constraint> constraints;
    QSet<int> frontier;

    for (int pos : revealed) {
        if (numbers[pos] <= 0) continue;

        QSet<int> neighbors = getNeighbors(pos, width, height);
        QSet<int> unknownNeighbors;
        int minesRequired = numbers[pos];

        for (int neighbor : neighbors) {
            if (flagged.contains(neighbor)) {
                minesRequired--;
            } else if (!revealed.contains(neighbor)) {
                unknownNeighbors.insert(neighbor);
            }
        }

        if (!unknownNeighbors.isEmpty()) {
            Constraint c;
            c.cell = pos;
            c.minesRequired = minesRequired;
            c.unknowns = unknownNeighbors;
            constraints.append(c);

            for (int cell : unknownNeighbors) {
                frontier.insert(cell);
            }
        }
    }

    for (int i = 0; i < constraints.size(); i++) {
        for (int j = 0; j < constraints.size(); j++) {
            if (i == j) continue;

            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            bool c1ContainedInC2 = true;
            for (int cell : c1.unknowns) {
                if (!c2.unknowns.contains(cell)) {
                    c1ContainedInC2 = false;
                    break;
                }
            }

            if (c1ContainedInC2 && c1.unknowns.size() < c2.unknowns.size()) {
                QSet<int> onlyInC2;
                for (int cell : c2.unknowns) {
                    if (!c1.unknowns.contains(cell)) {
                        onlyInC2.insert(cell);
                    }
                }

                if (c1.minesRequired == c1.unknowns.size()) {
                    int minesInNonOverlap = c2.minesRequired - c1.minesRequired;

                    if (minesInNonOverlap == onlyInC2.size() && minesInNonOverlap > 0) {
                        int minePos = *onlyInC2.begin();
                        int row1 = c1.cell / width;
                        int col1 = c1.cell % width;
                        int row2 = c2.cell / width;
                        int col2 = c2.cell % width;

                        QString reason = tr("Looking at the numbers %1 at %2,%3 and %4 at %5,%6: All %n mine(s) from the first number must be in cells that the second number also touches. This means the remaining cells around the second number must contain the remaining mines.", "", c1.minesRequired)
                                             .arg(numbers[c1.cell])
                                             .arg(col1+1).arg(row1+1)
                                             .arg(numbers[c2.cell])
                                             .arg(col2+1).arg(row2+1);

                        return {minePos, reason};
                    }

                    if (minesInNonOverlap == 0 && !onlyInC2.isEmpty()) {
                        int safePos = *onlyInC2.begin();
                        int row1 = c1.cell / width;
                        int col1 = c1.cell % width;
                        int row2 = c2.cell / width;
                        int col2 = c2.cell % width;

                        QString reason = tr("Looking at the numbers %1 at %2,%3 and %4 at %5,%6: All %n mine(s) from the first number must be in cells that the second number also touches. Since the second number only needs the same number of mines, the other cells around it must be safe.", "", c1.minesRequired)
                                             .arg(numbers[c1.cell])
                                             .arg(col1+1).arg(row1+1)
                                             .arg(numbers[c2.cell])
                                             .arg(col2+1).arg(row2+1);

                        return {safePos, reason};
                    }
                }

                if (c2.minesRequired == c1.minesRequired) {
                    if (!onlyInC2.isEmpty()) {
                        int safePos = *onlyInC2.begin();
                        int row1 = c1.cell / width;
                        int col1 = c1.cell % width;
                        int row2 = c2.cell / width;
                        int col2 = c2.cell % width;

                        QString reason = tr("The numbers %1 at %2,%3 and %4 at %5,%6 both need %n mine(s). Since all cells around the first number are also around the second number, the extra cells around the second number must be safe.", "", c1.minesRequired)
                                             .arg(numbers[c1.cell])
                                             .arg(col1+1).arg(row1+1)
                                             .arg(numbers[c2.cell])
                                             .arg(col2+1).arg(row2+1);

                        return {safePos, reason};
                    }
                }
            }
        }
    }

    for (int i = 0; i < constraints.size(); i++) {
        for (int j = i + 1; j < constraints.size(); j++) {
            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            QSet<int> sharedCells;
            for (int cell : c1.unknowns) {
                if (c2.unknowns.contains(cell)) {
                    sharedCells.insert(cell);
                }
            }

            if (sharedCells.isEmpty()) continue;

            QSet<int> onlyInC1;
            for (int cell : c1.unknowns) {
                if (!sharedCells.contains(cell)) {
                    onlyInC1.insert(cell);
                }
            }

            QSet<int> onlyInC2;
            for (int cell : c2.unknowns) {
                if (!sharedCells.contains(cell)) {
                    onlyInC2.insert(cell);
                }
            }

            if (c1.minesRequired > onlyInC1.size()) {
                int minSharedMines = c1.minesRequired - onlyInC1.size();

                if (c2.minesRequired - minSharedMines == onlyInC2.size() && !onlyInC2.isEmpty()) {
                    int minePos = *onlyInC2.begin();
                    int row1 = c1.cell / width;
                    int col1 = c1.cell % width;
                    int row2 = c2.cell / width;
                    int col2 = c2.cell % width;

                    QString reason = tr("The number %1 at %2,%3 needs at least %4 of its mines to be in the cells it shares with number %5 at %6,%7. This means the remaining %n non-shared cell(s) around the second number must all contain mines.", "", onlyInC2.size())
                                         .arg(numbers[c1.cell])
                                         .arg(col1+1).arg(row1+1)
                                         .arg(minSharedMines)
                                         .arg(numbers[c2.cell])
                                         .arg(col2+1).arg(row2+1);

                    return {minePos, reason};
                }

                if (c2.minesRequired <= minSharedMines && !onlyInC2.isEmpty()) {
                    int safePos = *onlyInC2.begin();
                    int row1 = c1.cell / width;
                    int col1 = c1.cell % width;
                    int row2 = c2.cell / width;
                    int col2 = c2.cell % width;

                    QString reason = tr("The number %1 at %2,%3 needs at least %4 of its mines to be in the cells it shares with number %5 at %6,%7. Since the second number only needs %8 mines total, its non-shared cells must be safe.", "")
                                         .arg(numbers[c1.cell])
                                         .arg(col1+1).arg(row1+1)
                                         .arg(minSharedMines)
                                         .arg(numbers[c2.cell])
                                         .arg(col2+1).arg(row2+1)
                                         .arg(c2.minesRequired);

                    return {safePos, reason};
                }
            }

            if (c2.minesRequired > onlyInC2.size()) {
                int minSharedMines = c2.minesRequired - onlyInC2.size();

                if (c1.minesRequired - minSharedMines == onlyInC1.size() && !onlyInC1.isEmpty()) {
                    int minePos = *onlyInC1.begin();
                    int row1 = c1.cell / width;
                    int col1 = c1.cell % width;
                    int row2 = c2.cell / width;
                    int col2 = c2.cell % width;

                    QString reason = tr("The number %1 at %2,%3 needs at least %4 of its mines to be in the cells it shares with number %5 at %6,%7. This means the remaining %n non-shared cell(s) around the first number must all contain mines.", "", onlyInC1.size())
                                         .arg(numbers[c2.cell])
                                         .arg(col2+1).arg(row2+1)
                                         .arg(minSharedMines)
                                         .arg(numbers[c1.cell])
                                         .arg(col1+1).arg(row1+1);

                    return {minePos, reason};
                }

                if (c1.minesRequired <= minSharedMines && !onlyInC1.isEmpty()) {
                    int safePos = *onlyInC1.begin();
                    int row1 = c1.cell / width;
                    int col1 = c1.cell % width;
                    int row2 = c2.cell / width;
                    int col2 = c2.cell % width;

                    QString reason = tr("The number %1 at %2,%3 needs at least %4 of its mines to be in the cells it shares with number %5 at %6,%7. Since the first number only needs %8 mines total, its non-shared cells must be safe.", "")
                                         .arg(numbers[c2.cell])
                                         .arg(col2+1).arg(row2+1)
                                         .arg(minSharedMines)
                                         .arg(numbers[c1.cell])
                                         .arg(col1+1).arg(row1+1)
                                         .arg(c1.minesRequired);

                    return {safePos, reason};
                }
            }

            int minSharedMines1 = c1.minesRequired - onlyInC1.size();
            int minSharedMines2 = c2.minesRequired - onlyInC2.size();
            int minSharedMines = qMax(0, qMax(minSharedMines1, minSharedMines2));

            int maxMinesC1Exclusive = c1.minesRequired - minSharedMines2;
            int maxMinesC2Exclusive = c2.minesRequired - minSharedMines1;

            if (maxMinesC1Exclusive < onlyInC1.size() && !onlyInC1.isEmpty()) {
                int safePos = *onlyInC1.begin();
                int row1 = c1.cell / width;
                int col1 = c1.cell % width;
                int row2 = c2.cell / width;
                int col2 = c2.cell % width;

                QString reason = tr("Looking at numbers %1 at %2,%3 and %4 at %5,%6: at least %7 mines must be in their %8 shared cells. This means at most %9 mines can be in the %n non-shared cell(s) around the first number, so they can't all be mines.", "", onlyInC1.size())
                                     .arg(numbers[c1.cell])
                                     .arg(col1+1).arg(row1+1)
                                     .arg(numbers[c2.cell])
                                     .arg(col2+1).arg(row2+1)
                                     .arg(minSharedMines2)
                                     .arg(sharedCells.size())
                                     .arg(maxMinesC1Exclusive);

                return {safePos, reason};
            }

            if (maxMinesC2Exclusive < onlyInC2.size() && !onlyInC2.isEmpty()) {
                int safePos = *onlyInC2.begin();
                int row1 = c1.cell / width;
                int col1 = c1.cell % width;
                int row2 = c2.cell / width;
                int col2 = c2.cell % width;

                QString reason = tr("Looking at numbers %1 at %2,%3 and %4 at %5,%6: at least %7 mines must be in their %8 shared cells. This means at most %9 mines can be in the %n non-shared cell(s) around the second number, so they can't all be mines.", "", onlyInC2.size())
                                     .arg(numbers[c1.cell])
                                     .arg(col1+1).arg(row1+1)
                                     .arg(numbers[c2.cell])
                                     .arg(col2+1).arg(row2+1)
                                     .arg(minSharedMines1)
                                     .arg(sharedCells.size())
                                     .arg(maxMinesC2Exclusive);

                return {safePos, reason};
            }
        }
    }

    if (frontier.size() <= 20) {
        for (int cell : frontier) {
            QVector<Constraint> relevantConstraints;
            for (const Constraint& c : constraints) {
                if (c.unknowns.contains(cell)) {
                    relevantConstraints.append(c);
                }
            }

            if (relevantConstraints.size() < 2) continue;

            QSet<int> influencedCells;
            bool firstConstraint = true;

            for (const Constraint& c : relevantConstraints) {
                if (firstConstraint) {
                    for (int unknown : c.unknowns) {
                        if (unknown != cell) {
                            influencedCells.insert(unknown);
                        }
                    }
                    firstConstraint = false;
                } else {
                    QSet<int> newInfluenced;
                    for (int unknown : c.unknowns) {
                        if (unknown != cell && influencedCells.contains(unknown)) {
                            newInfluenced.insert(unknown);
                        }
                    }
                    influencedCells = newInfluenced;
                }
            }

            if (!influencedCells.isEmpty()) {
                bool allSafe = true;

                for (const Constraint& c : relevantConstraints) {
                    int nonInfluencedCount = 0;
                    for (int unknown : c.unknowns) {
                        if (unknown != cell && !influencedCells.contains(unknown)) {
                            nonInfluencedCount++;
                        }
                    }

                    if (c.minesRequired != nonInfluencedCount + 1) {
                        allSafe = false;
                        break;
                    }
                }

                if (allSafe && !influencedCells.isEmpty()) {
                    int safePos = *influencedCells.begin();
                    int cellRow = cell / width;
                    int cellCol = cell % width;

                    QString reason = tr("If there is a mine at %1,%2, then certain cells that share multiple number constraints must be safe by process of elimination.", "")
                                         .arg(cellCol+1).arg(cellRow+1);

                    return {safePos, reason};
                }

                bool allMines = true;

                for (const Constraint& c : relevantConstraints) {
                    int nonInfluencedCount = 0;
                    for (int unknown : c.unknowns) {
                        if (unknown != cell && !influencedCells.contains(unknown)) {
                            nonInfluencedCount++;
                        }
                    }

                    if (c.minesRequired != nonInfluencedCount + influencedCells.size()) {
                        allMines = false;
                        break;
                    }
                }

                if (allMines && !influencedCells.isEmpty()) {
                    int minePos = *influencedCells.begin();
                    int cellRow = cell / width;
                    int cellCol = cell % width;

                    QString reason = tr("If the cell at %1,%2 is safe, then certain cells that share multiple number constraints must contain mines by process of elimination.", "")
                                         .arg(cellCol+1).arg(cellRow+1);

                    return {minePos, reason};
                }
            }
        }
    }

    if (frontier.size() > 8 && frontier.size() <= 32) {
        int cell = solveFrontierCSP(width, height, constraints, QList<int>(frontier.begin(), frontier.end()));
        if (cell != -1) {
            int row = cell / width;
            int col = cell % width;

            bool isMine = false;
            for (const Constraint& c : constraints) {
                if (c.unknowns.contains(cell)) {
                    int flaggedCount = 0;
                    for (int neighbor : getNeighbors(c.cell, width, height)) {
                        if (flagged.contains(neighbor)) {
                            flaggedCount++;
                        }
                    }

                    if (flaggedCount + 1 == numbers[c.cell]) {
                        isMine = true;
                        break;
                    }
                }
            }

            QString reason;
            if (isMine) {
                reason = tr("Through constraint satisfaction analysis, I've determined this cell must contain a mine.");
            } else {
                reason = tr("Through constraint satisfaction analysis, I've determined this cell must be safe.");
            }

            return {cell, reason};
        }
    } else if (frontier.size() > 32) {
        int cell = solveWithConstraintIntersection(width, height, constraints, QList<int>(frontier.begin(), frontier.end()));
        if (cell != -1) {
            int row = cell / width;
            int col = cell % width;

            QString reason = tr("Based on analyzing the pattern of revealed numbers, this is the most informative cell to click next.");

            return {cell, reason};
        }
    }

    return {-1, tr("I couldn't find any definite safe moves or mines through logical analysis at this time.")};
}

int MinesweeperSolver::solveFrontierCSP(int width, int height,
                                        const QVector<Constraint> &constraints,
                                        const QList<int> &frontier) {
    qDebug() << "Running CSP solver for" << frontier.size() << "frontier cells...";
    QVector<int> frontierArray = frontier.toVector();

    int numConfigs = 1 << frontier.size();

    qDebug() << "Testing" << numConfigs << "possible configurations";

    QVector<bool> definitelyMine(frontier.size(), true);
    QVector<bool> definitelySafe(frontier.size(), true);

    int validConfigs = 0;

    for (int config = 0; config < numConfigs; config++) {
        QVector<bool> mineConfig(frontier.size(), false);
        for (int i = 0; i < frontier.size(); i++) {
            mineConfig[i] = (config & (1 << i)) != 0;
        }

        bool valid = true;
        for (const Constraint &constraint : constraints) {
            int minesInConfig = 0;

            for (int i = 0; i < frontier.size(); i++) {
                int cell = frontierArray[i];
                if (mineConfig[i] && constraint.unknowns.contains(cell)) {
                    minesInConfig++;
                }
            }

            if (minesInConfig != constraint.minesRequired) {
                valid = false;
                break;
            }
        }

        if (valid) {
            validConfigs++;

            for (int i = 0; i < frontier.size(); i++) {
                if (!mineConfig[i]) definitelyMine[i] = false;
                if (mineConfig[i]) definitelySafe[i] = false;
            }
        }
    }

    if (validConfigs == 0) {
        qDebug() << "No valid configurations found - the board may be unsolvable or have a logical contradiction";
        return -1;
    }

    qDebug() << "Found" << validConfigs << "valid configurations out of" << numConfigs << "possibilities";

    for (int i = 0; i < frontier.size(); i++) {
        if (definitelySafe[i]) {
            int row = frontierArray[i] / width;
            int col = frontierArray[i] % width;
            qDebug() << "\nFound definitely safe cell at" << col << "," << row
                     << "\nReason: This cell is safe in ALL" << validConfigs << "valid configurations"
                     << "\nThis means no matter how the other cells are arranged, this cell cannot be a mine";
            return frontierArray[i];
        }
    }

    for (int i = 0; i < frontier.size(); i++) {
        if (definitelyMine[i]) {
            int row = frontierArray[i] / width;
            int col = frontierArray[i] % width;
            qDebug() << "\nFound definitely mine cell at" << col << "," << row
                     << "\nReason: This cell is a mine in ALL" << validConfigs << "valid configurations"
                     << "\nThis means no matter how the other cells are arranged, this cell must be a mine";
            return frontierArray[i];
        }
    }

    qDebug() << "No cells were definitively safe or mines in all configurations";
    return -1;
}

int MinesweeperSolver::solveWithConstraintIntersection(int width, int height,
                                                       const QVector<Constraint> &constraints,
                                                       const QList<int> &frontier) {
    qDebug() << "Using constraint intersection methods for large frontier";

    qDebug() << "Checking for subset relationships between constraints...";
    for (int i = 0; i < constraints.size(); i++) {
        for (int j = 0; j < constraints.size(); j++) {
            if (i == j) continue;

            const Constraint &c1 = constraints[i];
            const Constraint &c2 = constraints[j];

            bool isSubset = true;
            for (int cell : c1.unknowns) {
                if (!c2.unknowns.contains(cell)) {
                    isSubset = false;
                    break;
                }
            }

            if (isSubset && c1.unknowns.size() < c2.unknowns.size()) {
                QSet<int> diffCells = c2.unknowns - c1.unknowns;
                int diffMines = c2.minesRequired - c1.minesRequired;

                int row1 = c1.cell / width;
                int col1 = c1.cell % width;
                int row2 = c2.cell / width;
                int col2 = c2.cell % width;

                qDebug() << "Found subset relationship: Cell" << col1 << "," << row1
                         << "is a subset of cell" << col2 << "," << row2
                         << "with" << diffCells.size() << "different cells and" << diffMines << "mine difference";

                if (diffMines == diffCells.size() && diffMines > 0) {
                    int mineCell = *diffCells.begin();
                    int mineRow = mineCell / width;
                    int mineCol = mineCell % width;
                    qDebug() << "\nFound mine at" << mineCol << "," << mineRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. The difference of" << diffMines << "mines must be in the remaining"
                             << diffCells.size() << "cells, forcing them all to be mines.";
                    return mineCell;
                }

                if (diffMines == 0 && !diffCells.isEmpty()) {
                    int safeCell = *diffCells.begin();
                    int safeRow = safeCell / width;
                    int safeCol = safeCell % width;
                    qDebug() << "\nFound safe cell at" << safeCol << "," << safeRow
                             << "\nReason: Cell at" << col2 << "," << row2 << "requires" << c2.minesRequired
                             << "mines in its unknowns. Cell at" << col1 << "," << row1 << "requires" << c1.minesRequired
                             << "mines and is a subset. Since both need the same number of mines, the extra"
                             << diffCells.size() << "cells in the second constraint must be safe.";
                    return safeCell;
                }
            }
        }
    }

    qDebug() << "Looking for cells involved in multiple constraints...";

    QMap<int, int> cellConstraintCount;
    QMap<int, QSet<int>> cellsToConstraints;

    for (int i = 0; i < constraints.size(); i++) {
        const Constraint &c = constraints[i];
        for (int cell : c.unknowns) {
            cellConstraintCount[cell]++;
            cellsToConstraints[cell].insert(i);
        }
    }

    int mostConstrainedCell = -1;
    int maxConstraints = 0;
    for (auto it = cellConstraintCount.begin(); it != cellConstraintCount.end(); ++it) {
        if (it.value() > maxConstraints) {
            mostConstrainedCell = it.key();
            maxConstraints = it.value();
        }
    }

    if (mostConstrainedCell != -1 && maxConstraints >= 3) {
        int row = mostConstrainedCell / width;
        int col = mostConstrainedCell % width;

        QStringList constraintDescriptions;
        for (int constraintIdx : cellsToConstraints[mostConstrainedCell]) {
            const Constraint &c = constraints[constraintIdx];
            int cRow = c.cell / width;
            int cCol = c.cell % width;
            constraintDescriptions.append(QString("Cell at %1,%2 (needs %3 mines in %4 cells)")
                                              .arg(cCol).arg(cRow)
                                              .arg(c.minesRequired).arg(c.unknowns.size()));
        }

    qDebug() << "\nSuggesting highly constrained cell at" << col << "," << row
             << "\nReason: This cell is involved in" << maxConstraints << "different constraints:"
             << "\n" << constraintDescriptions.join("\n")
                 << "\nResolving this cell will provide the most information about the board.";
        return mostConstrainedCell;
    }

    if (!frontier.isEmpty()) {
        int randomCell = frontier.first();
        int row = randomCell / width;
        int col = randomCell % width;
        qDebug() << "\nSuggesting frontier cell at" << col << "," << row
                 << "\nReason: No definite solution found with current information."
                 << "\nThis cell is on the frontier (adjacent to revealed cells) and may help uncover more information.";
        return randomCell;
    }

    qDebug() << "No viable hint found";
    return -1;
}
