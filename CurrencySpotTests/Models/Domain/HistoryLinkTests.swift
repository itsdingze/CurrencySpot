@testable import CurrencySpot
import Foundation
import Testing

@Suite("HistoryLink")
struct HistoryLinkTests {
    @Test("a link survives the trip through its URL")
    func roundTripsThroughURL() {
        let link = HistoryLink(base: "USD", target: "JPY", period: .oneYear)

        #expect(HistoryLink(url: link.url) == link)
    }

    @Test("the URL names the pair and time range in the app's scheme")
    func urlNamesThePairAndRange() {
        let link = HistoryLink(base: "USD", target: "JPY", period: .oneWeek)

        #expect(link.url.absoluteString == "currencyspot://history?base=USD&target=JPY&range=1W")
    }

    @Test("a link without a time range opens on three months")
    func missingRangeOpensThreeMonths() throws {
        let url = try #require(URL(string: "currencyspot://history?base=USD&target=JPY"))

        #expect(HistoryLink(url: url)?.period == .threeMonths)
    }

    @Test("a link with an unknown time range still opens the pair on three months")
    func unknownRangeOpensThreeMonths() throws {
        let url = try #require(URL(string: "currencyspot://history?base=USD&target=JPY&range=2W"))

        #expect(HistoryLink(url: url) == HistoryLink(base: "USD", target: "JPY", period: .threeMonths))
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
