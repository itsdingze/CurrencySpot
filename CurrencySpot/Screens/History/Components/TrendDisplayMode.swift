//
//  TrendDisplayMode.swift
//  CurrencySpot
//

/// What the per-row trend badge shows: the weekly percentage change, or the
/// absolute weekly change in the base-adjusted rate.
enum TrendDisplayMode: CaseIterable {
    case percentChange
    case priceChange

    var description: String {
        switch self {
        case .percentChange: "Percentage Change"
        case .priceChange: "Price Change"
        }
    }
}
