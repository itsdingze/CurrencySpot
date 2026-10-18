import Foundation

nonisolated struct RetryPolicy: Sendable {
    let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let jitterRange: ClosedRange<Double>
    private let jitter: @Sendable (ClosedRange<Double>) -> Double

    init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 8.0,
        jitterRange: ClosedRange<Double> = 0.75 ... 1.25,
        jitter: @escaping @Sendable (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterRange = jitterRange
        self.jitter = jitter
    }

    func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return Self.isRetryable(urlError)
        }
        if let appError = error as? AppError {
            return Self.isRetryable(appError)
        }
        return false
    }

    func delay(beforeRetry retry: Int) -> TimeInterval {
        precondition(retry >= 1, "Retries are numbered from 1")
        let exponentialDelay = baseDelay * pow(2.0, Double(retry - 1))
        return min(exponentialDelay, maxDelay) * jitter(jitterRange)
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }

    private static func isRetryable(_ error: AppError) -> Bool {
        switch error {
        case .networkError, .noInternetConnection:
            true
        case let .httpError(statusCode):
            (500 ... 599).contains(statusCode)
        default:
            false
        }
    }
}
