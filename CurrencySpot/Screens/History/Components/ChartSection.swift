//
//  ChartSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

// MARK: - Chart Section

struct ChartSection: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .elementGap) {
            ZStack {
                chartContent

                // The debounce/min-display overlay exists to avoid blinking a
                // spinner over EXISTING points during quick range changes; a
                // first load has no points and shows the spinner in its base
                // placeholder immediately instead.
                if viewModel.showLoadingOverlay, !viewModel.displayedChartDataPoints.isEmpty {
                    loadingView
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Private Views

    /// One stable branch for the chart across every load phase
    /// (`displayedChartDataPoints` already falls back to the previous points
    /// while loading, so the chart never blanks; the overlay communicates the
    /// load). Switching over the Loadable cases here would give the chart a
    /// new structural identity per phase change, resetting its entry-animation
    /// state and replaying the grow effect on every range change.
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

    /// Empty because no load has produced a result yet — distinct from a load
    /// that completed and genuinely returned nothing. Rendering "No data
    /// available" for this state flashed the message on every first entry.
    private var isAwaitingFirstResult: Bool {
        switch viewModel.chartData {
        case .idle, .loading: true
        case .loaded, .failed: false
        }
    }

    private var loadingView: some View {
        VStack(spacing: .elementGap) {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .chartHeight)
        .background(Color.chartPlaceholder, in: .rect(cornerRadius: .cardRadius))
        .accessibilityLabel("Loading chart data")
        .accessibilityHint("Please wait while historical exchange rate data is being loaded")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text("No data available")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .chartHeight)
            .background(Color.chartPlaceholder, in: .rect(cornerRadius: .cardRadius))
            .accessibilityLabel("Chart data not available")
            .accessibilityHint("Historical exchange rate data is not available for the selected currency pair")
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview("Loaded") {
    @Previewable @State var viewModel = HistoryViewModel.preview()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: "EUR") }
        .padding()
}

#Preview("Loading") {
    @Previewable @State var viewModel = HistoryViewModel.previewLoading()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: "EUR") }
        .padding()
}

#Preview("Failed") {
    @Previewable @State var viewModel = HistoryViewModel.preview()

    ChartSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        // An unknown currency code is the public intent that produces `.failed`.
        .task { viewModel.configure(base: "USD", target: "???") }
        .padding()
}
#endif
