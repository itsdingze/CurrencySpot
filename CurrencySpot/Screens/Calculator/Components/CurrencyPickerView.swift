//
//  CurrencyPickerView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/27/25.
//

import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    var exchangeRates: [ExchangeRate] // ← Updated to use value type
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var favoriteCurrencies: [String] {
        if let favorites = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) {
            return favorites
        }
        return ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD"]
    }

    private var filteredCurrencies: [ExchangeRate] {
        if searchText.isEmpty {
            exchangeRates.sorted { $0.currencyCode < $1.currencyCode }
        } else {
            exchangeRates.filter { currency in
                currency.currencyCode.rawValue.localizedStandardContains(searchText) ||
                    CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue).localizedStandardContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                SearchField(prompt: "Search currency code or name", text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Quick access to common currencies
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(favoriteCurrencies, id: \.self) { currency in
                                if exchangeRates.contains(where: { $0.currencyCode.rawValue == currency }) {
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
                                    .foregroundStyle(selectedCurrency == currency ? .white : .textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        CurrencyRowButton(
                            code: currency.currencyCode.rawValue,
                            name: CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue),
                            isSelected: selectedCurrency == currency.currencyCode.rawValue,
                            action: {
                                selectedCurrency = currency.currencyCode.rawValue
                                dismiss()
                            }
                        )
                        .accessibilityLabel("\(currency.currencyCode.rawValue), \(CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue))")
                        .accessibilityHint("Selects \(currency.currencyCode.rawValue) as currency")
                        .accessibilityValue(currency.rate.toStringMax4Decimals)
                        .accessibilityInputLabels([currency.currencyCode.rawValue, CurrencyUtilities.shared.name(for: currency.currencyCode.rawValue)])
                        .accessibilityAddTraits(selectedCurrency == currency.currencyCode.rawValue ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Currency")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done selecting currency")
                        .accessibilityHint("Closes the currency selection screen")
                        .accessibilityInputLabels(["Done", "Finish", "Close"])
                }
            }
        }
    }
}
