//
//  CurrencyChart.swift
//  CurrencySpot
//

import Charts
import SwiftUI

struct CurrencyChart: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
    @State private var rawSelectedDate: Date?
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

    // This controls when the animation will start after this view has being initialized
    private let animationDelay: Double = 0.3
    // This controls the duration of the animation
    private let animationDuration: Double = 0.5

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

        return viewModel.displayedChartDataPoints.closestPoint(to: rawSelectedDate)
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
                        RippleEffect(isActive: viewModel.showHighestPoint, color: .success)

                        ChartPointMarker(color: .success)
                    }
                    .opacity(viewModel.showHighestPoint ? 1.0 : 0.0)
                    .animation(.appToggle, value: viewModel.showHighestPoint)
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
                        RippleEffect(isActive: viewModel.showLowestPoint, color: .failure)

                        ChartPointMarker(color: .failure)
                    }
                    .opacity(viewModel.showLowestPoint ? 1.0 : 0.0)
                    .animation(.appToggle, value: viewModel.showLowestPoint)
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
                        .padding(.chipPadding)
                        .background(RoundedRectangle(cornerRadius: .badgeRadius).fill(chartColor).opacity(0.2))
                    }

                PointMark(
                    x: .value("Date", selectedDate.date, unit: .day),
                    y: .value("Rate", selectedDate.rate)
                )
                .symbol {
                    ChartPointMarker(color: chartColor, outerSize: 14, innerSize: 10)
                }
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisValueLabel(format: viewModel.selectedTimeRange.chartAxisDateFormat)
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
        .frame(height: .chartHeight)
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
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    @Previewable @State var viewModel = HistoryViewModel.preview()

    CurrencyChart(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { viewModel.openHistory(for: "EUR") }
        .padding()
}
#endif
