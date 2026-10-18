import Foundation
import OSLog

nonisolated enum NetworkRequestRunner {
    private static let logger = Logger(category: .network)

    // MARK: - Retry-Enabled Network Requests

    @concurrent
    static func performRequestWithRetry<T: Codable & Sendable>(
        url: URL,
        urlSession: URLSession,
        responseType: T.Type,
        endpoint: String? = nil,
        retryPolicy: RetryPolicy,
        clock: ClockService
    ) async throws -> T {
        let endpointKey = endpoint ?? url.path
        var retry = 0

        while true {
            do {
                let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
                if retry > 0 {
                    logger.info("Request to \(endpointKey, privacy: .public) succeeded on retry \(retry, privacy: .public)")
                }
                return result
            } catch is CancellationError {
                logger.info("Request to \(endpointKey, privacy: .public) was cancelled")
                throw CancellationError()
            } catch {
                guard retryPolicy.shouldRetry(error) else {
                    if retry > 0 {
                        logger.warning("Error not retryable, stopping retries for \(endpointKey, privacy: .public)")
                    }
                    throw error
                }
                guard retry < retryPolicy.maxRetries else {
                    logger.error("All retries exhausted for \(endpointKey, privacy: .public) after \(retry, privacy: .public) retries")
                    throw AppError.retryExhausted("Unable to connect to server", attempts: retry)
                }

                retry += 1
                let delay = retryPolicy.delay(beforeRetry: retry)
                logger.info("Retrying request to \(endpointKey, privacy: .public) (retry \(retry, privacy: .public), delay \(delay, format: .fixed(precision: 1), privacy: .public)s)")
                try await clock.sleep(for: .seconds(delay))
            }
        }
    }

    // MARK: - Standard Network Requests

    @concurrent
    private static func performRequest<T: Codable & Sendable>(
        url: URL,
        urlSession: URLSession,
        responseType _: T.Type
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(from: url)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        }

        if let httpResponse = response as? HTTPURLResponse {
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw AppError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw AppError.decodingError(error.localizedDescription)
        }
    }

    static func createURL(from urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw AppError.networkError("Invalid URL: \(urlString)")
        }
        return url
    }
}
