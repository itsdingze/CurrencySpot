import SwiftUI

struct FavoriteCurrenciesView: View {
    @Environment(SettingsViewModel.self) private var viewModel: SettingsViewModel
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(viewModel.favoriteCurrencies, id: \.self) { currency in
                HStack {
                    Text(currency.rawValue)
                        .font(.appHeadline.weight(.medium))

                    Spacer()

                    Text(CurrencyNameLookup.name(for: currency))
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Spacing.element)
                .padding(.horizontal, Spacing.cardPadding)
                .rowSeparator(isLast: currency == viewModel.favoriteCurrencies.last)
            }
            .onDelete { viewModel.removeFavorites(atOffsets: $0) }
            .onMove { viewModel.moveFavorites(fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.plain)
        .navigationTitle("Favorite Currencies")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add currency", systemImage: "plus", action: viewModel.addFavoriteTapped)
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: Bindable(viewModel).destination.isPresenting(.addFavoriteCurrency)) {
            AddCurrencyView()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FavoriteCurrenciesView()
    }
    .withDependencyContainer(.preview())
}
#endif
