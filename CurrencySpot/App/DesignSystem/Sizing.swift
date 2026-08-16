import CoreGraphics

nonisolated enum Spacing {
    // MARK: - Stack gaps

    static let hairline: CGFloat = 4
    static let tight: CGFloat = 8
    static let element: CGFloat = 12
    static let section: CGFloat = 16
    static let block: CGFloat = 24
    static let onboarding: CGFloat = 40

    // MARK: - Interior padding

    static let chipPadding: CGFloat = 8
    static let badgePaddingHorizontal: CGFloat = 8
    static let badgePaddingVertical: CGFloat = 4
    static let cardPadding: CGFloat = 16
    static let screenInset: CGFloat = 24
    static let instructionInset: CGFloat = 32
}

nonisolated enum Radius {
    static let badge: CGFloat = 8
    static let card: CGFloat = 12
    static let container: CGFloat = 16
}

nonisolated enum ControlMetrics {
    static let buttonSize: CGFloat = 44
}
