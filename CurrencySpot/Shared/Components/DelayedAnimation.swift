//
//  DelayedAnimation.swift
//  CurrencySpot
//

import SwiftUI
import UIKit

/// Sleeps `delay` seconds, then runs `action` inside a smooth animation.
/// Returns without acting when the surrounding task is cancelled mid-sleep.
/// Shared by the onboarding views' staggered entrance sequences.
func delayedAnimation(_ delay: Double, action: @escaping () -> Void) async {
    // Reduce Motion collapses the staggered entrance to an instant reveal.
    let effectiveDelay = UIAccessibility.isReduceMotionEnabled ? 0 : delay

    guard effectiveDelay > 0 else {
        withAnimation(.smooth) { action() }
        return
    }

    do {
        try await Task.sleep(for: .seconds(effectiveDelay))
    } catch {
        return
    }
    withAnimation(.smooth) {
        action()
    }
}
