//
//  NetworkUtility.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/29/25.
//

import Foundation

/// Utility class for common networking operations
/// Provides unified HTTP error handling and JSON decoding across the app
class NetworkUtility {
    // MARK: - Retry-Enabled Network Requests

    /// Performs a network request with automatic retry logic, unified error handling and JSON decoding
    /// - Parameters:
    ///   - url: The URL to make the request to
    ///   - urlSession: The URLSession to use for the request
    ///   - responseType: The expected response type conforming to Codable
    ///   - endpoint: Identifier for retry tracking (defaults to URL path)
    /// - Returns: Decoded response object of the specified type
    /// - Throws: AppError for network, HTTP, or decoding failures after all retries exhausted
    static func performRequestWithRetry<T: Codable>(
        url: URL,
        urlSession: URLSession,
        responseType: T.Type,
        endpoint: String? = nil
    ) async throws -> T {
        let endpointKey = endpoint ?? url.path
        let retryManager = RetryManager.shared

        var lastError: Error?

        // First attempt (not counted as a retry)
        do {
            let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
            retryManager.recordSuccess(for: endpointKey)
            return result
        } catch {
            lastError = error

            // Check if this error should be retried
            guard retryManager.shouldRetry(error: error), retryManager.canRetry(for: endpointKey) else {
                // Not retryable or no more attempts - throw the error
                throw error
            }
        }

        // Retry loop with cancellation cleanup
        while retryManager.canRetry(for: endpointKey) {
            guard let retryInfo = retryManager.recordAttempt(for: endpointKey) else {
                // No more attempts available
                break
            }

            AppLogger.info("Retrying request to \(endpointKey) (attempt \(retryInfo.attempt), delay: \(String(format: "%.1f", retryInfo.delay))s)", category: .network)

            // Wait for the calculated delay with cancellation handling
            do {
                try await Task.sleep(for: .seconds(retryInfo.delay))
            } catch is CancellationError {
                // Task was cancelled - reset retry state and rethrow
                retryManager.reset(for: endpointKey)
                AppLogger.info("Request to \(endpointKey) was cancelled during retry delay", category: .network)
                throw CancellationError()
            }

            do {
                let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
                retryManager.recordSuccess(for: endpointKey)
                AppLogger.info("Request to \(endpointKey) succeeded on attempt \(retryInfo.attempt)", category: .network)
                return result
            } catch is CancellationError {
                // Task was cancelled during request - reset retry state and rethrow
                retryManager.reset(for: endpointKey)
                AppLogger.info("Request to \(endpointKey) was cancelled during network request", category: .network)
                throw CancellationError()
            } catch {
                lastError = error
                AppLogger.warning("Retry \(retryInfo.attempt) failed for \(endpointKey): \(error.localizedDescription)", category: .network)

                // Check if we should continue retrying this specific error
                if !retryManager.shouldRetry(error: error) {
                    AppLogger.warning("Error not retryable, stopping retry attempts for \(endpointKey)", category: .network)
                    break
                }
            }
        }

        // All retries exhausted
        let finalAttempt = retryManager.getCurrentAttempt(for: endpointKey)
        AppLogger.error("All retry attempts exhausted for \(endpointKey) after \(finalAttempt) attempts", category: .network)

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
    static func performRequest<T: Codable>(
        url: URL,
        urlSession: URLSession,
        responseType _: T.Type
    ) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(from: url)

            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    throw AppError.apiError("HTTP Error: \(httpResponse.statusCode)")
                }
            }

            // Decode the JSON response
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            return decodedData

        } catch let error as AppError {
            // Re-throw AppError as-is
            throw error
        } catch {
            // Convert other errors to AppError
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
