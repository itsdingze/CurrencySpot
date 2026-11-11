import Foundation
import WidgetKit

enum RateSeriesTimeline {
    private static let loadRateSeries = LoadRateSeriesUseCase(
        fetcher: FrankfurterAPI(
            session: FrankfurterAPI.makeDefaultSession(),
            retryPolicy: RetryPolicy(maxRetries: 1),
            clock: ContinuousClockService(),
            now: { .now }
        ),
        cache: RateSeriesCache(directory: URL.cachesDirectory.appending(path: "RateSeries", directoryHint: .isDirectory))
    )

    static func entry(for request: RateSeriesRequest, in context: TimelineProviderContext) async -> RateSeriesEntry {
        await loaded(request, in: context).entry
    }

    static func timeline(for request: RateSeriesRequest, in context: TimelineProviderContext) async -> Timeline<RateSeriesEntry> {
        let loaded = await loaded(request, in: context)
        return Timeline(entries: [loaded.entry], policy: .after(loaded.refresh))
    }

    private static func loaded(_ request: RateSeriesRequest, in context: TimelineProviderContext) async -> (entry: RateSeriesEntry, refresh: Date) {
        let now = Date.now
        let load = context.isPreview
            ? RateSeriesLoad(snapshot: SampleRateSeries.entry(for: request).snapshot, isFresh: true)
            : await loadRateSeries(request, now: now)
        return (RateSeriesEntry(date: now, request: request, snapshot: load.snapshot), load.nextRefresh(after: now))
    }
}

extension FrankfurterAPI: HistoricalRatesFetching {}
