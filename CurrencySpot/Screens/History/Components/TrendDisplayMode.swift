import Foundation

enum TrendDisplayMode: CaseIterable {
    case percentChange
    case priceChange

    var displayName: LocalizedStringResource {
        switch self {
        case .percentChange: .historyTrendDisplayPercentChange
        case .priceChange: .historyTrendDisplayRateChange
        }
    }
}
