import SwiftUI

struct UnifiedCurrencyView: View {
    enum DisplayType {
        case source
        case converted

        fileprivate var title: LocalizedStringResource {
            switch self {
            case .source:
                .calculatorCurrencyFrom
            case .converted:
                .calculatorCurrencyTo
            }
        }

        fileprivate var captionStyle: AnyShapeStyle {
            switch self {
            case .source:
                AnyShapeStyle(Color.secondary)
            case .converted:
                AnyShapeStyle(.tint)
            }
        }

        fileprivate var amountStyle: AnyShapeStyle {
            switch self {
            case .source:
                AnyShapeStyle(Color.primary)
            case .converted:
                AnyShapeStyle(.tint)
            }
        }

        fileprivate func backgroundColor(accent: Color) -> Color {
            switch self {
            case .source:
                Color.secondary.opacity(0.2)
            case .converted:
                .selectionFill(on: accent)
            }
        }

        fileprivate func strokeColor(accent: Color) -> Color {
            switch self {
            case .source:
                Color.secondary.opacity(0.1)
            case .converted:
                accent.opacity(0.1)
            }
        }
    }

    let type: DisplayType
    let amount: String
    let compactAmount: String
    let currencyCode: CurrencyCode
    let onPress: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            titleView
            contentRow
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var titleView: some View {
        Text(type.title)
            .font(.appHeadline.weight(.medium))
            .foregroundStyle(type.captionStyle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contentRow: some View {
        AdaptiveStack {
            amountText
            Spacer()
            currencyButton
        }
    }

    private var minimumAmountScale: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0.5 : 0.7
    }

    private var amountText: some View {
        ViewThatFits(in: .horizontal) {
            MinimumScaleIdealWidth(minimumScale: minimumAmountScale) {
                amountLabel(amount)
            }
            amountLabel(compactAmount)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityAmountLabel)
        .accessibilityValue(accessibilityAmountValue)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func amountLabel(_ text: String) -> some View {
        Text(text)
            .font(.appLargeTitle.monospacedDigit())
            .foregroundStyle(type.amountStyle)
            .lineLimit(1)
            .minimumScaleFactor(minimumAmountScale)
            .contentTransition(.numericText())
    }

    private var accessibilityAmountLabel: LocalizedStringResource {
        switch type {
        case .source:
            .calculatorCurrencyAmountSourceAccessibilityLabel
        case .converted:
            .calculatorCurrencyAmountConvertedAccessibilityLabel
        }
    }

    private var accessibilityAmountValue: LocalizedStringResource {
        .calculatorCurrencyAmountAccessibilityValue(amount: amount, currency: currencyCode.localizedName)
    }

    @ViewBuilder
    private var currencyButton: some View {
        Button(action: onPress) {
            HStack {
                FixedWidthCurrencyLabel(code: currencyCode)

                Image(systemName: "chevron.down")
                    .font(.appCaption)
                    .bold()
            }
        }
        .buttonStyle(.currencyCode(fill: type.backgroundColor(accent: accent), stroke: type.strokeColor(accent: accent)))
        .foregroundStyle(type.captionStyle)
        .accessibilityLabel(accessibilityButtonLabel)
        .accessibilityValue(accessibilityButtonValue)
        .accessibilityInputLabels(accessibilityInputLabels)
    }

    private var accessibilityButtonLabel: LocalizedStringResource {
        switch type {
        case .source:
            .calculatorCurrencyPickerSourceAccessibilityLabel
        case .converted:
            .calculatorCurrencyPickerTargetAccessibilityLabel
        }
    }

    private var accessibilityButtonValue: LocalizedStringResource {
        .calculatorCurrencyPickerAccessibilityValue(name: currencyCode.localizedName, code: currencyCode.rawValue)
    }

    private var accessibilityInputLabels: [String] {
        let currencyName = currencyCode.localizedName
        return [currencyCode.rawValue, currencyName]
    }
}

private struct MinimumScaleIdealWidth: Layout {
    let minimumScale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let size = subview.sizeThatFits(proposal)
        guard proposal.width == nil else { return size }
        return CGSize(width: size.width * minimumScale, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

#Preview {
    VStack(spacing: 24) {
        UnifiedCurrencyView(type: .source, amount: "1,234.56", compactAmount: "1.2K", currencyCode: .usd, onPress: {})
        UnifiedCurrencyView(
            type: .converted,
            amount: "179,889,999,999,999,820.11",
            compactAmount: "179,890T",
            currencyCode: .jpy,
            onPress: {}
        )
    }
    .padding()
}
