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
