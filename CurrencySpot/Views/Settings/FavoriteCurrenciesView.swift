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
                        .foregroundStyle(.secondary)
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

    var filteredCurrencies: [ExchangeRateDataValue] {
        let favorites = viewModel.favoriteCurrencies

        let available = calculatorViewModel.availableRates.filter { !favorites.contains($0.currencyCode.rawValue) }

        if searchText.isEmpty {
            return available.sorted { $0.currencyCode < $1.currencyCode }
        } else {
            return available.filter { currency in
                currency.currencyCode.rawValue.localizedCaseInsensitiveContains(searchText) ||
                    CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search currency code or name", text: $searchText)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                List {
                    ForEach(filteredCurrencies, id: \.currencyCode) { currency in
                        Button(action: {
                            viewModel.addToFavorites(currency.currencyCode.rawValue)
                            isPresented = false
                        }) {
                            HStack {
                                Text(currency.currencyCode.rawValue)
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.medium)

                                Spacer()

                                Text(CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
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
