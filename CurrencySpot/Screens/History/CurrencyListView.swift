import SwiftUI

struct CurrencyListView: View {
    @Environment(CurrencyListViewModel.self) private var viewModel
    @State private var editMode: EditMode = .inactive
    @Environment(\.screenLayout) private var screenLayout

    private var isEditing: Bool { editMode == .active }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if screenLayout.isWide {
                NavigationSplitView {
                    currencyList
                        .navigationSplitViewColumnWidth(min: 320, ideal: 400)
                } detail: {
                    detail
                }
            } else if #available(iOS 27.1, *), screenLayout == .tabletop {
                tabletopContent
            } else {
                NavigationStack(path: $viewModel.path) {
                    currencyList
                        .navigationDestination(for: HistoryRoute.self) { historyView(for: $0) }
                }
            }
        }
    }

    // MARK: - View Components

    @available(iOS 27.1, *)
    private var tabletopContent: some View {
        TabletopSplit {
            NavigationStack {
                tabletopChart
                    .toolbarTitleDisplayMode(.inline)
            }
        } bottom: {
            NavigationStack {
                currencyList
            }
        }
    }

    @ViewBuilder
    private var tabletopChart: some View {
        if let route = viewModel.selection {
            historyView(for: route)
        } else if let link = viewModel.chartLink {
            CurrencyHistoryView(viewModel: viewModel.historyViewModel(for: link))
                .id(link)
        } else {
            ContentUnavailableView(.historyDetailEmptyTitle, systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private var currencyList: some View {
        @Bindable var viewModel = viewModel
        return content
            .navigationTitle(.historyListTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: .historyListSearchPrompt
            )
            .autocorrectionDisabled()
            .toolbar {
                trailingToolbarItems
            }
            .sheet(isPresented: $viewModel.destination.isPresenting(.basePicker)) {
                BasePickerSheet(
                    selection: viewModel.baseCurrency,
                    favorites: viewModel.basePickerFavorites,
                    exchangeRates: viewModel.basePickerRates,
                    onSelect: { viewModel.selectBase($0) }
                )
            }
            .onChange(of: viewModel.displayedCurrencies.count) { _, count in
                guard viewModel.isSearching else { return }
                AccessibilityNotification.Announcement(String(localized: .historyListSearchResults(count: count))).post()
            }
            .onChange(of: viewModel.isSearching || viewModel.isWatchlistEmpty) { _, cannotEdit in
                if cannotEdit { editMode = .inactive }
            }
            .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private var detail: some View {
        if let route = viewModel.selection {
            historyView(for: route)
        } else {
            ContentUnavailableView(.historyDetailEmptyTitle, systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private func historyView(for route: HistoryRoute) -> some View {
        CurrencyHistoryView(viewModel: viewModel.historyViewModel(for: route.link))
            .id(route)
    }

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
        } else if viewModel.isWaitingForConnection {
            waitingForConnection
        } else if viewModel.isLoadingRates {
            ProgressView(.calculatorLoading)
        } else {
            watchlistList
        }
    }

    private var watchlistList: some View {
        @Bindable var viewModel = viewModel
        return List(selection: $viewModel.selectedCurrency) {
            let currencies = viewModel.displayedCurrencies
            ForEach(currencies) { entry in
                CurrencyRow(entry: entry, metricsHidden: isEditing)
                    .padding(.vertical, Spacing.element)
                    .padding(.horizontal, Spacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(isEditing ? [] : .isButton)
                    .rowSeparator(isLast: entry.id == currencies.last?.id)
                    .tag(entry.code)
                    .selectionDisabled(isEditing)
            }
            .onDelete { viewModel.removeFromWatchlist(atOffsets: $0) }
            .onMove(perform: viewModel.sortOption == .manual
                ? { viewModel.moveWatchlist(fromOffsets: $0, toOffset: $1) }
                : nil)
        }
        .listStyle(.plain)
    }

    private var searchResultsList: some View {
        @Bindable var viewModel = viewModel
        return List(selection: $viewModel.selectedCurrency) {
            ForEach(viewModel.displayedCurrencies) { entry in
                HStack(spacing: Spacing.element) {
                    WatchlistToggleButton(
                        isInWatchlist: viewModel.isInWatchlist(entry.code),
                        action: { viewModel.toggleWatchlist(entry.code) }
                    )

                    CurrencyRow(entry: entry, showsTrendChart: false)
                        .contentShape(Rectangle())
                        .accessibilityAddTraits(.isButton)
                }
                .tag(entry.code)
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private var emptyWatchlist: some View {
        ContentUnavailableView {
            Label(.historyListEmptyTitle, systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text(.historyListEmptyDescription)
        }
    }

    private var waitingForConnection: some View {
        ContentUnavailableView {
            Label(.errorNoInternetTitle, systemImage: "wifi.slash")
        } description: {
            Text(.calculatorErrorMessageOffline)
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            BaseCurrencyButton(code: viewModel.baseCurrency, action: viewModel.baseCurrencyTapped)
        }
        if #available(iOS 26, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                Button(.historyListDone, action: finishEditing)
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
                    Label(.historyListEditWatchlist, systemImage: "pencil")
                }
            }

            Picker(selection: $viewModel.sortOption) {
                ForEach(CurrencySortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            } label: {
                Label(.historyListSortBy, systemImage: "arrow.up.arrow.down")
                Text(viewModel.sortOption.displayName)
            }
            .pickerStyle(.menu)

            Picker(selection: $viewModel.trendDisplayMode) {
                ForEach(TrendDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label(.historyListIndicator, systemImage: "chart.line.uptrend.xyaxis")
                Text(viewModel.trendDisplayMode.displayName)
            }
            .pickerStyle(.menu)
        } label: {
            Label(.historyListOptions, systemImage: optionsIcon)
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
