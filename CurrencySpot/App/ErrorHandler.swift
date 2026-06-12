//
//  ErrorHandler.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation

@Observable
final class ErrorHandler {
    /// Single source of truth for the global error alert: non-nil means presented.
    private(set) var currentError: AppError?

    func handle(_ error: Error) {
        guard let appError = AppError.from(error) else {
            // Don't show cancellation errors
            return
        }
        currentError = appError
    }

    func dismiss() {
        currentError = nil
    }
}
