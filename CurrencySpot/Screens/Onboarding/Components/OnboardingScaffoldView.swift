import SwiftUI

struct OnboardingScaffoldView<Icon: View, Footer: View>: View {
    private let title: String
    private let icon: Icon
    private let cards: [OnboardingCard]
    private let footer: Footer
    private let buttonTitle: String
    private let onContinue: () -> Void

    init(
        title: String,
        buttonTitle: String = "Continue",
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

    @State private var animateIcon: Bool = false
    @State private var animateTitle: Bool = false
    @State private var animatedCardIDs: Set<String> = []
    @State private var animateFooter: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: Spacing.onboarding) {
                    icon
                        .frame(maxWidth: .infinity)
                        .blurSlide(animateIcon)

                    Text(title)
                        .font(.appTitle)
                        .multilineTextAlignment(.center)
                        .blurSlide(animateTitle)
                        .accessibilityAddTraits(.isHeader)

                    cardsView
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 0) {
                footer

                Button(action: onContinue) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .padding(.bottom, Spacing.tight)
                .accessibilityLabel("Continue to app")
            }
            .blurSlide(animateFooter)
        }
        .safeAreaPadding(.horizontal, Spacing.instructionInset)
        .interactiveDismissDisabled()
        .allowsHitTesting(animateFooter || voiceOverEnabled)
        .accessibilityElement(children: .contain)
        .task {
            guard !animateIcon else { return }

            await delayedAnimation(0.35) {
                animateIcon = true
            }

            guard !Task.isCancelled else { return }

            await delayedAnimation(0.2) {
                animateTitle = true
            }
            guard !Task.isCancelled else { return }

            do { try await Task.sleep(for: .seconds(0.2)) } catch { return }

            for (index, card) in cards.enumerated() {
                let delay = Double(index) * 0.1
                await delayedAnimation(delay) {
                    animatedCardIDs.insert(card.id)
                }
                guard !Task.isCancelled else { return }
            }

            await delayedAnimation(0.2) {
                animateFooter = true
            }
        }
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
        title: "Welcome",
        icon: {
            Image(systemName: "sparkles")
                .font(.appTitle)
        },
        cards: [
            OnboardingCard(
                symbol: "dollarsign.arrow.circlepath",
                title: "Real-time Exchange Rates",
                subTitle: "Convert between currencies using the latest exchange rates."
            ),
        ],
        footer: {
            Text("Footer copy")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .padding(.vertical, Spacing.block)
        },
        onContinue: {}
    )
}
#endif
