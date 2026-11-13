import SwiftUI

struct BasePickerSheet: View {
    let selection: CurrencyCode
    let favorites: [CurrencyCode]
    let exchangeRates: [ExchangeRate]
    let onSelect: (CurrencyCode) -> Void

    var body: some View {
        NavigationStack {
            CurrencyPickerView(
                selectedCurrency: Binding(get: { selection }, set: { onSelect($0) }),
                exchangeRates: exchangeRates,
                favoriteCurrencies: favorites
            )
        }
        .fitsFoldedScreen()
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selection = CurrencyCode.usd

    BasePickerSheet(
        selection: selection,
        favorites: CurrencyDefaults.favoriteCurrencies,
        exchangeRates: SampleExchangeRates.getCurrencyRates(),
        onSelect: { selection = $0 }
    )
}
#endif
