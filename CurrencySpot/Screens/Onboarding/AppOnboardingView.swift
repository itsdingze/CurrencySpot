//
//  AppOnboardingView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/8/25.
//

import SwiftUI

struct OnBoardingCard: Identifiable {
    var symbol: String
    var title: String
    var subTitle: String

    /// Stable across rebuilds (a stored UUID would change identity every init).
    var id: String { "\(symbol)-\(title)" }
}

struct AppOnboardingView<Icon: View, Footer: View>: View {
    var title: String
    var icon: Icon
    var cards: [OnBoardingCard]
    var footer: Footer
    var buttonTitle: String
    var onContinue: () -> Void

    init(
        title: String,
        buttonTitle: String = "Continue",
        @ViewBuilder icon: @escaping () -> Icon,
        cards: [OnBoardingCard],
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
                VStack(alignment: .center, spacing: .onboardingGap) {
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
                .padding(.bottom, .tightGap)
                .accessibilityLabel("Continue to app")
            }
            .blurSlide(animateFooter)
        }
        .safeAreaPadding(.horizontal, .onboardingInset)
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
        VStack(alignment: .leading, spacing: .onboardingGap) {
            ForEach(cards) { card in
                FeatureRow(symbol: card.symbol, title: card.title, subtitle: card.subTitle)
                    .blurSlide(animatedCardIDs.contains(card.id))
            }
        }
    }
}

extension View {
    @ViewBuilder
    func blurSlide(_ show: Bool) -> some View {
        compositingGroup()
            .blur(radius: show ? 0 : 10)
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 100)
    }
}

struct CurrencySpotOnboarding: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel

    var body: some View {
        AppOnboardingView(
            title: "Welcome to CurrencySpot",
            icon: {
                Image("Icon")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                    }
                    .padding(.top, .onboardingGap)
                    .accessibilityHidden(true)
            },
            cards: [
                OnBoardingCard(
                    symbol: "dollarsign.arrow.circlepath",
                    title: "Real-time Exchange Rates",
                    subTitle: "Convert between currencies using the latest exchange rates."
                ),
                OnBoardingCard(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Historical Tracking",
                    subTitle: "Visualize currency performance with interactive charts."
                ),
                OnBoardingCard(
                    symbol: "wifi.slash",
                    title: "Offline Support",
                    subTitle: "Continue converting with cached rates when offline."
                ),
            ],
            footer: {
                Text("Exchange rates are aggregated from central banks worldwide.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, .blockGap)
            },
            onContinue: settingsViewModel.dismissOnboarding
        )
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CurrencySpotOnboarding()
        .withDependencyContainer(container)
}
#endif
