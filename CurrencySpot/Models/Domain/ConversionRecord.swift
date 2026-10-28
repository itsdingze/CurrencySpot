import Foundation

nonisolated struct ConversionRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let calculation: CalculatorExpression?
    let amount: Decimal
    let base: CurrencyCode
    let target: CurrencyCode
    let converted: Decimal
    let date: Date

    func isSameConversion(as other: ConversionRecord) -> Bool {
        calculation == other.calculation && amount == other.amount && base == other.base && target == other.target
    }
}
