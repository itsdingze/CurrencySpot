//
//  CurrencyRow.swift
//  CurrencySpot
//

import SwiftUI

/// One currency in the History list: code/name, mini trend chart, and rate.
struct CurrencyRow: View {
    let entry: CurrencyListEntry

    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel

    var body: some View {
        let trendData = historyViewModel.getTrendData(for: entry.code)

        HStack(spacing: .elementGap) {
            VStack(alignment: .leading, spacing: .hairlineGap) {
                Text(entry.code)
                    .font(.appTitle2)

                Text(entry.name)
                    .lineLimit(1)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if let trend = trendData {
                MiniChart(trend: trend)
            }

            VStack(alignment: .trailing, spacing: .hairlineGap) {
                Text(entry.rate.toStringMax4Decimals)
                    .lineLimit(1)
                    .font(.appTitle2)
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

    List {
        CurrencyRow(entry: CurrencyListEntry(code: "EUR", name: "Euro", rate: 0.92))
        CurrencyRow(entry: CurrencyListEntry(code: "JPY", name: "Japanese Yen", rate: 148.31))
    }
    .listStyle(.plain)
    .withDependencyContainer(container)
}
