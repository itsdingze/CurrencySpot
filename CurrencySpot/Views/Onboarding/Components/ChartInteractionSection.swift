//
//  ChartInteractionSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/27/25.
//

import Charts
import SwiftUI

struct ChartInteractionSection: View {
    @State private var selectedDate: Date?
    @State private var fingerAnimationState: InteractionState = .idle
    @State private var currentDataPointIndex: Int = 0

    private enum InteractionState {
        case idle
        case appearing
        case touchDown
        case dragging
        case touchUp
        case disappearing
    }

    private var selectedDataPoint: SampleDataPoint? {
        guard let selectedDate else { return nil }
        return SampleChartData.points.min { point1, point2 in
            abs(point1.date.timeIntervalSince(selectedDate)) < abs(point2.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        VStack {
            chartWithInteraction
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart touch interaction demonstration")
        .accessibilityHint("Watch the animated finger showing how to touch and drag on charts to explore data")
        .task {
            try? await Task.sleep(for: .seconds(1.0))
            await simulateFingerInteraction()
        }
    }

    private var chartWithInteraction: some View {
        GeometryReader { geometry in
            Chart {
                ForEach(SampleChartData.points) { dataPoint in
                    AreaMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        yStart: .value("Rate", dataPoint.rate),
                        yEnd: .value("Rate", SampleChartData.minimumRate * 0.99)
                    )
                    .interpolationMethod(.cardinal(tension: 0.8))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.15),
                                     Color.accentColor.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", dataPoint.date, unit: .day),
                        y: .value("Rate", dataPoint.rate)
                    )
                    .interpolationMethod(.cardinal(tension: 0.8))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.accentColor)
                }

                if let selectedDataPoint {
                    RuleMark(x: .value("Date", selectedDataPoint.date, unit: .day))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .zIndex(-1)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack {
                                Text(selectedDataPoint.date.chartDisplay)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)

                                Text(selectedDataPoint.rate.toStringMax4Decimals)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .fontDesign(.rounded)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.2)))
                        }

                    PointMark(
                        x: .value("Date", selectedDataPoint.date, unit: .day),
                        y: .value("Rate", selectedDataPoint.rate)
                    )
                    .symbol {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 14, height: 14)

                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: SampleChartData.chartYDomain)
            .overlay(
                animatedFingerOverlay(in: geometry)
                    .allowsHitTesting(false)
            )
        }
        .frame(height: 180)
        .padding(.top, 80)
    }

    @ViewBuilder
    private func animatedFingerOverlay(in geometry: GeometryProxy) -> some View {
        if fingerAnimationState != .idle {
            let position = computeFingerPositionForDataPoint(currentDataPointIndex, in: geometry)

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
                .position(position)
                .opacity(fingerOpacity)
                .scaleEffect(fingerScale)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
        }
    }

    private var fingerOpacity: Double {
        switch fingerAnimationState {
        case .idle, .disappearing: 0
        case .appearing, .touchUp: 0.5
        case .touchDown, .dragging: 1
        }
    }

    private var fingerScale: Double {
        switch fingerAnimationState {
        case .touchDown, .dragging: 0.95
        default: 1.1
        }
    }

    private func computeFingerPositionForDataPoint(_ dataPointIndex: Int, in geometry: GeometryProxy) -> CGPoint {
        let chartStartingXPosition = geometry.size.width * 0.11
        let dataPointSpacing = geometry.size.width * 0.15
        let xPosition = chartStartingXPosition + (CGFloat(dataPointIndex) * dataPointSpacing)
        let yPosition = geometry.size.height

        return CGPoint(x: xPosition, y: yPosition)
    }

    private func simulateFingerInteraction() async {
        currentDataPointIndex = 1

        withAnimation(.snappy) {
            fingerAnimationState = .appearing
        }

        try? await Task.sleep(for: .seconds(0.5))

        withAnimation(.snappy) {
            fingerAnimationState = .touchDown
            selectedDate = SampleChartData.points[currentDataPointIndex].date
        }

        try? await Task.sleep(for: .seconds(0.5))

        withAnimation(.snappy) {
            fingerAnimationState = .dragging
        }

        let targetIndex = 5
        let steps = 8
        let stepDuration: TimeInterval = 2.0 / Double(steps)

        for step in 1 ... steps {
            let progress = Double(step) / Double(steps)
            let interpolatedIndex = interpolateIndex(from: 1, to: targetIndex, progress: progress)

            withAnimation(.linear(duration: stepDuration)) {
                currentDataPointIndex = interpolatedIndex
                if interpolatedIndex < SampleChartData.points.count {
                    selectedDate = SampleChartData.points[interpolatedIndex].date
                }
            }

            try? await Task.sleep(for: .seconds(stepDuration))
        }

        try? await Task.sleep(for: .seconds(0.5))

        withAnimation(.snappy) {
            fingerAnimationState = .touchUp
            selectedDate = nil
        }

        try? await Task.sleep(for: .seconds(0.5))

        withAnimation(.snappy) {
            fingerAnimationState = .disappearing
        }

        try? await Task.sleep(for: .seconds(0.3))

        fingerAnimationState = .idle

        try? await Task.sleep(for: .seconds(1.0))

        await simulateFingerInteraction()
    }

    private func interpolateIndex(from start: Int, to end: Int, progress: Double) -> Int {
        let clampedProgress = max(0, min(1, progress))
        let interpolatedValue = Double(start) + (Double(end - start) * clampedProgress)
        return min(SampleChartData.points.count - 1, Int(round(interpolatedValue)))
    }
}

#Preview {
    ChartInteractionSection()
        .padding()
}
