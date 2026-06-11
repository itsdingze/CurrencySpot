//
//  ErrorHandler.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation

@Observable
@MainActor
final class ErrorHandler {
    var currentError: AppError?
    var showingError: Bool = false

    private let clock: ClockService

    // nonisolated(unsafe): only ever mutated on the main actor; deinit (nonisolated)
    // reads it once when no other reference can exist.
    private nonisolated(unsafe) var dismissTask: Task<Void, Never>?

    init(clock: ClockService = ContinuousClockService()) {
        self.clock = clock
    }

    deinit {
        dismissTask?.cancel()
    }

    func handle(_ error: Error) {
        guard let appError = AppError.from(error) else {
            // Don't show cancellation errors
            return
        }

        // Cancel any pending dismissal so it cannot clear this newly surfaced error.
        dismissTask?.cancel()
        currentError = appError
        showingError = true
    }

    func dismiss() {
        showingError = false
        // Keep currentError briefly so the alert dismisses smoothly. Cancel any prior pending
        // clear, and bail if a new error surfaced while we were waiting.
        dismissTask?.cancel()
        dismissTask = Task { [clock] in
            try? await clock.sleep(for: .seconds(0.3))
            guard !Task.isCancelled, !showingError else { return }
            currentError = nil
        }
    }
}
