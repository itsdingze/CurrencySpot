import SwiftUI

nonisolated extension Font {
    // WidgetKit drops the weight: argument of Font.system(_:design:weight:)
    static let appLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let appTitle = Font.system(.title, design: .rounded).weight(.semibold)
    static let appTitle2 = Font.system(.title2, design: .rounded).weight(.semibold)
    static let appTitle3 = Font.system(.title3, design: .rounded).weight(.semibold)
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appCallout = Font.system(.callout, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
    static let appFootnote = Font.system(.footnote, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appCaption2 = Font.system(.caption2, design: .rounded)

    static let appMonospaced = Font.system(.footnote, design: .monospaced)
}
