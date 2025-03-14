#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QJSValue>
#include <QVector>
#include <QVariantList>

class GridBridgeHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit GridBridgeHelper(QObject *parent = nullptr);

    // Flood fill reveal - returns list of cells to reveal
    Q_INVOKABLE QVariantList performFloodFillReveal(int index, int gridSizeX, int gridSizeY,
                                                    const QVector<int> &mines,
                                                    const QVector<int> &numbers,
                                                    QJSValue getCellCallback);

    // Get adjacent cells to reveal when clicking on a number
    Q_INVOKABLE QVariantList getAdjacentCellsToReveal(int index, int gridSizeX, int gridSizeY,
                                                      const QVector<int> &numbers,
                                                      QJSValue getCellCallback);

    // Helper functions
    Q_INVOKABLE bool hasUnrevealedNeighbors(int index, int gridSizeX, int gridSizeY,
                                            const QVector<int> &numbers,
                                            QJSValue getCellCallback);

    Q_INVOKABLE int getNeighborFlagCount(int index, int gridSizeX, int gridSizeY,
                                         QJSValue getCellCallback);
};
