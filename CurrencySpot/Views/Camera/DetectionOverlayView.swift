//
//  DetectionOverlayView.swift
//  CurrencySpot
//

import SwiftUI

/// Covers every detected price with an in-place converted plate, Lens-style,
/// and outlines other numbers so they can be converted by tap.
/// Overlapping plates are depth-graded: deeper ones dim, and tapping a dimmed
/// plate promotes it to the front instead of opening the detail.
/// Coordinates are in the camera view's space, provided by the scanner.
struct DetectionOverlayView: View {
    let items: [DetectedItem]
    let targetCurrency: String
    /// Outline tap: pin a converted plate onto a number the classifier skipped.
    let onOutlineTap: (UUID) -> Void
    /// Plate tap: open the conversion detail.
    let onPlateTap: (UUID) -> Void

    private let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    /// Rendered plate sizes, keyed by item id, captured as each plate lays out.
    @State private var plateSizes: [UUID: CGSize] = [:]
    /// Promotion order, most recent last. Presentation-only state.
    @State private var promotions: [UUID] = []
    /// The last outline tapped, promoted once its plate becomes visible.
    @State private var pendingReveal: UUID?

    private var priceItems: [DetectedItem] {
        items.filter { $0.conversion.isPrice }
    }

    private var depths: [UUID: Int] {
        let plates = priceItems.compactMap { item -> BadgeClusterResolver.Badge? in
            guard let size = plateSizes[item.id] else { return nil }
            return BadgeClusterResolver.Badge(
                id: item.id,
                frame: frame(for: item, size: size),
                boxMidY: item.bounds.midY
            )
        }
        return resolver.depths(for: plates, promotions: promotions)
    }

    var body: some View {
        let depths = depths
        ZStack {
            ForEach(items) { item in
                if item.conversion.isPrice {
                    plate(for: item, depth: depths[item.id])
                } else {
                    DetectionOutline(item: item, onTap: handleOutlineTap)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: items)
        .animation(.easeOut(duration: 0.15), value: promotions)
        .onChange(of: items) { _, _ in syncRevealPromotion() }
    }

    private func plate(for item: DetectedItem, depth: Int?) -> some View {
        let depth = depth ?? 0
        return Button {
            handlePlateTap(item.id, depth: depth)
        } label: {
            ConvertedPlate(
                amount: item.conversion.converted,
                currencyCode: targetCurrency,
                boxSize: item.bounds.size,
                dimmed: depth > 0
            )
            // Tiny price tags still get a comfortable tap target.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { plateSizes[item.id] = $0 }
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .opacity(opacity(forDepth: depth))
        .zIndex(zIndex(forDepth: depth))
        .accessibilityHint(depth > 0
            ? "Brings this conversion to the front"
            : "Shows the conversion detail")
    }

    private func handlePlateTap(_ id: UUID, depth: Int) {
        if depth > 0 {
            promote(id)
        } else {
            onPlateTap(id)
        }
    }

    private func handleOutlineTap(_ id: UUID) {
        pendingReveal = id
        onOutlineTap(id)
    }

    /// Promote a plate that an outline tap just revealed, then prune stale state.
    private func syncRevealPromotion() {
        let visible = Set(priceItems.map(\.id))
        if let revealed = pendingReveal {
            if visible.contains(revealed) {
                // Plate is now on screen: consume the pending reveal.
                promote(revealed)
                pendingReveal = nil
            } else if !items.contains(where: { $0.id == revealed }) {
                // Item dropped out entirely; nothing left to reveal.
                pendingReveal = nil
            }
            // Otherwise keep waiting: the item exists but its plate isn't visible yet.
        }
        promotions.removeAll { !visible.contains($0) }
        plateSizes = plateSizes.filter { visible.contains($0.key) }
    }

    private func promote(_ id: UUID) {
        promotions.removeAll { $0 == id }
        promotions.append(id)
    }

    private func frame(for item: DetectedItem, size: CGSize) -> CGRect {
        CGRect(
            x: item.bounds.midX - size.width / 2,
            y: item.bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func opacity(forDepth depth: Int) -> Double {
        switch depth {
        case 0: 1.0
        case 1: 0.55
        case 2: 0.4
        default: 0.3
        }
    }

    /// Front plate (depth 0) sits highest; deeper plates fall behind but stay
    /// above the outlines, which ride at the ZStack default of 0.
    private func zIndex(forDepth depth: Int) -> Double {
        Double(priceItems.count - depth)
    }
}

private struct DetectionOutline: View {
    let item: DetectedItem
    let onTap: (UUID) -> Void

    var body: some View {
        Button {
            onTap(item.id)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: item.bounds.width + 8, height: item.bounds.height + 6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .accessibilityLabel("Convert \(item.transcript)")
    }
}

/// The converted amount rendered over the original price, sized to match it.
private struct ConvertedPlate: View {
    let amount: Decimal
    let currencyCode: String
    /// Detected box being covered; drives font size and minimum plate size.
    let boxSize: CGSize
    /// Dimmed plates drop their shadow so the front plate reads as on top.
    let dimmed: Bool

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
            .font(.system(size: ConvertedPlateMetrics.fontSize(forBoxHeight: boxSize.height), design: .rounded).weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: boxSize.width + 8, minHeight: boxSize.height + 6)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.25), lineWidth: 0.5) }
            .shadow(color: .black.opacity(dimmed ? 0 : 0.15), radius: 3, y: 1)
            .accessibilityLabel("Converted price \(amount.formatted(.currency(code: currencyCode)))")
    }

    private var cornerRadius: CGFloat {
        min(8, boxSize.height * 0.25)
    }
}

#Preview {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        DetectionOverlayView(
            items: [
                // Two tags close enough that their plates overlap — depth-graded
                // dimming and z-order keep them legible.
                DetectedItem(
                    id: UUID(),
                    transcript: "¥1,200",
                    bounds: CGRect(x: 120, y: 340, width: 110, height: 36),
                    conversion: .init(amount: 1200, converted: 8.08, isPrice: true)
                ),
                DetectedItem(
                    id: UUID(),
                    transcript: "¥980",
                    bounds: CGRect(x: 128, y: 312, width: 96, height: 34),
                    conversion: .init(amount: 980, converted: 6.59, isPrice: true)
                ),
                DetectedItem(
                    id: UUID(),
                    transcript: "¥154",
                    bounds: CGRect(x: 240, y: 430, width: 52, height: 16),
                    conversion: .init(amount: 154, converted: 1.04, isPrice: true)
                ),
                DetectedItem(
                    id: UUID(),
                    transcript: "1200",
                    bounds: CGRect(x: 80, y: 520, width: 90, height: 28),
                    conversion: .init(amount: 1200, converted: 8.08, isPrice: false)
                ),
            ],
            targetCurrency: "USD",
            onOutlineTap: { _ in },
            onPlateTap: { _ in }
        )
    }
}
