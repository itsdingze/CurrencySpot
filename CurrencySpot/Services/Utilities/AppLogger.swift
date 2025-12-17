//
//  AppLogger.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/28/25.
//

import Foundation
import os.log

/// Categories for organizing log messages
enum LogCategory: String {
    case network = "Network"
    case data = "DataCoordinator"
    case cache = "Cache"
    case ui = "UI"
    case persistence = "Persistence"
    case useCase = "UseCase"
    case viewModel = "ViewModel"
    case app = "App"
}

/// Centralized logging service using os.log
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CurrencySpot"

    /// Get a logger for a specific category
    static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: - Convenience Methods

    /// Log debug information (verbose, development only)
    static func debug(_ message: String, category: LogCategory) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    /// Log debug information with private data
    static func debugPrivate(_ message: String, category: LogCategory) {
        logger(for: category).debug("\(message, privacy: .private)")
    }

    /// Log general information (normal app flow)
    static func info(_ message: String, category: LogCategory) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    /// Log general information with private data
    static func infoPrivate(_ message: String, category: LogCategory) {
        logger(for: category).info("\(message, privacy: .private)")
    }

    /// Log warnings (potential issues)
    static func warning(_ message: String, category: LogCategory) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    /// Log warnings with private data
    static func warningPrivate(_ message: String, category: LogCategory) {
        logger(for: category).warning("\(message, privacy: .private)")
    }

    /// Log errors (recoverable failures)
    static func error(_ message: String, category: LogCategory) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    /// Log errors with private data
    static func errorPrivate(_ message: String, category: LogCategory) {
        logger(for: category).error("\(message, privacy: .private)")
    }

    /// Log faults (critical failures)
    static func fault(_ message: String, category: LogCategory) {
        logger(for: category).fault("\(message, privacy: .public)")
    }

    /// Log faults with private data
    static func faultPrivate(_ message: String, category: LogCategory) {
        logger(for: category).fault("\(message, privacy: .private)")
    }
}
