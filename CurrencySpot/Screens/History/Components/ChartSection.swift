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
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: 260)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Loading chart data")
        .accessibilityHint("Please wait while historical exchange rate data is being loaded")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text("No data available")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: 260)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Chart data not available")
            .accessibilityHint("Historical exchange rate data is not available for the selected currency pair")
    }
}
