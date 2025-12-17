//
//  ChartSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import Accessibility
import Charts
import SwiftUI

// MARK: - Chart Section

struct ChartSection: View {
    @Environment(HistoryViewModel.self) var viewModel: HistoryViewModel
    @Binding var isChartSelectionActive: Bool

    @State private var showLoadingOverlay = false
    @State private var loadingTask: Task<Void, Never>?

    private let minimumLoadingDuration: TimeInterval = 0.3
    private let loadingDebounceDelay: TimeInterval = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                if !viewModel.displayedChartDataPoints.isEmpty {
                    CurrencyChart(isChartSelectionActive: $isChartSelectionActive)
                } else {
                    noDataView
                }

                if showLoadingOverlay {
                    loadingView
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
            handleLoadingStateChange(newValue)
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }

    private func handleLoadingStateChange(_ isLoading: Bool) {
        loadingTask?.cancel()

        if isLoading {
            loadingTask = Task {
                try? await Task.sleep(for: .seconds(loadingDebounceDelay))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLoadingOverlay = true
                }
            }
        } else {
            if showLoadingOverlay {
                loadingTask = Task {
                    try? await Task.sleep(for: .seconds(minimumLoadingDuration))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLoadingOverlay = false
                    }
                }
            } else {
                loadingTask?.cancel()
                showLoadingOverlay = false
            }
        }
    }

    // MARK: - Private Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: 260)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityLabel("Loading chart data")
        .accessibilityHint("Please wait while historical exchange rate data is being loaded")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var noDataView: some View {
        Text("No data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: 260)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .accessibilityLabel("Chart data not available")
            .accessibilityHint("Historical exchange rate data is not available for the selected currency pair")
    }
}

// MARK: - Currency Chart

struct CurrencyChart: View {
    @Environment(HistoryViewModel.self) var viewModel: HistoryViewModel
    @State private var rawSelectedDate: Date?
    @Binding var isChartSelectionActive: Bool

    // Cached index to avoid recalculation
    @State private var cachedDate: Date?
    @State private var cachedIndex: Int?

    @State private var animationPhase: AnimationPhase = .pending
    private var isChartReady: Bool {
        animationPhase != .pending
    }

    private var isSelectionEnabled: Bool {
        animationPhase == .complete
    }

    private enum AnimationPhase {
        case pending, animating, complete
    }

    var animationDelay: Double = 0.3 // This controls when the animation will start after this view has being initialized
    var animationDuration: Double = 0.5 // This controls the duration of the animation

    private var chartColor: Color {
        .accentColor
    }

    private var trendColor: Color {
        if rawSelectedDate == nil {
            viewModel.trendDirection.color
        } else {
            .accentColor
        }
    }

    // Find highest and lowest points
    private var highestPoint: ChartDataPoint? {
        viewModel.displayedChartDataPoints.max { $0.rate < $1.rate }
    }

    private var lowestPoint: ChartDataPoint? {
        viewModel.displayedChartDataPoints.min { $0.rate < $1.rate }
    }

    // Optimized selection with binary search
    private var selectedDate: ChartDataPoint? {
        guard let rawSelectedDate else { return nil }

        return findClosestDataPoint(to: rawSelectedDate)
    }

    private func findClosestDataPoint(to date: Date) -> ChartDataPoint? {
        let dataPoints = viewModel.displayedChartDataPoints
        guard !dataPoints.isEmpty else { return nil }

        let calendar = TimeZoneManager.cetCalendar
        let targetDay = calendar.startOfDay(for: date)

        // Binary search for insertion point using normalized dates
        var left = 0
        var right = dataPoints.count

        while left < right {
            let mid = left + (right - left) / 2
            let midDay = calendar.startOfDay(for: dataPoints[mid].date)

            if midDay < targetDay {
                left = mid + 1
            } else {
                right = mid
            }
        }

        // Check candidates around the insertion point
        var candidates: [ChartDataPoint] = []

        if left > 0 {
            candidates.append(dataPoints[left - 1])
        }
        if left < dataPoints.count {
            candidates.append(dataPoints[left])
        }

        // Compare using day-level granularity
        return candidates.min { point1, point2 in
            let day1 = calendar.startOfDay(for: point1.date)
            let day2 = calendar.startOfDay(for: point2.date)

            return abs(day1.timeIntervalSince(targetDay)) < abs(day2.timeIntervalSince(targetDay))
        }
    }

