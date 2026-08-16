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
