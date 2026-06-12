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
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.gray, Color.primary.opacity(0.1))
                }
                .accessibilityLabel("Close")
            }

            VStack(spacing: 8) {
                amountLine(item.conversion.amount, code: baseCurrency)
                    .foregroundStyle(Color.textSecondary)

                Image(systemName: "arrow.down")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityHidden(true)

                amountLine(item.conversion.converted, code: targetCurrency, fractionDigits: 2)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.top, 8)

            VStack(spacing: 16) {
                Button(action: openInConverter) {
                    Label("Open in Convert", systemImage: "arrow.left.arrow.right")
                        .font(.system(.headline, design: .rounded))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: hideConversion) {
                    Label("Hide this conversion", systemImage: "eye.slash")
                        .font(.system(.subheadline, design: .rounded))
                }
                .foregroundStyle(Color.textSecondary)
            }
            .padding(.top, 32)
        }
        .safeAreaPadding(.horizontal)
        .safeAreaPadding(.top)
    }

    private func amountLine(_ amount: Decimal, code: String, fractionDigits: Int? = nil) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(amount, format: fractionDigits.map { .number.precision(.fractionLength($0)) } ?? .number)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text(CurrencyUtilities.shared.name(for: code))
                .font(.system(.title3, design: .rounded).weight(.semibold))
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
