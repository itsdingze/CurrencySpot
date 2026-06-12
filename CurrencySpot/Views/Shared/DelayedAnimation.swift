//
//  DelayedAnimation.swift
//  CurrencySpot
//

import SwiftUI

/// Sleeps `delay` seconds, then runs `action` inside a smooth animation.
/// Returns without acting when the surrounding task is cancelled mid-sleep.
/// Shared by the onboarding views' staggered entrance sequences.
@MainActor
func delayedAnimation(_ delay: Double, action: @escaping () -> Void) async {
    guard delay > 0 else {
        withAnimation(.smooth) { action() }
        return
    }

    do {
        try await Task.sleep(for: .seconds(delay))
    } catch {
        return
    }
    withAnimation(.smooth) {
        action()
    }
}
