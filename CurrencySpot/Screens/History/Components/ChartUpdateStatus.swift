import SwiftUI

struct ChartUpdateStatus: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel

    var body: some View {
        DelayedUpdatingBanner(banner: viewModel.updateStatus) { banner in
            if banner != .hidden {
                RateStatusLine(
                    status: banner,
                    savedRatesTime: lastUpdatedTime,
                    showsRetry: viewModel.canRetryUpdate,
                    retryAction: viewModel.retry,
                    alignment: .leading
                )
            } else if let lastUpdatedTime {
                Text(.calculatorRateInfoLastUpdated(date: lastUpdatedTime))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.chipPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastUpdatedTime: String? {
        viewModel.lastUpdated?.savedRatesDisplay(relativeTo: .now)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.preview()

    ChartUpdateStatus()
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}
#endif
