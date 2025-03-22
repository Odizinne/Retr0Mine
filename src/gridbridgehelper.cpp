#include <QSet>
#include <QDebug>
#include "gridbridgehelper.h"

GridBridgeHelper::GridBridgeHelper(QObject *parent)
    : QObject(parent) {
}

QVariantList GridBridgeHelper::performFloodFillReveal(int index, int gridSizeX, int gridSizeY,
                                                      const QVector<int> &mines,
                                                      const QVector<int> &numbers,
                                                      QJSValue getCellCallback) {
    QVariantList cellsToReveal;

    if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || !getCellCallback.isCallable()) {
        qWarning() << "Invalid parameters in performFloodFillReveal";
        return cellsToReveal;
    }

    QJSValue cell = getCellCallback.call({index});
    if (!cell.isObject()) {
        return cellsToReveal;
    }

    bool isRevealed = cell.property("revealed").toBool();
    bool isFlagged = cell.property("flagged").toBool();
    if (isRevealed || isFlagged) {
        return cellsToReveal;
    }

    cellsToReveal.append(index);

    if (mines.contains(index)) {
        return cellsToReveal;
    }

    int cellNumber = numbers.value(index, 0);
    if (cellNumber > 0) {
        return cellsToReveal;
    }

    QVector<int> cellsToProcess;
    QSet<int> visited;

    cellsToProcess.append(index);
    visited.insert(index);

    while (!cellsToProcess.isEmpty()) {
        int currentIndex = cellsToProcess.takeFirst();
        int row = currentIndex / gridSizeX;
        int col = currentIndex % gridSizeX;

        for (int r = -1; r <= 1; ++r) {
            for (int c = -1; c <= 1; ++c) {
                int newRow = row + r;
                int newCol = col + c;

                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                    continue;
                }

                int adjacentIndex = newRow * gridSizeX + newCol;

                if (visited.contains(adjacentIndex)) {
                    continue;
                }

                visited.insert(adjacentIndex);

                QJSValue adjacentCell = getCellCallback.call({adjacentIndex});
                if (!adjacentCell.isObject()) {
                    continue;
                }

                bool adjacentFlagged = adjacentCell.property("flagged").toBool();
                if (adjacentFlagged) {
                    continue;
                }

                bool adjacentRevealed = adjacentCell.property("revealed").toBool();
                if (!adjacentRevealed) {
                    cellsToReveal.append(adjacentIndex);

                    int adjacentNumber = numbers.value(adjacentIndex, 0);
                    if (adjacentNumber == 0) {
                        cellsToProcess.append(adjacentIndex);
                    }
                }
            }
        }
    }

    return cellsToReveal;
}

QVariantList GridBridgeHelper::getAdjacentCellsToReveal(int index, int gridSizeX, int gridSizeY,
                                                        const QVector<int> &numbers,
                                                        QJSValue getCellCallback) {
    QVariantList cellsToReveal;

    if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || !getCellCallback.isCallable()) {
        qWarning() << "Invalid parameters in getAdjacentCellsToReveal";
        return cellsToReveal;
    }

    QJSValue cell = getCellCallback.call({index});
    if (!cell.isObject()) {
        return cellsToReveal;
    }

    bool isRevealed = cell.property("revealed").toBool();
    if (!isRevealed) {
        return cellsToReveal;
    }

    int cellNumber = numbers.value(index, 0);
    if (cellNumber <= 0) {
        return cellsToReveal;
    }

    int row = index / gridSizeX;
    int col = index % gridSizeX;
    int flaggedCount = 0;
    QVector<int> adjacentUnrevealed;
    bool hasQuestionMark = false;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                continue;
            }

            int adjacentIndex = newRow * gridSizeX + newCol;

            QJSValue adjacentCell = getCellCallback.call({adjacentIndex});
            if (!adjacentCell.isObject()) {
                continue;
            }

            bool questioned = adjacentCell.property("questioned").toBool();
            bool safeQuestioned = adjacentCell.property("safeQuestioned").toBool();
            if (questioned || safeQuestioned) {
                hasQuestionMark = true;
                break;
            }

            bool adjacentFlagged = adjacentCell.property("flagged").toBool();
            if (adjacentFlagged) {
                flaggedCount++;
            } else {
                bool adjacentRevealed = adjacentCell.property("revealed").toBool();
                if (!adjacentRevealed) {
                    adjacentUnrevealed.append(adjacentIndex);
                }
            }
        }

        if (hasQuestionMark) {
            break;
        }
    }

    if (hasQuestionMark) {
        return cellsToReveal;
    }

    if (flaggedCount == cellNumber && !adjacentUnrevealed.isEmpty()) {
        for (int i = 0; i < adjacentUnrevealed.size(); ++i) {
            cellsToReveal.append(adjacentUnrevealed[i]);
        }
    }

    return cellsToReveal;
}

bool GridBridgeHelper::hasUnrevealedNeighbors(int index, int gridSizeX, int gridSizeY,
                                              const QVector<int> &numbers,
                                              QJSValue getCellCallback) {
    if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || !getCellCallback.isCallable()) {
        return false;
    }

    int cellNumber = numbers.value(index, 0);
    if (cellNumber == 0) {
        return false;
    }

    int row = index / gridSizeX;
    int col = index % gridSizeX;
    int flagCount = 0;
    bool hasUnrevealed = false;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                continue;
            }

            int adjacentIndex = newRow * gridSizeX + newCol;

            QJSValue adjacentCell = getCellCallback.call({adjacentIndex});
            if (!adjacentCell.isObject()) {
                continue;
            }

            bool adjacentFlagged = adjacentCell.property("flagged").toBool();
            if (adjacentFlagged) {
                flagCount++;
            }

            bool adjacentRevealed = adjacentCell.property("revealed").toBool();
            if (!adjacentRevealed && !adjacentFlagged) {
                hasUnrevealed = true;
            }
        }
    }

    return hasUnrevealed || flagCount != cellNumber;
}

int GridBridgeHelper::getNeighborFlagCount(int index, int gridSizeX, int gridSizeY,
                                           QJSValue getCellCallback) {
    if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || !getCellCallback.isCallable()) {
        return 0;
    }

    int row = index / gridSizeX;
    int col = index % gridSizeX;
    int flagCount = 0;

    for (int r = -1; r <= 1; ++r) {
        for (int c = -1; c <= 1; ++c) {
            if (r == 0 && c == 0) continue;

            int newRow = row + r;
            int newCol = col + c;

            if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                continue;
            }

            int adjacentIndex = newRow * gridSizeX + newCol;

            QJSValue adjacentCell = getCellCallback.call({adjacentIndex});
            if (!adjacentCell.isObject()) {
                continue;
            }

            bool adjacentFlagged = adjacentCell.property("flagged").toBool();
            if (adjacentFlagged) {
                flagCount++;
            }
        }
    }

    return flagCount;
}
