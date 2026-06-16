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
        NavigationStack {
            VStack(spacing: 32) {
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
            }
            .padding()
            .navigationTitle("Conversion")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    @Previewable @State var isPresented = false

    Button("Show conversion") { isPresented = true }
        .sheet(isPresented: $isPresented) {
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
            .presentationDetents([.fraction(0.4)])
        }
}
#endif
