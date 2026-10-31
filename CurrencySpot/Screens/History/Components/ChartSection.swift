import SwiftUI

// MARK: - Chart Section

enum ChartMetrics {
    static let height: CGFloat = 260
}

struct ChartSection: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        if viewModel.showLoadingOverlay {
            loadingView
                .transition(.opacity)
        } else if let statistics = viewModel.chartStatistics {
            CurrencyChart(statistics: statistics, isChartSelectionActive: $isChartSelectionActive)
        } else if isAwaitingFirstResult {
            placeholder
        } else if viewModel.isWaitingForConnection {
            offlineView
        } else if viewModel.chartData.error != nil {
            failedView
        } else {
            noDataView
        }
    }

    // MARK: - Private Views

    private var isAwaitingFirstResult: Bool {
        switch viewModel.chartData {
        case .idle, .loading: true
        case .loaded, .failed: false
        }
    }

    private var placeholder: some View {
        Color.clear
            .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
            .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
            .accessibilityHidden(true)
    }

    private var loadingView: some View {
        ProgressView(.calculatorLoading)
            .padding()
            .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
            .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var offlineView: some View {
        VStack(spacing: Spacing.element) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(.errorNoInternetTitle)
                .font(.appHeadline)

            Text(.calculatorErrorMessageOffline)
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, idealHeight: ChartMetrics.height, maxHeight: ChartMetrics.height)
        .background(Color.chartPlaceholder, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
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
