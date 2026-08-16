import SwiftUI

struct CalculatorErrorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel
    @Environment(AppState.self) private var appState: AppState

    private var isConnected: Bool { appState.networkMonitor.isConnected }

    var body: some View {
        VStack(spacing: Spacing.element) {
            Image(systemName: "exclamationmark.triangle")
                .font(.appLargeTitle)
                .foregroundStyle(Color.secondaryAccent)
                .accessibilityHidden(true)

            Text("Unable to Load Exchange Rates")
                .font(.appTitle3.bold())
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal)

            if isConnected {
                Button("Try Again") { calculatorViewModel.retryFetch() }
                    .buttonStyle(.primaryAction)
                    .accessibilityLabel("Try loading exchange rates again")
            } else {
                Button("Use Sample Rates") { calculatorViewModel.showSampleRates() }
                    .buttonStyle(.primaryAction)
                    .accessibilityLabel("Use sample rates")

                Text("Sample rates are made up, not real exchange rates.")
                    .font(.appCaption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Couldn't load exchange rates")
    }

    private var message: String {
        isConnected
            ? "Something went wrong loading the latest rates. Please try again."
            : "You're offline and there are no saved rates yet. Connect to the internet to get the latest rates."
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CalculatorErrorView()
        .withDependencyContainer(container)
}
#endif
