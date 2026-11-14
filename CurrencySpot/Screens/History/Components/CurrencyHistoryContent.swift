import SwiftUI

struct CurrencyHistoryContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isChartSelectionActive = false

    let viewModel: CurrencyHistoryViewModel

    private var isShowingChart: Bool {
        !viewModel.showLoadingOverlay && viewModel.chartStatistics != nil
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            sections

            ScrollView { sections }
        }
        .safeAreaPadding()
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: viewModel.appMovedToBackground()
            case .active: viewModel.appBecameActive()
            default: break
            }
        }
        .task {
            await viewModel.loadChart()
        }
        .environment(viewModel)
    }

    private var sections: some View {
        VStack(spacing: Spacing.section) {
            HeaderSection(isChartSelectionActive: $isChartSelectionActive)

            ChartSection(isChartSelectionActive: $isChartSelectionActive)

            StatisticsSection()

            if isShowingChart {
                ChartUpdateStatus()
            }

            Spacer()
        }
    }
}

#if DEBUG
#Preview {
    CurrencyHistoryContent(viewModel: .preview())
}
#endif
