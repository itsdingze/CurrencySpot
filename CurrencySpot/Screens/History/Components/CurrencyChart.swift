import Charts
import SwiftUI

struct CurrencyChart: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel
    @Environment(\.appAccent) private var accent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var rawSelectedDate: Date?
    @State private var axSelectionIndex: Int?
    let statistics: ChartStatistics
    @Binding var isChartSelectionActive: Bool

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

    private let animationDelay: Double = 0.3
    private let animationDuration: Double = 0.5

    private var trendColor: Color {
        if rawSelectedDate == nil {
            statistics.trendDirection.color
        } else {
            accent
        }
    }

    private var yAxisSpan: Double {
        statistics.chartYDomain.upperBound - statistics.chartYDomain.lowerBound
    }

    private struct SeriesPoint: Identifiable {
        struct ID: Hashable {
            let series: CurrencyHistoryViewModel.ChartSeriesID
            let date: Date
        }

        let id: ID
        let point: ChartDataPoint
    }

    private var seriesPoints: [SeriesPoint] {
        let series = viewModel.chartSeriesID
        return viewModel.displayedChartDataPoints.map {
            SeriesPoint(id: SeriesPoint.ID(series: series, date: $0.date), point: $0)
        }
    }

    private var highestPoint: ChartDataPoint? {
        viewModel.displayedChartDataPoints.max { $0.rate < $1.rate }
    }

    private var lowestPoint: ChartDataPoint? {
        viewModel.displayedChartDataPoints.min { $0.rate < $1.rate }
    }

    private var selectedDate: ChartDataPoint? {
        guard let rawSelectedDate else { return nil }

        return viewModel.displayedChartDataPoints.closestPoint(to: rawSelectedDate)
    }

    var body: some View {
        Chart {
            if isChartReady, !viewModel.displayedChartDataPoints.isEmpty {
                RuleMark(y: .value(.historyChartPlotAverage, statistics.averageRate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.gray.opacity(viewModel.showAverageLine ? 0.5 : 0.0))
                    .zIndex(-1)
            }

            ForEach(seriesPoints) { seriesPoint in
                RateAreaLineMarks(
                    date: seriesPoint.point.date,
                    rate: isChartReady ? seriesPoint.point.rate : statistics.lowestRate,
                    lowestRate: statistics.lowestRate,
                    areaColor: trendColor,
                    lineStyle: trendColor
                )
            }

            if let highestPoint, isChartReady {
                PointMark(
                    x: .value(.rateChartAxisDate, highestPoint.date, unit: .day),
                    y: .value(.rateChartAxisRate, highestPoint.rate)
                )
                .symbol {
                    ZStack {
                        RippleEffect(isActive: viewModel.showHighestPoint, color: .success)

                        ChartPointMarker(color: .success)
                    }
                    .opacity(viewModel.showHighestPoint ? 1.0 : 0.0)
                    .animation(.appToggle, value: viewModel.showHighestPoint)
                }
            }

            if let lowestPoint, isChartReady {
                PointMark(
                    x: .value(.rateChartAxisDate, lowestPoint.date, unit: .day),
                    y: .value(.rateChartAxisRate, lowestPoint.rate)
                )
                .symbol {
                    ZStack {
                        RippleEffect(isActive: viewModel.showLowestPoint, color: .failure)

                        ChartPointMarker(color: .failure)
                    }
                    .opacity(viewModel.showLowestPoint ? 1.0 : 0.0)
                    .animation(.appToggle, value: viewModel.showLowestPoint)
                }
            }

            if let selectedDate {
                RuleMark(x: .value(.rateChartAxisDate, selectedDate.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .zIndex(-1)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack {
                            Text(selectedDate.date.rateDayDisplay)

                            Text(selectedDate.rate.toStringMax4Decimals)
                        }
                        .foregroundStyle(.tint)
                        .fontDesign(.rounded)
                        .padding(Spacing.chipPadding)
                        .background(.tint.opacity(0.2), in: .rect(cornerRadius: Radius.badge))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }

                PointMark(
                    x: .value(.rateChartAxisDate, selectedDate.date, unit: .day),
                    y: .value(.rateChartAxisRate, selectedDate.rate)
                )
                .symbol {
                    ChartPointMarker(color: .tint, outerSize: 14, innerSize: 10)
                }
            }
        }
        .chartXAxis {
            if dynamicTypeSize.isAccessibilitySize {
                AxisMarks(preset: .aligned) {
                    AxisValueLabel(format: viewModel.selectedTimeRange.chartAxisDateFormat, collisionResolution: .greedy)
                }
            } else {
                AxisMarks {
                    AxisValueLabel(format: viewModel.selectedTimeRange.chartAxisDateFormat, collisionResolution: .greedy)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(doubleValue.axisLabel(across: yAxisSpan))
                            .fontDesign(.rounded)
                    }
                }
            }
        }
        .chartYScale(domain: statistics.chartYDomain)
        .environment(\.calendar, CETCalendar.calendar)
        .environment(\.timeZone, CETCalendar.timeZone)
        .chartXSelection(value: isSelectionEnabled ? $rawSelectedDate : .constant(nil))
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityValue(chartAccessibilityValue)
        .accessibilityHint(chartAccessibilityHint)
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
        .onChange(of: rawSelectedDate) { _, newValue in
            isChartSelectionActive = newValue != nil
        }
        .task {
            do { try await Task.sleep(for: .seconds(animationDelay)) } catch { return }
            withAnimation(.smooth(duration: animationDuration)) {
                animationPhase = .animating
            } completion: {
                animationPhase = .complete
            }
        }
        .padding(8)
        .frame(height: ChartMetrics.height)
    }

    // MARK: - Accessibility Helpers

    private var chartAccessibilityLabel: LocalizedStringResource {
        .historyChartAccessibilityLabel(
            base: viewModel.baseCurrency.rawValue,
            target: viewModel.targetCurrency.rawValue
        )
    }

    private var chartAccessibilityValue: LocalizedStringResource {
        let dataPoints = viewModel.displayedChartDataPoints

        if let index = axSelectionIndex, dataPoints.indices.contains(index) {
            let point = dataPoints[index]
            return .historyChartAccessibilityValueSelectedPoint(
                date: point.date.rateDayDisplay,
                rate: point.rate.toStringMax4Decimals
            )
        }

        guard let first = dataPoints.first, let last = dataPoints.last else {
            return .historyChartAccessibilityValueEmpty
        }

        return chartSummary(
            count: dataPoints.count,
            startDate: first.date.rateDayDisplay,
            endDate: last.date.rateDayDisplay,
            rate: last.rate.toStringMax4Decimals
        )
    }

    private func chartSummary(count: Int, startDate: String, endDate: String, rate: String) -> LocalizedStringResource {
        switch statistics.trendDirection {
        case .up:
            .historyChartAccessibilityValueSummaryUp(count: count, startDate: startDate, endDate: endDate, rate: rate)
        case .down:
            .historyChartAccessibilityValueSummaryDown(count: count, startDate: startDate, endDate: endDate, rate: rate)
        case .stable:
            .historyChartAccessibilityValueSummaryStable(count: count, startDate: startDate, endDate: endDate, rate: rate)
        }
    }

    private var chartAccessibilityHint: LocalizedStringResource {
        .historyChartAccessibilityHint
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let dataPoints = viewModel.displayedChartDataPoints
        guard !dataPoints.isEmpty else { return }

        let current = axSelectionIndex ?? dataPoints.count - 1
        let next: Int
        switch direction {
        case .increment:
            next = min(current + 1, dataPoints.count - 1)
        case .decrement:
            next = max(current - 1, 0)
        @unknown default:
            next = current
        }

        axSelectionIndex = next
        rawSelectedDate = dataPoints[next].date
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.preview()

    VStack {
        if let statistics = viewModel.chartStatistics {
            CurrencyChart(statistics: statistics, isChartSelectionActive: .constant(false))
        }
    }
    .environment(viewModel)
    .task { await viewModel.loadChart() }
    .padding()
}
#endif
