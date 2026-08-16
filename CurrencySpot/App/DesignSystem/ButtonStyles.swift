import SwiftUI

private let pressedOpacity = 0.7

// MARK: - Primary action

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(Color.white)
            .padding(12)
            .adaptiveGlassBackground(in: .rect(cornerRadius: Radius.container), isInteractive: true, tintedFallback: .accentColor)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
    }
}

extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

// MARK: - Control button

struct ControlButtonStyle: ButtonStyle {
    var glass = true

    func makeBody(configuration: Configuration) -> some View {
        ControlButtonChrome(glass: glass, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

extension ButtonStyle where Self == ControlButtonStyle {
    static var controlButton: ControlButtonStyle { ControlButtonStyle() }
    static func controlButton(glass: Bool) -> ControlButtonStyle { ControlButtonStyle(glass: glass) }
}

// The chrome lives in a View, not in the ButtonStyle: @ScaledMetric only tracks
// Dynamic Type inside a view context.
private struct ControlButtonChrome<Label: View>: View {
    let glass: Bool
    let isPressed: Bool
    @ViewBuilder var label: Label

    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = ControlMetrics.buttonSize

    var body: some View {
        box
            .contentShape(.rect)
            .opacity(isPressed ? pressedOpacity : 1)
    }

    @ViewBuilder
    private var box: some View {
        let framed = label
            .font(.appHeadline)
            .frame(width: size, height: size)
        if glass {
            framed.adaptiveGlassBackground(in: .circle, isInteractive: true)
        } else {
            framed
        }
    }
}

// MARK: - Number pad key

struct NumberPadKeyButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(foreground)
            .adaptiveGlassBackground(in: Capsule(), isInteractive: true, tint: fill) {
                Capsule().fill(fill)
            }
            .contentShape(.rect)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
    }
}

extension ButtonStyle where Self == NumberPadKeyButtonStyle {
    static func numberPadKey(fill: Color, foreground: Color) -> NumberPadKeyButtonStyle {
        NumberPadKeyButtonStyle(fill: fill, foreground: foreground)
    }
}

// MARK: - Currency chip

struct CurrencyChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        chip(configuration.label)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
    }

    @ViewBuilder
    private func chip(_ label: Configuration.Label) -> some View {
        let styled = label
            .font(.appHeadline.weight(.medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
        if isSelected {
            styled.adaptiveGlassBackground(in: .rect(cornerRadius: Radius.card), tintedFallback: .accentColor)
        } else {
            styled
        }
    }
}

extension ButtonStyle where Self == CurrencyChipButtonStyle {
    static func currencyChip(isSelected: Bool) -> CurrencyChipButtonStyle {
        CurrencyChipButtonStyle(isSelected: isSelected)
    }
}

// MARK: - Currency code

struct CurrencyCodeButtonStyle: ButtonStyle {
    var fill: Color?
    var stroke: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        chip(configuration.label)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
    }

    @ViewBuilder
    private func chip(_ label: Configuration.Label) -> some View {
        if let fill {
            label
                .padding(Spacing.chipPadding)
                .adaptiveGlassBackground(in: .rect(cornerRadius: Radius.card), isInteractive: true, tint: fill) {
                    RoundedRectangle(cornerRadius: Radius.card)
                        .fill(fill)
                        .stroke(stroke, lineWidth: 1)
                }
        } else {
            label.padding(.horizontal, Spacing.chipPadding)
        }
    }
}

extension ButtonStyle where Self == CurrencyCodeButtonStyle {
    static func currencyCode(fill: Color? = nil, stroke: Color = .clear) -> CurrencyCodeButtonStyle {
        CurrencyCodeButtonStyle(fill: fill, stroke: stroke)
    }
}
