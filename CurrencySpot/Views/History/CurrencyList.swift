//
//  CurrencyList.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/30/25.
//

import SwiftUI

struct CurrencyList: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 12) {
                searchBar
                currenciesList
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { _ in
                CurrencyHistoryView()
            }
            .toolbar {
                leadingToolbarItems
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
            .padding(.top, 4)
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

    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // iOS 26 renders the large title via the navigation bar; older versions need an explicit title.
            if #unavailable(iOS 26) {
                Text("History")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
            }
        }
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
                if #available(iOS 26, *) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Color.accentColor)
                }
                else{
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 24, design: .rounded))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.accentColor, Color.tertiaryBackground)
                }
            }
        }
    }
}

#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        CurrencyList()
    }
    .withDependencyContainer(container)
}
