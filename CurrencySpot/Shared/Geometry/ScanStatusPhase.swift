enum ScanStatusPhase: Equatable {
    case hidden
    case scanning
    case pointHint
    case notFound
    case numbersOnly

    static func resolve(
        isLive: Bool,
        hasPrices: Bool,
        isRecognizingStill: Bool,
        hintElapsed: Bool,
        hasOutlines: Bool = false
    ) -> ScanStatusPhase {
        if hasPrices { return .hidden }
        if isLive {
            if hasOutlines { return .numbersOnly }
            return hintElapsed ? .pointHint : .scanning
        }
        if isRecognizingStill { return .hidden }
        return hasOutlines ? .numbersOnly : .notFound
    }
}
