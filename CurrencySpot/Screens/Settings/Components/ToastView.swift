import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.element) {
            Image(systemName: icon)
                .font(.appTitle3)
                .foregroundStyle(Color.success)

            Text(message)
                .font(.appHeadline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.secondaryBackground)
                .stroke(Color.background, lineWidth: 1)
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ToastView(message: "123", icon: "house")
}
