import SwiftUI

struct CurrencyRowButton: View {
    let code: CurrencyCode
    let name: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                AdaptiveStack {
                    Text(code.rawValue)
                        .font(.appHeadline.weight(.medium))

                    Spacer()

                    Text(name)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.secondary)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Spacing.hairline)
        }
    }
}

#Preview {
    List {
        CurrencyRowButton(code: .eur, name: "Euro", action: {})
        CurrencyRowButton(code: .jpy, name: "Japanese Yen", isSelected: true, action: {})
    }
    .listStyle(.plain)
}
