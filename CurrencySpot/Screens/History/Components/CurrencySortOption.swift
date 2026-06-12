//
//  CurrencySortOption.swift
//  CurrencySpot
//

/// Sort orders for the History currency list.
enum CurrencySortOption: CaseIterable {
    case nameAZ
    case rateHighToLow
    case rateLowToHigh

    var description: String {
        switch self {
        case .nameAZ: "Name (A-Z)"
        case .rateHighToLow: "Rate (High to Low)"
        case .rateLowToHigh: "Rate (Low to High)"
        }
    }
}
