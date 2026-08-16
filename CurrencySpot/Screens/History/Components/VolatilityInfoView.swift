import SwiftUI

struct VolatilityInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            HStack {
                Text("What is Volatility?")
                    .font(.appHeadline)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close volatility information")
            }

            VStack(alignment: .leading, spacing: Spacing.element) {
                Text("Volatility measures how much the exchange rate fluctuates over time.")
                    .font(.appSubheadline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.tight) {
                    ForEach(VolatilityLevel.allCases, id: \.self) { level in
                        volatilityLevelRow(level)
                    }
                }

                Text("Lower volatility means more stable exchange rates, while higher volatility indicates larger price swings.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.cardPadding)
        .frame(idealWidth: 320, maxWidth: 400)
        .presentationBackground(.regularMaterial)
    }

    @ViewBuilder
    private func volatilityLevelRow(_ level: VolatilityLevel) -> some View {
        HStack(spacing: Spacing.tight) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(level.displayName)
                .font(.appCaption.weight(.medium))
                .frame(minWidth: 70, alignment: .leading)

            Text(level.rangeDescription)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName) volatility: \(level.rangeDescription)")
    }
}

#Preview {
    VolatilityInfoView()
}
