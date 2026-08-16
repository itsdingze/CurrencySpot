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
                        name: CurrencyNameLookup.name(for: currency.currencyCode),
                        action: {
                            viewModel.addFavorite(currency.currencyCode)
                            viewModel.dismissDestination()
                        }
                    )
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Add Currency")
            .toolbarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search currency code or name"
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: viewModel.dismissDestination)
                }
            }
            .onChange(of: currencies.count) { _, count in
                AccessibilityNotification.Announcement("\(count) currencies found").post()
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
