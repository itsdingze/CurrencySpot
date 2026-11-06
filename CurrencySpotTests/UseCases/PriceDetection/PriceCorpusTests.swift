import Foundation
import Testing
@testable import CurrencySpot

struct PriceCorpusTests {
    @Test(arguments: MainPriceCorpus.cases)
    func mainCorpusCaseMatchesItsLabel(_ corpusCase: PriceCorpusCase) throws {
        try expectLabel(of: corpusCase)
    }

    @Test(arguments: HeldOutPriceCorpus.cases)
    func heldOutCorpusCaseMatchesItsLabel(_ corpusCase: PriceCorpusCase) throws {
        try expectLabel(of: corpusCase)
    }

    @Test(arguments: HeldOutPriceCorpus.knownGaps)
    func heldOutCorpusKnownGapStillMissesItsLabel(_ gap: PriceCorpusGap) {
        withKnownIssue(Comment(rawValue: gap.reason)) {
            try expectLabel(of: gap.corpusCase)
        }
    }

    private func expectLabel(of corpusCase: PriceCorpusCase) throws {
        let classifier = PriceClassifier(baseCurrency: corpusCase.base)
        let result = classifier.classify(corpusCase.text)
        switch corpusCase.label {
        case let .price(amount):
            #expect(result == (try .price(amount)))
        case .notPrice:
            #expect(result?.isPrice != true)
        case .bare:
            #expect(result?.isPrice == false)
        case let .multi(amounts):
            let expected = try amounts.map { try #require(Decimal(string: $0)) }
            let first = try #require(result)
            #expect(first.isPrice && expected.contains(first.amount))
            let candidates = classifier.candidates(in: corpusCase.text).filter(\.isPrice).map(\.amount)
            #expect(Set(expected).isSubset(of: candidates))
        }
    }
}
