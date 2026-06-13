//
//  BadgeDetailView.swift
//  CurrencySpot
//

import SwiftUI

/// Detail shown when tapping a converted plate: the original and converted
/// amounts, a shortcut to the Convert tab, and an escape hatch that
/// uncovers a misread price.
struct BadgeDetailView: View {
    let item: DetectedItem
    let baseCurrency: String
    let targetCurrency: String
    let openInConverter: () -> Void
    let hideConversion: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .controlIconStyle(size: .closeIconSize, padding: .closeIconPadding)
                        .adaptiveGlassBackground(in: .circle, isInteractive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            VStack(spacing: .tightGap) {
                amountLine(item.conversion.amount, code: baseCurrency)
                    .foregroundStyle(Color.textSecondary)

                Image(systemName: "arrow.down")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)

                amountLine(item.conversion.converted, code: targetCurrency, fractionDigits: 2)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.top, .tightGap)

            VStack(spacing: .sectionGap) {
                Button(action: openInConverter) {
                    Label("Open in Convert", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)

                Button(action: hideConversion) {
                    Label("Hide this conversion", systemImage: "eye.slash")
                        .font(.appSubheadline)
                }
                .foregroundStyle(Color.textSecondary)
            }
            .padding(.top, 32)
        }
        .safeAreaPadding(.horizontal)
        .safeAreaPadding(.top)
    }

    private func amountLine(_ amount: Decimal, code: String, fractionDigits: Int? = nil) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: .tightGap) {
            Text(amount, format: fractionDigits.map { .number.precision(.fractionLength($0)) } ?? .number)
                .font(.appLargeTitle)
            Text(CurrencyUtilities.name(for: code))
                .font(.appTitle3)
        }
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        BadgeDetailView(
            item: DetectedItem(
                id: UUID(),
                transcript: "¥1,200",
                bounds: .zero,
                conversion: .init(amount: 1200, converted: 8.0824, isPrice: true)
            ),
            baseCurrency: "JPY",
            targetCurrency: "USD",
            openInConverter: {},
            hideConversion: {}
        )
    }
}
