//
//  ErrorHandlerTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("ErrorHandler Tests")
@MainActor
struct ErrorHandlerTests {
    private let handler = ErrorHandler()

    @Test("handle publishes the error as the single presentation source of truth")
    func handlePublishesError() {
        #expect(handler.currentError == nil)

        handler.handle(AppError.noInternetConnection)

        #expect(handler.currentError == .noInternetConnection)
    }

    @Test("cancellation errors are swallowed, not surfaced")
    func cancellationIgnored() {
        handler.handle(CancellationError())

        #expect(handler.currentError == nil)
    }

    @Test("a newer error replaces the presented one")
    func newerErrorReplaces() {
        handler.handle(AppError.noInternetConnection)
        handler.handle(AppError.noCachedData)

        #expect(handler.currentError == .noCachedData)
    }

    @Test("dismiss clears the presented error")
    func dismissClears() {
        handler.handle(AppError.noCachedData)

        handler.dismiss()

        #expect(handler.currentError == nil)
    }
}
