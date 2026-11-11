import Foundation

struct NormalizedTranscript {
    let transcript: String
    let characters: [Character]
    private let originalIndices: [String.Index]

    private static let replacements: [Character: Character] = {
        var table: [Character: Character] = [
            "，": ",", "．": ".", "：": ":", "／": "/", "％": "%", "（": "(", "）": ")",
            "￥": "¥", "＄": "$", "￡": "£", "￦": "₩",
            "\u{2019}": "'", "\u{02BC}": "'",
            "\u{2013}": "-", "\u{2014}": "-", "\u{2212}": "-", "\u{FF0D}": "-",
            "٫": ".", "٬": ",",
        ]
        for digits in ["０１２３４５６７８９", "٠١٢٣٤٥٦٧٨٩", "۰۱۲۳۴۵۶۷۸۹", "०१२३४५६७८९"] {
            for (digit, ascii) in zip(digits, "0123456789") {
                table[digit] = ascii
            }
        }
        return table
    }()

    init(_ transcript: String) {
        self.transcript = transcript
        characters = transcript.map(Self.normalized)
        originalIndices = Array(transcript.indices) + [transcript.endIndex]
    }

    func originalRange(_ span: Range<Int>) -> Range<String.Index> {
        originalIndices[span.lowerBound]..<originalIndices[span.upperBound]
    }

    private static func normalized(_ character: Character) -> Character {
        if let replacement = replacements[character] { return replacement }
        return character.isWhitespace && !character.isNewline ? " " : character
    }

    var count: Int { characters.count }

    func character(at offset: Int) -> Character? {
        characters.indices.contains(offset) ? characters[offset] : nil
    }

    func isDigit(_ offset: Int) -> Bool {
        guard let character = character(at: offset) else { return false }
        return character.isASCII && character.isNumber
    }

    func isSpace(_ offset: Int) -> Bool {
        character(at: offset) == " "
    }

    func isBlank(_ range: Range<Int>, atMost maxLength: Int) -> Bool {
        range.count <= maxLength && range.allSatisfy(isSpace)
    }

    func string(_ range: Range<Int>) -> String {
        String(characters[range])
    }

    func hasPrefix(_ prefix: String, at offset: Int) -> Bool {
        let prefixCharacters = Array(prefix)
        guard offset >= 0, offset + prefixCharacters.count <= count else { return false }
        return Array(characters[offset..<offset + prefixCharacters.count]) == prefixCharacters
    }

    func word(startingAt offset: Int, where isPart: (Character) -> Bool) -> String {
        var end = offset
        while let character = character(at: end), isPart(character) { end += 1 }
        return string(offset..<end)
    }

    func word(endingBefore offset: Int, where isPart: (Character) -> Bool) -> String {
        var start = offset
        while let character = character(at: start - 1), isPart(character) { start -= 1 }
        return string(start..<offset)
    }

    func offset(of index: String.Index) -> Int {
        transcript.distance(from: transcript.startIndex, to: index)
    }
}
