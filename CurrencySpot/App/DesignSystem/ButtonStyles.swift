//
//  ButtonStyles.swift
//  CurrencySpot
//

import SwiftUI

// MARK: - Primary action

/// The app's primary call-to-action: accent-tinted Liquid Glass on iOS 26+,
/// falling back to an accent-filled rounded rect on earlier systems.
struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(Color.white)
            .padding(.controlIconPadding)
            .adaptiveGlassBackground(in: .rect(cornerRadius: .containerRadius), isInteractive: true, tintedFallback: .accentColor)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

// MARK: - Currency chip

/// Quick-access currency chips in the picker's horizontal rail. The accent
/// glass background appears only when selected.
struct CurrencyChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        chip(configuration.label)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    @ViewBuilder
    private func chip(_ label: Configuration.Label) -> some View {
        let styled = label
            .font(.appHeadline.weight(.medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
        if isSelected {
            styled.adaptiveGlassBackground(in: .rect(cornerRadius: .cardRadius), tintedFallback: .accentColor)
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

/// The fixed-width currency-code buttons in the calculator and camera
/// controls. A `fill` renders the calculator's bordered chip; the camera's
/// glass-hosted variant stays chromeless (horizontal padding only).
struct CurrencyCodeButtonStyle: ButtonStyle {
    var fill: Color?
    var stroke: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        chip(configuration.label)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }

    @ViewBuilder
    private func chip(_ label: Configuration.Label) -> some View {
        if let fill {
            label
                .padding(.chipPadding)
                .adaptiveGlassBackground(in: .rect(cornerRadius: .cardRadius), isInteractive: true, tint: fill) {
                    RoundedRectangle(cornerRadius: .cardRadius)
                        .fill(fill)
                        .stroke(stroke, lineWidth: 1)
                }
        } else {
            label.padding(.horizontal, .chipPadding)
        }
    }
}

extension ButtonStyle where Self == CurrencyCodeButtonStyle {
    static func currencyCode(fill: Color? = nil, stroke: Color = .clear) -> CurrencyCodeButtonStyle {
        CurrencyCodeButtonStyle(fill: fill, stroke: stroke)
    }
}
