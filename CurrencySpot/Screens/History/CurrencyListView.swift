import SwiftUI

struct CurrencyListView: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @State private var editMode: EditMode = .inactive

    private var isEditing: Bool { editMode == .active }

    var body: some View {
        NavigationStack(path: Bindable(historyViewModel).path) {
            content
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: Bindable(historyViewModel).searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search currencies"
            )
            .autocorrectionDisabled()
            .navigationDestination(for: CurrencyCode.self) { _ in
                CurrencyHistoryView()
            }
            .toolbar {
                trailingToolbarItems
            }
            .onChange(of: historyViewModel.displayedCurrencies.count) { _, count in
                guard historyViewModel.isSearching else { return }
                AccessibilityNotification.Announcement("\(count) currencies found").post()
            }
            .onChange(of: historyViewModel.isSearching || historyViewModel.isWatchlistEmpty) { _, cannotEdit in
                if cannotEdit { editMode = .inactive }
            }
            .environment(\.editMode, $editMode)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var content: some View {
        if historyViewModel.isSearching {
            if historyViewModel.displayedCurrencies.isEmpty {
                ContentUnavailableView.search(text: historyViewModel.searchText)
            } else {
                searchResultsList
            }
        } else if historyViewModel.isWatchlistEmpty {
            emptyWatchlist
        } else {
            watchlistList
        }
    }

    private var watchlistList: some View {
        List {
            let currencies = historyViewModel.displayedCurrencies
            ForEach(currencies) { entry in
                Button(action: { historyViewModel.openHistory(for: entry.code) }) {
                    CurrencyRow(entry: entry, metricsHidden: isEditing)
                        .padding(.vertical, Spacing.element)
                        .padding(.horizontal, Spacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowSeparator(isLast: entry.id == currencies.last?.id)
            }
            .onDelete { historyViewModel.removeFromWatchlist(atOffsets: $0) }
            .onMove(perform: historyViewModel.sortOption == .manual
                ? { historyViewModel.moveWatchlist(fromOffsets: $0, toOffset: $1) }
                : nil)
        }
        .listStyle(.plain)
    }

    private var searchResultsList: some View {
        List {
            ForEach(historyViewModel.displayedCurrencies) { entry in
                HStack(spacing: Spacing.element) {
                    WatchlistToggleButton(
                        isInWatchlist: historyViewModel.isInWatchlist(entry.code),
                        action: { historyViewModel.toggleWatchlist(entry.code) }
                    )

                    Button { historyViewModel.openHistory(for: entry.code) } label: {
                        CurrencyRow(entry: entry, showsTrendChart: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private var emptyWatchlist: some View {
        ContentUnavailableView {
            Label("No Currencies", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Search above to add currencies to your list.")
        }
    }

    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                EditButton()
            } else {
                optionsMenu
            }
        }
    }

    private var optionsIcon: String {
        if #available(iOS 26, *) { "ellipsis" } else { "ellipsis.circle" }
    }

    private var optionsMenu: some View {
        Menu {
            if !historyViewModel.isSearching && !historyViewModel.isWatchlistEmpty {
                Button {
                    withAnimation { editMode = .active }
                } label: {
                    Label("Edit Watchlist", systemImage: "pencil")
                }
            }

            Picker(selection: sortSelection) {
                ForEach(CurrencySortOption.allCases, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
                Text(historyViewModel.sortOption.description)
            }
            .pickerStyle(.menu)

            Picker(selection: trendSelection) {
                ForEach(TrendDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.description).tag(mode)
                }
            } label: {
                Label("Indicator", systemImage: "chart.line.uptrend.xyaxis")
                Text(historyViewModel.trendDisplayMode.description)
            }
            .pickerStyle(.menu)
        } label: {
            Label("Options", systemImage: optionsIcon)
        }
    }

    private var sortSelection: Binding<CurrencySortOption> {
        Binding(
            get: { historyViewModel.sortOption },
            set: { historyViewModel.selectSortOption($0) }
        )
    }

    private var trendSelection: Binding<TrendDisplayMode> {
        Binding(
            get: { historyViewModel.trendDisplayMode },
            set: { historyViewModel.selectTrendDisplayMode($0) }
        )
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CurrencyListView()
        .withDependencyContainer(container)
}
#endif
