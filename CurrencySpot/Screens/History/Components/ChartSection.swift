import SwiftUI

// MARK: - Chart Section

enum ChartMetrics {
    static let height: CGFloat = 260
}

struct ChartSection: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.element) {
            ZStack {
                chartContent

                if viewModel.showLoadingOverlay, !viewModel.displayedChartDataPoints.isEmpty {
                    loadingView
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var chartContent: some View {
        if let statistics = viewModel.chartStatistics {
            CurrencyChart(statistics: statistics, isChartSelectionActive: $isChartSelectionActive)
        } else if isAwaitingFirstResult {
            loadingView
        } else if viewModel.chartData.error != nil {
            failedView
        } else {
            noDataView
        }
    }

    private var isAwaitingFirstResult: Bool {
        switch viewModel.chartData {
        case .idle, .loading: true
        case .loaded, .failed: false
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.element) {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding()
        .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
        .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
        .accessibilityLabel(.historyChartLoadingAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text(.historyChartEmpty)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
            .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
            .accessibilityLabel(.historyChartEmptyAccessibilityLabel)
    }

    private var failedView: some View {
        VStack(spacing: Spacing.element) {
            Text(.historyChartFailed)
                .foregroundStyle(.secondary)

            Button(.historyChartFailedRetry, action: viewModel.retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
        .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
    }
}

#if DEBUG
#Preview("Loaded") {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.preview()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}

#Preview("Loading") {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.previewLoading()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}

#Preview("Failed") {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.previewFailed()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}
#endif
