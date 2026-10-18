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
    }

    enum Marker {
        case highest
        case lowest
        case average

        fileprivate var color: Color {
            switch self {
            case .highest: .success
            case .lowest: .failure
            case .average: .gray
            }
        }

        fileprivate func hint(isShown: Bool) -> LocalizedStringResource {
            switch (self, isShown) {
            case (.highest, true): .statCardHighestHideAccessibilityHint
            case (.highest, false): .statCardHighestShowAccessibilityHint
            case (.lowest, true): .statCardLowestHideAccessibilityHint
            case (.lowest, false): .statCardLowestShowAccessibilityHint
            case (.average, true): .statCardAverageHideAccessibilityHint
            case (.average, false): .statCardAverageShowAccessibilityHint
            }
        }
    }

    let label: LocalizedStringResource
    let value: String?
    let marker: Marker?
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

                    if let marker {
                        Circle()
                            .fill(marker.color.opacity(isToggled ? 1.0 : 0.3))
                            .frame(width: size.indicatorDiameter, height: size.indicatorDiameter)
                            .animation(.appToggle, value: isToggled)
                    }
                }

                Text(displayedValue)
                    .font(size.valueFont.weight(.medium).monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.chipPadding)
            .background(background, in: .rect(cornerRadius: Radius.badge))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(marker == nil || value == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isToggled ? .isSelected : [])
    }

    private var displayedValue: String {
        value ?? String(localized: .statCardValuePlaceholder)
    }

    private var accessibilityLabel: LocalizedStringResource {
        guard let value else { return .statCardPlaceholderAccessibilityLabel(label: String(localized: label)) }
        return .statCardAccessibilityLabel(label: String(localized: label), value: value)
    }

    private var background: Color {
        switch size {
        case .regular: .clear
        case .compact: isToggled && marker != nil ? accent.opacity(0.08) : Color.gray.opacity(0.05)
        }
    }

    private var accessibilityHint: Text {
        guard let marker, value != nil else { return Text(verbatim: "") }
        return Text(marker.hint(isShown: isToggled))
    }
}

#Preview {
    VStack {
        StatCard(label: .historyStatisticsHighest, value: "1.1800", marker: .highest, isToggled: true, size: .regular) {}
        StatCard(label: .historyStatisticsAverage, value: nil, marker: .average, isToggled: false, size: .regular) {}
        StatCard(label: .historyStatisticsLowest, value: "1.1400", marker: .lowest, isToggled: false, size: .compact) {}
        StatCard(label: .historyStatisticsVolatility, value: "Low", marker: nil, isToggled: false, size: .compact) {}
    }
    .padding()
}
