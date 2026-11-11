import SwiftUI

struct ConversionSnippetView: View {
    let conversion: FormattedConversion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(conversion.converted)
                .font(.appLargeTitle)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let lastUpdated = conversion.lastUpdated {
                Text(lastUpdated)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardPadding)
    }
}
