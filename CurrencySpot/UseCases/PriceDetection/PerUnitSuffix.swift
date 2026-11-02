import Foundation

struct PerUnitSuffix {
    let text: String
    let end: Int

    static func following(_ offset: Int, in transcript: String) -> PerUnitSuffix? {
        let characters = Array(transcript)
        guard offset < characters.count else { return nil }
        let rest = String(characters[offset...])
        guard let match = rest.prefixMatch(of: pattern) else { return nil }
        return PerUnitSuffix(
            text: "/" + match.output.1 + match.output.2,
            end: offset + rest.distance(from: rest.startIndex, to: match.range.upperBound)
        )
    }

    private static let pattern = #/\s?\/\s?(\d{0,4})\s?(kg|lbs|lb|oz|ml|cl|dl|pcs|pce|pc|piece|each|ea|stk|st|l|g|個|本|枚)(?!\p{L})/#
        .ignoresCase()
}
