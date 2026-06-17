//
//  FavoriteCurrenciesView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

import SwiftUI

struct FavoriteCurrenciesView: View {
    @Environment(SettingsViewModel.self) private var viewModel: SettingsViewModel
    @State private var showingAddSheet = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(viewModel.favoriteCurrencies, id: \.self) { currency in
                HStack {
                    Text(currency)
                        .font(.appHeadline.weight(.medium))

                    Spacer()

                    Text(CurrencyUtilities.name(for: currency))
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                }
                .hideOuterListSeparators(
                    isFirst: currency == viewModel.favoriteCurrencies.first,
                    isLast: currency == viewModel.favoriteCurrencies.last
                )
            }
            .onDelete { indexSet in
                let currenciesToRemove = indexSet.map { viewModel.favoriteCurrencies[$0] }
                currenciesToRemove.forEach { viewModel.removeFromFavorites($0) }
            }
            .onMove { from, to in
                viewModel.moveFavorites(from: from, to: to)
                viewModel.saveSettings()
            }
        }
        .listStyle(.plain)
        .navigationTitle("Favorite Currencies")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add currency", systemImage: "plus") {
                    showingAddSheet = true
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingAddSheet) {
            AddCurrencyView(isPresented: $showingAddSheet)
        }
    }
}

struct AddCurrencyView: View {
    @Environment(SettingsViewModel.self) private var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel
    @State private var searchText = ""

    private var filteredCurrencies: [ExchangeRate] {
        let favorites = viewModel.favoriteCurrencies

        let available = calculatorViewModel.availableRates.filter { !favorites.contains($0.currencyCode.rawValue) }

        if searchText.isEmpty {
            return available.sorted { $0.currencyCode < $1.currencyCode }
        } else {
            return available.filter { currency in
                currency.currencyCode.rawValue.localizedStandardContains(searchText) ||
                    CurrencyUtilities.name(for: currency.currencyCode.rawValue).localizedStandardContains(searchText)
            }
        }
    }

    var body: some View {
        let currencies = filteredCurrencies
        return NavigationStack {
            VStack {
                SearchField(prompt: "Search currency code or name", text: $searchText)
                    .padding(.horizontal)
                    .zIndex(1)

                List {
                    ForEach(Array(currencies.enumerated()), id: \.element.currencyCode) { index, currency in
                        CurrencyRowButton(
                            code: currency.currencyCode.rawValue,
                            name: CurrencyUtilities.name(for: currency.currencyCode.rawValue),
                            action: {
                                viewModel.addToFavorites(currency.currencyCode.rawValue)
                                isPresented = false
                            }
                        )
                        .hideOuterListSeparators(at: index, of: currencies.count)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Currency")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: currencies.count) { _, count in
                AccessibilityNotification.Announcement("\(count) currencies found").post()
            }
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    NavigationStack {
        FavoriteCurrenciesView()
    }
    .withDependencyContainer(DependencyContainer.preview())
}

#Preview("AddCurrencyView") {
    @Previewable @State var isPresented = true

    AddCurrencyView(isPresented: $isPresented)
        .withDependencyContainer(DependencyContainer.preview())
}
#endif
