//
//  CalculatorErrorView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import SwiftUI

struct CalculatorErrorView: View {
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel
    @Environment(AppState.self) var appState: AppState
    var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundColor(.secondaryAccent)
                .accessibilityHidden(true)

            Text("Unable to Load Exchange Rates")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(errorMessage ?? "An unexpected error occurred. Please try again.")
                .multilineTextAlignment(.center)
                .foregroundColor(.textSecondary)
                .padding(.horizontal)

            if appState.networkMonitor.isConnected {
                Button("Retry Connection") {
                    Task {
                        await calculatorViewModel.fetchExchangeRates()
                    }
                }
                .padding(12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .accessibilityLabel("Retry loading exchange rates")
                .accessibilityHint("Attempts to fetch exchange rates from server again")
                .accessibilityInputLabels(["Retry", "Try again", "Reload"])
            } else {
                Button("Use Mock Data") {
                    calculatorViewModel.useMockData()
                }
                .padding(12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .accessibilityLabel("Use sample data")
                .accessibilityHint("Loads sample exchange rates for testing purposes")
                .accessibilityInputLabels(["Mock data", "Sample data", "Demo mode"])

                Text("Note: Mock data is not accurate for real conversions")
                    .font(.system(.caption, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textSecondary)
                    .accessibilityLabel("Warning: Sample data is not accurate for real currency conversions")
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error loading exchange rates")
        .accessibilityValue(errorMessage ?? "An unexpected error occurred")
    }
}

#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    CalculatorErrorView(errorMessage: "123wqiehqwoiehjqwoiehqowiehoqioaisjdoiajwdiojqoiejqowejq")
        .withDependencyContainer(container)
        .environment(appState)
}
