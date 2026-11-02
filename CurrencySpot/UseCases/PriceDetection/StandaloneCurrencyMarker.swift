import Foundation

struct StandaloneCurrencyMarker {
    enum Side {
        case leading
        case trailing
    }

    let glyph: Character
    let side: Side

    static func glyph(in transcript: String) -> Character? {
        let visible = NormalizedTranscript(transcript).characters.filter { !$0.isWhitespace }
        guard visible.count == 1, let glyph = visible.first, CurrencyMarkerVocabulary.symbols[glyph] != nil
        else { return nil }
        return glyph
    }

    func attached(to transcript: String) -> String {
        side == .leading ? "\(glyph)\(transcript)" : "\(transcript)\(glyph)"
    }
}
