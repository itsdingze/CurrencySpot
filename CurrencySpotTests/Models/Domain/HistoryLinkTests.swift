@testable import CurrencySpot
import Foundation
import Testing

@Suite("HistoryLink")
struct HistoryLinkTests {
    @Test("a link survives the trip through its URL")
    func roundTripsThroughURL() {
        let link = HistoryLink(base: "USD", target: "JPY")

        #expect(HistoryLink(url: link.url) == link)
    }

    @Test("the URL names the pair in the app's scheme")
    func urlNamesThePair() {
        #expect(HistoryLink(base: "USD", target: "JPY").url.absoluteString == "currencyspot://history?base=USD&target=JPY")
    }

    @Test(
        "a URL that isn't a well-formed history link opens nothing",
        arguments: [
            "https://history?base=USD&target=JPY",
            "currencyspot://convert?base=USD&target=JPY",
            "currencyspot://history?base=USD",
            "currencyspot://history?base=usd&target=JPY",
            "currencyspot://history?base=USD&target=YENN",
            "currencyspot://history?base=USD&target=USD",
        ]
    )
    func rejectsMalformedLinks(_ string: String) throws {
        #expect(HistoryLink(url: try #require(URL(string: string))) == nil)
    }
}
