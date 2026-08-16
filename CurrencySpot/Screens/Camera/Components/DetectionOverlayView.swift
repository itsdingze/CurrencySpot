import SwiftUI

struct DetectionOverlayView: View {
    let items: [DetectedItem]
    let targetCurrency: CurrencyCode
    let isLive: Bool
    let onOutlineTap: (UUID) -> Void
    let onPlateTap: (UUID) -> Void

    private let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    @State private var plateSizes: [UUID: CGSize] = [:]
    @State private var promotions: [UUID] = []
    @State private var pendingReveal: UUID?

    private var priceItems: [DetectedItem] {
        items.filter { $0.conversion.isPrice }
    }

    private func depths(for priceItems: [DetectedItem]) -> [UUID: Int] {
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
        let priceItems = priceItems
        let depths = depths(for: priceItems)
        ZStack {
            ForEach(items) { item in
                if item.conversion.isPrice {
                    plate(for: item, depth: depths[item.id], plateCount: priceItems.count)
                } else {
                    DetectionOutline(item: item, onTap: handleOutlineTap)
                }
            }
        }
        .animation(.appTrack, value: items)
        .animation(.appTrack, value: promotions)
        .onChange(of: items) { _, _ in syncRevealPromotion() }
        .overlay {
            if isLive && !priceItems.isEmpty {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("\(priceItems.count) prices detected. Double-tap the shutter to freeze and review.")
            }
        }
    }

    @ViewBuilder
    private func plate(for item: DetectedItem, depth: Int?, plateCount: Int) -> some View {
        let depth = depth ?? 0
        let button = Button {
            handlePlateTap(item.id, depth: depth)
        } label: {
            ConvertedPlate(
                amount: item.conversion.converted,
                currencyCode: targetCurrency,
                boxSize: item.bounds.size
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { plateSizes[item.id] = $0 }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .opacity(opacity(forDepth: depth))
        .zIndex(zIndex(forDepth: depth, plateCount: plateCount))
        .accessibilityHidden(isLive)
        if depth > 0 {
            button.accessibilityHint("Brings this conversion to the front")
        } else {
            button.accessibilityHint("Opens conversion details")
        }
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

    private func syncRevealPromotion() {
        let visible = Set(priceItems.map(\.id))
        if let revealed = pendingReveal {
            if visible.contains(revealed) {
                promote(revealed)
                pendingReveal = nil
            } else if !items.contains(where: { $0.id == revealed }) {
                pendingReveal = nil
            }
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

    private func zIndex(forDepth depth: Int, plateCount: Int) -> Double {
        Double(plateCount - depth)
    }
}

private struct DetectionOutline: View {
    let item: DetectedItem
    let onTap: (UUID) -> Void

    var body: some View {
        Button {
            onTap(item.id)
        } label: {
            RoundedRectangle(cornerRadius: ConvertedPlateMetrics.cornerRadius(forBoxHeight: item.bounds.height))
                .stroke(.white, lineWidth: 2)
                .frame(
                    width: item.bounds.width + ConvertedPlateMetrics.horizontalInflation,
                    height: item.bounds.height + ConvertedPlateMetrics.verticalInflation
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .position(x: item.bounds.midX, y: item.bounds.midY)
        .accessibilityLabel("Number \(item.transcript)")
        .accessibilityHint("Convert this number")
    }
}

private struct ConvertedPlate: View {
    let amount: Decimal
    let currencyCode: CurrencyCode
    let boxSize: CGSize

    var body: some View {
        Text(amount, format: .currency(code: currencyCode.rawValue))
            .font(.system(size: ConvertedPlateMetrics.fontSize(forBoxHeight: boxSize.height), design: .rounded).weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, Spacing.badgePaddingHorizontal)
            .padding(.vertical, Spacing.badgePaddingVertical)
            .frame(
                minWidth: boxSize.width + ConvertedPlateMetrics.horizontalInflation,
                minHeight: boxSize.height + ConvertedPlateMetrics.verticalInflation
            )
            .background(.black.mix(with: .white, by: 0.15).opacity(0.9), in: .rect(cornerRadius: cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.25), lineWidth: 0.5) }
            .accessibilityLabel("Converted price \(amount.formatted(.currency(code: currencyCode.rawValue)))")
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var cornerRadius: CGFloat {
        ConvertedPlateMetrics.cornerRadius(forBoxHeight: boxSize.height)
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
            targetCurrency: .usd,
            isLive: false,
            onOutlineTap: { _ in },
            onPlateTap: { _ in }
        )
    }
}
