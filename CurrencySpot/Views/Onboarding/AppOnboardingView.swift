//
//  AppOnboardingView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/8/25.
//

import SwiftUI

struct OnBoardingCard: Identifiable {
    var id: String = UUID().uuidString
    var symbol: String
    var title: String
    var subTitle: String
}

@resultBuilder
struct OnBoardingCardResultBuilder {
    static func buildBlock(_ components: OnBoardingCard...) -> [OnBoardingCard] {
        components.compactMap(\.self)
    }
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
        @OnBoardingCardResultBuilder cards: @escaping () -> [OnBoardingCard],
        @ViewBuilder footer: @escaping () -> Footer,
        onContinue: @escaping () -> Void
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.icon = icon()
        self.cards = cards()
        self.footer = footer()
        self.onContinue = onContinue

        _animateCards = .init(initialValue: Array(repeating: false, count: self.cards.count))
    }

    @State private var animateIcon: Bool = false
    @State private var animateTitle: Bool = false
    @State private var animateCards: [Bool]
    @State private var animateFooter: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 40) {
                    icon
                        .frame(maxWidth: .infinity)
                        .blurSlide(animateIcon)

                    Text(title)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .blurSlide(animateTitle)
                        .accessibilityAddTraits(.isHeader)

                    CardsView()
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 0) {
                footer

                Button(action: onContinue) {
                    Text(buttonTitle)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .tint(Color.accentColor)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .padding(.bottom, 10)
                .accessibilityLabel("Continue to app")
                .accessibilityHint("Finishes onboarding and opens the main app")
                .accessibilityInputLabels(["Continue", "Get started", "Finish", "Next"])
            }
            .blurSlide(animateFooter)
        }
        .safeAreaPadding(.horizontal, 36)
        .interactiveDismissDisabled()
        .allowsHitTesting(animateFooter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Currency Converter")
        .accessibilityHint("Learn about app features and get started")
        .task {
            guard !animateIcon else { return }

            await delayedAnimation(0.35) {
                animateIcon = true
            }

            await delayedAnimation(0.2) {
                animateTitle = true
            }

            try? await Task.sleep(for: .seconds(0.2))

            for index in animateCards.indices {
                let delay = Double(index) * 0.1
                await delayedAnimation(delay) {
                    animateCards[index] = true
                }
            }

            await delayedAnimation(0.2) {
                animateFooter = true
            }
        }
    }

    @ViewBuilder
    func CardsView() -> some View {
        VStack(alignment: .leading, spacing: 40) {
            ForEach(cards.indices, id: \.self) { index in
                let card = cards[index]

                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "circle")
                        .opacity(0)
                        .frame(width: 40)
                        .overlay(
                            Image(systemName: card.symbol)
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 45)
                                .accessibilityHidden(true)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.title)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)

                        Text(card.subTitle)
                            .font(.system(.subheadline, design: .rounded, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .blurSlide(animateCards[index])
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(card.title): \(card.subTitle)")
            }
        }
    }

    private func delayedAnimation(_ delay: Double, action: @escaping () -> Void) async {
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
    @Binding var showOnBoarding: Bool
    @Environment(SettingsViewModel.self) private var settingsViewModel

    var body: some View {
        AppOnboardingView(
            title: "Welcome to Currency Converter"
        ) {
            Image("Icon")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                )
                .padding(.top, 40)
        } cards: {
            OnBoardingCard(
                symbol: "dollarsign.arrow.circlepath",
                title: "Real-time Exchange Rates",
                subTitle: "Convert between currencies using the latest exchange rates."
            )

            OnBoardingCard(
                symbol: "chart.line.uptrend.xyaxis",
                title: "Historical Tracking",
                subTitle: "Visualize currency performance with interactive charts."
            )

            OnBoardingCard(
                symbol: "wifi.slash",
                title: "Offline Support",
                subTitle: "Continue converting with cached rates when offline."
            )
        } footer: {
            Text("Exchange rates are provided by the [European Central Bank.](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html)")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
        } onContinue: {
            showOnBoarding = false
        }
    }
}

#Preview {
    @Previewable @State var showOnBoarding = true
    let container = DependencyContainer.preview()

    CurrencySpotOnboarding(showOnBoarding: $showOnBoarding)
        .withDependencyContainer(container)
}
