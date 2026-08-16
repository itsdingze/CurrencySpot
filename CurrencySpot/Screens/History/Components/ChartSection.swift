import SwiftUI

// MARK: - Chart Section

enum ChartMetrics {
    static let height: CGFloat = 260
}

struct ChartSection: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
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
        if viewModel.displayedChartDataPoints.isEmpty {
            if isAwaitingFirstResult {
                loadingView
            } else {
                noDataView
            }
        } else {
            CurrencyChart(isChartSelectionActive: $isChartSelectionActive)
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
        .frame(maxWidth: .infinity, maxHeight: ChartMetrics.height)
        .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
        .accessibilityLabel("Loading chart data")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text("No data available")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: ChartMetrics.height)
            .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
            .accessibilityLabel("Chart data not available")
    }
}

#if DEBUG
#Preview("Loaded") {
    @Previewable @State var viewModel = HistoryViewModel.preview()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: .eur) }
        .padding()
}

#Preview("Loading") {
    @Previewable @State var viewModel = HistoryViewModel.previewLoading()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: .eur) }
        .padding()
}

#Preview("Failed") {
    @Previewable @State var viewModel = HistoryViewModel.previewFailed()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: .eur) }
        .padding()
}
#endif
