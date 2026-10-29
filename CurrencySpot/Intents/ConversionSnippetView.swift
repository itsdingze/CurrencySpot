import SwiftUI

struct ConversionSnippetView: View {
    let conversion: FormattedConversion

    var body: some View {
        Text(conversion.converted)
            .font(.appLargeTitle)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
    }
}
