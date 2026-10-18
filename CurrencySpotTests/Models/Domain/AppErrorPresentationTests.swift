@testable import CurrencySpot
import Foundation
import Testing

@Suite("AppError presentation")
struct AppErrorPresentationTests {
    private static let mappedURLCodes: [URLError.Code] = [
        .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
        .dnsLookupFailed, .httpTooManyRedirects, .resourceUnavailable, .badServerResponse,
    ]

    @Test("a timed-out request explains the timeout in one complete message")
    func timedOutMessage() throws {
        let error = try #require(AppError.from(URLError(.timedOut)))

        #expect(String(localized: error.message) == "The request timed out. Please check your internet connection and try again.")
    }

    @Test("every mapped URL failure shows its own message")
    func mappedURLFailuresAreDistinct() throws {
        let messages = try Self.mappedURLCodes.map { code in
            try String(localized: #require(AppError.from(URLError(code))).message)
        }

        #expect(Set(messages).count == Self.mappedURLCodes.count)
        #expect(!messages.contains(String(localized: AppError.networkError("").message)))
    }

    @Test("an unmapped URL failure falls back to the generic connection message")
    func unmappedURLFailureMessage() throws {
        let error = try #require(AppError.from(URLError(.badURL)))

        #expect(String(localized: error.message) == "Unable to connect to the server. Please try again later.")
    }

    @Test("an offline URL failure becomes the no-internet error")
    func offlineURLFailure() {
        #expect(AppError.from(URLError(.notConnectedToInternet)) == .noInternetConnection)
    }

    @Test("diagnostic payloads never reach the title or message", arguments: [
        AppError.networkError("diagnostic-payload"),
        .decodingError("diagnostic-payload"),
        .dateCalculationError("diagnostic-payload"),
        .unknownError("diagnostic-payload"),
        .dataValidationError("diagnostic-payload"),
        .initializationFailed("diagnostic-payload"),
        .retryExhausted("diagnostic-payload", attempts: 3),
    ])
    func payloadStaysOutOfPresentation(error: AppError) {
        #expect(!String(localized: error.title).contains("diagnostic-payload"))
        #expect(!String(localized: error.message).contains("diagnostic-payload"))
    }

    @Test("retry exhaustion pluralizes the attempt count", arguments: [
        (1, "Unable to connect after 1 attempt. Please check your internet connection and try again."),
        (3, "Unable to connect after 3 attempts. Please check your internet connection and try again."),
    ])
    func retryExhaustedMessage(attempts: Int, expected: String) {
        let error = AppError.retryExhausted("server down", attempts: attempts)

        #expect(String(localized: error.message) == expected)
    }
}
