//
//  ChartOnboardingView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/23/25.
//

import SwiftUI

struct ChartOnboardingView: View {
    @Binding var showOnboarding: Bool
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @State private var currentOnboardingPage = 0
    @State private var shouldAnimateChartIcon = false
    @State private var shouldAnimateTitle = false
    @State private var shouldAnimateContent = false
    @State private var shouldAnimateFooter = false

    private let totalPages = 2

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            contentScrollView
            footerSection
        }
        .safeAreaPadding(.horizontal, 36)
        .interactiveDismissDisabled()
        .allowsHitTesting(shouldAnimateFooter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart features onboarding")
        .task {
            startAnimations()
        }
    }

    // MARK: - View Components

    private var navigationHeader: some View {
        NavigationHeader(
            currentPage: $currentOnboardingPage,
            totalPages: totalPages,
            onBack: {
                withAnimation(.snappy) {
                    resetAnimations()
                    currentOnboardingPage = max(0, currentOnboardingPage - 1)
                }
                startAnimations()
            },
            onSkip: {
                withAnimation {
                    settingsViewModel.hasSeenChartOnboarding = true
                    showOnboarding = false
                }
            }
        )
    }

    private var contentScrollView: some View {
        ScrollView(.vertical) {
            VStack(alignment: .center, spacing: 40) {
                chartSection
                titleSection
                featuresSection
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var chartSection: some View {
        Group {
            if currentOnboardingPage == 0 {
                ChartPreviewSection()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                ChartInteractionSection()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(currentOnboardingPage == 0 ? "Interactive chart demonstration" : "Chart touch interaction demonstration")
        .accessibilityHint(currentOnboardingPage == 0 ? "Shows how statistics can toggle chart indicators" : "Demonstrates how to touch and drag on charts to explore data points")
    }

    private var titleSection: some View {
        Group {
            if currentOnboardingPage == 0 {
                Text("Interactive Chart")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .blurSlide(shouldAnimateTitle)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text("Explore Data Points")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .blurSlide(shouldAnimateTitle)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var featuresSection: some View {
        Group {
            if currentOnboardingPage == 0 {
                firstPageFeatures
                    .blurSlide(shouldAnimateContent)
            } else {
                secondPageFeatures
                    .blurSlide(shouldAnimateContent)
            }
        }
    }

    private var firstPageFeatures: some View {
        VStack(alignment: .leading, spacing: 40) {
            FeatureRow(
                symbol: "hand.tap",
                title: "Toggle Chart Elements",
                subtitle: "Tap on statistics to show or hide chart indicators."
            )

            FeatureRow(
                symbol: "chart.line.flattrend.xyaxis",
                title: "View Average Line",
                subtitle: "Tap 'Average' to display the average rate line on the chart."
            )
        }
    }

    private var secondPageFeatures: some View {
        VStack(alignment: .leading, spacing: 40) {
            FeatureRow(
                symbol: "hand.point.up.left",
                title: "Touch to Select",
                subtitle: "Touch and hold on the chart to see detailed information for any date."
            )

            FeatureRow(
                symbol: "arrow.left.and.right",
                title: "Drag to Explore",
                subtitle: "Move your finger across the chart to explore different data points."
            )
        }
    }

    private var footerSection: some View {
        continueButton
            .padding(.top, 24)
    }

    private var continueButton: some View {
        Button(action: handleContinueAction) {
            continueButtonLabel
        }
        .tint(Color.accentColor)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .padding(.bottom, 10)
        .blurSlide(shouldAnimateFooter)
        .accessibilityLabel(continueAccessibilityLabel)
        .accessibilityHint(continueAccessibilityHint)
        .accessibilityInputLabels(continueAccessibilityInputLabels)
    }

    private var continueButtonLabel: some View {
        Text(currentOnboardingPage == totalPages - 1 ? "Let's Start!" : "Continue")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var continueAccessibilityLabel: String {
        currentOnboardingPage == totalPages - 1 ? "Finish onboarding" : "Continue to next page"
    }

    private var continueAccessibilityHint: String {
        currentOnboardingPage == totalPages - 1 ? "Finishes chart onboarding and returns to main app" : "Continues to the next onboarding page"
    }

    private var continueAccessibilityInputLabels: [String] {
        currentOnboardingPage == totalPages - 1 ? ["Finish", "Done", "Let's start", "Complete"] : ["Continue", "Next"]
    }

    private func handleContinueAction() {
        if currentOnboardingPage < totalPages - 1 {
            withAnimation(.smooth) {
                resetAnimations()
                currentOnboardingPage += 1
            }
            startAnimations()
        } else {
            withAnimation {
                settingsViewModel.hasSeenChartOnboarding = true
                showOnboarding = false
            }
        }
    }

    private func resetAnimations() {
        shouldAnimateChartIcon = false
        shouldAnimateTitle = false
        shouldAnimateContent = false
        shouldAnimateFooter = false
    }

    private func startAnimations() {
        Task {
            await executeAnimationAfterDelay(0.35) {
                shouldAnimateChartIcon = true
            }

            await executeAnimationAfterDelay(0.2) {
                shouldAnimateTitle = true
            }

            await executeAnimationAfterDelay(0.2) {
                shouldAnimateContent = true
            }

            await executeAnimationAfterDelay(0.2) {
                shouldAnimateFooter = true
            }
        }
    }

    private func executeAnimationAfterDelay(_ delay: Double, action: @escaping () -> Void) async {
        guard delay > 0 else {
            withAnimation(.smooth) { action() }
            return
        }

        try? await Task.sleep(for: .seconds(delay))
        withAnimation(.smooth) {
            action()
        }
    }
}

#Preview {
    @Previewable @State var showOnboarding = true
    let container = DependencyContainer.preview()

    ChartOnboardingView(showOnboarding: $showOnboarding)
        .withDependencyContainer(container)
}
