//
//  CurrencyHistoryView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import SwiftUI

struct CurrencyHistoryView: View {
    @Environment(HistoryViewModel.self) var viewModel: HistoryViewModel
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel
    @Environment(SettingsViewModel.self) var settingsViewModel: SettingsViewModel
    @State private var isChartSelectionActive: Bool = false
    @State private var showChartOnboarding = false

    var body: some View {
        VStack(spacing: 16) {
            HeaderSection(
                isChartSelectionActive: $isChartSelectionActive
            )

            ChartSection(isChartSelectionActive: $isChartSelectionActive)

            StatisticsSection()

            footerSection

            Spacer()
        }
        .environment(viewModel)
        .safeAreaPadding()
        .sheet(isPresented: $showChartOnboarding) {
            ChartOnboardingView(showOnboarding: $showChartOnboarding)
        }
        .onAppear {
            // Show chart onboarding the first time user enters chart view
            #if DEBUG
                // Always show onboarding in debug builds for testing
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    showChartOnboarding = true
                }
            #else
                // Only show onboarding if user hasn't seen it in release builds
                if !settingsViewModel.hasSeenChartOnboarding {
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        showChartOnboarding = true
                    }
                }
            #endif
        }
    }

    // MARK: - Private Views

    private var footerSection: some View {
        HStack {
            Text("Data provided by European Central Bank")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let container = DependencyContainer.preview()

    CurrencyHistoryView()
        .withDependencyContainer(container)
}
