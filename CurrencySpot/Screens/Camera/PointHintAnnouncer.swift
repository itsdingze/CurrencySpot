struct PointHintAnnouncer {
    private var hintElapsed = false
    private var hasAnnounced = false

    mutating func shouldAnnounce(phase: ScanStatusPhase, hintElapsed elapsed: Bool) -> Bool {
        defer { hintElapsed = elapsed }
        guard elapsed, !hintElapsed, !hasAnnounced, phase == .pointHint else { return false }
        hasAnnounced = true
        return true
    }
}
