//
//  Motion.swift
//  CurrencySpot
//

import SwiftUI

/// Animation tokens. Names describe the gesture's role, not the curve.
nonisolated extension Animation {
    /// Show/hide of chart indicators and other element toggles.
    static let appToggle = Animation.smooth(duration: 0.3)
    /// Selection changes: pickers, tabs, ripples, sheet reveals.
    static let appSelect = Animation.snappy
    /// The currency swap flip.
    static let appFlip = Animation.bouncy(duration: 0.6)
    /// Loading-overlay fades.
    static let appQuickFade = Animation.easeInOut(duration: 0.2)
    /// Detection plates tracking the live camera frame.
    static let appTrack = Animation.easeInOut(duration: 0.07)
}
