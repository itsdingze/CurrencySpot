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
    var errorMessage: String?

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

            Text(errorMessage ?? "An unexpected error occurred. Please try again.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal)

            if appState.networkMonitor.isConnected {
                Button("Retry Connection") {
                    calculatorViewModel.retryFetch()
                }
                .padding(.fieldPadding)
                .foregroundStyle(.white)
                .adaptiveGlassBackground(in: .rect(cornerRadius: .cardRadius), isInteractive: true, tint: .accentColor) {
                    RoundedRectangle(cornerRadius: .cardRadius)
                        .fill(Color.accentColor)
                }
                .accessibilityLabel("Retry loading exchange rates")
                .accessibilityHint("Attempts to fetch exchange rates from server again")
                .accessibilityInputLabels(["Retry", "Try again", "Reload"])
            } else {
                Button("Use Mock Data") {
                    calculatorViewModel.useMockData()
                }
                .padding(.fieldPadding)
                .foregroundStyle(.white)
                .adaptiveGlassBackground(in: .rect(cornerRadius: .cardRadius), isInteractive: true, tint: .accentColor) {
                    RoundedRectangle(cornerRadius: .cardRadius)
                        .fill(Color.accentColor)
                }
                .accessibilityLabel("Use sample data")
                .accessibilityHint("Loads sample exchange rates for testing purposes")
                .accessibilityInputLabels(["Mock data", "Sample data", "Demo mode"])

                Text("Note: Mock data is not accurate for real conversions")
                    .font(.appCaption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityLabel("Warning: Sample data is not accurate for real currency conversions")
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error loading exchange rates")
        .accessibilityValue(errorMessage ?? "An unexpected error occurred")
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    @Previewable @State var appState = AppState.shared
    let container = DependencyContainer.preview()

    CalculatorErrorView(errorMessage: "123wqiehqwoiehjqwoiehqowiehoqioaisjdoiajwdiojqoiejqowejq")
        .withDependencyContainer(container)
        .environment(appState)
}
#endif
