//
//  BrightnessSlider.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/9/25.
//

import SwiftUI

// MARK: - Brightness Slider

struct BrightnessSlider: View {
    // MARK: Public

    @Binding var value: Double
    var range: ClosedRange<Double>
    var baseColor: Color

    init(value: Binding<Double>, range: ClosedRange<Double>, baseColor: Color) {
        _value = value
        self.range = range
        self.baseColor = baseColor
    }

    // MARK: - Private

    @State private var lastOffset: CGFloat = 0

    private var leadingOffset: CGFloat = -2
    private var trailingOffset: CGFloat = -2

    private var knobSize: CGSize = .init(width: 32, height: 32)

    var trackGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                baseColor.adjustBrightness(range.upperBound),
                baseColor,
                baseColor.adjustBrightness(range.lowerBound),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .frame(height: 16)
                    .foregroundStyle(trackGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(.black.opacity(0.1), lineWidth: 2)
                    )
                HStack {
                    Circle()
                        .fill(baseColor.adjustBrightness(CGFloat(value)))
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .frame(width: knobSize.width, height: knobSize.height)
                        .foregroundColor(.white)
                        .offset(x: knobOffset(in: geometry))
                        .gesture(dragGesture(in: geometry))
                    Spacer()
                }
            }
            // Add tap functionality
            .contentShape(Rectangle())
            .onTapGesture { location in
                let sliderPos = min(max(location.x, 0 + leadingOffset), geometry.size.width - knobSize.width - trailingOffset)
                let sliderVal = CGFloat(geometry.size.width - knobSize.width - trailingOffset - sliderPos).map(
                    from: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset),
                    to: CGFloat(range.lowerBound) ... CGFloat(range.upperBound)
                )
                value = Double(sliderVal)
            }
        }
    }

    private func knobOffset(in geometry: GeometryProxy) -> CGFloat {
        let outputRange = min(leadingOffset, geometry.size.width - knobSize.width - trailingOffset)
            ... max(leadingOffset, geometry.size.width - knobSize.width - trailingOffset)

        return (geometry.size.width - knobSize.width - trailingOffset)
            - CGFloat($value.wrappedValue).map(from: CGFloat(range.lowerBound) ... CGFloat(range.upperBound), to: outputRange)
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if abs(value.translation.width) < 0.1 {
                    lastOffset = (geometry.size.width - knobSize.width - trailingOffset) - CGFloat(self.$value.wrappedValue).map(from: CGFloat(range.lowerBound) ... CGFloat(range.upperBound), to: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset))
                }

                let sliderPos = max(0 + leadingOffset, min(lastOffset + value.translation.width, geometry.size.width - knobSize.width - trailingOffset))
                let sliderVal = (geometry.size.width - knobSize.width - trailingOffset - sliderPos).map(from: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset), to: CGFloat(range.lowerBound) ... CGFloat(range.upperBound))

                self.value = Double(sliderVal)
            }
    }
}

// MARK: - Extensions

extension Color {
    func adjustBrightness(_ amount: Double) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b) + amount, opacity: Double(a))
    }
}
