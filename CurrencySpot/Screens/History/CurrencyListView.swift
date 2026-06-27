//
//  CurrencyListView.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/30/25.
//

import SwiftUI

struct CurrencyListView: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @State private var navigationPath = NavigationPath()
    @State private var editMode: EditMode = .inactive

    private var isEditing: Bool { editMode == .active }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: .elementGap) {
                searchBar
                content
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { _ in
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
            // After .toolbar so the EditButton and the list share one edit mode.
            .environment(\.editMode, $editMode)
        }
    }

    // MARK: - Private Methods

    private func navigateToCurrency(_ currencyCode: String) {
        // Single load: openHistory sets the pair without per-property reloads, then resets + loads once.
        historyViewModel.openHistory(for: currencyCode)
        navigationPath.append(currencyCode)
    }

    // MARK: - View Components

    private var searchBar: some View {
        SearchField(prompt: "Search currencies", text: Bindable(historyViewModel).searchText)
            .padding(.horizontal)
            .padding(.top, .hairlineGap)
            .zIndex(1)
    }

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
                Button(action: { navigateToCurrency(entry.code) }) {
                    CurrencyRow(entry: entry, metricsHidden: isEditing)
                        .padding(.vertical, .elementGap)
                        .padding(.horizontal, .cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Full-width hitbox: plain style only hit-tests opaque content.
                        .contentShape(Rectangle())
                }
                // Plain style: no row press/selection tint when swiping or tapping.
                .buttonStyle(.plain)
                .rowSeparator(isLast: entry.id == currencies.last?.id)
            }
            .onDelete { historyViewModel.removeFromWatchlist(atOffsets: $0) }
            // Reorder applies only under manual order; other sorts would re-rank immediately.
            .onMove(perform: historyViewModel.sortOption == .manual
                ? { historyViewModel.moveWatchlist(fromOffsets: $0, toOffset: $1) }
                : nil)
        }
        .listStyle(.plain)
    }

    private var searchResultsList: some View {
        List {
            ForEach(historyViewModel.displayedCurrencies) { entry in
                HStack(spacing: .elementGap) {
                    WatchlistToggleButton(
                        isInWatchlist: historyViewModel.isInWatchlist(entry.code),
                        action: { historyViewModel.toggleWatchlist(entry.code) }
                    )

                    CurrencyRow(entry: entry, showsTrendChart: false)
                        .contentShape(Rectangle())
                        .onTapGesture { navigateToCurrency(entry.code) }
                        .accessibilityAddTraits(.isButton)
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

            // A second Text in a picker label renders as the row's subtitle.
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
                .foregroundStyle(Color.accentColor)
        }
    }

    /// Routed through the guarded setter (sortOption is private(set)).
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        CurrencyListView()
    }
    .withDependencyContainer(container)
}
#endif
