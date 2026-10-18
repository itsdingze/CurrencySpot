import SwiftUI

struct AppOnboardingView: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel

    private let iconSide: CGFloat = 80

    var body: some View {
        OnboardingScaffoldView(
            title: .onboardingWelcomeTitle,
            icon: {
                let iconShape = RoundedRectangle(cornerRadius: AppIconArtwork.cornerRadius(forSide: iconSide))

                Image("Icon")
                    .resizable()
                    .frame(width: iconSide, height: iconSide)
                    .clipShape(iconShape)
                    .overlay {
                        iconShape.stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                    }
                    .padding(.top, Spacing.onboarding)
                    .accessibilityHidden(true)
            },
            cards: [
                OnboardingCard(
                    symbol: "dollarsign.arrow.circlepath",
                    title: .onboardingWelcomeRatesTitle,
                    subTitle: .onboardingWelcomeRatesSubtitle
                ),
                OnboardingCard(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: .onboardingWelcomeHistoryTitle,
                    subTitle: .onboardingWelcomeHistorySubtitle
                ),
                OnboardingCard(
                    symbol: "wifi.slash",
                    title: .onboardingWelcomeOfflineTitle,
                    subTitle: .onboardingWelcomeOfflineSubtitle
                ),
            ],
            footer: {
                Text(.onboardingWelcomeFooter)
                    .font(.appCaption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.block)
            },
            onContinue: settingsViewModel.dismissOnboarding
        )
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    AppOnboardingView()
        .withDependencyContainer(container)
}
#endif
