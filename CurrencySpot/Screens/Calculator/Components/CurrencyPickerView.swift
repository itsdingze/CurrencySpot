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
                    CurrencyUtilities.name(for: currency.currencyCode.rawValue).localizedStandardContains(searchText)
            }
        }
    }

    var body: some View {
        VStack {
            SearchField(prompt: "Search currency code or name", text: $searchText)
                .padding(.horizontal)
                .padding(.top, .tightGap)

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
                                }
                                .buttonStyle(CurrencyChipButtonStyle(isSelected: selectedCurrency == currency))
                                .accessibilityLabel("\(currency), \(CurrencyUtilities.name(for: currency))")
                                .accessibilityHint("Selects \(currency) as currency")
                                .accessibilityInputLabels([currency, CurrencyUtilities.name(for: currency)])
                                .accessibilityAddTraits(selectedCurrency == currency ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, .tightGap)
            }

            List {
                ForEach(filteredCurrencies, id: \.currencyCode) { currency in
                    CurrencyRowButton(
                        code: currency.currencyCode.rawValue,
                        name: CurrencyUtilities.name(for: currency.currencyCode.rawValue),
                        isSelected: selectedCurrency == currency.currencyCode.rawValue,
                        action: {
                            selectedCurrency = currency.currencyCode.rawValue
                            dismiss()
                        }
                    )
                    .accessibilityLabel("\(currency.currencyCode.rawValue), \(CurrencyUtilities.name(for: currency.currencyCode.rawValue))")
                    .accessibilityHint("Selects \(currency.currencyCode.rawValue) as currency")
                    .accessibilityValue(currency.rate.toStringMax4Decimals)
                    .accessibilityInputLabels([currency.currencyCode.rawValue, CurrencyUtilities.name(for: currency.currencyCode.rawValue)])
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

#Preview {
    @Previewable @State var selectedCurrency = "USD"

    NavigationStack {
        CurrencyPickerView(
            selectedCurrency: $selectedCurrency,
            exchangeRates: MockExchangeRates.getCurrencyRates()
        )
    }
}
