import Foundation

nonisolated enum LiveReadPacing {
    private static let seriousHeatReadInterval = Duration.milliseconds(500)

    static func allowsRead(thermalState: ProcessInfo.ThermalState, sinceLastReadStart: Duration?) -> Bool {
        switch thermalState {
        case .serious:
            guard let sinceLastReadStart else { return true }
            return sinceLastReadStart >= seriousHeatReadInterval
        case .critical:
            return false
        default:
            return true
        }
    }
}
