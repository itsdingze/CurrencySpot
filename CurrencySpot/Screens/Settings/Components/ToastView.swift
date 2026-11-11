import SwiftUI

struct ToastView: View {
    let message: LocalizedStringResource
    let icon: String
    let tint: Color

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .imageScale(.large)
        }
        .font(.appSubheadline.weight(.semibold))
        .padding(.horizontal, Spacing.section)
        .padding(.vertical, Spacing.element)
        .adaptiveGlassBackground(in: .capsule)
    }
}

#Preview {
    ToastView(message: ToastData(type: .preferencesReset).message, icon: "house", tint: .success)
}
