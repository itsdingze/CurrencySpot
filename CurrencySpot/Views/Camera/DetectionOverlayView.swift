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

    /// Gap between a badge and the box it labels.
    private let clearance: CGFloat = 22
    /// Badges flip below their box rather than ride above this Y.
    private let topGuard: CGFloat = 40

    private let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    /// Rendered badge sizes, keyed by item id, captured as each badge lays out.
    @State private var badgeSizes: [UUID: CGSize] = [:]
    /// Promotion order, most recent last. Presentation-only state.
    @State private var promotions: [UUID] = []
    /// The last outline tapped, promoted once its badge becomes visible.
    @State private var pendingReveal: UUID?

    private var priceItems: [DetectedItem] {
        items.filter { $0.conversion.isPrice }
    }

    private var depths: [UUID: Int] {
        let badges = priceItems.compactMap { item -> BadgeClusterResolver.Badge? in
            guard let size = badgeSizes[item.id] else { return nil }
            return BadgeClusterResolver.Badge(
                id: item.id,
                frame: frame(for: item, size: size),
                boxMidY: item.bounds.midY
            )
        }
        return resolver.depths(for: badges, promotions: promotions)
    }

    var body: some View {
        let depths = depths
        ZStack {
            ForEach(items) { item in
                DetectionOutline(item: item, onTap: handleOutlineTap)
            }
            ForEach(priceItems) { item in
                badge(for: item, depth: depths[item.id])
            }
        }
        .animation(.easeOut(duration: 0.15), value: items)
        .animation(.easeOut(duration: 0.15), value: promotions)
        .onChange(of: items) { _, _ in syncRevealPromotion() }
    }

    private func badge(for item: DetectedItem, depth: Int?) -> some View {
        let depth = depth ?? 0
        return Button {
            handleBadgeTap(item.id, depth: depth)
        } label: {
            ConvertedBadge(
                amount: item.conversion.converted,
                currencyCode: targetCurrency,
                dimmed: depth > 0
            )
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { badgeSizes[item.id] = $0 }
        .position(x: item.bounds.midX, y: preferredCenterY(for: item))
        .opacity(opacity(forDepth: depth))
        .zIndex(zIndex(forDepth: depth))
        .accessibilityHint(depth > 0
            ? "Brings this conversion to the front"
            : "Shows the conversion detail")
    }

    private func handleBadgeTap(_ id: UUID, depth: Int) {
        if depth > 0 {
            promote(id)
        } else {
            onBadgeTap(id)
        }
    }

    private func handleOutlineTap(_ id: UUID) {
        pendingReveal = id
        onOutlineTap(id)
    }

    /// Promote a badge that an outline tap just revealed, then prune stale state.
    private func syncRevealPromotion() {
        let visible = Set(priceItems.map(\.id))
        if let revealed = pendingReveal {
            if visible.contains(revealed) {
                // Badge is now on screen: consume the pending reveal.
                promote(revealed)
                pendingReveal = nil
            } else if !items.contains(where: { $0.id == revealed }) {
                // Item dropped out entirely; nothing left to reveal.
                pendingReveal = nil
            }
            // Otherwise keep waiting: the item exists but its badge isn't visible yet.
        }
        promotions.removeAll { !visible.contains($0) }
        badgeSizes = badgeSizes.filter { visible.contains($0.key) }
    }

    private func promote(_ id: UUID) {
        promotions.removeAll { $0 == id }
        promotions.append(id)
    }

    /// Centered `clearance` above the box; flips below when the box hugs the top.
    private func preferredCenterY(for item: DetectedItem) -> CGFloat {
        let above = item.bounds.minY - clearance
        return above > topGuard ? above : item.bounds.maxY + clearance
    }

    private func frame(for item: DetectedItem, size: CGSize) -> CGRect {
        CGRect(
            x: item.bounds.midX - size.width / 2,
            y: preferredCenterY(for: item) - size.height / 2,
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

    /// Front badge (depth 0) sits highest; deeper badges fall behind but stay
    /// above the outlines, which ride at the ZStack default of 0.
    private func zIndex(forDepth depth: Int) -> Double {
        Double(priceItems.count - depth)
    }
}

private struct DetectionOutline: View {
    let item: DetectedItem
    let onTap: (UUID) -> Void

    private var color: Color {
        item.conversion.isPrice ? .accentColor : .white.opacity(0.6)
    }

    var body: some View {
        Button {
            onTap(item.id)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color, lineWidth: 1.5)
                .frame(width: item.bounds.width + 8, height: item.bounds.height + 6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .accessibilityLabel(item.conversion.isPrice
            ? "Hide conversion for \(item.transcript)"
            : "Convert \(item.transcript)")
    }
}

private struct ConvertedBadge: View {
    let amount: Decimal
    let currencyCode: String
    /// Dimmed badges drop their shadow so the front badge reads as on top.
    let dimmed: Bool

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(dimmed ? 0 : 0.15), radius: 3, y: 1)
            .accessibilityLabel("Converted price \(amount.formatted(.currency(code: currencyCode)))")
    }
}

#Preview {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        DetectionOverlayView(
            items: [
                // Three tags clustered tightly enough that their badges overlap —
                // depth-graded dimming and z-order keep them legible.
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
                    transcript: "¥1,540",
                    bounds: CGRect(x: 136, y: 286, width: 104, height: 34),
                    conversion: .init(amount: 1540, converted: 10.36, isPrice: true)
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
            onBadgeTap: { _ in }
        )
    }
}
