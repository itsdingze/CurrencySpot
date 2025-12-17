//
//  CurrencyList.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/30/25.
//

import SwiftUI

private enum CurrencySortOption {
    case nameAZ
    case rateHighToLow
    case rateLowToHigh

    var description: String {
        switch self {
        case .nameAZ: "Name (A-Z)"
        case .rateHighToLow: "Rate (High to Low)"
        case .rateLowToHigh: "Rate (Low to High)"
        }
    }
}

struct CurrencyList: View {
    @Environment(CalculatorViewModel.self) var calculatorViewModel: CalculatorViewModel
    @Environment(HistoryViewModel.self) var historyViewModel: HistoryViewModel
    @State private var searchText = ""
    @State private var sortOption: CurrencySortOption = .nameAZ
    @State private var navigationPath = NavigationPath()

    // Cache the base rate to avoid recalculating it
    private var baseRate: Double {
        calculatorViewModel.availableRates.first { $0.currencyCode == calculatorViewModel.baseCurrency }?.rate ?? 1.0
    }

    private var displayedCurrencies: [ExchangeRateDataValue] {
        let filteredCurrencies = calculatorViewModel.availableRates
            .filter { $0.currencyCode != calculatorViewModel.baseCurrency }
            .filter { currency in
                guard !searchText.isEmpty else { return true }

                let name = CurrencyUtilities.shared.name(for: currency.currencyCode)
                return currency.currencyCode.localizedCaseInsensitiveContains(searchText) ||
                    name.localizedCaseInsensitiveContains(searchText)
            }

        return sorted(currencies: filteredCurrencies)
    }

    private func sorted(currencies: [ExchangeRateDataValue]) -> [ExchangeRateDataValue] {
        switch sortOption {
        case .nameAZ:
            currencies.sorted {
                CurrencyUtilities.shared.name(for: $0.currencyCode) < CurrencyUtilities.shared.name(for: $1.currencyCode)
            }
        case .rateHighToLow:
            currencies.sorted {
                calculateExchangeRate(from: $0.rate) > calculateExchangeRate(from: $1.rate)
            }
        case .rateLowToHigh:
            currencies.sorted {
                calculateExchangeRate(from: $0.rate) < calculateExchangeRate(from: $1.rate)
            }
        }
    }

    private func calculateExchangeRate(from targetRate: Double) -> Double {
        targetRate / baseRate
    }

    private func navigateToCurrency(_ currencyCode: String) {
        historyViewModel.targetCurrency = currencyCode
        historyViewModel.baseCurrency = calculatorViewModel.baseCurrency
        historyViewModel.resetDisplayedDataAndTimeRange()
        navigationPath.append(currencyCode)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 12) {
                searchBar
                currenciesList
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { _ in
                CurrencyHistoryView()
            }
            .toolbar {
                leadingToolbarItems
                trailingToolbarItems
            }
        }
        .onAppear {
            // Sync base currency when view appears
            historyViewModel.baseCurrency = calculatorViewModel.baseCurrency
        }
        .onChange(of: calculatorViewModel.baseCurrency) { _, newValue in
            // Sync when base currency changes in calculator
            historyViewModel.baseCurrency = newValue
        }
    }

    // MARK: - View Components

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)

            TextField("Search currencies", text: $searchText)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(10)
        .background(Color.tertiaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var currenciesList: some View {
        List {
            ForEach(displayedCurrencies, id: \.currencyCode) { currency in
                Button(action: {
                    navigateToCurrency(currency.currencyCode)
                }) {
                    CurrencyRow(
                        currencyCode: currency.currencyCode,
                        currencyName: CurrencyUtilities.shared.name(for: currency.currencyCode),
                        rate: calculateExchangeRate(from: currency.rate)
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if #available(iOS 26, *) {
            }
            else{
                Text("History")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
            }
        }
    }

    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach([CurrencySortOption.nameAZ, .rateHighToLow, .rateLowToHigh], id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.description)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                if #available(iOS 26, *) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Color.accentColor)
                }
                else{
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 24, design: .rounded))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.accentColor, Color.tertiaryBackground)
                }
            }
        }
    }
}

// Component for individual currency row
struct CurrencyRow: View {
    let currencyCode: String
    let currencyName: String
    let rate: Double

    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel

    init(currencyCode: String, currencyName: String, rate: Double) {
        self.currencyCode = currencyCode
        self.currencyName = currencyName
        self.rate = rate
    }

    var body: some View {
        let trendData = historyViewModel.getTrendData(for: currencyCode)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currencyCode)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)

                Text(currencyName)
                    .lineLimit(1)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if let trend = trendData {
                MiniChart(trendDataValue: trend)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(rate.toStringMax4Decimals)
                    .lineLimit(1)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()

                if let trend = trendData {
                    TrendIndicator(change: trend.weeklyChange, direction: trend.direction)
                }
            }
            .frame(width: 108, alignment: .trailing)
        }
    }
}

#Preview {
    let container = DependencyContainer.preview()

    NavigationStack {
        CurrencyList()
    }
    .withDependencyContainer(container)
}
