import SwiftUI
import UIKit

func delayedAnimation(_ delay: Double, action: @escaping () -> Void) async {
    let effectiveDelay = UIAccessibility.isReduceMotionEnabled ? 0 : delay

    guard effectiveDelay > 0 else {
        withAnimation(.appStageReveal) { action() }
        return
    }

    do {
        try await Task.sleep(for: .seconds(effectiveDelay))
    } catch {
        return
    }
    withAnimation(.appStageReveal) {
        action()
    }
}
