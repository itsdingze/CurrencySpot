import Foundation

@Observable
final class ErrorHandler {
    private(set) var currentError: AppError?

    func handle(_ error: Error) {
        guard let appError = AppError.from(error) else {
            return
        }
        currentError = appError
    }

    func dismiss() {
        currentError = nil
    }
}
