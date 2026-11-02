import Foundation
import Testing
@testable import CurrencySpot

extension PriceClassification {
    static func price(_ amount: String) throws -> PriceClassification {
        PriceClassification(amount: try #require(Decimal(string: amount)), isPrice: true)
    }

    static func outline(_ amount: String) throws -> PriceClassification {
        PriceClassification(amount: try #require(Decimal(string: amount)), isPrice: false)
    }
}
