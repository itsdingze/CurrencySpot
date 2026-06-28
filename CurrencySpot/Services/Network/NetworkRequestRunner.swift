//
//  NetworkRequestRunner.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/29/25.
//

import Foundation

/// Runs network requests with automatic retry, unified HTTP error handling,
/// and JSON decoding across the app.
nonisolated enum NetworkRequestRunner {
    // MARK: - Retry-Enabled Network Requests

    /// Performs a network request with automatic retry logic, unified error handling and JSON decoding
    /// - Parameters:
    ///   - url: The URL to make the request to
    ///   - urlSession: The URLSession to use for the request
    ///   - responseType: The expected response type conforming to Codable
    ///   - endpoint: Identifier for retry tracking (defaults to URL path)
    ///   - retryManager: Retry state tracker; production shares one instance so the
    ///     calculator's retry indicator reflects network-layer attempts
    ///   - clock: Suspension seam so retry backoff is controllable under test
    /// - Returns: Decoded response object of the specified type
    /// - Throws: AppError for network, HTTP, or decoding failures after all retries exhausted
    @concurrent
    static func performRequestWithRetry<T: Codable & Sendable>(
        url: URL,
        urlSession: URLSession,
        responseType: T.Type,
        endpoint: String? = nil,
        retryManager: RetryManager = .shared,
        clock: ClockService = ContinuousClockService()
    ) async throws -> T {
        let endpointKey = endpoint ?? url.path
        // Static context: no DI seam reaches here, so a local live logger is used.
        let logger = OSLogLoggerService()

        var lastError: Error?

        // First attempt (not counted as a retry)
        do {
            let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
            await retryManager.recordSuccess(for: endpointKey)
            return result
        } catch {
            lastError = error

            // Check if this error should be retried
            guard retryManager.shouldRetry(error: error), await retryManager.canRetry(for: endpointKey) else {
                // Not retryable or no more attempts - throw the error
                throw error
            }
        }

        // Retry loop with cancellation cleanup
        while await retryManager.canRetry(for: endpointKey) {
            guard let retryInfo = await retryManager.recordAttempt(for: endpointKey) else {
                // No more attempts available
                break
            }

            logger.info("Retrying request to \(endpointKey) (attempt \(retryInfo.attempt), delay: \(String(format: "%.1f", retryInfo.delay))s)", category: .network)

            // Wait for the calculated delay with cancellation handling
            do {
                try await clock.sleep(for: .seconds(retryInfo.delay))
            } catch is CancellationError {
                // Task was cancelled - reset retry state and rethrow
                await retryManager.reset(for: endpointKey)
                logger.info("Request to \(endpointKey) was cancelled during retry delay", category: .network)
                throw CancellationError()
            }

            do {
                let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
                await retryManager.recordSuccess(for: endpointKey)
                logger.info("Request to \(endpointKey) succeeded on attempt \(retryInfo.attempt)", category: .network)
                return result
            } catch is CancellationError {
                // Task was cancelled during request - reset retry state and rethrow
                await retryManager.reset(for: endpointKey)
                logger.info("Request to \(endpointKey) was cancelled during network request", category: .network)
                throw CancellationError()
            } catch {
                lastError = error
                logger.warning("Retry \(retryInfo.attempt) failed for \(endpointKey): \(error.localizedDescription)", category: .network)

                // Check if we should continue retrying this specific error
                if !retryManager.shouldRetry(error: error) {
                    logger.warning("Error not retryable, stopping retry attempts for \(endpointKey)", category: .network)
                    break
                }
            }
        }

        // All retries exhausted
        let finalAttempt = await retryManager.getCurrentAttempt(for: endpointKey)
        logger.error("All retry attempts exhausted for \(endpointKey) after \(finalAttempt) attempts", category: .network)

        // Convert to retry-specific error if appropriate
        if let lastError, retryManager.shouldRetry(error: lastError) {
            throw AppError.retryExhausted("Unable to connect to server", attempts: finalAttempt)
        } else {
            throw lastError ?? AppError.networkError("Request failed after retries")
        }
    }

    // MARK: - Standard Network Requests

    /// Performs a network request with unified error handling and JSON decoding
    /// - Parameters:
    ///   - url: The URL to make the request to
    ///   - urlSession: The URLSession to use for the request
    ///   - responseType: The expected response type conforming to Codable
    /// - Returns: Decoded response object of the specified type
    /// - Throws: AppError for network, HTTP, or decoding failures
    @concurrent
    private static func performRequest<T: Codable & Sendable>(
        url: URL,
        urlSession: URLSession,
        responseType _: T.Type
    ) async throws -> T {
        // URLError must propagate unchanged so retry classification keeps
        // working — except .cancelled, which URLSession throws in place of
        // CancellationError when the surrounding task is cancelled; mapping
        // it makes the upstream cancellation branches reachable.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(from: url)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        }

        // Check for HTTP errors
        if let httpResponse = response as? HTTPURLResponse {
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw AppError.apiError("HTTP Error: \(httpResponse.statusCode)")
            }
        }

        // Decode the JSON response, wrapping only genuine decoding failures
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw AppError.decodingError(error.localizedDescription)
        }
    }

    /// Creates a URL from a string with proper error handling
    /// - Parameter urlString: The URL string to convert
    /// - Returns: A valid URL object
    /// - Throws: AppError.networkError if the URL string is invalid
    static func createURL(from urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw AppError.networkError("Invalid URL: \(urlString)")
        }
        return url
    }
}
