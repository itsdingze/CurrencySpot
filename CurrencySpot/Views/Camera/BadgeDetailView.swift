//
//  BadgeDetailView.swift
//  CurrencySpot
//

import SwiftUI

/// Detail shown when tapping a converted badge: full precision, the rate used,
/// rate freshness, and a shortcut to the Convert tab.
struct BadgeDetailView: View {
    let item: DetectedItem
    let baseCurrency: String
    let targetCurrency: String
    let rateUsed: Decimal
    let rateFreshness: String
    let openInConverter: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(item.conversion.amount, format: .currency(code: baseCurrency))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                Text(item.conversion.converted, format: .currency(code: targetCurrency).precision(.fractionLength(2...4)))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(spacing: 8) {
                detailRow(
                    label: "Rate",
                    value: "1 \(baseCurrency) = \(rateUsed.formatted(.number.precision(.significantDigits(1...4)))) \(targetCurrency)"
                )
                detailRow(label: "Rates", value: rateFreshness)
            }
            .padding(14)
            .background(Color.secondaryBackground, in: .rect(cornerRadius: 12))

            Button(action: openInConverter) {
                Label("Open in Convert", systemImage: "arrow.left.arrow.right")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.textPrimary)
        }
        .font(.system(.subheadline, design: .rounded))
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
            rateUsed: 0.00673,
            rateFreshness: "Last updated: Today, 9:41 AM",
            openInConverter: {}
        )
    }
}
