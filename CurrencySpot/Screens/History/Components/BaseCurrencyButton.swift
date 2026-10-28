import SwiftUI

struct BaseCurrencyButton: View {
    let code: CurrencyCode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.hairline) {
                Text(code.rawValue)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, Spacing.hairline)
        }
        .accessibilityLabel(.historyBasePickerAccessibilityLabel)
        .accessibilityValue(.historyBasePickerAccessibilityValue(
            name: code.localizedName,
            code: code.rawValue
        ))
    }
}

#Preview {
    BaseCurrencyButton(code: .usd) {}
        .padding()
}
