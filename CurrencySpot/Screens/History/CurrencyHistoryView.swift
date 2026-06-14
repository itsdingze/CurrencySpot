//
//  CurrencyHistoryView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import SwiftUI

struct CurrencyHistoryView: View {
    @Environment(HistoryViewModel.self) private var viewModel: HistoryViewModel
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel
    @State private var isChartSelectionActive: Bool = false

    var body: some View {
        VStack(spacing: .sectionGap) {
            HeaderSection(
                isChartSelectionActive: $isChartSelectionActive
            )

            ChartSection(isChartSelectionActive: $isChartSelectionActive)

            StatisticsSection()

            Spacer()
        }
        .environment(viewModel)
        .safeAreaPadding()
        .sheet(isPresented: Bindable(viewModel).isChartOnboardingPresented) {
            ChartOnboardingView(showOnboarding: Bindable(viewModel).isChartOnboardingPresented)
        }
        .task {
            // Show chart onboarding the first time the user enters the chart view.
            await viewModel.presentChartOnboardingIfNeeded(
                hasSeenChartOnboarding: settingsViewModel.hasSeenChartOnboarding
            )
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CurrencyHistoryView()
        .withDependencyContainer(container)
}
#endif
