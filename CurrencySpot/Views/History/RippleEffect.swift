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
    @State private var fadeTask: Task<Void, Never>?

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
            .onDisappear { fadeTask?.cancel() }
    }

    private func startRippleAnimation() {
        // Cancel any in-flight fade so a re-trigger can't double-animate, and reset state.
        fadeTask?.cancel()
        scale = 1
        opacity = 0

        withAnimation(.snappy) {
            scale = 3.0
            opacity = 1.0
        }

        // Fade out happens after a brief delay, tied to the view's lifetime.
        fadeTask = Task {
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 0
            }
        }
    }
}
