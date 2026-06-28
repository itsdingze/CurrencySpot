//
//  NumberFormatting.swift
//  CurrencySpot
//

import Foundation

extension Double {
    /// Convert to string with maximum 2 decimal places (0-2 range)
    var toStringMax2Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    /// Convert to string with maximum 4 decimal places (0-4 range)
    var toStringMax4Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 4)))
    }

    /// Convert to string with 2 decimal places
    var toString2Decimals: String {
        formatted(.number.precision(.fractionLength(2 ... 2)))
    }
}
