import Foundation
import WidgetKit

enum RateSeriesTimeline {
    private static let loadRateSeries = LoadRateSeriesUseCase(
        fetcher: FrankfurterAPI(
            session: FrankfurterAPI.makeDefaultSession(),
            retryPolicy: RetryPolicy(maxRetries: 1),
            clock: ContinuousClockService()
        ),
        cache: RateSeriesCache(directory: URL.cachesDirectory.appending(path: "RateSeries", directoryHint: .isDirectory))
    )

    static func entry(for request: RateSeriesRequest, in context: TimelineProviderContext) async -> RateSeriesEntry {
        if context.isPreview {
            return SampleRateSeries.entry(for: request)
        }
        let now = Date.now
        return RateSeriesEntry(date: now, request: request, snapshot: await loadRateSeries(request, now: now))
    }

    static func timeline(for request: RateSeriesRequest, in context: TimelineProviderContext) async -> Timeline<RateSeriesEntry> {
        let entry = await entry(for: request, in: context)
        let refresh = RatePublishSchedule.nextRefresh(after: entry.date, latestRateDay: entry.snapshot?.latestRateDay)
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

extension FrankfurterAPI: HistoricalRatesFetching {}
