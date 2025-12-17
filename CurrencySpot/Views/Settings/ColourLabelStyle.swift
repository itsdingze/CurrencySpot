//
//  ColourLabelStyle.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/9/25.
//

import SwiftUI

// MARK: - Extensions

extension Color {
    static let green2 = Color(red: 60 / 255, green: 136 / 255, blue: 37 / 255)
    static let green3 = Color(red: 143 / 255, green: 197 / 255, blue: 112 / 255)
    static let gold = Color(red: 255 / 255, green: 215 / 255, blue: 0)
    static let lightGreen = Color(red: 173 / 255, green: 255 / 255, blue: 47 / 255)
    static let darkGray = Color(red: 105 / 255, green: 105 / 255, blue: 105 / 255)

    func adjust(hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, opacity: CGFloat = 1) -> Color {
        let color = UIColor(self)
        var currentHue: CGFloat = 0
        var currentSaturation: CGFloat = 0
        var currentBrigthness: CGFloat = 0
        var currentOpacity: CGFloat = 0

        if color.getHue(&currentHue, saturation: &currentSaturation, brightness: &currentBrigthness, alpha: &currentOpacity) {
            return Color(hue: currentHue + hue, saturation: currentSaturation + saturation, brightness: currentBrigthness + brightness, opacity: currentOpacity + opacity)
        }
        return self
    }
}

// MARK: - Label Style

struct ColourLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == ColourLabelStyle {
    static var colourLabelStyle: ColourLabelStyle {
        ColourLabelStyle()
    }
}

// MARK: - Circle Button

struct CircleButton: View {
    let item: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Circle()
            .fill(item)
            .frame(width: 32, height: 32)
            .overlay {
                Circle()
                    .stroke(item.adjust(brightness: -0.2), lineWidth: 2)
            }
            .padding(5)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .onTapGesture(perform: action)
    }
}

// MARK: - Color Slider

struct ColorSlider: View {
    // MARK: Public

    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat>
    @Binding var selectedColor: Color

    init(value: Binding<CGFloat>, range: ClosedRange<CGFloat>, selectedColor: Binding<Color>) {
        _value = value
        self.range = range
        _selectedColor = selectedColor
    }

    // MARK: - Private

    @State private var lastOffset: CGFloat = 0

    private var leadingOffset: CGFloat = -2
    private var trailingOffset: CGFloat = -2

    private var knobSize: CGSize = .init(width: 32, height: 32)

    var trackGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                selectedColor.adjust(brightness: range.upperBound),
                selectedColor,
                selectedColor.adjust(brightness: range.lowerBound),
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
                            .stroke(trackGradient, lineWidth: 2)
                    )
                HStack {
                    Circle()
                        .fill(selectedColor.adjust(brightness: value))
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .shadow(radius: 8, y: 5)
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
                let sliderVal = (geometry.size.width - knobSize.width - trailingOffset - sliderPos).map(
                    from: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset),
                    to: range
                )
                value = sliderVal
            }
        }
    }

    private func knobOffset(in geometry: GeometryProxy) -> CGFloat {
        let outputRange = min(leadingOffset, geometry.size.width - knobSize.width - trailingOffset)
            ... max(leadingOffset, geometry.size.width - knobSize.width - trailingOffset)

        return (geometry.size.width - knobSize.width - trailingOffset)
            - $value.wrappedValue.map(from: range, to: outputRange)
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if abs(value.translation.width) < 0.1 {
                    lastOffset = (geometry.size.width - knobSize.width - trailingOffset) - self.$value.wrappedValue.map(from: range, to: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset))
                }

                let sliderPos = max(0 + leadingOffset, min(lastOffset + value.translation.width, geometry.size.width - knobSize.width - trailingOffset))
                let sliderVal = (geometry.size.width - knobSize.width - trailingOffset - sliderPos).map(from: leadingOffset ... (geometry.size.width - knobSize.width - trailingOffset), to: range)

                self.value = sliderVal
            }
    }
}

// MARK: - Colour Button

struct ColourButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(
                title: {
                    Text("Colour")
                        .font(.system(.footnote, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.gray)
                },
                icon: {
                    Image(systemName: "paintpalette.fill")
                        .tint(.green2)
                        .font(.system(.title2, design: .rounded))
                        .frame(width: 50, height: 50)
                        .background {
                            Circle()
                                .fill(Color.green3)
                        }
                }
            )
            .labelStyle(.colourLabelStyle)
        }
    }
}

// MARK: - Content View

struct ContentView1: View {
    @State var colourSheetPresented = false
    @State private var brightness: CGFloat = 0
    @State var selectedColour = Color.blue

    let colors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow,
        .gold, .green, .lightGreen, .mint, .indigo, .brown,
        .gray, .darkGray, .cyan, .teal, .white, .black,
    ]

    private let adaptiveColumn = [
        GridItem(.adaptive(minimum: 52)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color with applied brightness
                selectedColour
                    .brightness(brightness)
                    .ignoresSafeArea()

                // Main color picker button
                ColourButton {
                    colourSheetPresented = true
                }
                .sheet(isPresented: $colourSheetPresented) {
                    NavigationStack {
                        VStack {
                            // Grid of color options
                            LazyVGrid(columns: adaptiveColumn, spacing: 20) {
                                ForEach(colors, id: \.self) { item in
                                    CircleButton(
                                        item: item.adjust(brightness: item == selectedColour ? brightness : 0),
                                        isSelected: item == selectedColour
                                    ) {
                                        selectedColour = item
                                    }
                                }
                            }

                            // Brightness slider
                            ColorSlider(value: $brightness, range: -0.5 ... 0.5, selectedColor: $selectedColour)
                                .padding()
                                .frame(height: 60)
                        }
                        .padding(.horizontal)
                        .toolbar {
                            // System color picker in toolbar
                            ToolbarItem(placement: .topBarLeading) {
                                ColorPicker("Colours", selection: $selectedColour, supportsOpacity: false)
                                    .labelsHidden()
                            }

                            // Close button
                            ToolbarItem(placement: .primaryAction) {
                                Button(action: {
                                    colourSheetPresented = false
                                }, label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24, design: .rounded))
                                        .fontDesign(.rounded)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.gray)
                                })
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle("Background Colour")
                    }
                    .presentationDetents([.fraction(0.4)])
                    .presentationCornerRadius(32)
                    .presentationBackground {
                        ZStack {
                            // Background with subtle color gradient
                            Color(uiColor: UIColor.secondarySystemBackground)
                            LinearGradient(colors: [
                                selectedColour.adjust(brightness: brightness).opacity(0.05),
                                selectedColour.adjust(brightness: brightness).opacity(0.1),
                                selectedColour.adjust(brightness: brightness).opacity(0.15),
                                selectedColour.adjust(brightness: brightness).opacity(0.2),
                            ], startPoint: .top, endPoint: .bottom)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView1()
    }
}
