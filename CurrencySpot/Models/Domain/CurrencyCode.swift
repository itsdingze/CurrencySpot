//
//  CurrencyCode.swift
//  CurrencySpot
//

import Foundation

/// A validated currency code: exactly 3 ASCII uppercase letters.
/// Validation happens once at data boundaries (network mapper, persistence mappers);
/// everything downstream can trust the value.
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

    /// For compile-time constants only; bypasses validation.
    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    static let usd = CurrencyCode(unchecked: "USD")

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
