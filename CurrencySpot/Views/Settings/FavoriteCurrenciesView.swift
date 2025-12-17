//
//  FavoriteCurrenciesView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/19/25.
//

import SwiftUI

struct FavoriteCurrenciesView: View {
    @Environment(SettingsViewModel.self) var viewModel: SettingsViewModel
    @State private var showingAddSheet = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(viewModel.favoriteCurrencies, id: \.self) { currency in
                HStack {
                    Text(currency)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.medium)

                    Spacer()

                    Text(CurrencyUtilities.shared.name(for: currency))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
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
        .navigationTitle("Favorite Currencies")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
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
    @Environment(SettingsViewModel.self) var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel
    @State private var searchText = ""
    @State private var searchResults: [ExchangeRateDataValue] = [] // ← Updated to use value type

    var filteredCurrencies: [ExchangeRateDataValue] { // ← Updated to use value type
        let favorites = viewModel.favoriteCurrencies

        let available = calculatorViewModel.availableRates.filter { !favorites.contains($0.currencyCode) }

        if searchText.isEmpty {
            return available.sorted { $0.currencyCode < $1.currencyCode }
        } else {
            return searchResults.isEmpty ?
                available.filter { currency in
                    currency.currencyCode.localizedCaseInsensitiveContains(searchText) ||
                        CurrencyUtilities.shared.name(for: currency.currencyCode).localizedCaseInsensitiveContains(searchText)
                } : searchResults
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search currency code or name", text: $searchText)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.tertiaryBackground)
                .cornerRadius(12)
                .padding(.horizontal)

                List {
                    ForEach(filteredCurrencies, id: \.currencyCode) { currency in
                        Button(action: {
                            viewModel.addToFavorites(currency.currencyCode)
                            isPresented = false
                        }) {
                            HStack {
                                Text(currency.currencyCode)
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.medium)

                                Spacer()

                                Text(CurrencyUtilities.shared.name(for: currency.currencyCode))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
