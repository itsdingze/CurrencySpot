import SwiftUI

nonisolated extension EnvironmentValues {
    @Entry var appAccent: Color = .accentColor
}

extension View {
    func appAccent(_ color: Color) -> some View {
        tint(color)
            .environment(\.appAccent, color)
    }
}
