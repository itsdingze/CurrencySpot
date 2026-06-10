//
//  DetectionOverlayView.swift
//  CurrencySpot
//

import SwiftUI

/// Outlines every detected price candidate and pins a converted badge next to prices.
/// Coordinates are in the camera view's space, provided by the scanner.
struct DetectionOverlayView: View {
    let items: [DetectedItem]
    let targetCurrency: String
    /// Outline tap: toggle the converted badge on or off.
    let onOutlineTap: (UUID) -> Void
    /// Badge tap: open the conversion detail.
    let onBadgeTap: (UUID) -> Void

    var body: some View {
        ZStack {
            ForEach(items) { item in
                DetectedItemMarker(
                    item: item,
                    targetCurrency: targetCurrency,
                    onOutlineTap: onOutlineTap,
                    onBadgeTap: onBadgeTap
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: items)
    }
}

private struct DetectedItemMarker: View {
    let item: DetectedItem
    let targetCurrency: String
    let onOutlineTap: (UUID) -> Void
    let onBadgeTap: (UUID) -> Void

    private var outlineColor: Color {
        item.conversion.isPrice ? .accentColor : .white.opacity(0.6)
    }

    var body: some View {
        Button {
            onOutlineTap(item.id)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .stroke(outlineColor, lineWidth: 1.5)
                .frame(width: item.bounds.width + 8, height: item.bounds.height + 6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .accessibilityLabel(item.conversion.isPrice
            ? "Hide conversion for \(item.transcript)"
            : "Convert \(item.transcript)")

        if item.conversion.isPrice {
            Button {
                onBadgeTap(item.id)
            } label: {
                ConvertedBadge(amount: item.conversion.converted, currencyCode: targetCurrency)
            }
            .buttonStyle(.plain)
            .position(x: item.bounds.midX, y: badgeCenterY)
            .accessibilityHint("Shows the conversion detail")
        }
    }

    /// Pinned above the price so the original is never covered;
    /// flips below when the price sits near the top edge.
    private var badgeCenterY: CGFloat {
        let clearance: CGFloat = 22
        let above = item.bounds.minY - clearance
        return above > 40 ? above : item.bounds.maxY + clearance
    }
}

private struct ConvertedBadge: View {
    let amount: Decimal
    let currencyCode: String

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .accessibilityLabel("Converted price \(amount.formatted(.currency(code: currencyCode)))")
    }
}

#Preview {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        DetectionOverlayView(
            items: [
                DetectedItem(
                    id: UUID(),
                    transcript: "¥1,200",
                    bounds: CGRect(x: 120, y: 300, width: 110, height: 36),
                    conversion: .init(amount: 1200, converted: 8.08, isPrice: true)
                ),
                DetectedItem(
                    id: UUID(),
                    transcript: "1200",
                    bounds: CGRect(x: 80, y: 480, width: 90, height: 28),
                    conversion: .init(amount: 1200, converted: 8.08, isPrice: false)
                ),
            ],
            targetCurrency: "USD",
            onOutlineTap: { _ in },
            onBadgeTap: { _ in }
        )
    }
}
