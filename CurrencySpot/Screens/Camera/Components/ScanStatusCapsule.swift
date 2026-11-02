import SwiftUI

struct ScanStatusCapsule: View {
    let isLive: Bool
    let hasPrices: Bool
    let hasOutlines: Bool
    let isRecognizingStill: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hintElapsed = false
    @State private var hintAnnouncer = PointHintAnnouncer()

    private var phase: ScanStatusPhase {
        .resolve(
            isLive: isLive,
            hasPrices: hasPrices,
            isRecognizingStill: isRecognizingStill,
            hintElapsed: hintElapsed,
            hasOutlines: hasOutlines
        )
    }

    var body: some View {
        ZStack {
            if let message {
                Text(message)
                    .font(.appSubheadline)
                    .modifier(Shimmer(active: phase == .scanning))
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.vertical, Spacing.chipPadding)
                    .background(.regularMaterial, in: backgroundShape)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .task(id: isAwaitingFirstPrice) {
            hintElapsed = false
            guard isAwaitingFirstPrice else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            hintElapsed = true
        }
        .onChange(of: phase) { announcePointHintIfNeeded() }
        .onChange(of: hintElapsed) { announcePointHintIfNeeded() }
        .onChange(of: isLive) { hintAnnouncer = PointHintAnnouncer() }
    }

    private var isAwaitingFirstPrice: Bool { isLive && !hasPrices }

    private func announcePointHintIfNeeded() {
        if hintAnnouncer.shouldAnnounce(phase: phase, hintElapsed: hintElapsed) {
            AccessibilityNotification.Announcement(String(localized: .cameraAnnouncementPointHint)).post()
        }
    }

    private var backgroundShape: AnyShape {
        dynamicTypeSize.isAccessibilitySize ? AnyShape(.rect(cornerRadius: Radius.container)) : AnyShape(.capsule)
    }

    private var message: LocalizedStringResource? {
        switch phase {
        case .hidden: nil
        case .scanning: .cameraStatusScanning
        case .pointHint: .cameraStatusPointHint
        case .notFound: .cameraStatusNotFound
        case .numbersOnly: .cameraStatusNumbersOnly
        }
    }
}

private struct Shimmer: ViewModifier {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel = false

    private var shimmering: Bool { active && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .opacity(shimmering ? 0.7 : 1)
            .overlay {
                if shimmering {
                    GeometryReader { proxy in
                        let band = proxy.size.width * 0.6
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: travel ? proxy.size.width : -band)
                    }
                    .mask(content)
                    .onAppear {
                        travel = false
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            travel = true
                        }
                    }
                }
            }
    }
}

#Preview("Live, scanning") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        ScanStatusCapsule(isLive: true, hasPrices: false, hasOutlines: false, isRecognizingStill: false)
    }
}

#Preview("Frozen, no prices") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        ScanStatusCapsule(isLive: false, hasPrices: false, hasOutlines: false, isRecognizingStill: false)
    }
}

#Preview("Frozen, numbers only") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        ScanStatusCapsule(isLive: false, hasPrices: false, hasOutlines: true, isRecognizingStill: false)
    }
}
