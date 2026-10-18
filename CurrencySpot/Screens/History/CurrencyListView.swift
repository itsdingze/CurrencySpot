import SwiftUI

struct CurrencyListView: View {
    @Environment(CurrencyListViewModel.self) private var viewModel
    @State private var editMode: EditMode = .inactive

    private var isEditing: Bool { editMode == .active }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack(path: $viewModel.path) {
            content
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search currencies"
            )
            .autocorrectionDisabled()
            .navigationDestination(for: CurrencyCode.self) { code in
                CurrencyHistoryView(viewModel: viewModel.historyViewModel(for: code))
            }
            .toolbar {
                trailingToolbarItems
            }
            .onChange(of: viewModel.displayedCurrencies.count) { _, count in
                guard viewModel.isSearching else { return }
                AccessibilityNotification.Announcement("\(count) currencies found").post()
            }
            .onChange(of: viewModel.isSearching || viewModel.isWatchlistEmpty) { _, cannotEdit in
                if cannotEdit { editMode = .inactive }
            }
            .environment(\.editMode, $editMode)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            if viewModel.displayedCurrencies.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                searchResultsList
            }
        } else if viewModel.isWatchlistEmpty {
            emptyWatchlist
        } else {
            watchlistList
        }
    }

    private var watchlistList: some View {
        List {
            let currencies = viewModel.displayedCurrencies
            ForEach(currencies) { entry in
                Button(action: { viewModel.openHistory(for: entry.code) }) {
                    CurrencyRow(entry: entry, metricsHidden: isEditing)
                        .padding(.vertical, Spacing.element)
                        .padding(.horizontal, Spacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowSeparator(isLast: entry.id == currencies.last?.id)
            }
            .onDelete { viewModel.removeFromWatchlist(atOffsets: $0) }
            .onMove(perform: viewModel.sortOption == .manual
                ? { viewModel.moveWatchlist(fromOffsets: $0, toOffset: $1) }
                : nil)
        }
        .listStyle(.plain)
    }

    private var searchResultsList: some View {
        List {
            ForEach(viewModel.displayedCurrencies) { entry in
                HStack(spacing: Spacing.element) {
                    WatchlistToggleButton(
                        isInWatchlist: viewModel.isInWatchlist(entry.code),
                        action: { viewModel.toggleWatchlist(entry.code) }
                    )

                    Button { viewModel.openHistory(for: entry.code) } label: {
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
                Button("Done", action: finishEditing)
                    .fontWeight(.semibold)
            } else {
                optionsMenu
            }
        }
    }

    private func startEditing() {
        withAnimation { editMode = .active }
    }

    private func finishEditing() {
        withAnimation { editMode = .inactive }
    }

    private var optionsIcon: String {
        if #available(iOS 26, *) { "ellipsis" } else { "ellipsis.circle" }
    }

    private var optionsMenu: some View {
        @Bindable var viewModel = viewModel
        return Menu {
            if !viewModel.isSearching && !viewModel.isWatchlistEmpty {
                Button(action: startEditing) {
                    Label("Edit Watchlist", systemImage: "pencil")
                }
            }

            Picker(selection: $viewModel.sortOption) {
                ForEach(CurrencySortOption.allCases, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
                Text(viewModel.sortOption.description)
            }
            .pickerStyle(.menu)

            Picker(selection: $viewModel.trendDisplayMode) {
                ForEach(TrendDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.description).tag(mode)
                }
            } label: {
                Label("Indicator", systemImage: "chart.line.uptrend.xyaxis")
                Text(viewModel.trendDisplayMode.description)
            }
            .pickerStyle(.menu)
        } label: {
            Label("Options", systemImage: optionsIcon)
        }
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CurrencyListView()
        .withDependencyContainer(container)
}
#endif
