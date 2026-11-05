import SwiftUI

enum AppIconOption: CaseIterable, Identifiable {
    case dollar
    case euro
    case yen
    case pound
    case won
    case coins

    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .dollar
    }

    var id: Self { self }

    var alternateIconName: String? {
        switch self {
        case .dollar: nil
        case .euro: "AppIconEuro"
        case .yen: "AppIconYen"
        case .pound: "AppIconPound"
        case .won: "AppIconWon"
        case .coins: "AppIconCoins"
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .dollar: .settingsAppIconDollar
        case .euro: .settingsAppIconEuro
        case .yen: .settingsAppIconYen
        case .pound: .settingsAppIconPound
        case .won: .settingsAppIconWon
        case .coins: .settingsAppIconCoins
        }
    }

    var artwork: ImageResource {
        switch self {
        case .dollar: .icon
        case .euro: .iconEuro
        case .yen: .iconYen
        case .pound: .iconPound
        case .won: .iconWon
        case .coins: .iconCoins
        }
    }
}
