import Foundation

enum SpacedGroupingMerger {
    static func merged(
        _ tokens: [NumberToken],
        in text: NormalizedTranscript,
        isMarked: (Range<Int>) -> Bool
    ) -> [NumberToken] {
        var result: [NumberToken] = []
        var index = 0
        while index < tokens.count {
            let end = chainEnd(from: index, in: tokens, text: text)
            if end > index {
                let merged = merge(tokens[index...end])
                if merged.hasDashNotation || isMarked(merged.span) {
                    result.append(merged)
                    index = end + 1
                    continue
                }
            }
            result.append(tokens[index])
            index += 1
        }
        return result
    }

    private static func chainEnd(from start: Int, in tokens: [NumberToken], text: NormalizedTranscript) -> Int {
        guard isHead(tokens[start]) else { return start }
        var end = start
        while end + 1 < tokens.count,
              end == start || isPlainThousands(tokens[end]),
              tokens[end + 1].span.lowerBound == tokens[end].span.upperBound + 1,
              text.isSpace(tokens[end].span.upperBound),
              isGroup(tokens[end + 1]) {
            end += 1
        }
        return end
    }

    private static func isHead(_ token: NumberToken) -> Bool {
        isUndecorated(token) && token.groups.count == 1 && (1...3).contains(token.groups[0].count)
    }

    private static func isPlainThousands(_ token: NumberToken) -> Bool {
        isUndecorated(token) && token.groups.count == 1 && token.groups[0].count == 3
    }

    private static func isUndecorated(_ token: NumberToken) -> Bool {
        token.multipliedAmount == nil && !token.hasDashNotation
    }

    private static func isGroup(_ token: NumberToken) -> Bool {
        guard token.multipliedAmount == nil, token.groups.first?.count == 3 else { return false }
        if token.groups.count == 1 { return true }
        return token.groups.count == 2 && token.separators[0] != "'" && (1...2).contains(token.groups[1].count)
    }

    private static func merge(_ parts: ArraySlice<NumberToken>) -> NumberToken {
        parts.dropFirst().reduce(into: parts[parts.startIndex]) { merged, part in
            merged.groups += part.groups
            merged.separators += [" "] + part.separators
            merged.span = merged.span.lowerBound..<part.span.upperBound
            merged.hasDashNotation = part.hasDashNotation
        }
    }
}
