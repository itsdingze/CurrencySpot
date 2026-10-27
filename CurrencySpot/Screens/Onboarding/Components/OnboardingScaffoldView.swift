import SwiftUI

struct OnboardingScaffoldView<Icon: View, Footer: View>: View {
    private let title: LocalizedStringResource
    private let icon: Icon
    private let cards: [OnboardingCard]
    private let footer: Footer
    private let buttonTitle: LocalizedStringResource
    private let onContinue: () -> Void

    init(
        title: LocalizedStringResource,
        buttonTitle: LocalizedStringResource = .onboardingWelcomeContinue,
        @ViewBuilder icon: @escaping () -> Icon,
        cards: [OnboardingCard],
        @ViewBuilder footer: @escaping () -> Footer,
        onContinue: @escaping () -> Void
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.icon = icon()
        self.cards = cards
        self.footer = footer()
        self.onContinue = onContinue
    }

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var animateIcon: Bool = false
    @State private var animateTitle: Bool = false
    @State private var animatedCardIDs: Set<String> = []
    @State private var animateFooter: Bool = false
    @State private var isRevealComplete = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .center, spacing: Spacing.onboarding) {
                icon
                    .frame(maxWidth: .infinity)
                    .blurSlide(animateIcon)

                Text(title)
                    .font(.appTitle)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .blurSlide(animateTitle)
                    .accessibilityAddTraits(.isHeader)

                cardsView

                if isFooterScrolling {
                    footer
                        .blurSlide(animateFooter)
                }
            }
        }
        .adaptiveBottomBar { bottomBar }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.horizontal, Spacing.instructionInset)
        .interactiveDismissDisabled()
        .allowsHitTesting(isRevealComplete || voiceOverEnabled)
        .accessibilityElement(children: .contain)
        .onAppear(perform: revealInStages)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if !isFooterScrolling {
                footer
            }

            Button(action: onContinue) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primaryAction)
            .padding(.bottom, Spacing.tight)
        }
        .blurSlide(animateFooter)
        .background {
            if !isFooterScrolling {
                footerBackdrop
            }
        }
    }

    private var footerBackdrop: some View {
        Rectangle()
            .fill(BackgroundStyle())
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: Spacing.block)
                    Rectangle()
                }
            }
            .ignoresSafeArea(edges: [.horizontal, .bottom])
    }

    private var isFooterScrolling: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private func revealInStages() {
        guard !animateIcon else { return }

        reveal(after: 0.35) { animateIcon = true }
        reveal(after: 0.55) { animateTitle = true }

        var cardDelay = 0.75
        for (index, card) in cards.enumerated() {
            cardDelay += Double(index) * 0.1
            reveal(after: cardDelay) { animatedCardIDs.insert(card.id) }
        }

        withAnimation(.appStageReveal(after: cardDelay + 0.2, reduceMotion: reduceMotion)) {
            animateFooter = true
        } completion: {
            isRevealComplete = true
        }
    }

    private func reveal(after delay: TimeInterval, _ change: () -> Void) {
        withAnimation(.appStageReveal(after: delay, reduceMotion: reduceMotion), change)
    }

    private var cardsView: some View {
        VStack(alignment: .leading, spacing: Spacing.onboarding) {
            ForEach(cards) { card in
                FeatureRow(symbol: card.symbol, title: card.title, subtitle: card.subTitle)
                    .blurSlide(animatedCardIDs.contains(card.id))
            }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingScaffoldView(
        title: .onboardingWelcomeTitle,
        icon: {
            Image(systemName: "sparkles")
                .font(.appTitle)
        },
        cards: [
            OnboardingCard(
                symbol: "dollarsign.arrow.circlepath",
                title: .onboardingWelcomeRatesTitle,
                subTitle: .onboardingWelcomeRatesSubtitle
            ),
        ],
        footer: {
            Text(.onboardingWelcomeFooter)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .padding(.vertical, Spacing.block)
        },
        onContinue: {}
    )
}
#endif
