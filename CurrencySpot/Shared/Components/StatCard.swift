import SwiftUI

struct StatCard: View {
    enum Size {
        case regular
        case compact

        fileprivate var labelFont: Font {
            switch self {
            case .regular: .appSubheadline
            case .compact: .appCaption
            }
        }

        fileprivate var valueFont: Font {
            switch self {
            case .regular: .appHeadline
            case .compact: .appFootnote
            }
        }

        fileprivate var indicatorDiameter: CGFloat {
            switch self {
            case .regular: 6
            case .compact: 5
            }
        }

        fileprivate func hint(for label: String, isToggled: Bool) -> String {
            let indicator = label.lowercased()
            switch (self, isToggled) {
            case (.regular, true): return "Hides the \(indicator) marker on the chart"
            case (.regular, false): return "Shows the \(indicator) marker on the chart"
            case (.compact, true): return "Tap to hide \(indicator) indicator on chart"
            case (.compact, false): return "Tap to show \(indicator) indicator on chart"
            }
        }
    }

    let label: String
    let value: String
    let indicatorColor: Color?
    let isToggled: Bool
    let size: Size
    let action: () -> Void

    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                HStack(spacing: Spacing.hairline) {
                    Text(label)
                        .font(size.labelFont)
                        .foregroundStyle(.secondary)

                    if let indicatorColor {
                        Circle()
                            .fill(indicatorColor.opacity(isToggled ? 1.0 : 0.3))
                            .frame(width: size.indicatorDiameter, height: size.indicatorDiameter)
                            .animation(.appToggle, value: isToggled)
                    }
                }

                Text(value)
                    .font(size.valueFont.weight(.medium).monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.chipPadding)
            .background(background, in: .rect(cornerRadius: Radius.badge))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(indicatorColor == nil)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isToggled ? .isSelected : [])
    }

    private var background: Color {
        switch size {
        case .regular: .clear
        case .compact: isToggled && indicatorColor != nil ? accent.opacity(0.08) : Color.gray.opacity(0.05)
        }
    }

    private var accessibilityHint: String {
        guard indicatorColor != nil else { return "" }
        return size.hint(for: label, isToggled: isToggled)
    }
}

#Preview {
    VStack {
        StatCard(label: "Highest", value: "1.1800", indicatorColor: .success, isToggled: true, size: .regular) {}
        StatCard(label: "Lowest", value: "1.1400", indicatorColor: .failure, isToggled: false, size: .compact) {}
        StatCard(label: "Volatility", value: "Low", indicatorColor: nil, isToggled: false, size: .compact) {}
    }
    .padding()
}
