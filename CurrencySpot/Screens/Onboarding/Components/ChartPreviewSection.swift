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

    var body: some View {
        VStack(spacing: .blockGap) {
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
                            RippleEffect(isActive: showHighest, color: .success)

                            ChartPointMarker(color: .success, outerSize: 8, innerSize: 7)
                        }
                        .opacity(showHighest ? 1.0 : 0.0)
                        .animation(.appToggle, value: showHighest)
                    }
                }

                if let lowestPoint = SampleChartData.lowestPoint {
                    PointMark(
                        x: .value("Date", lowestPoint.date, unit: .day),
                        y: .value("Rate", lowestPoint.rate)
                    )
                    .symbol {
                        ZStack {
                            RippleEffect(isActive: showLowest, color: .failure)

                            ChartPointMarker(color: .failure, outerSize: 8, innerSize: 7)
                        }
                        .opacity(showLowest ? 1.0 : 0.0)
                        .animation(.appToggle, value: showLowest)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: SampleChartData.chartYDomain)
            .frame(height: 180)

            VStack(spacing: .tightGap) {
                HStack(spacing: .elementGap) {
                    MockStatCard(
                        label: "Highest",
                        value: String(format: "%.4f", SampleChartData.highestPoint?.rate ?? 0),
                        isToggled: showHighest,
                        color: .success
                    ) {
                        withAnimation(.appToggle) {
                            showHighest.toggle()
                        }
                    }

                    MockStatCard(
                        label: "Lowest",
                        value: String(format: "%.4f", SampleChartData.lowestPoint?.rate ?? 0),
                        isToggled: showLowest,
                        color: .failure
                    ) {
                        withAnimation(.appToggle) {
                            showLowest.toggle()
                        }
                    }
                }

                HStack(spacing: .elementGap) {
                    MockStatCard(
                        label: "Average",
                        value: String(format: "%.4f", SampleChartData.averageRate),
                        isToggled: showAverage,
                        color: .gray
                    ) {
                        withAnimation(.appToggle) {
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
        .padding(.top, .blockGap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive chart statistics demonstration")
        .accessibilityHint("Watch the chart indicators toggle as statistics are selected")
        .task {
            await runInteractiveChartDemo()
        }
    }

    private func runInteractiveChartDemo() async {
        do { try await Task.sleep(for: .seconds(1.5)) } catch { return }

        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(0.5)) } catch { return }
            withAnimation(.appToggle) {
                showAverage = true
            }

            do { try await Task.sleep(for: .seconds(0.7)) } catch { return }
            withAnimation(.appToggle) {
                showHighest = true
            }

            do { try await Task.sleep(for: .seconds(0.7)) } catch { return }
            withAnimation(.appToggle) {
                showLowest = true
            }

            do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
            withAnimation(.appToggle) {
                showAverage = false
                showHighest = false
                showLowest = false
            }

            do { try await Task.sleep(for: .seconds(1.0)) } catch { return }
        }
    }
}

private struct MockStatCard: View {
    let label: String
    let value: String
    let isToggled: Bool
    let color: Color?
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        let card = Button(action: action) {
            VStack(alignment: .leading, spacing: .hairlineGap) {
                HStack(spacing: .hairlineGap) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let color {
                        Circle()
                            .fill(color.opacity(isToggled ? 1.0 : 0.3))
                            .frame(width: 5, height: 5)
                            .animation(.appToggle, value: isToggled)
                    }
                }

                Text(value)
                    .font(.appFootnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.chipPadding)
            .background(
                RoundedRectangle(cornerRadius: .badgeRadius)
                    .fill(isToggled && color != nil ?
                        Color.accentColor.opacity(0.08) :
                        Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(color == nil)
        .accessibilityLabel("\(label): \(value)")

        if color != nil {
            card.accessibilityHint(isToggled ? "Tap to hide \(label.lowercased()) indicator on chart" : "Tap to show \(label.lowercased()) indicator on chart")
        } else {
            card
        }
    }
}

#Preview {
    ChartPreviewSection()
        .padding()
}
