//
//  RippleEffect.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 9/9/25.
//

import SwiftUI

struct RippleEffect: View {
    let isActive: Bool
    let color: Color

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startRippleAnimation()
                }
            }
    }

    private func startRippleAnimation() {
        // Reset initial state
        scale = 1
        opacity = 0

        withAnimation(.snappy) {
            scale = 3.0
            opacity = 1.0
        }

        // Fade out happens after a brief delay
        Task {
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 0
            }
        }
    }
}
