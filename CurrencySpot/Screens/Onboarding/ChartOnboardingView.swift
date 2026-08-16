import SwiftUI

struct ChartOnboardingView: View {
    @Environment(HistoryViewModel.self) private var viewModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var currentOnboardingPage = 0
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
        .safeAreaPadding(.horizontal, Spacing.instructionInset)
        .interactiveDismissDisabled()
        .allowsHitTesting(shouldAnimateFooter || voiceOverEnabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart features onboarding")
        .onChange(of: currentOnboardingPage) {
            AccessibilityNotification.Announcement("Page \(currentOnboardingPage + 1) of \(totalPages)").post()
        }
        .task(id: currentOnboardingPage) {
            await runStagedAnimations()
        }
    }

    // MARK: - View Components

    private var navigationHeader: some View {
        NavigationHeader(
            currentPage: $currentOnboardingPage,
            totalPages: totalPages,
            onBack: {
                withAnimation(.appSelect) {
                    resetAnimations()
                    currentOnboardingPage = max(0, currentOnboardingPage - 1)
                }
            },
            onSkip: {
                withAnimation {
                    viewModel.completeChartOnboarding()
                }
            }
        )
    }

    private var contentScrollView: some View {
        ScrollView(.vertical) {
            VStack(alignment: .center, spacing: Spacing.onboarding) {
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
        .frame(minHeight: 320)
        .accessibilityElement(children: .contain)
    }

    private var titleSection: some View {
        Group {
            if currentOnboardingPage == 0 {
                Text("Interactive Chart")
                    .font(.appTitle)
                    .multilineTextAlignment(.center)
                    .blurSlide(shouldAnimateTitle)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text("Explore Data Points")
                    .font(.appTitle)
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
        VStack(alignment: .leading, spacing: Spacing.onboarding) {
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
        VStack(alignment: .leading, spacing: Spacing.onboarding) {
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
            .padding(.top, Spacing.block)
    }

    private var continueButton: some View {
        Button(action: handleContinueAction) {
            continueButtonLabel
        }
        .buttonStyle(.primaryAction)
        .padding(.bottom, Spacing.tight)
        .blurSlide(shouldAnimateFooter)
        .accessibilityLabel(continueAccessibilityLabel)
    }

    private var continueButtonLabel: some View {
        Text(currentOnboardingPage == totalPages - 1 ? "Let's Start!" : "Continue")
            .frame(maxWidth: .infinity)
    }

    private var continueAccessibilityLabel: String {
        currentOnboardingPage == totalPages - 1 ? "Finish onboarding" : "Continue to next page"
    }

    private func handleContinueAction() {
        if currentOnboardingPage < totalPages - 1 {
            withAnimation(.appStageReveal) {
                resetAnimations()
                currentOnboardingPage += 1
            }
        } else {
            withAnimation {
                viewModel.completeChartOnboarding()
            }
        }
    }

    private func resetAnimations() {
        shouldAnimateTitle = false
        shouldAnimateContent = false
        shouldAnimateFooter = false
    }

    private func runStagedAnimations() async {
        await delayedAnimation(0.55) {
            shouldAnimateTitle = true
        }
        guard !Task.isCancelled else { return }

        await delayedAnimation(0.2) {
            shouldAnimateContent = true
        }
        guard !Task.isCancelled else { return }

        await delayedAnimation(0.2) {
            shouldAnimateFooter = true
        }
    }

}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    ChartOnboardingView()
        .withDependencyContainer(container)
}
#endif
