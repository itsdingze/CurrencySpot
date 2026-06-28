//
//  CalculatorErrorView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import SwiftUI

struct CalculatorErrorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel
    @Environment(AppState.self) private var appState: AppState

    private var isConnected: Bool { appState.networkMonitor.isConnected }

    var body: some View {
        VStack(spacing: .elementGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.appLargeTitle)
                .foregroundStyle(Color.secondaryAccent)
                .accessibilityHidden(true)

            Text("Unable to Load Exchange Rates")
                .font(.appTitle3.bold())
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal)

            // Online: retrying is the useful action. Offline: a retry would just fail, so
            // the only real choice is opting into sample rates — and connectivity
            // returning restarts the load automatically.
            if isConnected {
                Button("Try Again") { calculatorViewModel.retryFetch() }
                    .buttonStyle(.primaryAction)
                    .accessibilityLabel("Try loading exchange rates again")
            } else {
                Button("Use Sample Rates") { calculatorViewModel.useMockData() }
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    CalculatorErrorView()
        .withDependencyContainer(container)
        .environment(appState)
}
#endif
