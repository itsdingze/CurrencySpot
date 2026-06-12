//
//  Loadable.swift
//  CurrencySpot
//

import Foundation

/// Exhaustive model for async UI state. Replaces the `isLoading` + `errorMessage`
/// + data triple, which allows representable-but-invalid combinations.
///
/// The `previous` payloads on `.loading` and `.failed` are what enable graceful
/// degradation: a refetch shows stale data instead of blanking the screen, and a
/// failure can fall back to the last known good value.
nonisolated enum Loadable<T> {
    case idle
    case loading(previous: T?)
    case loaded(T)
    case failed(AppError, previous: T?)
}

nonisolated extension Loadable {
    /// The current or last known value, regardless of phase.
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
