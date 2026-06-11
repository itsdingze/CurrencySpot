//
//  ScanStatusCapsule.swift
//  CurrencySpot
//

import SwiftUI

/// Which status message the camera capsule shows, if any.
enum ScanStatusPhase: Equatable {
    case hidden
    case scanning
    case pointHint
    case notFound

    static func resolve(
        isLive: Bool,
        hasPrices: Bool,
        isRecognizingStill: Bool,
        hintElapsed: Bool
    ) -> ScanStatusPhase {
        if hasPrices { return .hidden }
        if isLive { return hintElapsed ? .pointHint : .scanning }
        return isRecognizingStill ? .hidden : .notFound
    }
}

/// Status capsule above the shutter: shows that live scanning is active,
/// nudges the user after a few seconds without results, and reports when a
/// frozen frame or imported photo contained no prices.
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
        // The timer lives on this always-present container: attached to the
        // conditional content it could never fire while the capsule is hidden.
        ZStack {
            if let message {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .modifier(Shimmer(active: phase == .scanning))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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
    }

    /// Live with nothing found yet — the only state that runs the hint timer.
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

/// Sweeps a highlight band across the content to signal ongoing activity.
private struct Shimmer: ViewModifier {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel = false

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            content
                .opacity(0.7)
                .overlay {
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
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        travel = true
                    }
                }
        } else {
            content
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
