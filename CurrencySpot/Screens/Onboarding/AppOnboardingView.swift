import SwiftUI

struct AppOnboardingView: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel

    private let iconSide: CGFloat = 80

    var body: some View {
        OnboardingScaffoldView(
            title: "Welcome to CurrencySpot",
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
                    title: "Real-time Exchange Rates",
                    subTitle: "Convert between currencies using the latest exchange rates."
                ),
                OnboardingCard(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Historical Tracking",
                    subTitle: "Visualize currency performance with interactive charts."
                ),
                OnboardingCard(
                    symbol: "wifi.slash",
                    title: "Offline Support",
                    subTitle: "Continue converting with cached rates when offline."
                ),
            ],
            footer: {
                Text("Exchange rates are aggregated from central banks worldwide.")
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
