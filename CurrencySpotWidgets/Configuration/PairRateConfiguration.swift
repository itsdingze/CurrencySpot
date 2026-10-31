import AppIntents

struct PairRateConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.pairRate.name"
    static let description = IntentDescription("widget.pairRate.description")

    @Parameter(title: "widget.parameter.base", default: CurrencyEntity(code: WidgetCurrencyDefaults.current.base))
    var base: CurrencyEntity

    @Parameter(title: "widget.parameter.target", default: CurrencyEntity(code: WidgetCurrencyDefaults.current.target))
    var target: CurrencyEntity

    @Parameter(title: "widget.parameter.period", default: .oneMonth)
    var period: WidgetPeriod

    var request: RateSeriesRequest {
        RateSeriesRequest(base: base.code, currencies: [target.code], period: period.timeRange)
    }
}
