//
//  NoPricesHint.swift
//  CurrencySpot
//

import SwiftUI

/// Subtle hint shown after a few seconds of live scanning with no prices found.
struct NoPricesHint: View {
    let detectedItems: [DetectedItem]
    let isLive: Bool

    @State private var isVisible = false

    private var hasPrices: Bool {
        detectedItems.contains { $0.conversion.isPrice }
    }

    var body: some View {
        Group {
            if isVisible {
                Text("Point at a price tag or menu")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: .capsule)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .task(id: hintState) {
            guard hintState.eligible else {
                isVisible = false
                return
            }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            isVisible = true
        }
    }

    private var hintState: HintState {
        HintState(eligible: isLive && !hasPrices)
    }

    private struct HintState: Equatable {
        let eligible: Bool
    }
}

#Preview {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        NoPricesHint(detectedItems: [], isLive: true)
    }
}
