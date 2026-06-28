//
//  RateBanner.swift
//  CurrencySpot
//

/// The in-context status strip shown above the calculator whenever the displayed rates
/// are anything other than current and live. `.hidden` means the rates are up to date —
/// show nothing.
///
/// This is the single source of truth for that strip, derived from connectivity, the
/// load phase, and whether the last refresh succeeded — so the banner and the loading
/// view can never contradict each other.
nonisolated enum RateBanner: Equatable {
    /// Rates are current and live; no strip.
    case hidden
    /// A refresh is in flight while previously loaded rates stay on screen.
    case updating
    /// No connection; showing the most recent saved rates.
    case offlineSaved
    /// Online, but the last refresh failed; showing the most recent saved rates.
    case updateFailed
    /// Showing made-up sample rates because no real rates are available.
    case sample
}
