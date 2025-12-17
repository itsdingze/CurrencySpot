//
//  RetryManager.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/28/25.
//

import Combine
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

/// NSCache-compatible wrapper for retry state
private final class RetryStateWrapper {
    let state: InternalRetryState

    init(_ state: InternalRetryState) {
        self.state = state
    }
}

/// Manages retry logic and state tracking for network operations
final class RetryManager {
    static let shared = RetryManager()

    private let configuration = RetryConfiguration.default
    private let queue = DispatchQueue(label: "RetryManager", qos: .utility)

    // Track retry state per endpoint using NSCache for automatic memory management
    private let retryStates = NSCache<NSString, RetryStateWrapper>()
    private var networkCancellable: AnyCancellable?

    private init() {
        // Configure NSCache with count-based limit for predictable memory usage
        retryStates.countLimit = 100 // Limit to 100 concurrent endpoints

        // Subscribe to network connectivity changes
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        // Note: NetworkMonitor uses @Observable which doesn't provide publishers
        // For now, skip automatic network monitoring integration
        // Network state changes can be manually triggered via networkDidBecomeAvailable()
        AppLogger.info("RetryManager initialized - manual network state management available", category: .network)
    }

    // MARK: - Public Interface

    /// Determines if an error should be retried
    /// - Parameter error: The error to evaluate
    /// - Returns: True if the error is retryable
    func shouldRetry(error: Error) -> Bool {
        // Check for retryable network errors
        if let urlError = error as? URLError {
            return isRetryableURLError(urlError)
        }

        // Check for retryable app errors
        if let appError = error as? AppError {
            return isRetryableAppError(appError)
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
        let jitter = Double.random(in: configuration.jitterRange)
        return cappedDelay * jitter
    }

    /// Checks if more attempts are available for the given endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: True if more attempts are available
    func canRetry(for endpoint: String) -> Bool {
        queue.sync { () -> Bool in
            guard let wrapper = retryStates.object(forKey: endpoint as NSString) else { return true }

            switch wrapper.state {
            case .initial, .succeeded:
                return true
            case let .retrying(attempt, _):
                return attempt < configuration.maxAttempts
            case .exhausted:
                return false
            }
        }
    }

    /// Records a retry attempt for the given endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: The current attempt number and next delay, or nil if exhausted
    func recordAttempt(for endpoint: String) -> (attempt: Int, delay: TimeInterval)? {
        queue.sync { () -> (attempt: Int, delay: TimeInterval)? in
            let currentState = retryStates.object(forKey: endpoint as NSString)?.state ?? .initial

            switch currentState {
            case .initial:
                let delay = calculateDelay(for: 0)
                retryStates.setObject(RetryStateWrapper(.retrying(attempt: 1, nextDelay: delay)), forKey: endpoint as NSString)
                return (attempt: 1, delay: delay)

            case let .retrying(attempt, _):
                if attempt >= configuration.maxAttempts {
                    retryStates.setObject(RetryStateWrapper(.exhausted), forKey: endpoint as NSString)
                    return nil
                }

                let nextAttempt = attempt + 1
                let delay = calculateDelay(for: nextAttempt - 1)
                retryStates.setObject(RetryStateWrapper(.retrying(attempt: nextAttempt, nextDelay: delay)), forKey: endpoint as NSString)
                return (attempt: nextAttempt, delay: delay)

            case .exhausted, .succeeded:
                return nil
            }
        }
    }

    /// Records a successful operation, resetting retry state
    /// - Parameter endpoint: The endpoint identifier
    func recordSuccess(for endpoint: String) {
        queue.sync { () in
            retryStates.setObject(RetryStateWrapper(.succeeded), forKey: endpoint as NSString)
        }
    }

    /// Gets the current retry attempt for an endpoint
    /// - Parameter endpoint: The endpoint identifier
    /// - Returns: The current attempt number, or 0 if no attempts recorded
    func getCurrentAttempt(for endpoint: String) -> Int {
        queue.sync { () -> Int in
            guard let wrapper = retryStates.object(forKey: endpoint as NSString) else { return 0 }

            switch wrapper.state {
            case .initial, .succeeded:
                return 0
            case let .retrying(attempt, _):
                return attempt
            case .exhausted:
                return configuration.maxAttempts
            }
        }
    }

    /// Resets retry state for an endpoint (useful when network reconnects)
    /// - Parameter endpoint: The endpoint identifier
    func reset(for endpoint: String) {
        queue.sync { () in
            retryStates.setObject(RetryStateWrapper(.initial), forKey: endpoint as NSString)
        }
    }

    /// Resets all retry states (useful when network reconnects)
    func resetAll() {
        queue.sync { () in
            retryStates.removeAllObjects()
        }
    }

    /// Call this when network connectivity is restored to reset all retry states
    /// This allows clients to manually trigger retry state cleanup
    func networkDidBecomeAvailable() {
        AppLogger.info("Network reconnected - resetting retry states", category: .network)
        resetAll()
    }

    // MARK: - Private Methods

    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }

    private func isRetryableAppError(_ error: AppError) -> Bool {
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

    private func extractHTTPStatusCode(from message: String) -> Int? {
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

    private func isRetryableHTTPStatus(_ statusCode: Int) -> Bool {
        // Retry 5xx server errors, but not 4xx client errors
        (500 ... 599).contains(statusCode)
    }
}
