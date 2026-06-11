//
//  RetryState.swift
//  CurrencySpot
//

/// User-visible retry progress for the offline banner.
enum RetryState {
    case none
    case retrying(attempt: Int, maxAttempts: Int)
    case exhausted
}
