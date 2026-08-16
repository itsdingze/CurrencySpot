import Foundation

nonisolated enum Loadable<T> {
    case idle
    case loading(previous: T?)
    case loaded(T)
    case failed(AppError, previous: T?)
}

nonisolated extension Loadable {
    var value: T? {
        switch self {
        case .idle:
            nil
        case let .loading(previous):
            previous
        case let .loaded(value):
            value
        case let .failed(_, previous):
            previous
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: AppError? {
        if case let .failed(error, _) = self { return error }
        return nil
    }
}

nonisolated extension Loadable: Equatable where T: Equatable {}
