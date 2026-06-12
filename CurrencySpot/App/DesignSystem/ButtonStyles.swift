//
//  ButtonStyles.swift
//  CurrencySpot
//

import SwiftUI

// MARK: - Primary action

/// The app's primary call-to-action: borderedProminent with the container
/// radius, headline label, and breathing room.
struct PrimaryActionButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(.appHeadline)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: .containerRadius))
    }
}

extension PrimitiveButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

// MARK: - Currency chip

/// Quick-access currency chips in the picker's horizontal rail.
struct CurrencyChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline.weight(.medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: .cardRadius))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Currency code

/// The fixed-width currency-code buttons in the calculator and camera
/// controls. A fill renders the calculator's bordered chip; the camera's
/// glass-hosted variant stays chromeless (horizontal padding only).
struct CurrencyCodeButtonStyle: ButtonStyle {
    var fill: Color?
    var stroke: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, .chipPadding)
            .padding(.vertical, fill == nil ? 0 : .chipPadding)
            .background {
                if let fill {
                    RoundedRectangle(cornerRadius: .cardRadius)
                        .fill(fill)
                        .stroke(stroke, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Segmented tab

/// One segment of the time-range picker. The selection pill slides between
/// segments via the shared namespace's matched geometry.
struct SegmentedTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    let namespace: Namespace.ID

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline.weight(isSelected ? .semibold : .regular))
            .padding(.chipPadding)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: .cardRadius)
                        .fill(Color.selectionFill)
                        .matchedGeometryEffect(id: "selectedSegment", in: namespace)
                }
            }
            .animation(.appSelect, value: isSelected)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