    var body: some View {
        Chart {
            // Average rate line - always present, controlled by opacity
            if isChartReady, !viewModel.displayedChartDataPoints.isEmpty {
                RuleMark(y: .value("Average", viewModel.averageRate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.gray.opacity(viewModel.showAverageLine ? 0.5 : 0.0))
                    .zIndex(-1)
            }

            ForEach(viewModel.displayedChartDataPoints) { dataPoint in
                AreaMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    yStart: .value("Rate", isChartReady ? dataPoint.rate : viewModel.lowestRate),
                    yEnd: .value("Rate", viewModel.lowestRate * 0.99)
                )
                .interpolationMethod(.cardinal(tension: 0.8))
                .foregroundStyle(
                    .linearGradient(
                        colors: [trendColor.opacity(0.15),
                                 trendColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value("Rate", isChartReady ? dataPoint.rate : viewModel.lowestRate)
                )
                .interpolationMethod(.cardinal(tension: 0.8))
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(trendColor)
            }

            // Highest point marker - always present, controlled by opacity
            if let highestPoint, isChartReady {
                PointMark(
                    x: .value("Date", highestPoint.date, unit: .day),
                    y: .value("Rate", highestPoint.rate)
                )
                .symbol {
                    ZStack {
                        RippleEffect(isActive: viewModel.showHighestPoint, color: .green)

                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                    .opacity(viewModel.showHighestPoint ? 1.0 : 0.0)
                    .animation(.smooth(duration: 0.3), value: viewModel.showHighestPoint)
                }
            }

            // Lowest point marker - always present, controlled by opacity
            if let lowestPoint, isChartReady {
                PointMark(
                    x: .value("Date", lowestPoint.date, unit: .day),
                    y: .value("Rate", lowestPoint.rate)
                )
                .symbol {
                    ZStack {
                        RippleEffect(isActive: viewModel.showLowestPoint, color: .red)

                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 8, height: 8)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                    .opacity(viewModel.showLowestPoint ? 1.0 : 0.0)
                    .animation(.smooth(duration: 0.3), value: viewModel.showLowestPoint)
                }
            }

            if let selectedDate {
                RuleMark(x: .value("Date", selectedDate.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .zIndex(-1)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack {
                            Text(selectedDate.date.chartDisplay)
                                .foregroundStyle(chartColor)

                            Text(selectedDate.rate.toStringMax4Decimals)
                                .foregroundStyle(chartColor)
                        }
                        .fontDesign(.rounded)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(chartColor).opacity(0.2))
                    }

                PointMark(
                    x: .value("Date", selectedDate.date, unit: .day),
                    y: .value("Rate", selectedDate.rate)
                )
                .symbol {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 14, height: 14)

                        Circle()
                            .fill(chartColor)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(doubleValue.toStringMax2Decimals)
                            .fontDesign(.rounded)
                    }
                }
            }
        }
        .chartYScale(domain: viewModel.chartYDomain)
        .chartXSelection(value: isSelectionEnabled ? $rawSelectedDate : .constant(nil))
        .animation(.smooth, value: viewModel.displayedChartDataPoints)
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityHint(chartAccessibilityHint)
        .accessibilityInputLabels(["Chart", "Graph", "Exchange rate chart", "Historical data"])
        .accessibilityAddTraits(.allowsDirectInteraction)
        // .accessibilityChartDescriptor(chartDescriptor) // Temporarily disabled due to compiler performance
        .onChange(of: rawSelectedDate) { _, newValue in
            // Update the selection active state whenever rawSelectedDate changes
            isChartSelectionActive = newValue != nil

            if let newDate = newValue,
               let closestPoint = viewModel.displayedChartDataPoints.min(by: {
                   abs($0.date.timeIntervalSince(newDate)) < abs($1.date.timeIntervalSince(newDate))
               })
            {
                cachedDate = newDate
                cachedIndex = viewModel.displayedChartDataPoints.firstIndex(where: { $0.date == closestPoint.date })
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(animationDelay))
                withAnimation(.smooth(duration: animationDuration)) {
                    animationPhase = .animating
                } completion: {
                    animationPhase = .complete
                }
            }
        }
        .padding(8)
        .frame(height: 260)
    }

    // MARK: - Accessibility Helpers

    private var chartAccessibilityLabel: String {
        "Exchange rate chart for \(viewModel.baseCurrency) to \(viewModel.targetCurrency)"
    }

    private var chartAccessibilityValue: String {
        let dataPoints = viewModel.displayedChartDataPoints
        guard !dataPoints.isEmpty else { return "No data available" }

        let dateRange = "\(dataPoints.first?.date.chartDisplay ?? "") to \(dataPoints.last?.date.chartDisplay ?? "")"
        let currentRate = dataPoints.last?.rate.toStringMax4Decimals ?? "Unknown"
        let trend = viewModel.trendDirection.description

        return "Showing \(dataPoints.count) data points from \(dateRange). Current rate: \(currentRate). Trend: \(trend)"
    }

    private var chartAccessibilityHint: String {
        if rawSelectedDate != nil {
            "Double tap to deselect data point. Swipe left or right to navigate between data points"
        } else {
            "Double tap to select a data point. Use audio graphs for detailed exploration"
        }
    }

    private var chartDescriptor: AXChartDescriptor {
        let dataPoints = viewModel.displayedChartDataPoints
        guard !dataPoints.isEmpty else {
            return AXChartDescriptor(
                title: "Exchange Rate Chart",
                summary: "No data available for exchange rate chart",
                xAxis: AXCategoricalDataAxisDescriptor(title: "Date", categoryOrder: []),
                yAxis: AXNumericDataAxisDescriptor(title: "Rate", range: 0 ... 1, gridlinePositions: []) { _ in "0" },
                series: []
            )
        }

        // Create X-axis descriptor for dates
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Date",
            categoryOrder: dataPoints.map(\.date.chartDisplay)
        )

        // Create Y-axis descriptor for rates
        let rates = dataPoints.map(\.rate)
        let minRate = rates.min() ?? 0
        let maxRate = rates.max() ?? 1

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Exchange Rate",
            range: minRate ... maxRate,
            gridlinePositions: []
        ) { value in
            "\(value.toStringMax4Decimals)"
        }

        // Create data series
        let series = AXDataSeriesDescriptor(
            name: "Exchange Rate",
            isContinuous: true,
            dataPoints: dataPoints.map { point in
                AXDataPoint(
                    x: point.date.chartDisplay,
                    y: point.rate,
                    label: "\(point.date.chartDisplay): \(point.rate.toStringMax4Decimals)"
                )
            }
        )

        let summary = """
        Exchange rate chart for \(viewModel.baseCurrency) to \(viewModel.targetCurrency) 
        showing \(dataPoints.count) data points. 
        Current rate: \(dataPoints.last?.rate.toStringMax4Decimals ?? "Unknown"). 
        Trend: \(viewModel.trendDirection.description).
        """

        return AXChartDescriptor(
            title: "Exchange Rate Chart",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
