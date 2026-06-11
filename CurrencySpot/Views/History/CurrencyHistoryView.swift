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
        .task {
            // Show chart onboarding the first time the user enters the chart view.
            guard !settingsViewModel.hasSeenChartOnboarding else { return }
            do { try await Task.sleep(for: .seconds(0.5)) } catch { return }
            showChartOnboarding = true
        }
    }

    // MARK: - Private Views

    private var footerSection: some View {
        HStack {
            Text("Exchange rates aggregated from central banks worldwide")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let container = DependencyContainer.preview()

    CurrencyHistoryView()
        .withDependencyContainer(container)
}
