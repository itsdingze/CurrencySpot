import SwiftUI

enum AppIconOption: CaseIterable, Identifiable {
    case dollar
    case coins

    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .dollar
    }

    var id: Self { self }

    var alternateIconName: String? {
        switch self {
        case .dollar: nil
        case .coins: "AppIconCoins"
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .dollar: .settingsAppIconDollar
        case .coins: .settingsAppIconCoins
        }
    }

    var artwork: ImageResource {
        switch self {
        case .dollar: .icon
        case .coins: .iconCoins
        }
    }
}
