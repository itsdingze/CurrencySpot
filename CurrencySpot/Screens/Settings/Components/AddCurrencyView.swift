import SwiftUI

struct AddCurrencyView: View {
    @Environment(SettingsViewModel.self) private var viewModel: SettingsViewModel
    @Environment(ExchangeRatesStore.self) private var ratesStore: ExchangeRatesStore
    @State private var searchText = ""

    private var filteredCurrencies: [ExchangeRate] {
        viewModel.addableCurrencies(from: ratesStore.rates, matching: searchText)
    }

    var body: some View {
        let currencies = filteredCurrencies
        return NavigationStack {
            List {
                ForEach(currencies, id: \.currencyCode) { currency in
                    CurrencyRowButton(
                        code: currency.currencyCode,
                        name: currency.currencyCode.localizedName,
                        action: {
                            viewModel.addFavorite(currency.currencyCode)
                            viewModel.dismissDestination()
                        }
                    )
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle(.settingsAddCurrencyTitle)
            .toolbarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: .settingsAddCurrencySearchPrompt
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(.settingsAddCurrencyCancel, action: viewModel.dismissDestination)
                }
            }
            .onChange(of: currencies.count) { _, count in
                AccessibilityNotification.Announcement(String(localized: .settingsAddCurrencySearchResults(count: count))).post()
            }
        }
    }
}

#if DEBUG
#Preview {
    AddCurrencyView()
        .withDependencyContainer(.preview())
}
#endif
