//
//  RetryManager.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/28/25.
//

import Foundation

/// Configuration for retry behavior
private struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let jitterRange: ClosedRange<Double>

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 8.0,
        jitterRange: 0.75 ... 1.25
    )
}

/// Tracks retry state for network operations
private enum InternalRetryState {
    case initial
    case retrying(attempt: Int, nextDelay: TimeInterval)
    case exhausted
    case succeeded
}

/// Manages retry logic and state tracking for network operations
actor RetryManager {
    static let shared = RetryManager()

    private let configuration = RetryConfiguration.default
    private let jitter: @Sendable (ClosedRange<Double>) -> Double

    private var retryStates: [String: InternalRetryState] = [:]

    /// - Parameter jitter: Random factor source for backoff delays; tests inject
    ///   a deterministic value.
    init(jitter: @escaping @Sendable (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        self.jitter = jitter
    }

    // MARK: - Public Interface

    /// Determines if an error should be retried
    /// - Parameter error: The error to evaluate
    /// - Returns: True if the error is retryable
    nonisolated func shouldRetry(error: Error) -> Bool {
        // Check for retryable network errors
        if let urlError = error as? URLError {
            return Self.isRetryableURLError(urlError)
        }

        // Check for retryable app errors
        if let appError = error as? AppError {
            return Self.isRetryableAppError(appError)
        }

        return false
    }

    /// Calculates the next retry delay with exponential backoff and jitter
    /// - Parameters:
    ///   - attempt: The current attempt number (0-based)
    /// - Returns: The delay in seconds before the next retry
    func calculateDelay(for attempt: Int) -> TimeInterval {
        // Input validation to prevent undefined behavior
        precondition(attempt >= 0, "Attempt number must be non-negative")

        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)

        // Add jitter to prevent thundering herd
        return cappedDelay * jitter(configuration.jitterRange)
    }

    /// Checks if more attempts are available for the given endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: True if more attempts are available
    func canRetry(for endpoint: String) -> Bool {
        guard let state = retryStates[endpoint] else { return true }

        switch state {
        case .initial, .succeeded:
            return true
        case let .retrying(attempt, _):
            return attempt < configuration.maxAttempts
        case .exhausted:
            return false
        }
    }

    /// Records a retry attempt for the given endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: The current attempt number and next delay, or nil if exhausted
    func recordAttempt(for endpoint: String) -> (attempt: Int, delay: TimeInterval)? {
        let currentState = retryStates[endpoint] ?? .initial

        switch currentState {
        case .initial:
            let delay = calculateDelay(for: 0)
            retryStates[endpoint] = .retrying(attempt: 1, nextDelay: delay)
            return (attempt: 1, delay: delay)

        case let .retrying(attempt, _):
            if attempt >= configuration.maxAttempts {
                retryStates[endpoint] = .exhausted
                return nil
            }

            let nextAttempt = attempt + 1
            let delay = calculateDelay(for: nextAttempt - 1)
            retryStates[endpoint] = .retrying(attempt: nextAttempt, nextDelay: delay)
            return (attempt: nextAttempt, delay: delay)

        case .exhausted, .succeeded:
            return nil
        }
    }

    /// Records a successful operation, resetting retry state
    /// - Parameter endpoint: The endpoint identifier
    func recordSuccess(for endpoint: String) {
        retryStates[endpoint] = .succeeded
    }

    /// Gets the current retry attempt for an endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: The current attempt number, or 0 if no attempts recorded
    func getCurrentAttempt(for endpoint: String) -> Int {
        guard let state = retryStates[endpoint] else { return 0 }

        switch state {
        case .initial, .succeeded:
            return 0
        case let .retrying(attempt, _):
            return attempt
        case .exhausted:
            return configuration.maxAttempts
        }
    }

    /// Resets retry state for an endpoint (useful when network reconnects)
    /// - Parameter endpoint: The endpoint identifier
    func reset(for endpoint: String) {
        retryStates[endpoint] = .initial
    }

    // MARK: - Private Methods

    private static func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }

    private static func isRetryableAppError(_ error: AppError) -> Bool {
        switch error {
        case .networkError, .noInternetConnection:
            true
        case let .apiError(message):
            // Extract HTTP status code from message and check if it's a 5xx server error
            extractHTTPStatusCode(from: message)
                .map { isRetryableHTTPStatus($0) } ?? false
        default:
            false
        }
    }

    private static func extractHTTPStatusCode(from message: String) -> Int? {
        // Extract status code from "HTTP Error: 500" format
        let pattern = #"HTTP Error: (\d{3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let statusCodeRange = Range(match.range(at: 1), in: message)
        else {
            return nil
        }
        return Int(message[statusCodeRange])
    }

    private static func isRetryableHTTPStatus(_ statusCode: Int) -> Bool {
        // Retry 5xx server errors, but not 4xx client errors
        (500 ... 599).contains(statusCode)
    }
}
