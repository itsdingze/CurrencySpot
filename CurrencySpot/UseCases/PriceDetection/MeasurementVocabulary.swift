import Foundation

enum MeasurementVocabulary {
    static let unitWords: Set<String> = [
        "kg", "g", "mg", "µg", "mcg", "lb", "lbs", "oz", "fl", "gal", "qt", "ct",
        "km", "m", "cm", "mm", "nm", "mi", "ft", "yd", "inch", "inches", "sqft", "awg",
        "ml", "l", "cl", "dl", "cc", "vol",
        "kcal", "cal", "kj", "wh", "kwh", "kw", "w", "v", "mah", "ah", "hp", "ps", "psi", "lm", "db",
        "ghz", "mhz", "hz", "mph", "rpm", "fps", "dpi", "px", "mp",
        "gb", "tb", "mb", "kb", "mbps", "gbps",
        "h", "hr", "hrs", "min", "mins", "sec",
        "pcs", "pc", "pt", "pts", "x", "stk", "tbsp", "tsp",
    ]

    static let countNouns: Set<String> = [
        "reviews", "review", "ratings", "rating", "votes", "sold", "views", "likes", "followers",
        "comments", "people", "persons", "guests", "seats", "members", "users", "steps",
    ]

    static let marksAfter: Set<Character> = ["%", "‰", "°", "\"", "″", "'"]

    static let gluedMarksAfter: Set<Character> = ["★", "☆", "⭐"]

    static let marksBefore: Set<Character> = ["★", "☆", "⭐", "#", "№", "Ø", "⌀"]

    static let gluedMarksBefore: Set<Character> = ["%", "‰"]

    static let gluedPrefixes: Set<Character> = ["#", "№", "/", "×"]

    static let counters: [String] = [
        "倍", "件", "名", "人", "個", "个", "本", "枚", "分", "秒", "時間", "時", "歩", "回", "点", "号", "番",
        "階", "層", "種", "种", "杯", "皿", "台", "冊", "泊", "歳", "位", "度", "升", "克", "丁", "合", "部",
        "席", "室", "年", "月", "日", "公斤", "公里", "公分", "厘米", "毫升", "ポイント",
        "명", "배", "층", "번", "개", "잔", "분", "시간", "인분", "권", "장", "대", "살", "년", "월", "일", "호",
        "กม", "กก", "ชม", "คน",
    ]
}
