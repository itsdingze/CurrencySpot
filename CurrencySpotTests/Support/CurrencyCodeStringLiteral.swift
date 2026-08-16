@testable import CurrencySpot
import Foundation

extension CurrencyCode: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = try! CurrencyCode(validating: value)
    }
}
