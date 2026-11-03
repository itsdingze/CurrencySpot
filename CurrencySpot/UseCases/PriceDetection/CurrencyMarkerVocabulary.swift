import Foundation

enum CurrencyMarkerVocabulary {
    struct LocalWord {
        let placement: CurrencyMarker.Placement
        var needsMoneyShape = false
    }

    static let centSign: Character = "¢"

    static let euroSign: Character = "€"

    static let kuai: Character = "块"

    static let kuaiBaseCurrency = CurrencyCode.cny

    static let symbolsWithoutSpacedGrouping: Set<Character> = ["¥", "円", "元", "원", "₩", "圓"]

    static let symbols: [Character: CurrencyMarker.Placement] = {
        var table: [Character: CurrencyMarker.Placement] = [:]
        for symbol in "$£¥₩₹฿₱₦₪₨৳₡₲₭₮៛₵₾₼" { table[symbol] = .beforeNumber }
        for symbol in "€₽₴₸₺₫" { table[symbol] = .afterNumber }
        for symbol in "円元원圓¢" { table[symbol] = .afterNumberOnly }
        return table
    }()

    static let wordLikeISOCodes: Set<String> = [
        "ALL", "TOP", "CUP", "TRY", "PEN", "GEL", "SOS", "MOP", "BOB", "CAD", "COP", "RON", "BAM", "AWG", "CVE",
        "MNT", "SCR",
    ]

    private static let isoCodes = Set(Locale.commonISOCurrencyCodes).union(["RMB"])

    private static let localWords: [String: LocalWord] = {
        var table: [String: LocalWord] = [:]
        for word in ["Rs", "Rp", "KSh", "Ksh"] { table[word] = LocalWord(placement: .beforeNumber) }
        for word in ["kr", "Kr", "zł", "Zł", "Kč", "lei", "Lei", "лв", "руб", "грн", "VNĐ", "đ"] {
            table[word] = LocalWord(placement: .afterNumber)
        }
        table["Ft"] = LocalWord(placement: .afterNumber, needsMoneyShape: true)
        for word in [
            "บาท", "yen", "Yen", "euro", "euros", "Euro", "Euros", "baht", "rupees", "pesos", "yuan", "dollars",
        ] {
            table[word] = LocalWord(placement: .afterNumberOnly)
        }
        return table
    }()

    private static let baseGatedWords: [String: (word: LocalWord, base: String)] = [
        "RM": (LocalWord(placement: .beforeNumber), "MYR"),
        "TL": (LocalWord(placement: .afterNumber), "TRY"),
        "Fr": (LocalWord(placement: .beforeNumber, needsMoneyShape: true), "CHF"),
        "SFr": (LocalWord(placement: .beforeNumber, needsMoneyShape: true), "CHF"),
        "KD": (LocalWord(placement: .beforeNumber), "KWD"),
        "BD": (LocalWord(placement: .beforeNumber), "BHD"),
        "JD": (LocalWord(placement: .beforeNumber), "JOD"),
        "DT": (LocalWord(placement: .afterNumber), "TND"),
        "QR": (LocalWord(placement: .beforeNumber), "QAR"),
        "SR": (LocalWord(placement: .beforeNumber), "SAR"),
        "Dh": (LocalWord(placement: .beforeNumber), "AED"),
        "Dhs": (LocalWord(placement: .beforeNumber), "AED"),
        "Tk": (LocalWord(placement: .beforeNumber), "BDT"),
        "Ft": (LocalWord(placement: .afterNumber), "HUF"),
    ]

    static func isSymbolGlyph(_ character: Character) -> Bool {
        symbols[character] != nil || character == kuai
    }

    static func isISOCode(_ word: String) -> Bool {
        word.count == 3 && word.allSatisfy { $0.isASCII && $0.isUppercase } && isoCodes.contains(word)
    }

    static func localWord(_ word: String, baseCurrency: CurrencyCode?) -> LocalWord? {
        if let gated = baseGatedWords[word], gated.base == baseCurrency?.rawValue { return gated.word }
        return localWords[word]
    }

    static func isCurrencyWord(_ word: String) -> Bool {
        isISOCode(word) || localWords[word] != nil || baseGatedWords[word] != nil
    }
}
