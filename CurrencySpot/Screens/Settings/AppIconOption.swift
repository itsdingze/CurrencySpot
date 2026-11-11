import SwiftUI

enum AppIconOption: CaseIterable, Identifiable {
    case dollar
    case euro
    case yen
    case pound
    case won
    case coins
    case dollarYenCoins
    case dollarPoundCoins
    case dollarWonCoins
    case poundEuroCoins
    case wonYenCoins

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
        case .dollarYenCoins: "AppIconDollarYenCoins"
        case .dollarPoundCoins: "AppIconDollarPoundCoins"
        case .dollarWonCoins: "AppIconDollarWonCoins"
        case .poundEuroCoins: "AppIconPoundEuroCoins"
        case .wonYenCoins: "AppIconWonYenCoins"
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
        case .dollarYenCoins: .settingsAppIconDollarYenCoins
        case .dollarPoundCoins: .settingsAppIconDollarPoundCoins
        case .dollarWonCoins: .settingsAppIconDollarWonCoins
        case .poundEuroCoins: .settingsAppIconPoundEuroCoins
        case .wonYenCoins: .settingsAppIconWonYenCoins
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
        case .dollarYenCoins: .iconDollarYenCoins
        case .dollarPoundCoins: .iconDollarPoundCoins
        case .dollarWonCoins: .iconDollarWonCoins
        case .poundEuroCoins: .iconPoundEuroCoins
        case .wonYenCoins: .iconWonYenCoins
        }
    }
}
