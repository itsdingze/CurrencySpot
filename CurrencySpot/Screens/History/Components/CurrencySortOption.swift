import Foundation

enum CurrencySortOption: CaseIterable {
    case manual
    case priceChange
    case percentChange
    case symbol
    case name

    var displayName: LocalizedStringResource {
        switch self {
        case .manual: .historySortManual
        case .priceChange: .historySortRateChange
        case .percentChange: .historySortPercentChange
        case .symbol: .historySortCurrencyCode
        case .name: .historySortName
        }
    }
}
