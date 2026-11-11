@testable import CurrencySpot
import Foundation
import Testing

@Suite("AppIconOption Tests")
struct AppIconOptionTests {
    @Test("every icon in the picker is one iOS can put on the Home Screen")
    func everyIconIsRegisteredWithIOS() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])

        for name in AppIconOption.allCases.compactMap(\.alternateIconName) {
            #expect(alternates[name] != nil, "\(name) is missing from CFBundleAlternateIcons")
        }
    }
}
