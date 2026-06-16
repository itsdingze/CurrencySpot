//
//  Sizing.swift
//  CurrencySpot
//

import SwiftUI

/// Spacing, padding, and radius tokens on a 4/8 grid.
/// Names describe role, never value — bump a role here, every call site follows.
nonisolated extension CGFloat {
    // MARK: Stack gaps

    /// Tightest grouping: label/value pairs, icon/text within one line.
    static let hairlineGap: CGFloat = 4
    /// Related elements inside one control or cluster.
    static let tightGap: CGFloat = 8
    /// Sibling elements within a section.
    static let elementGap: CGFloat = 12
    /// Between sections of a screen.
    static let sectionGap: CGFloat = 16
    /// Between major content blocks (camera overlays, picker grids).
    static let blockGap: CGFloat = 24
    /// Generous rhythm of the onboarding screens.
    static let onboardingGap: CGFloat = 40

    // MARK: Interior padding

    /// Chip and stat-card interiors.
    static let chipPadding: CGFloat = 8
    /// Search fields, toasts, inline error buttons.
    static let fieldPadding: CGFloat = 12
    /// Inset around an SF Symbol inside a circular control button.
    static let controlIconPadding: CGFloat = 12
    /// Inset around a compact close-button glyph; its larger padding pairs with
    /// `closeIconSize` to keep the same 44pt tap target as a standard control icon.
    static let closeIconPadding: CGFloat = 14
    /// Card and popover interiors.
    static let cardPadding: CGFloat = 16
    /// Horizontal inset of full-width banners and camera overlays.
    static let screenInset: CGFloat = 24
    /// Edge inset of the onboarding and camera-state screens.
    static let onboardingInset: CGFloat = 32

    // MARK: Corner radii

    /// Micro badges and chart annotation bubbles.
    static let badgeRadius: CGFloat = 8
    static let badgePaddingHorizontal: CGFloat = 8
    static let badgePaddingVertical: CGFloat = 4
    /// The dominant card/field radius.
    static let cardRadius: CGFloat = 12
    /// Containers and primary-action buttons.
    static let containerRadius: CGFloat = 16
    /// Camera feed clip and sheet presentation corners.
    static let previewRadius: CGFloat = 32

    // MARK: Fixed layout

    /// Diameter of a circular icon-control tap target (and its glass circle).
    /// `ControlButtonStyle` scales from here with Dynamic Type relative to
    /// `.headline`, matching its `.appHeadline` glyph.
    static let controlButtonSize: CGFloat = 44
    /// Smaller glyph for a compact close/dismiss button; its larger padding keeps
    /// the 44pt tap target a standard control icon has.
    static let closeIconSize: CGFloat = 16
    /// Height of the main history chart and its placeholders.
    static let chartHeight: CGFloat = 260
}
