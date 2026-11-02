import Foundation

struct PriceClassification: Equatable, Sendable {
    let amount: Decimal
    let isPrice: Bool
}

struct PriceClassifier {
    private let baseCurrency: CurrencyCode?

    init(baseCurrency: CurrencyCode? = nil) {
        self.baseCurrency = baseCurrency
    }

    func classify(_ transcript: String) -> PriceClassification? {
        let reading = TranscriptPriceReading(transcript, baseCurrency: baseCurrency)
        let best = reading.markedPrices.first
            ?? reading.unmarkedPricesWithCents.first
            ?? reading.unmarkedPrices.first
            ?? reading.outlines.first
        return best?.classification
    }

    func candidates(in transcript: String) -> [PriceCandidate] {
        let reading = TranscriptPriceReading(transcript, baseCurrency: baseCurrency)
        if !reading.markedPrices.isEmpty { return reading.markedPrices }
        if !reading.unmarkedPrices.isEmpty { return reading.unmarkedPrices }
        return Array(reading.outlines.prefix(1))
    }
}
