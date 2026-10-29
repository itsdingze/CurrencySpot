import SwiftUI

enum WidgetInsets {
    static let horizontal: CGFloat = 16
    static let vertical: CGFloat = 14
}

extension View {
    func widgetContentPadding() -> some View {
        padding(.horizontal, WidgetInsets.horizontal)
            .padding(.vertical, WidgetInsets.vertical)
    }
}
