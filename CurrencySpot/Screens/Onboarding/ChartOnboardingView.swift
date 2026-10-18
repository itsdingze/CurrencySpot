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
    @State private var scrollPosition = ScrollPosition(edge: .top)

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
        .accessibilityLabel(.onboardingChartAccessibilityLabel)
        .onChange(of: currentOnboardingPage) {
            let announcement = LocalizedStringResource.onboardingChartPageAnnouncement(
                page: currentOnboardingPage + 1,
                total: totalPages
            )
            AccessibilityNotification.Announcement(String(localized: announcement)).post()
        }
        .onChange(of: currentOnboardingPage, initial: true) {
            presentCurrentPage()
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
        .scrollPosition($scrollPosition)
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
                Text(.onboardingChartPreviewTitle)
                    .font(.appTitle)
                    .multilineTextAlignment(.center)
                    .blurSlide(shouldAnimateTitle)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text(.onboardingChartInteractionTitle)
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
                title: .onboardingChartToggleTitle,
                subtitle: .onboardingChartToggleSubtitle
            )

            FeatureRow(
                symbol: "chart.line.flattrend.xyaxis",
                title: .onboardingChartAverageTitle,
                subtitle: .onboardingChartAverageSubtitle
            )
        }
    }

    private var secondPageFeatures: some View {
        VStack(alignment: .leading, spacing: Spacing.onboarding) {
            FeatureRow(
                symbol: "hand.point.up.left",
                title: .onboardingChartSelectTitle,
                subtitle: .onboardingChartSelectSubtitle
            )

            FeatureRow(
                symbol: "arrow.left.and.right",
                title: .onboardingChartDragTitle,
                subtitle: .onboardingChartDragSubtitle
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
        Text(currentOnboardingPage == totalPages - 1 ? LocalizedStringResource.onboardingChartStart : .onboardingChartContinue)
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

    private func presentCurrentPage() {
        scrollPosition.scrollTo(edge: .top)
        revealPageInStages()
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
