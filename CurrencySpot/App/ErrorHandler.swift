import Foundation

@Observable
final class ErrorHandler {
    private(set) var currentError: AppError?

    var isPresentingError: Bool {
        get { currentError != nil }
        set { if !newValue { dismiss() } }
    }

    func handle(_ error: AppError) {
        currentError = error
    }

    func dismiss() {
        currentError = nil
    }
}
