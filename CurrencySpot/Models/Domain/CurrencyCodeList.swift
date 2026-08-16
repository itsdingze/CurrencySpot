import IdentifiedCollections

typealias CurrencyCodeList = IdentifiedArray<CurrencyCode, CurrencyCode>

extension IdentifiedArray where ID == CurrencyCode, Element == CurrencyCode {
    // append(_:) rather than init(uniqueElements:), which traps on the duplicates
    // older persisted preference data can contain.
    static func deduplicating(_ codes: [CurrencyCode]) -> Self {
        var array = Self(id: \.self)
        for code in codes {
            array.append(code)
        }
        return array
    }
}
