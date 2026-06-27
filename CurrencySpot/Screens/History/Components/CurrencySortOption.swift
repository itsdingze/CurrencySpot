//
//  CurrencySortOption.swift
//  CurrencySpot
//

/// Sort orders for the History watchlist. `manual` is the user's drag order and
/// the only mode in which rows can be reordered; the rest are computed orders.
enum CurrencySortOption: CaseIterable {
    case manual
    case priceChange
    case percentChange
    case symbol
    case name

    var description: String {
        switch self {
        case .manual: "Manual"
        case .priceChange: "Price Change"
        case .percentChange: "Percentage Change"
        case .symbol: "Symbol"
        case .name: "Name"
        }
    }
}
