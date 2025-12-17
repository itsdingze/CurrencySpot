//
//  CurrencyPickerView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/27/25.
//

import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    var exchangeRates: [ExchangeRateDataValue] // ← Updated to use value type
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [ExchangeRateDataValue] = [] // ← Updated to use value type
    var showCommonCurrencies: Bool = true

    var favoriteCurrencies: [String] {
        if let favorites = UserDefaults.standard.stringArray(forKey: "FavoriteCurrencies") {
            return favorites
        }
        return ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD"]
    }

    var filteredCurrencies: [ExchangeRateDataValue] { // ← Updated to use value type
        if searchText.isEmpty {
            exchangeRates.sorted { $0.currencyCode < $1.currencyCode }
        } else {
            searchResults.isEmpty ?
                exchangeRates.filter { currency in
                    currency.currencyCode.localizedCaseInsensitiveContains(searchText) ||
                        CurrencyUtilities.shared.name(for: currency.currencyCode).localizedCaseInsensitiveContains(searchText)
                } : searchResults
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Custom search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textSecondary)

                    TextField("Search currency code or name", text: $searchText)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Search currencies")
                        .accessibilityHint("Enter currency code or name to filter the list")
                        .accessibilityInputLabels(["Search", "Filter", "Find currency"])

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.textSecondary)
                        }
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clears the search text")
                        .accessibilityInputLabels(["Clear", "Reset search"])
                    }
                }
                .padding(10)
                .background(Color.tertiaryBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)

                // Quick access to common currencies
                if searchText.isEmpty, showCommonCurrencies {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(favoriteCurrencies, id: \.self) { currency in
                                if exchangeRates.contains(where: { $0.currencyCode == currency }) {
                                    Button(action: {
                                        selectedCurrency = currency
                                        dismiss()
                                    }) {
                                        Text(currency)
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.medium)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                    }
                                    .background(selectedCurrency == currency ? Color.accentColor : Color.clear)
                                    .foregroundColor(selectedCurrency == currency ? .white : .textPrimary)
                                    .cornerRadius(12)
                                    .accessibilityLabel("\(currency), \(CurrencyUtilities.shared.name(for: currency))")
                                    .accessibilityHint("Selects \(currency) as currency")
                                    .accessibilityInputLabels([currency, CurrencyUtilities.shared.name(for: currency)])
                                    .accessibilityAddTraits(selectedCurrency == currency ? [.isButton, .isSelected] : .isButton)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }

                List {
                    ForEach(filteredCurrencies, id: \.currencyCode) { currency in
                        Button(action: {
                            selectedCurrency = currency.currencyCode
                            dismiss()
                        }) {
                            HStack {
                                Text(currency.currencyCode)
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.medium)

                                Spacer()

                                Text(CurrencyUtilities.shared.name(for: currency.currencyCode))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)

                                if selectedCurrency == currency.currencyCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel("\(currency.currencyCode), \(CurrencyUtilities.shared.name(for: currency.currencyCode))")
                        .accessibilityHint("Selects \(currency.currencyCode) as currency")
                        .accessibilityValue(currency.rate.toStringMax4Decimals)
                        .accessibilityInputLabels([currency.currencyCode, CurrencyUtilities.shared.name(for: currency.currencyCode)])
                        .accessibilityAddTraits(selectedCurrency == currency.currencyCode ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done selecting currency")
                        .accessibilityHint("Closes the currency selection screen")
                        .accessibilityInputLabels(["Done", "Finish", "Close"])
                }
            }
        }
    }
}
