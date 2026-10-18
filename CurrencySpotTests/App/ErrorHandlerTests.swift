@testable import CurrencySpot
import Foundation
import Testing

@Suite("ErrorHandler Tests")
struct ErrorHandlerTests {
    private let handler = ErrorHandler()

    @Test("handle publishes the error as the single presentation source of truth")
    func handlePublishesError() {
        #expect(handler.currentError == nil)

        handler.handle(.noInternetConnection)

        #expect(handler.currentError == .noInternetConnection)
    }

    @Test("cancellation converts to no AppError, so it never reaches the handler")
    func cancellationNeverConverts() {
        #expect(AppError.from(CancellationError()) == nil)
        #expect(AppError.from(URLError(.cancelled)) == nil)
    }

    @Test("a newer error replaces the presented one")
    func newerErrorReplaces() {
        handler.handle(.noInternetConnection)
        handler.handle(.cameraCaptureFailed)

        #expect(handler.currentError == .cameraCaptureFailed)
    }

    @Test("dismiss clears the presented error")
    func dismissClears() {
        handler.handle(.cameraCaptureFailed)

        handler.dismiss()

        #expect(handler.currentError == nil)
    }

    @Test("the alert presentation flag follows the error and clears it when the alert closes")
    func presentationFlagFollowsError() {
        #expect(handler.isPresentingError == false)

        handler.handle(.noInternetConnection)
        #expect(handler.isPresentingError == true)

        handler.isPresentingError = true
        #expect(handler.currentError == .noInternetConnection)

        handler.isPresentingError = false
        #expect(handler.currentError == nil)
    }
}
