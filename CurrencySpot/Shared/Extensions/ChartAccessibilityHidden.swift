import SwiftUI

extension View {
    // Charts keeps its axis values in VoiceOver under .accessibilityHidden(true) and .accessibilityElement(children: .ignore)
    func chartAccessibilityHidden() -> some View {
        accessibilityRepresentation {
            Color.clear
                .accessibilityHidden(true)
        }
    }
}
