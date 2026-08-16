import Foundation

nonisolated struct ScannedConversion: Hashable, Sendable {
    let amount: Decimal
    let converted: Decimal
    let isPrice: Bool

    var asPrice: ScannedConversion {
        ScannedConversion(amount: amount, converted: converted, isPrice: true)
    }

    var asNonPrice: ScannedConversion {
        ScannedConversion(amount: amount, converted: converted, isPrice: false)
    }
}
