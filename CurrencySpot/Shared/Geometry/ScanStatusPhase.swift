enum ScanStatusPhase: Equatable {
    case hidden
    case scanning
    case pointHint
    case notFound
    case numbersOnly
    case freezeHint

    static func resolve(
        isLive: Bool,
        hasPrices: Bool,
        isRecognizingStill: Bool,
        hintElapsed: Bool,
        hasOutlines: Bool = false,
        suggestsFreezing: Bool = false
    ) -> ScanStatusPhase {
        if hasPrices { return isLive && suggestsFreezing ? .freezeHint : .hidden }
        if isLive {
            if hasOutlines { return .numbersOnly }
            return hintElapsed ? .pointHint : .scanning
        }
        if isRecognizingStill { return .hidden }
        return hasOutlines ? .numbersOnly : .notFound
    }
}
