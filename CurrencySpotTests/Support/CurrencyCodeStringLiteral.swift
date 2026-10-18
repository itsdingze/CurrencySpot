@testable import CurrencySpot
import Foundation

extension CurrencyCode: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let code = CurrencyCode(value) else {
            preconditionFailure("Test fixture uses an invalid currency code literal: \"\(value)\"")
        }
        self = code
    }
}
