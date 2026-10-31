import AppIntents
import WidgetKit

struct RateListConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.rateList.name"
    static let description = IntentDescription("widget.rateList.description")

    @Parameter(title: "widget.parameter.base", default: CurrencyEntity(code: WidgetCurrencyDefaults.current.base))
    var base: CurrencyEntity

    @Parameter(
        title: "widget.parameter.currencies",
        default: WidgetCurrencyDefaults.current.listCurrencies.map(CurrencyEntity.init),
        size: [.systemMedium: 2, .systemLarge: 7]
    )
    var currencies: [CurrencyEntity]

    @Parameter(title: "widget.parameter.period", default: .oneMonth)
    var period: WidgetPeriod

    func request(for family: WidgetFamily) -> RateSeriesRequest {
        RateSeriesRequest.list(
            base: base.code,
            currencies: currencies.map(\.code),
            period: period.timeRange,
            limit: RateListLayout.rowLimit(for: family)
        )
    }
}
