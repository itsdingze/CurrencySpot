//
//  ChartPreviewSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/27/25.
//

import Charts
import SwiftUI

struct ChartPreviewSection: View {
    @State private var showAverage = false
    @State private var showHighest = false
    @State private var showLowest = false
    @State private var animateDemo = false

    var body: some View {
        VStack(spacing: 20) {
            Chart {
                RuleMark(y: .value("Average", SampleChartData.averageRate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.gray.opacity(showAverage ? 0.5 : 0.0))
                    .zIndex(-1)

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

                if let highestPoint = SampleChartData.highestPoint {
                    PointMark(
                        x: .value("Date", highestPoint.date, unit: .day),
                        y: .value("Rate", highestPoint.rate)
                    )
                    .symbol {
                        ZStack {
                            RippleEffect(isActive: showHighest, color: .green)

                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 8, height: 8)

                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                        }
                        .opacity(showHighest ? 1.0 : 0.0)
                        .animation(.smooth(duration: 0.3), value: showHighest)
                    }
                }

                if let lowestPoint = SampleChartData.lowestPoint {
                    PointMark(
                        x: .value("Date", lowestPoint.date, unit: .day),
                        y: .value("Rate", lowestPoint.rate)
                    )
                    .symbol {
                        ZStack {
                            RippleEffect(isActive: showLowest, color: .red)

                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 8, height: 8)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                        }
                        .opacity(showLowest ? 1.0 : 0.0)
                        .animation(.smooth(duration: 0.3), value: showLowest)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: SampleChartData.chartYDomain)
            .frame(height: 180)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MockStatCard(
                        label: "Highest",
                        value: String(format: "%.4f", SampleChartData.highestPoint?.rate ?? 0),
                        isToggled: showHighest,
                        color: .green
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showHighest.toggle()
                        }
                    }

                    MockStatCard(
                        label: "Lowest",
                        value: String(format: "%.4f", SampleChartData.lowestPoint?.rate ?? 0),
                        isToggled: showLowest,
                        color: .red
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showLowest.toggle()
                        }
                    }
                }

                HStack(spacing: 12) {
                    MockStatCard(
                        label: "Average",
                        value: String(format: "%.4f", SampleChartData.averageRate),
                        isToggled: showAverage,
                        color: .gray
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showAverage.toggle()
                        }
                    }

                    MockStatCard(
                        label: "Volatility",
                        value: "Low",
                        isToggled: false,
                        color: nil
                    ) {}
                }
            }
        }
        .padding(.top, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive chart statistics demonstration")
        .accessibilityHint("Watch the chart indicators toggle as statistics are selected")
        .onAppear {
            beginInteractiveChartDemo()
        }
    }

    private func beginInteractiveChartDemo() {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await performDemoAnimationSequence()
        }
    }

    private func performDemoAnimationSequence() async {
        withAnimation(.smooth(duration: 0.5)) {
            animateDemo = true
        }

        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.smooth(duration: 0.3)) {
            showAverage = true
        }

        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.smooth(duration: 0.3)) {
            showHighest = true
        }

        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.smooth(duration: 0.3)) {
            showLowest = true
        }

        try? await Task.sleep(for: .seconds(1.6))
        withAnimation(.smooth(duration: 0.3)) {
            showAverage = false
            showHighest = false
            showLowest = false
            animateDemo = false
        }

        try? await Task.sleep(for: .seconds(1.0))
        await performDemoAnimationSequence()
    }
}

private struct MockStatCard: View {
    let label: String
    let value: String
    let isToggled: Bool
    let color: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let color {
                        Circle()
                            .fill(color.opacity(isToggled ? 1.0 : 0.3))
                            .frame(width: 5, height: 5)
                            .animation(.smooth(duration: 0.3), value: isToggled)
                    }
                }

                Text(value)
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToggled && color != nil ?
                        Color.accentColor.opacity(0.08) :
                        Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(color == nil)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint(color != nil ? (isToggled ? "Tap to hide \(label.lowercased()) indicator on chart" : "Tap to show \(label.lowercased()) indicator on chart") : "")
        .accessibilityAddTraits(color != nil ? .isButton : [])
    }
}

#Preview {
    ChartPreviewSection()
        .padding()
}
