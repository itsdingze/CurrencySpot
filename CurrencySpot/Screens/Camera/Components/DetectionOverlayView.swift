import SwiftUI

struct DetectionOverlayView: View {
    let items: [DetectedItem]
    let targetCurrency: CurrencyCode
    let isLive: Bool
    let imageSize: CGSize?
    let onOutlineTap: (UUID) -> Void
    let onPlateTap: (UUID) -> Void

    private let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var viewSize = CGSize.zero
    @State private var layout = PlateLayout.Result.empty
    @State private var layoutMemory = PlateLayoutMemory(tracksFrames: true)
    @State private var promotions: [UUID] = []
    @State private var pendingReveal: UUID?

    private var priceItems: [DetectedItem] {
        items.filter { $0.conversion.isPrice }
    }

    private func depths(for plates: [PlateLayout.Plate]) -> [UUID: Int] {
        let midYs = Dictionary(items.map { ($0.id, $0.tokenQuad.center.y) }) { first, _ in first }
        let badges = plates.map { plate in
            BadgeClusterResolver.Badge(id: plate.id, frame: plate.visibleBounds, boxMidY: midYs[plate.id] ?? plate.center.y)
        }
        return resolver.depths(for: badges, promotions: promotions)
    }

    var body: some View {
        let itemsByID = Dictionary(items.map { ($0.id, $0) }) { first, _ in first }
        let depths = depths(for: layout.plates)
        ZStack {
            ForEach(layout.outlines, id: \.id) { outline in
                if let item = itemsByID[outline.id] {
                    DetectionOutline(item: item, outline: outline, angle: layout.angle, isLive: isLive, onTap: handleOutlineTap)
                }
            }
            ForEach(layout.plates, id: \.id) { plate in
                if let item = itemsByID[plate.id] {
                    plateButton(for: item, plate: plate, depth: depths[plate.id] ?? 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.appTrack, value: layout)
        .animation(.appTrack, value: promotions)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            viewSize = size
            relayout()
        }
        .onChange(of: items) { _, _ in
            syncRevealPromotion()
            relayout()
        }
        .onChange(of: targetCurrency) { _, _ in
            relayout()
        }
        .onChange(of: isLive) { _, _ in
            layoutMemory = PlateLayoutMemory(tracksFrames: true)
            relayout()
        }
        .onChange(of: legibilityWeight) { _, _ in
            relayout()
        }
        .overlay {
            if isLive, let liveSummary = liveSummary(priceCount: priceItems.count) {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel(liveSummary)
            }
        }
    }

    private func liveSummary(priceCount: Int) -> LocalizedStringResource? {
        if priceCount > 0 { return .cameraDetectionSummaryAccessibilityLabel(count: priceCount) }
        if !items.isEmpty { return .cameraDetectionNumbersSummaryAccessibilityLabel(count: items.count) }
        return nil
    }

    private func relayout() {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        var memory = isLive ? layoutMemory : PlateLayoutMemory(tracksFrames: false)
        let legibilityWeight = legibilityWeight
        layout = PlateLayout(frame: layoutFrame, measureText: { PlateTextWidth.of($0, fontSize: $1, legibilityWeight: legibilityWeight) })
            .layout(items, text: plateText, memory: &memory)
        if isLive { layoutMemory = memory }
    }

    private var layoutFrame: CGRect {
        guard let imageSize else { return CGRect(origin: .zero, size: viewSize) }
        return AspectFitMapping(imageSize: imageSize, viewSize: viewSize).viewRect(for: CGRect(origin: .zero, size: imageSize))
    }

    private func plateText(for item: DetectedItem) -> String {
        item.conversion.converted.formatted(.currency(code: targetCurrency.rawValue))
    }

    @ViewBuilder
    private func plateButton(for item: DetectedItem, plate: PlateLayout.Plate, depth: Int) -> some View {
        let button = Button {
            handlePlateTap(item.id, depth: depth)
        } label: {
            HitTargetFrame(target: plate.hitTarget, visibleCenter: plate.center) {
                ConvertedPlate(plate: plate)
                    .rotationEffect(.radians(layout.angle))
                    .opacity(opacity(forDepth: depth))
            }
        }
        .buttonStyle(.plain)
        .position(x: plate.hitTarget.midX, y: plate.hitTarget.midY)
        .zIndex(Double(layout.plates.count - depth))
        .accessibilityLabel(.cameraDetectionPlateAccessibilityLabel(
            transcript: item.transcript,
            price: plate.text
        ))
        .accessibilityAddTraits(isLive ? .updatesFrequently : [])
        .accessibilityHidden(isLive)
        if depth > 0 {
            button.accessibilityHint(.cameraDetectionPlatePromoteAccessibilityHint)
        } else {
            button.accessibilityHint(.cameraDetectionPlateDetailsAccessibilityHint)
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
        let present = Set(items.map(\.id))
        promotions.removeAll { !present.contains($0) }
    }

    private func promote(_ id: UUID) {
        promotions.removeAll { $0 == id }
        promotions.append(id)
    }

    private func opacity(forDepth depth: Int) -> Double {
        let opacity = switch depth {
        case 0: 1.0
        case 1: 0.55
        case 2: 0.4
        default: 0.3
        }
        let needsSolidPlates = reduceTransparency || colorSchemeContrast == .increased
        return needsSolidPlates ? max(opacity, 0.85) : opacity
    }
}

private struct HitTargetFrame<Content: View>: View {
    let target: CGRect
    let visibleCenter: CGPoint
    @ViewBuilder let content: Content

    var body: some View {
        Color.clear
            .frame(width: target.width, height: target.height)
            .overlay(alignment: .topLeading) {
                content
                    .position(x: visibleCenter.x - target.minX, y: visibleCenter.y - target.minY)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
    }
}

private struct DetectionOutline: View {
    let item: DetectedItem
    let outline: PlateLayout.Outline
    let angle: CGFloat
    let isLive: Bool
    let onTap: (UUID) -> Void

    var body: some View {
        Button {
            onTap(item.id)
        } label: {
            HitTargetFrame(target: outline.hitTarget, visibleCenter: outline.center) {
                RoundedRectangle(cornerRadius: outline.cornerRadius)
                    .stroke(.black.opacity(0.55), lineWidth: 3.5)
                    .overlay {
                        RoundedRectangle(cornerRadius: outline.cornerRadius)
                            .stroke(.white, lineWidth: 1.75)
                    }
                    .frame(width: outline.size.width, height: outline.size.height)
                    .rotationEffect(.radians(angle))
            }
        }
        .buttonStyle(.plain)
        .position(x: outline.hitTarget.midX, y: outline.hitTarget.midY)
        .accessibilityLabel(.cameraDetectionOutlineAccessibilityLabel(number: item.transcript))
        .accessibilityHint(.cameraDetectionOutlineAccessibilityHint)
        .accessibilityHidden(isLive)
    }
}

private struct ConvertedPlate: View {
    let plate: PlateLayout.Plate

    var body: some View {
        Text(verbatim: plate.text)
            .font(.system(size: plate.fontSize, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.tint)
            .frame(width: plate.size.width, height: plate.size.height)
            .background(.black.mix(with: .white, by: 0.15), in: .rect(cornerRadius: plate.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: plate.cornerRadius)
                    .stroke(.white.opacity(0.25), lineWidth: 0.5)
            }
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
                    bounds: CGRect(x: 128, y: 290, width: 96, height: 34),
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
            imageSize: nil,
            onOutlineTap: { _ in },
            onPlateTap: { _ in }
        )
    }
}
