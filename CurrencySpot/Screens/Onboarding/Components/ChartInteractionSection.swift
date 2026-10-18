import Charts
import SwiftUI

struct ChartInteractionSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @Environment(\.appAccent) private var accent

    private static let hiddenFinger = FingerDemoFrame(progress: 1, opacity: 0, touch: 0)
    private static let heldFinger = FingerDemoFrame(progress: 3, opacity: 1, touch: 1)

    var body: some View {
        VStack {
            demo
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.onboardingChartInteractionAccessibilityLabel)
        .accessibilityHint(interactionHint)
    }

    private var interactionHint: LocalizedStringResource {
        reduceMotion
            ? .onboardingChartInteractionStaticHint
            : .onboardingChartInteractionAnimatedHint
    }

    @ViewBuilder
    private var demo: some View {
        if reduceMotion {
            chart(at: Self.heldFinger)
        } else {
            KeyframeAnimator(initialValue: Self.hiddenFinger, repeating: true) { finger in
                chart(at: finger)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 1.0)
                    CubicKeyframe(0.5, duration: 0.3)
                    LinearKeyframe(0.5, duration: 0.5)
                    CubicKeyframe(1, duration: 0.2)
                    LinearKeyframe(1, duration: 3.0)
                    CubicKeyframe(0.5, duration: 0.2)
                    LinearKeyframe(0.5, duration: 0.5)
                    CubicKeyframe(0, duration: 0.3)
                }
                KeyframeTrack(\.touch) {
                    LinearKeyframe(0, duration: 1.8)
                    CubicKeyframe(1, duration: 0.2)
                    LinearKeyframe(1, duration: 3.0)
                    CubicKeyframe(0, duration: 0.2)
                    LinearKeyframe(0, duration: 0.8)
                }
                KeyframeTrack(\.progress) {
                    LinearKeyframe(1, duration: 2.5)
                    CubicKeyframe(5, duration: 2.0)
                    LinearKeyframe(5, duration: 1.5)
                }
            }
        }
    }

    private func chart(at finger: FingerDemoFrame) -> some View {
        let selectedDataPoint = finger.selectedIndex(pointCount: SampleChartData.points.count)
            .map { SampleChartData.points[$0] }

        return Chart {
            ForEach(SampleChartData.points) { dataPoint in
                RateAreaLineMarks(
                    date: dataPoint.date,
                    rate: dataPoint.rate,
                    lowestRate: SampleChartData.minimumRate,
                    areaColor: accent,
                    lineStyle: .tint
                )
            }

            if let selectedDataPoint {
                RuleMark(x: .value(.rateChartAxisDate, selectedDataPoint.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .zIndex(-1)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack {
                            Text(selectedDataPoint.date.chartDisplay)

                            Text(selectedDataPoint.rate.toStringMax4Decimals)
                        }
                        .font(.appSubheadline)
                        .foregroundStyle(.tint)
                        .padding(Spacing.chipPadding)
                        .background(.selectionFill(on: accent), in: .rect(cornerRadius: Radius.badge))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }

                PointMark(
                    x: .value(.rateChartAxisDate, selectedDataPoint.date, unit: .day),
                    y: .value(.rateChartAxisRate, selectedDataPoint.rate)
                )
                .symbol {
                    ChartPointMarker(color: .tint, outerSize: 14, innerSize: 10)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: SampleChartData.chartYDomain)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plot = geometry[plotFrame]
                    if let fingertip = finger.fingertip(alongX: pointXPositions(proxy: proxy, plotMinX: plot.minX), atHeight: plot.midY) {
                        fingerGlyph(finger)
                            .position(fingertip)
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 180)
        .padding(.top, 80)
    }

    private func fingerGlyph(_ finger: FingerDemoFrame) -> some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.title)
            .foregroundStyle(.tint)
            .scaleEffect(finger.scale, anchor: .topLeading)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
            .opacity(finger.opacity)
            .frame(width: 0, height: 0, alignment: .topLeading)
    }

    private func pointXPositions(proxy: ChartProxy, plotMinX: CGFloat) -> [CGFloat] {
        var positions: [CGFloat] = []
        for point in SampleChartData.points {
            guard let day = calendar.dateInterval(of: .day, for: point.date),
                  let x = proxy.position(forX: day.start.addingTimeInterval(day.duration / 2))
            else { return [] }
            positions.append(plotMinX + x)
        }
        return positions
    }
}

#Preview {
    ChartInteractionSection()
        .padding()
}
