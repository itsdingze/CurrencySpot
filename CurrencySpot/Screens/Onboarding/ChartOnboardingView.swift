import SwiftUI

struct ChartOnboardingView: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentOnboardingPage = 0
    @State private var shouldAnimateTitle = false
    @State private var shouldAnimateContent = false
    @State private var shouldAnimateFooter = false
    @State private var isRevealComplete = false

    private let totalPages = 2

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            contentScrollView
            footerSection
        }
        .safeAreaPadding(.horizontal, Spacing.instructionInset)
        .interactiveDismissDisabled()
        .allowsHitTesting(isRevealComplete || voiceOverEnabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart features onboarding")
        .onChange(of: currentOnboardingPage) {
            AccessibilityNotification.Announcement("Page \(currentOnboardingPage + 1) of \(totalPages)").post()
        }
        .onChange(of: currentOnboardingPage, initial: true) {
            revealPageInStages()
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
                    .transition(pageTransition(from: .leading))
            } else {
                ChartInteractionSection()
                    .transition(pageTransition(from: .trailing))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
        .accessibilityElement(children: .contain)
    }

    private func pageTransition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
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
    }

    private var continueButtonLabel: some View {
        Text(currentOnboardingPage == totalPages - 1 ? "Let's Start!" : "Continue")
            .frame(maxWidth: .infinity)
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
        isRevealComplete = false
    }

    private func revealPageInStages() {
        withAnimation(.appStageReveal(after: 0.55, reduceMotion: reduceMotion)) {
            shouldAnimateTitle = true
        }
        withAnimation(.appStageReveal(after: 0.75, reduceMotion: reduceMotion)) {
            shouldAnimateContent = true
        }
        withAnimation(.appStageReveal(after: 0.95, reduceMotion: reduceMotion)) {
            shouldAnimateFooter = true
        } completion: {
            isRevealComplete = true
        }
    }
}

#if DEBUG
#Preview {
    ChartOnboardingView()
        .environment(CurrencyHistoryViewModel.preview())
}
#endif
