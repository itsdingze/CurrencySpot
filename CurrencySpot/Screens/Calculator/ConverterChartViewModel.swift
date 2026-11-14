import Observation

@Observable
final class ConverterChartViewModel {
    private let makeHistoryViewModel: @MainActor (HistoryLink) -> CurrencyHistoryViewModel

    @ObservationIgnored private var current: (link: HistoryLink, viewModel: CurrencyHistoryViewModel)?

    init(makeHistoryViewModel: @escaping @MainActor (HistoryLink) -> CurrencyHistoryViewModel) {
        self.makeHistoryViewModel = makeHistoryViewModel
    }

    func chart(base: CurrencyCode, target: CurrencyCode) -> CurrencyHistoryViewModel {
        let link = HistoryLink(base: base, target: target)
        if let current, current.link == link {
            return current.viewModel
        }
        let viewModel = makeHistoryViewModel(link)
        current = (link, viewModel)
        return viewModel
    }
}
