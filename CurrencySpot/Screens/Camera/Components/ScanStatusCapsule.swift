import SwiftUI

struct ScanStatusCapsule: View {
    let isLive: Bool
    let hasPrices: Bool
    let isRecognizingStill: Bool

    @State private var hintElapsed = false

    private var phase: ScanStatusPhase {
        .resolve(
            isLive: isLive,
            hasPrices: hasPrices,
            isRecognizingStill: isRecognizingStill,
            hintElapsed: hintElapsed
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
                    .background(.regularMaterial, in: .capsule)
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
        .onChange(of: phase == .pointHint) { _, showing in
            if showing {
                AccessibilityNotification.Announcement("Point the camera at a price tag.").post()
            }
        }
    }

    private var isAwaitingFirstPrice: Bool { isLive && !hasPrices }

    private var message: LocalizedStringKey? {
        switch phase {
        case .hidden: nil
        case .scanning: "Scanning"
        case .pointHint: "Point at a price tag or menu"
        case .notFound: "No prices found"
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
        ScanStatusCapsule(isLive: true, hasPrices: false, isRecognizingStill: false)
    }
}

#Preview("Frozen, no prices") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        ScanStatusCapsule(isLive: false, hasPrices: false, isRecognizingStill: false)
    }
}
