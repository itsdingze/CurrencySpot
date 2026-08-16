import SwiftUI

struct CurrencyPickerView: View {
    @Binding private var selectedCurrency: CurrencyCode
    private let exchangeRates: [ExchangeRate]
    private let favoriteCurrencies: [CurrencyCode]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    init(
        selectedCurrency: Binding<CurrencyCode>,
        exchangeRates: [ExchangeRate],
        favoriteCurrencies: [CurrencyCode]
    ) {
        _selectedCurrency = selectedCurrency
        self.exchangeRates = exchangeRates
        self.favoriteCurrencies = favoriteCurrencies
    }

    private var filteredCurrencies: [ExchangeRate] {
        CurrencySearch.results(in: exchangeRates, excluding: [], matching: searchText)
    }

    var body: some View {
        VStack {
            if searchText.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(favoriteCurrencies, id: \.self) { currency in
                            if exchangeRates.contains(where: { $0.currencyCode == currency }) {
                                Button(action: {
                                    selectedCurrency = currency
                                    dismiss()
                                }) {
                                    Text(currency.rawValue)
                                }
                                .buttonStyle(.currencyChip(isSelected: selectedCurrency == currency))
                                .accessibilityLabel("\(currency.rawValue), \(CurrencyNameLookup.name(for: currency))")
                                .accessibilityAddTraits(selectedCurrency == currency ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .padding(.vertical, Spacing.tight)
                .zIndex(1)
            }

            List {
                ForEach(filteredCurrencies, id: \.currencyCode) { currency in
                    CurrencyRowButton(
                        code: currency.currencyCode,
                        name: CurrencyNameLookup.name(for: currency.currencyCode),
                        isSelected: selectedCurrency == currency.currencyCode,
                        action: {
                            selectedCurrency = currency.currencyCode
                            dismiss()
                        }
                    )
                    .accessibilityLabel("\(currency.currencyCode.rawValue), \(CurrencyNameLookup.name(for: currency.currencyCode))")
                    .accessibilityValue(currency.rate.toStringMax4Decimals)
                    .accessibilityAddTraits(selectedCurrency == currency.currencyCode ? [.isButton, .isSelected] : .isButton)
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Select Currency")
        .toolbarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search currency code or name"
        )
        .autocorrectionDisabled()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selectedCurrency = CurrencyCode.usd

    NavigationStack {
        CurrencyPickerView(
            selectedCurrency: $selectedCurrency,
            exchangeRates: SampleExchangeRates.getCurrencyRates(),
            favoriteCurrencies: CurrencyDefaults.favoriteCurrencies
        )
    }
}
#endif
