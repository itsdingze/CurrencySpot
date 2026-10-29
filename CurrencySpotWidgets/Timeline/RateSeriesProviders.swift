import WidgetKit

struct PairRateProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RateSeriesEntry {
        SampleRateSeries.entry(for: PairRateConfiguration().request)
    }

    func snapshot(for configuration: PairRateConfiguration, in context: Context) async -> RateSeriesEntry {
        await RateSeriesTimeline.entry(for: configuration.request, in: context)
    }

    func timeline(for configuration: PairRateConfiguration, in context: Context) async -> Timeline<RateSeriesEntry> {
        await RateSeriesTimeline.timeline(for: configuration.request, in: context)
    }
}

struct RateListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RateSeriesEntry {
        SampleRateSeries.entry(for: RateListConfiguration().request(for: context.family))
    }

    func snapshot(for configuration: RateListConfiguration, in context: Context) async -> RateSeriesEntry {
        await RateSeriesTimeline.entry(for: configuration.request(for: context.family), in: context)
    }

    func timeline(for configuration: RateListConfiguration, in context: Context) async -> Timeline<RateSeriesEntry> {
        await RateSeriesTimeline.timeline(for: configuration.request(for: context.family), in: context)
    }
}
