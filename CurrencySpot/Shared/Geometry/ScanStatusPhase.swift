enum ScanStatusPhase: Equatable {
    case hidden
    case scanning
    case pointHint
    case notFound

    static func resolve(
        isLive: Bool,
        hasPrices: Bool,
        isRecognizingStill: Bool,
        hintElapsed: Bool
    ) -> ScanStatusPhase {
        if hasPrices { return .hidden }
        if isLive { return hintElapsed ? .pointHint : .scanning }
        return isRecognizingStill ? .hidden : .notFound
    }
}
