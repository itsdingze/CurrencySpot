import SwiftUI

struct VolatilityInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AccessibilitySizeScrollView {
            content
        }
        .scrollIndicatorsFlash(onAppear: true)
        .frame(idealWidth: 320, maxWidth: 400)
        .presentationBackground(.regularMaterial)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            HStack {
                Text(.historyVolatilityInfoTitle)
                    .font(.appHeadline)

                Spacer()

                Button { dismiss() } label: {
                    Label(.historyVolatilityInfoClose, systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .minimumHitTarget()
                }
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: Spacing.element) {
                Text(.historyVolatilityInfoBody)
                    .font(.appSubheadline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.tight) {
                    ForEach(VolatilityLevel.allCases, id: \.self) { level in
                        volatilityLevelRow(level)
                    }
                }

                Text(.historyVolatilityInfoFootnote)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.cardPadding)
    }

    @ViewBuilder
    private func volatilityLevelRow(_ level: VolatilityLevel) -> some View {
        AdaptiveStack(spacing: Spacing.tight) {
            HStack(spacing: Spacing.tight) {
                Circle()
                    .fill(level.color)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(level.displayName)
                    .font(.appCaption.weight(.medium))
                    .frame(minWidth: 70, alignment: .leading)
            }

            Text(level.rangeDescription)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(.historyVolatilityInfoLevelAccessibilityLabel(
            level: String(localized: level.displayName),
            range: String(localized: level.rangeDescription)
        ))
    }
}

#Preview {
    VolatilityInfoView()
}
