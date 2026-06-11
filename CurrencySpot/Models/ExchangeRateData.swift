//
//  ExchangeRateData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/28/25.
//

import Foundation
import SwiftData

@Model
final class ExchangeRateData {
    @Attribute(.unique) var currencyCode: String
    var rate: Double

    init(currencyCode: String, rate: Double) {
        self.currencyCode = currencyCode
        self.rate = rate
    }
}

// MARK: - Entity -> Domain Mapping

extension ExchangeRateData {
    /// Validates the stored code at the persistence → domain boundary.
    func toDomain() throws -> ExchangeRateDataValue {
        ExchangeRateDataValue(currencyCode: try CurrencyCode(validating: currencyCode), rate: rate)
    }
}
