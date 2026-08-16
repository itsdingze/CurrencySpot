import Foundation

nonisolated enum NetworkRequestRunner {
    // MARK: - Retry-Enabled Network Requests

    @concurrent
    static func performRequestWithRetry<T: Codable & Sendable>(
        url: URL,
        urlSession: URLSession,
        responseType: T.Type,
        endpoint: String? = nil,
        retryManager: RetryManager,
        clock: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) async throws -> T {
        let endpointKey = endpoint ?? url.path

        var lastError: Error?

        do {
            let result = try await performRequest(url: url, urlSession: urlSession, responseType: responseType)
            await retryManager.recordSuccess(for: endpointKey)
            return result
        } catch {
            lastError = error

            guard retryManager.shouldRetry(error: error), await retryManager.canRetry(for: endpointKey) else {
                throw error
            }
        }

        while true {
            guard let retryInfo = await retryManager.recordAttempt(for: endpointKey) else {
                break
            }

            logger.info("Retrying request to \(endpointKey) (attempt \(retryInfo.attempt), delay: \(retryInfo.delay.formatted(.number.precision(.fractionLength(1))))s)", category: .network)

            do {
                try await clock.sleep(for: .seconds(retryInfo.delay))
            } catch is CancellationError {
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
                await retryManager.reset(for: endpointKey)
                logger.info("Request to \(endpointKey) was cancelled during network request", category: .network)
                throw CancellationError()
            } catch {
                lastError = error
                logger.warning("Retry \(retryInfo.attempt) failed for \(endpointKey): \(error.localizedDescription)", category: .network)

                if !retryManager.shouldRetry(error: error) {
                    logger.warning("Error not retryable, stopping retry attempts for \(endpointKey)", category: .network)
                    break
                }
            }
        }

        let finalAttempt = await retryManager.getCurrentAttempt(for: endpointKey)
        logger.error("All retry attempts exhausted for \(endpointKey) after \(finalAttempt) attempts", category: .network)

        if let lastError, retryManager.shouldRetry(error: lastError) {
            throw AppError.retryExhausted("Unable to connect to server", attempts: finalAttempt)
        } else {
            throw lastError ?? AppError.networkError("Request failed after retries")
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
                throw AppError.apiError("HTTP Error: \(httpResponse.statusCode)")
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
