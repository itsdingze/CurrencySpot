import Foundation

nonisolated struct CurrencyCode: Hashable, Sendable {
    let rawValue: String

    init(validating rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw AppError.dataValidationError("Invalid currency code: '\(rawValue)'")
        }
        self.rawValue = rawValue
    }

    init?(_ rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    static let usd = CurrencyCode(unchecked: "USD")
    static let eur = CurrencyCode(unchecked: "EUR")
    static let gbp = CurrencyCode(unchecked: "GBP")
    static let jpy = CurrencyCode(unchecked: "JPY")
    static let cny = CurrencyCode(unchecked: "CNY")
    static let cad = CurrencyCode(unchecked: "CAD")
    static let aud = CurrencyCode(unchecked: "AUD")
    static let inr = CurrencyCode(unchecked: "INR")
    static let chf = CurrencyCode(unchecked: "CHF")
    static let mxn = CurrencyCode(unchecked: "MXN")
    static let brl = CurrencyCode(unchecked: "BRL")
    static let rub = CurrencyCode(unchecked: "RUB")
    static let bgn = CurrencyCode(unchecked: "BGN")
    static let czk = CurrencyCode(unchecked: "CZK")
    static let dkk = CurrencyCode(unchecked: "DKK")
    static let hkd = CurrencyCode(unchecked: "HKD")

    private static func isValid(_ string: String) -> Bool {
        string.utf8.count == 3 && string.utf8.allSatisfy { (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains($0) }
    }
}

nonisolated extension CurrencyCode: Comparable {
    static func < (lhs: CurrencyCode, rhs: CurrencyCode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated extension CurrencyCode: Codable {
    init(from decoder: Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated extension CurrencyCode: CustomStringConvertible {
    var description: String { rawValue }
}
