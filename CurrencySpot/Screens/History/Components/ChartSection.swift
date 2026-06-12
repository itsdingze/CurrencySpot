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

                if viewModel.showLoadingOverlay {
                    loadingView
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Private Views

    /// `.loading` and `.failed` render their previous points so the chart never
    /// blanks during a range change; the overlay communicates the load.
    @ViewBuilder
    private var chartContent: some View {
        switch viewModel.chartData {
        case .idle:
            noDataView
        case let .loading(previous):
            chartOrPlaceholder(for: previous ?? [])
        case let .loaded(points):
            chartOrPlaceholder(for: points)
        case let .failed(_, previous):
            chartOrPlaceholder(for: previous ?? [])
        }
    }

    @ViewBuilder
    private func chartOrPlaceholder(for points: [ChartDataPoint]) -> some View {
        if points.isEmpty {
            noDataView
        } else {
            CurrencyChart(isChartSelectionActive: $isChartSelectionActive)
        }
    }

    private var loadingView: some View {
        VStack(spacing: .elementGap) {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .chartHeight)
        .background(Color.chartPlaceholder)
        .clipShape(RoundedRectangle(cornerRadius: .cardRadius))
        .accessibilityLabel("Loading chart data")
        .accessibilityHint("Please wait while historical exchange rate data is being loaded")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text("No data available")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .chartHeight)
            .background(Color.chartPlaceholder)
            .clipShape(RoundedRectangle(cornerRadius: .cardRadius))
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
