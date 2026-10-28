import Foundation

struct KeypadKey: Identifiable {
    typealias Role = CalculatorExpression.Input

    let id: String
    let amountRole: Role
    let calculatorRole: Role
    let slot: KeySlot

    private init(_ id: String, amount: Role, calculator: Role? = nil, slot: KeySlot) {
        self.id = id
        amountRole = amount
        calculatorRole = calculator ?? amount
        self.slot = slot
    }

    func isPresent(in mode: CalculatorViewModel.KeypadMode) -> Bool {
        switch mode {
        case .amount: slot.amount != nil
        case .calculator: slot.calculator != nil
        }
    }

    func role(in mode: CalculatorViewModel.KeypadMode) -> Role {
        mode == .amount ? amountRole : calculatorRole
    }

    static let all: [KeypadKey] = [
        KeypadKey("topDelete", amount: .delete, slot: KeySlot(calculator: GridCell(row: 0, column: 0))),
        KeypadKey("topClear", amount: .clear, slot: KeySlot(calculator: GridCell(row: 0, column: 1))),
        KeypadKey("percent", amount: .percent, slot: KeySlot(calculator: GridCell(row: 0, column: 2))),
        KeypadKey("divide", amount: .operation(.divide), slot: KeySlot(calculator: GridCell(row: 0, column: 3))),
        digitKey(7), digitKey(8), digitKey(9),
        operatorKey("multiply", .multiply, row: 1),
        digitKey(4), digitKey(5), digitKey(6),
        operatorKey("subtract", .subtract, row: 2),
        digitKey(1), digitKey(2), digitKey(3),
        operatorKey("add", .add, row: 3),
        KeypadKey(
            "amountClear",
            amount: .clear,
            slot: KeySlot(amount: GridCell(row: 3, column: 0), hidden: .leading(calculatorRow: 4))
        ),
        KeypadKey(
            "0",
            amount: .digit(0),
            slot: KeySlot(amount: GridCell(row: 3, column: 1), calculator: GridCell(row: 4, column: 0, span: 2))
        ),
        KeypadKey(
            "deleteThenPoint",
            amount: .delete,
            calculator: .decimalPoint,
            slot: KeySlot(amount: GridCell(row: 3, column: 2), calculator: GridCell(row: 4, column: 2))
        ),
        KeypadKey(
            "equals",
            amount: .equals,
            slot: KeySlot(calculator: GridCell(row: 4, column: 3), hidden: .trailing(amountRow: 3))
        ),
    ]

    private static func operatorKey(_ id: String, _ op: CalculatorExpression.Operator, row: Int) -> KeypadKey {
        KeypadKey(
            id,
            amount: .operation(op),
            slot: KeySlot(calculator: GridCell(row: row, column: 3), hidden: .trailing(amountRow: row - 1))
        )
    }

    private static func digitKey(_ digit: Int) -> KeypadKey {
        let row = 2 - (digit - 1) / 3
        let column = (digit - 1) % 3
        return KeypadKey(
            "\(digit)",
            amount: .digit(digit),
            slot: KeySlot(amount: GridCell(row: row, column: column), calculator: GridCell(row: row + 1, column: column))
        )
    }
}
