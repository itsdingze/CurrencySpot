//
//  RetryState.swift
//  CurrencySpot
//

/// User-visible retry progress for the offline banner.
nonisolated enum RetryState {
    case none
    case retrying(attempt: Int, maxAttempts: Int)
    case exhausted
}
