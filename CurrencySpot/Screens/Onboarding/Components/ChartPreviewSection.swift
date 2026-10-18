import Charts
import SwiftUI

struct ChartPreviewSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAccent) private var accent
    @State private var tappedIndicators: [ChartIndicator: Bool] = [:]

    var body: some View {
        demo
            .padding(.top, Spacing.block)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(.onboardingChartPreviewAccessibilityLabel)
            .accessibilityHint(.onboardingChartPreviewAccessibilityHint)
    }

    @ViewBuilder
    private var demo: some View {
        if reduceMotion {
            section(demoShowing: Set(ChartIndicator.allCases))
        } else {
            KeyframeAnimator(initialValue: 0.0, repeating: true) { step in
                let phase = DemoPhase(step: step)
                section(demoShowing: phase.shownIndicators)
                    .animation(.appToggle, value: phase)
                    .onChange(of: phase) {
                        withAnimation(.appToggle) { tappedIndicators.removeAll() }
                    }
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 1.5)
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.7)
                    MoveKeyframe(2)
                    LinearKeyframe(2, duration: 0.7)
                    MoveKeyframe(3)
                    LinearKeyframe(3, duration: 1.6)
                    MoveKeyframe(0)
                }
            }
        }
    }

    private func section(demoShowing demo: Set<ChartIndicator>) -> some View {
        let shown = shownIndicators(demoShowing: demo)
        return VStack(spacing: Spacing.block) {
            chart(showing: shown)
            statCards(showing: shown)
        }
    }

    private func shownIndicators(demoShowing demo: Set<ChartIndicator>) -> Set<ChartIndicator> {
        var shown = demo
        for (indicator, isShown) in tappedIndicators {
            if isShown {
                shown.insert(indicator)
            } else {
                shown.remove(indicator)
            }
        }
        return shown
    }

    private func toggle(_ indicator: ChartIndicator, in shown: Set<ChartIndicator>) {
        withAnimation(.appToggle) {
            tappedIndicators[indicator] = !shown.contains(indicator)
        }
    }

    private func chart(showing shown: Set<ChartIndicator>) -> some View {
        Chart {
            RuleMark(y: .value(.historyChartPlotAverage, SampleChartData.averageRate))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Color.gray.opacity(shown.contains(.average) ? 0.5 : 0.0))
                .zIndex(-1)

            ForEach(SampleChartData.points) { dataPoint in
                RateAreaLineMarks(
                    date: dataPoint.date,
                    rate: dataPoint.rate,
                    lowestRate: SampleChartData.minimumRate,
                    areaColor: accent,
                    lineStyle: .tint
                )
            }

            if let highestPoint = SampleChartData.highestPoint {
                PointMark(
                    x: .value(.rateChartAxisDate, highestPoint.date, unit: .day),
                    y: .value(.rateChartAxisRate, highestPoint.rate)
                )
                .symbol {
                    extremeMarker(isShown: shown.contains(.highest), color: .success)
                }
            }

            if let lowestPoint = SampleChartData.lowestPoint {
                PointMark(
                    x: .value(.rateChartAxisDate, lowestPoint.date, unit: .day),
                    y: .value(.rateChartAxisRate, lowestPoint.rate)
                )
                .symbol {
                    extremeMarker(isShown: shown.contains(.lowest), color: .failure)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: SampleChartData.chartYDomain)
        .frame(height: 180)
    }

    private func extremeMarker(isShown: Bool, color: Color) -> some View {
        ZStack {
            RippleEffect(isActive: isShown, color: color)

            ChartPointMarker(color: color, outerSize: 8, innerSize: 7)
        }
        .opacity(isShown ? 1.0 : 0.0)
        .animation(.appToggle, value: isShown)
    }

    private func statCards(showing shown: Set<ChartIndicator>) -> some View {
        VStack(spacing: Spacing.tight) {
            AdaptiveStack(spacing: Spacing.element) {
                StatCard(
                    label: .historyStatisticsHighest,
                    value: (SampleChartData.highestPoint?.rate ?? 0).formatted(.number.precision(.fractionLength(4))),
                    marker: .highest,
                    isToggled: shown.contains(.highest),
                    size: .compact
                ) {
                    toggle(.highest, in: shown)
                }

                StatCard(
                    label: .historyStatisticsLowest,
                    value: (SampleChartData.lowestPoint?.rate ?? 0).formatted(.number.precision(.fractionLength(4))),
                    marker: .lowest,
                    isToggled: shown.contains(.lowest),
                    size: .compact
                ) {
                    toggle(.lowest, in: shown)
                }
            }

            AdaptiveStack(spacing: Spacing.element) {
                StatCard(
                    label: .historyStatisticsAverage,
                    value: SampleChartData.averageRate.formatted(.number.precision(.fractionLength(4))),
                    marker: .average,
                    isToggled: shown.contains(.average),
                    size: .compact
                ) {
                    toggle(.average, in: shown)
                }

                StatCard(
                    label: .historyStatisticsVolatility,
                    value: String(localized: VolatilityLevel.low.displayName),
                    marker: nil,
                    isToggled: false,
                    size: .compact
                ) {}
            }
        }
    }
}

private nonisolated enum ChartIndicator: CaseIterable {
    case average
    case highest
    case lowest
}

private nonisolated enum DemoPhase {
    case cleared
    case average
    case highest
    case lowest

    init(step: Double) {
        switch step {
        case ..<0.5: self = .cleared
        case ..<1.5: self = .average
        case ..<2.5: self = .highest
        default: self = .lowest
        }
    }

    var shownIndicators: Set<ChartIndicator> {
        switch self {
        case .cleared: []
        case .average: [.average]
        case .highest: [.average, .highest]
        case .lowest: [.average, .highest, .lowest]
        }
    }
}

#Preview {
    ChartPreviewSection()
        .padding()
}
