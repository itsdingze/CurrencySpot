import SwiftUI

nonisolated extension Animation {
    static func appStageReveal(after delay: TimeInterval, reduceMotion: Bool) -> Animation {
        .appStageReveal.delay(reduceMotion ? 0 : delay)
    }
}
