import SwiftUI

// MARK: - Statistics Section

struct StatisticsSection: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: 0) {
                StatCard(
                    label: .historyStatisticsHighest,
                    value: viewModel.formattedHighestRate,
                    marker: .highest,
                    isToggled: viewModel.showHighestPoint,
                    size: .regular,
                    action: toggleHighestPoint
                )

                Spacer()

                StatCard(
                    label: .historyStatisticsLowest,
                    value: viewModel.formattedLowestRate,
                    marker: .lowest,
                    isToggled: viewModel.showLowestPoint,
                    size: .regular,
                    action: toggleLowestPoint
                )
            }

            Divider()

            HStack(spacing: 0) {
                StatCard(
                    label: .historyStatisticsAverage,
                    value: viewModel.formattedAverageRate,
                    marker: .average,
                    isToggled: viewModel.showAverageLine,
                    size: .regular,
                    action: toggleAverageLine
                )

                Spacer()

                volatilityCard(value: viewModel.formattedVolatility)
            }
        }
    }

    // MARK: - Private Methods

    private func toggleHighestPoint() {
        withAnimation(.appToggle) {
            viewModel.showHighestPoint.toggle()
        }
    }

    private func toggleLowestPoint() {
        withAnimation(.appToggle) {
            viewModel.showLowestPoint.toggle()
        }
    }

    private func toggleAverageLine() {
        withAnimation(.appToggle) {
            viewModel.showAverageLine.toggle()
        }
    }

    // MARK: - Private Views

    private func volatilityCard(value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Button(action: viewModel.volatilityInfoTapped) {
                HStack(spacing: Spacing.hairline) {
                    Text(.historyStatisticsVolatility)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "info.circle")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .layoutNeutralHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(.historyStatisticsVolatilityInfo)

            Text(value)
                .font(.appSubheadline.weight(.medium))
                .foregroundStyle(viewModel.volatilityLevel?.color ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.chipPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.historyStatisticsVolatilityAccessibilityLabel(value: value))
        .popover(isPresented: Bindable(viewModel).destination.isPresenting(.volatilityInfo)) {
            VolatilityInfoView()
                .presentationCompactAdaptation(.popover)
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.preview()

    StatisticsSection()
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}
#endif
