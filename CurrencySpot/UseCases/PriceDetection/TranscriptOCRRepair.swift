import Foundation

enum TranscriptOCRRepair {
    private static let letterO: Character = "O"
    private static let openingBrackets: Set<Character> = ["(", "["]

    static func repaired(_ characters: [Character]) -> [Character] {
        var result = characters
        for index in characters.indices where isDollarSignReadAsS(at: index, in: characters) {
            result[index] = "$"
        }
        for run in numberRuns(in: characters) where holdsZeroReadAsO(run, in: characters) {
            for index in run where characters[index] == letterO {
                result[index] = "0"
            }
        }
        return result
    }

    private static func isDollarSignReadAsS(at index: Int, in characters: [Character]) -> Bool {
        guard characters[index] == "S", isWordStart(index, in: characters) else { return false }
        var offset = index + 1
        while offset < characters.count, NormalizedTranscript.isDigit(characters[offset]) { offset += 1 }
        let centsEnd = offset + 3
        guard offset > index + 1, centsEnd <= characters.count, characters[offset] == ".",
              NormalizedTranscript.isDigit(characters[offset + 1]), NormalizedTranscript.isDigit(characters[offset + 2])
        else { return false }
        guard centsEnd < characters.count else { return true }
        return !characters[centsEnd].isLetter && !NormalizedTranscript.isDigit(characters[centsEnd])
    }

    private static func isWordStart(_ index: Int, in characters: [Character]) -> Bool {
        guard index > 0 else { return true }
        return characters[index - 1].isWhitespace || openingBrackets.contains(characters[index - 1])
    }

    private static func numberRuns(in characters: [Character]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        while start < characters.count {
            guard isNumberPart(characters[start]) else {
                start += 1
                continue
            }
            var end = start + 1
            while end < characters.count, isNumberPart(characters[end]) { end += 1 }
            runs.append(start..<end)
            start = end
        }
        return runs
    }

    private static func isNumberPart(_ character: Character) -> Bool {
        NormalizedTranscript.isDigit(character) || character == letterO || character == "." || character == ","
    }

    private static func holdsZeroReadAsO(_ run: Range<Int>, in characters: [Character]) -> Bool {
        let parts = characters[run]
        guard parts.contains(letterO), parts.contains(where: NormalizedTranscript.isDigit) else { return false }
        return !isWordLetter(at: run.lowerBound - 1, in: characters)
            && !isWordLetter(at: run.upperBound, in: characters)
            && touchesCurrencySymbol(run, in: characters)
    }

    private static func isWordLetter(at offset: Int, in characters: [Character]) -> Bool {
        guard let character = character(at: offset, in: characters) else { return false }
        return character.isLetter && CurrencyMarkerVocabulary.symbols[character] == nil
    }

    private static func touchesCurrencySymbol(_ run: Range<Int>, in characters: [Character]) -> Bool {
        let before = character(at: run.lowerBound - 1, in: characters) == " " ? run.lowerBound - 2 : run.lowerBound - 1
        let after = character(at: run.upperBound, in: characters) == " " ? run.upperBound + 1 : run.upperBound
        return [before, after].contains { offset in
            character(at: offset, in: characters).flatMap { CurrencyMarkerVocabulary.symbols[$0] } != nil
        }
    }

    private static func character(at offset: Int, in characters: [Character]) -> Character? {
        characters.indices.contains(offset) ? characters[offset] : nil
    }
}
