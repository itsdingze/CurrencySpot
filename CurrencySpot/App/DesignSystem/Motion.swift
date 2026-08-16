import SwiftUI

nonisolated extension Animation {
    static let appToggle = Animation.smooth(duration: 0.3)
    static let appSelect = Animation.snappy
    static let appFlip = Animation.bouncy(duration: 0.6)
    static let appQuickFade = Animation.easeInOut(duration: 0.2)
    static let appTrack = Animation.easeInOut(duration: 0.07)
    static let appStageReveal = Animation.smooth
}
