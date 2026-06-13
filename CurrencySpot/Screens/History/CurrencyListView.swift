//
//  CurrencyListView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/30/25.
//

import SwiftUI

struct CurrencyListView: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: .elementGap) {
                searchBar
                currenciesList
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { _ in
                CurrencyHistoryView()
            }
            .toolbar {
                trailingToolbarItems
            }
        }
    }

    // MARK: - Private Methods

    private func navigateToCurrency(_ currencyCode: String) {
        // Single load: openHistory sets the pair without per-property reloads, then resets + loads once.
        historyViewModel.openHistory(for: currencyCode)
        navigationPath.append(currencyCode)
    }

    // MARK: - View Components

    private var searchBar: some View {
        SearchField(prompt: "Search currencies", text: Bindable(historyViewModel).searchText)
            .padding(.horizontal)
            .padding(.top, .hairlineGap)
    }

    private var currenciesList: some View {
        List {
            ForEach(historyViewModel.displayedCurrencies) { entry in
                Button(action: { navigateToCurrency(entry.code) }) {
                    CurrencyRow(entry: entry)
                }
            }
        }
        .listStyle(.plain)
    }

    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(CurrencySortOption.allCases, id: \.self) { option in
                    Button(action: { historyViewModel.selectSortOption(option) }) {
                        HStack {
                            Text(option.description)
                            if historyViewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        CurrencyListView()
    }
    .withDependencyContainer(container)
}
#endif
