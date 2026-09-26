import Foundation

private nonisolated struct RetryConfiguration {
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

private nonisolated enum InternalRetryState {
    case retrying(attempt: Int, nextDelay: TimeInterval)
    case exhausted
}

actor RetryManager {
    private let configuration = RetryConfiguration.default
    private let jitter: @Sendable (ClosedRange<Double>) -> Double

    private var retryStates: [String: InternalRetryState] = [:]

    private nonisolated static let defaultJitter: @Sendable (ClosedRange<Double>) -> Double = { Double.random(in: $0) }

    init(jitter: @escaping @Sendable (ClosedRange<Double>) -> Double = RetryManager.defaultJitter) {
        self.jitter = jitter
    }

    // MARK: - Public Interface

    nonisolated func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            return Self.isRetryableURLError(urlError)
        }

        if let appError = error as? AppError {
            return Self.isRetryableAppError(appError)
        }

        return false
    }

    func calculateDelay(for attempt: Int) -> TimeInterval {
        precondition(attempt >= 0, "Attempt number must be non-negative")

        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)

        return cappedDelay * jitter(configuration.jitterRange)
    }

    func canRetry(for endpoint: String) -> Bool {
        guard let state = retryStates[endpoint] else { return true }

        switch state {
        case let .retrying(attempt, _):
            return attempt < configuration.maxAttempts
        case .exhausted:
            return false
        }
    }

    func recordAttempt(for endpoint: String) -> (attempt: Int, delay: TimeInterval)? {
        guard let currentState = retryStates[endpoint] else {
            let delay = calculateDelay(for: 0)
            retryStates[endpoint] = .retrying(attempt: 1, nextDelay: delay)
            return (attempt: 1, delay: delay)
        }

        switch currentState {
        case let .retrying(attempt, _):
            if attempt >= configuration.maxAttempts {
                retryStates[endpoint] = .exhausted
                return nil
            }

            let nextAttempt = attempt + 1
            let delay = calculateDelay(for: nextAttempt - 1)
            retryStates[endpoint] = .retrying(attempt: nextAttempt, nextDelay: delay)
            return (attempt: nextAttempt, delay: delay)

        case .exhausted:
            return nil
        }
    }

    func recordSuccess(for endpoint: String) {
        retryStates[endpoint] = nil
    }

    func getCurrentAttempt(for endpoint: String) -> Int {
        guard let state = retryStates[endpoint] else { return 0 }

        switch state {
        case let .retrying(attempt, _):
            return attempt
        case .exhausted:
            return configuration.maxAttempts
        }
    }

    func snapshot(for endpoint: String) -> (attempt: Int, maxAttempts: Int, canRetry: Bool) {
        (getCurrentAttempt(for: endpoint), configuration.maxAttempts, canRetry(for: endpoint))
    }

    func reset(for endpoint: String) {
        retryStates[endpoint] = nil
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
        case let .httpError(statusCode):
            (500 ... 599).contains(statusCode)
        default:
            false
        }
    }
}
