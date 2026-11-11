import Foundation
import Testing
@testable import CurrencySpot

nonisolated struct PriceCorpusCase: Sendable, CustomTestStringConvertible {
    enum Label: Sendable {
        case price(String)
        case notPrice
        case multi([String])
        case bare
    }

    let text: String
    let label: Label
    let group: String
    let base: CurrencyCode?

    init(_ text: String, _ label: Label, group: String, base: CurrencyCode? = nil) {
        self.text = text
        self.label = label
        self.group = group
        self.base = base
    }

    var testDescription: String { "[\(group)] \(text.debugDescription)" }
}
