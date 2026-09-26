import Foundation
import os.log

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

enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error
    case fault
}

nonisolated protocol LoggerService: Sendable {
    func log(_ level: LogLevel, _ message: String, category: LogCategory, isPrivate: Bool)
}

nonisolated extension LoggerService {
    func debug(_ message: String, category: LogCategory) {
        log(.debug, message, category: category, isPrivate: false)
    }

    func info(_ message: String, category: LogCategory) {
        log(.info, message, category: category, isPrivate: false)
    }

    func infoPrivate(_ message: String, category: LogCategory) {
        log(.info, message, category: category, isPrivate: true)
    }

    func warning(_ message: String, category: LogCategory) {
        log(.warning, message, category: category, isPrivate: false)
    }

    func error(_ message: String, category: LogCategory) {
        log(.error, message, category: category, isPrivate: false)
    }

    func fault(_ message: String, category: LogCategory) {
        log(.fault, message, category: category, isPrivate: false)
    }
}

nonisolated struct OSLogLoggerService: LoggerService {
    private static let loggers: [LogCategory: Logger] = {
        let subsystem = Bundle.main.bundleIdentifier ?? "CurrencySpot"
        return Dictionary(uniqueKeysWithValues: LogCategory.allCases.map {
            ($0, Logger(subsystem: subsystem, category: $0.rawValue))
        })
    }()

    func log(_ level: LogLevel, _ message: String, category: LogCategory, isPrivate: Bool) {
        guard let logger = Self.loggers[category] else { return }
        switch (level, isPrivate) {
        case (.debug, false): logger.debug("\(message, privacy: .public)")
        case (.debug, true): logger.debug("\(message, privacy: .private)")
        case (.info, false): logger.info("\(message, privacy: .public)")
        case (.info, true): logger.info("\(message, privacy: .private)")
        case (.warning, false): logger.warning("\(message, privacy: .public)")
        case (.warning, true): logger.warning("\(message, privacy: .private)")
        case (.error, false): logger.error("\(message, privacy: .public)")
        case (.error, true): logger.error("\(message, privacy: .private)")
        case (.fault, false): logger.fault("\(message, privacy: .public)")
        case (.fault, true): logger.fault("\(message, privacy: .private)")
        }
    }
}
