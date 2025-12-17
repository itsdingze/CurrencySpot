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

    func handle(_ error: Error) {
        guard let appError = AppError.from(error) else {
            // Don't show cancellation errors
            return
        }

        currentError = appError
        showingError = true
    }

    func dismiss() {
        showingError = false
        // Keep currentError for a moment so the alert dismisses smoothly
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            self.currentError = nil
        }
    }
}
