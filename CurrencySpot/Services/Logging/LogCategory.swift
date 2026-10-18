import Foundation
import OSLog

nonisolated enum LogCategory: String, CaseIterable, Sendable {
    case network = "Network"
    case data = "DataCoordinator"
    case cache = "Cache"
    case ui = "UI"
    case persistence = "Persistence"
    case useCase = "UseCase"
    case viewModel = "ViewModel"
    case app = "App"
}

nonisolated extension Logger {
    private static let appSubsystem = Bundle.main.bundleIdentifier ?? "CurrencySpot"

    init(category: LogCategory) {
        self.init(subsystem: Self.appSubsystem, category: category.rawValue)
    }
}
