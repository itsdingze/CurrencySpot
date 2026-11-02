import Testing
@testable import CurrencySpot

struct PointHintAnnouncerTests {
    private func announcements(
        _ updates: [(ScanStatusPhase, Bool)],
        with announcer: inout PointHintAnnouncer
    ) -> Int {
        var count = 0
        for (phase, hintElapsed) in updates where announcer.shouldAnnounce(phase: phase, hintElapsed: hintElapsed) {
            count += 1
        }
        return count
    }

    @Test func announcesWhenTheWaitEndsOnTheHint() {
        var announcer = PointHintAnnouncer()

        let count = announcements([(.scanning, false), (.pointHint, true)], with: &announcer)

        #expect(count == 1)
    }

    @Test func theHintAnnouncesOnlyOncePerLiveSession() {
        var announcer = PointHintAnnouncer()
        _ = announcements([(.scanning, false), (.pointHint, true)], with: &announcer)

        let count = announcements(
            [(.hidden, false), (.scanning, false), (.pointHint, true)],
            with: &announcer
        )

        #expect(count == 0)
    }
}
