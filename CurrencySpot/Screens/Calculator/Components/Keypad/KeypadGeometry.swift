import CoreGraphics

nonisolated struct GridCell: Equatable {
    let row: Int
    let column: Int
    var span = 1
}

nonisolated enum HiddenPlacement: Equatable {
    case above
    case trailing(amountRow: Int)
    case leading(calculatorRow: Int)
}

nonisolated struct KeySlot: Equatable {
    var amount: GridCell?
    var calculator: GridCell?
    var hidden = HiddenPlacement.above

    private static let stagger: CGFloat = 0.2

    fileprivate func travel(at progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        switch (amount, calculator) {
        case (nil, _): return max(0, (clamped - Self.stagger) / (1 - Self.stagger))
        case (_, nil): return min(1, clamped / (1 - Self.stagger))
        default: return clamped
        }
    }

    func visibility(at progress: CGFloat) -> CGFloat {
        switch (amount, calculator) {
        case (nil, _): travel(at: progress)
        case (_, nil): 1 - travel(at: progress)
        default: 1
        }
    }
}

nonisolated struct KeypadGeometry {
    let bounds: CGRect
    let spacing: CGFloat

    private var amountGrid: KeyGrid { KeyGrid(bounds: bounds, columns: 3, rows: 4, spacing: spacing) }
    private var calculatorGrid: KeyGrid { KeyGrid(bounds: bounds, columns: 4, rows: 5, spacing: spacing) }

    static func topOverflow(at progress: CGFloat, whileSwitching switching: CGFloat, whenSettled settled: CGFloat) -> CGFloat {
        progress <= 0 || progress >= 1 ? settled : switching
    }

    func frame(for slot: KeySlot, progress: CGFloat) -> CGRect {
        let start = slot.amount.map(amountGrid.frame) ?? hiddenFrame(for: slot)
        let end = slot.calculator.map(calculatorGrid.frame) ?? hiddenFrame(for: slot)
        return start.interpolated(to: end, progress: slot.travel(at: progress))
    }

    private func hiddenFrame(for slot: KeySlot) -> CGRect {
        let offscreen = spacing * 2
        switch slot.hidden {
        case .above:
            let target = calculatorGrid.frame(for: slot.calculator ?? GridCell(row: 0, column: 0))
            return CGRect(x: target.minX, y: bounds.minY - target.height - offscreen, width: target.width, height: target.height)
        case let .trailing(amountRow):
            let row = amountGrid.frame(for: GridCell(row: amountRow, column: 0))
            let width = calculatorGrid.frame(for: GridCell(row: 0, column: 0)).width
            return CGRect(x: bounds.maxX + offscreen, y: row.minY, width: width, height: row.height)
        case let .leading(calculatorRow):
            let row = calculatorGrid.frame(for: GridCell(row: calculatorRow, column: 0))
            let width = amountGrid.frame(for: GridCell(row: 0, column: 0)).width
            return CGRect(x: bounds.minX - width - offscreen, y: row.minY, width: width, height: row.height)
        }
    }
}

private nonisolated struct KeyGrid {
    let bounds: CGRect
    let columns: Int
    let rows: Int
    let spacing: CGFloat

    private var cellWidth: CGFloat { (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns) }
    private var cellHeight: CGFloat { (bounds.height - CGFloat(rows - 1) * spacing) / CGFloat(rows) }

    func frame(for cell: GridCell) -> CGRect {
        CGRect(
            x: bounds.minX + CGFloat(cell.column) * (cellWidth + spacing),
            y: bounds.minY + CGFloat(cell.row) * (cellHeight + spacing),
            width: CGFloat(cell.span) * cellWidth + CGFloat(cell.span - 1) * spacing,
            height: cellHeight
        )
    }
}

private nonisolated extension CGRect {
    func interpolated(to end: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: minX + (end.minX - minX) * progress,
            y: minY + (end.minY - minY) * progress,
            width: width + (end.width - width) * progress,
            height: height + (end.height - height) * progress
        )
    }
}
