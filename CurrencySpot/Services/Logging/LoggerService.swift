//
//  LoggerService.swift
//  CurrencySpot
//

import Foundation
import os.log

/// Categories for organizing log messages
enum LogCategory: String, Sendable {
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

/// Injectable logging seam. The single requirement keeps test doubles trivial;
/// the extension provides the ergonomic per-level methods call sites use.
/// `nonisolated`: logging is called from the persistence actor and @concurrent
/// network code, so the seam must not be MainActor-bound.
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

/// Live implementation over `os.Logger`.
nonisolated struct OSLogLoggerService: LoggerService {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CurrencySpot"

    func log(_ level: LogLevel, _ message: String, category: LogCategory, isPrivate: Bool) {
        let logger = Logger(subsystem: Self.subsystem, category: category.rawValue)
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
