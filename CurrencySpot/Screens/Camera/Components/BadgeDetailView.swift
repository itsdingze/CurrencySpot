import SwiftUI

struct BadgeDetailView: View {
    let item: DetectedItem
    let baseCurrency: CurrencyCode
    let targetCurrency: CurrencyCode
    let openInConverter: () -> Void
    let hideConversion: () -> Void
    var fullHeightThreshold: CGFloat = .infinity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            SheetFittingScrollView(fullHeightThreshold: fullHeightThreshold) {
                VStack(spacing: 32) {
                    VStack(spacing: Spacing.tight) {
                        scannedText

                        amountLine(
                            item.conversion.amount,
                            code: baseCurrency,
                            fractionDigits: AmountFractionDigits.showing(item.conversion.amount, in: baseCurrency)
                        )
                        .foregroundStyle(.secondary)

                        Image(systemName: "arrow.down")
                            .font(.appHeadline)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        amountLine(
                            item.conversion.converted,
                            code: targetCurrency,
                            fractionDigits: AmountFractionDigits.usual(for: targetCurrency)
                        )
                    }

                    VStack(spacing: Spacing.section) {
                        Button(action: openInConverter) {
                            Label(.cameraBadgeDetailOpenInConvert, systemImage: "arrow.left.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryAction)

                        Button(action: hideConversion) {
                            Label(.cameraBadgeDetailHide, systemImage: "eye.slash")
                                .font(.appSubheadline)
                        }
                        .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationTitle(.cameraBadgeDetailTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(.cameraBadgeDetailClose, systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var scannedText: some View {
        AdaptiveStack(alignment: .firstTextBaseline, stackedAlignment: .center, spacing: Spacing.tight) {
            Text(.cameraBadgeDetailScannedText)
                .foregroundStyle(.secondary)
            Text(verbatim: item.transcript)
        }
        .font(.appSubheadline)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func amountLine(_ amount: Decimal, code: CurrencyCode, fractionDigits: Int) -> some View {
        AdaptiveStack(alignment: .lastTextBaseline, stackedAlignment: .center, spacing: Spacing.tight) {
            Text(amount, format: .number.precision(.fractionLength(fractionDigits)))
                .font(.appLargeTitle)
                .lineLimit(isAccessibilitySize ? 1 : nil)
                .minimumScaleFactor(isAccessibilitySize ? 0.5 : 1)
            Text(code.localizedName)
                .font(.appTitle3)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var isPresented = false

    Button { isPresented = true } label: { Text(verbatim: "Show conversion") }
        .sheet(isPresented: $isPresented) {
            BadgeDetailView(
                item: DetectedItem(
                    id: UUID(),
                    transcript: "¥1,200",
                    bounds: .zero,
                    conversion: .init(amount: 1200, converted: 8.0824, isPrice: true)
                ),
                baseCurrency: .jpy,
                targetCurrency: .usd,
                openInConverter: {},
                hideConversion: {}
            )
        }
}
#endif
