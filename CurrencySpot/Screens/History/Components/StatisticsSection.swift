import SwiftUI

// MARK: - Statistics Section

struct StatisticsSection: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: 0) {
                Button(action: toggleHighestPoint) {
                    statCard(
                        label: "Highest",
                        value: viewModel.formattedHighestRate,
                        isToggled: viewModel.showHighestPoint,
                        indicatorColor: .success
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: toggleLowestPoint) {
                    statCard(
                        label: "Lowest",
                        value: viewModel.formattedLowestRate,
                        isToggled: viewModel.showLowestPoint,
                        indicatorColor: .failure
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 0) {
                Button(action: toggleAverageLine) {
                    statCard(
                        label: "Average",
                        value: viewModel.formattedAverageRate,
                        isToggled: viewModel.showAverageLine,
                        indicatorColor: Color.gray
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                volatilityCard(label: "Volatility", value: viewModel.formattedVolatility)
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

    @ViewBuilder
    private func statCard(label: String, value: String, isToggled: Bool = false, indicatorColor: Color? = nil) -> some View {
        let card = VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: Spacing.hairline) {
                Text(label)
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)

                if let color = indicatorColor {
                    Circle()
                        .fill(color.opacity(isToggled ? 1.0 : 0.3))
                        .frame(width: 6, height: 6)
                        .animation(.appToggle, value: isToggled)
                }
            }

            Text(value)
                .font(.appHeadline.weight(.medium).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.chipPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")

        if indicatorColor != nil {
            card.accessibilityHint(isToggled
                ? "Hides the \(label.lowercased()) marker on the chart"
                : "Shows the \(label.lowercased()) marker on the chart")
        } else {
            card
        }
    }

    @ViewBuilder
    private func volatilityCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Button(action: viewModel.volatilityInfoTapped) {
                HStack(spacing: Spacing.hairline) {
                    Text(label)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "info.circle")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volatility information")

            Text(value)
                .font(.appSubheadline.weight(.medium))
                .foregroundStyle(viewModel.volatilityLevel?.color ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.chipPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Volatility: \(value)")
        .popover(isPresented: Bindable(viewModel).destination.isPresenting(.volatilityInfo)) {
            VolatilityInfoView()
                .presentationCompactAdaptation(.popover)
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = HistoryViewModel.preview()

    StatisticsSection()
        .environment(viewModel)
        .task { viewModel.openHistory(for: .eur) }
        .padding()
}
#endif
