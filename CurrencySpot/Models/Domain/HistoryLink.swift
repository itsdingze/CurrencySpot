import Foundation

nonisolated struct HistoryLink: Hashable, Sendable {
    private static let scheme = "currencyspot"
    private static let host = "history"

    let base: CurrencyCode
    let target: CurrencyCode
    let period: TimeRange

    init(base: CurrencyCode, target: CurrencyCode, period: TimeRange = .threeMonths) {
        self.base = base
        self.target = target
        self.period = period
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let base = Self.currency(named: "base", in: items),
              let target = Self.currency(named: "target", in: items),
              base != target
        else { return nil }
        let period = items.first { $0.name == "range" }?.value.flatMap(TimeRange.init(rawValue:))
        self.init(base: base, target: target, period: period ?? .threeMonths)
    }

    private static func currency(named name: String, in items: [URLQueryItem]) -> CurrencyCode? {
        items.first { $0.name == name }?.value.flatMap { CurrencyCode($0) }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "base", value: base.rawValue),
            URLQueryItem(name: "target", value: target.rawValue),
            URLQueryItem(name: "range", value: period.rawValue),
        ]
        return components.url ?? URL(filePath: "/")
    }
}
