//
//  ChartOnboardingView.backup.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/23/25.
//  Original GeometryReader implementation
//

import SwiftUI

struct ChartOnboardingViewBackup: View {
    @Binding var showOnboarding: Bool
    @Environment(SettingsViewModel.self) private var settingsViewModel

    var body: some View {
        AppOnboardingView(
            title: "Interactive Chart Features"
        ) {
            // Top half displaying chart preview
            ChartPreviewSectionBackup()
        } cards: {
            OnBoardingCard(
                symbol: "hand.tap",
                title: "Toggle Chart Elements",
                subTitle: "Tap on statistics to show or hide chart indicators."
            )

            OnBoardingCard(
                symbol: "chart.line.uptrend.xyaxis",
                title: "View Average Line",
                subTitle: "Tap 'Average' to display the average rate line on the chart."
            )
        } footer: {
            Text("These interactive features help you analyze trends more effectively.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
        } onContinue: {
            withAnimation {
                settingsViewModel.hasSeenChartOnboarding = true
                showOnboarding = false
            }
        }
    }
}

// MARK: - Chart Preview Section (GeometryReader Approach)

private struct ChartPreviewSectionBackup: View {
    @State private var showAverage = false
    @State private var showHighest = false
    @State private var showLowest = false
    @State private var animateDemo = false

    var body: some View {
        VStack(spacing: 20) {
            // Simulated chart area with GeometryReader
            ZStack {
                // Background chart mockup
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 160)
                    .overlay(
                        VStack {
                            // Simulated chart line using GeometryReader
                            GeometryReader { geometry in
                                Path { path in
                                    let width = geometry.size.width
                                    let height = geometry.size.height

                                    // Create a wavy line representing currency fluctuations
                                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                                    path.addCurve(
                                        to: CGPoint(x: width * 0.3, y: height * 0.3),
                                        control1: CGPoint(x: width * 0.1, y: height * 0.6),
                                        control2: CGPoint(x: width * 0.2, y: height * 0.2)
                                    )
                                    path.addCurve(
                                        to: CGPoint(x: width * 0.6, y: height * 0.8),
                                        control1: CGPoint(x: width * 0.4, y: height * 0.4),
                                        control2: CGPoint(x: width * 0.5, y: height * 0.9)
                                    )
                                    path.addCurve(
                                        to: CGPoint(x: width, y: height * 0.5),
                                        control1: CGPoint(x: width * 0.7, y: height * 0.7),
                                        control2: CGPoint(x: width * 0.9, y: height * 0.4)
                                    )
                                }
                                .stroke(Color.accentColor, lineWidth: 2)

                                // Average line
                                if showAverage {
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.55))
                                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.55))
                                    }
                                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                    .transition(.opacity)
                                }

                                // Highest point
                                if showHighest {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3)
                                        .transition(.scale.combined(with: .opacity))
                                }

                                // Lowest point
                                if showLowest {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .position(x: geometry.size.width * 0.6, y: geometry.size.height * 0.8)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding()
                        }
                    )
            }

            // Simulated statistics section
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MockStatCardBackup(
                        label: "Highest",
                        value: "1.2345",
                        isToggled: showHighest,
                        color: .green
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showHighest.toggle()
                        }
                    }

                    MockStatCardBackup(
                        label: "Lowest",
                        value: "1.0987",
                        isToggled: showLowest,
                        color: .red
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showLowest.toggle()
                        }
                    }
                }

                HStack(spacing: 12) {
                    MockStatCardBackup(
                        label: "Average",
                        value: "1.1666",
                        isToggled: showAverage,
                        color: .gray
                    ) {
                        withAnimation(.smooth(duration: 0.3)) {
                            showAverage.toggle()
                        }
                    }

                    MockStatCardBackup(
                        label: "Volatility",
                        value: "Low",
                        isToggled: false,
                        color: nil
                    ) {
                        // Volatility is not interactive in demo
                    }
                }
            }

            // Hint text
            if !animateDemo {
                Text("Try tapping the statistics below!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.top, 20)
        .onAppear {
            // Start a demo animation after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                startDemoAnimation()
            }
        }
    }

    private func startDemoAnimation() {
        withAnimation(.smooth(duration: 0.5)) {
            animateDemo = true
        }

        // Animate through the toggles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.smooth(duration: 0.3)) {
                showAverage = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.smooth(duration: 0.3)) {
                showHighest = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.smooth(duration: 0.3)) {
                showLowest = true
            }
        }

        // Reset after showing all
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.smooth(duration: 0.3)) {
                showAverage = false
                showHighest = false
                showLowest = false
                animateDemo = false
            }

            // Restart the cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startDemoAnimation()
            }
        }
    }
}

// MARK: - Mock Stat Card (Backup Version)

private struct MockStatCardBackup: View {
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
    }
}

#Preview {
    @Previewable @State var showOnboarding = true
    let container = DependencyContainer.preview()

    ChartOnboardingViewBackup(showOnboarding: $showOnboarding)
        .withDependencyContainer(container)
}
