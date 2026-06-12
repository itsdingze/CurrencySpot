//
//  ExchangeRateData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/28/25.
//

import Foundation
import SwiftData

@Model
nonisolated final class ExchangeRateData {
    @Attribute(.unique) var currencyCode: String
    var rate: Double

    init(currencyCode: String, rate: Double) {
        self.currencyCode = currencyCode
        self.rate = rate
    }
}

// MARK: - Entity -> Domain Mapping

nonisolated extension ExchangeRateData {
    /// Validates the stored code at the persistence → domain boundary.
    func toDomain() throws -> ExchangeRate {
        ExchangeRate(currencyCode: try CurrencyCode(validating: currencyCode), rate: rate)
    }
}
