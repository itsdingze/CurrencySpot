import Testing
@testable import CurrencySpot

struct ScanStatusPhaseTests {
    @Test func scanningShowsImmediatelyWhileLiveWithNoPrices() {
        let phase = ScanStatusPhase.resolve(
            isLive: true,
            hasPrices: false,
            isRecognizingStill: false,
            hintElapsed: false
        )
        #expect(phase == .scanning)
    }

    @Test func liveHintAppearsAfterTheScanningGracePeriod() {
        let phase = ScanStatusPhase.resolve(
            isLive: true,
            hasPrices: false,
            isRecognizingStill: false,
            hintElapsed: true
        )
        #expect(phase == .pointHint)
    }

    @Test(arguments: [false, true])
    func anyPriceHidesTheCapsule(isLive: Bool) {
        let phase = ScanStatusPhase.resolve(
            isLive: isLive,
            hasPrices: true,
            isRecognizingStill: false,
            hintElapsed: true
        )
        #expect(phase == .hidden)
    }

    @Test func frozenFrameStaysSilentWhileStillRecognitionRuns() {
        let phase = ScanStatusPhase.resolve(
            isLive: false,
            hasPrices: false,
            isRecognizingStill: true,
            hintElapsed: false
        )
        #expect(phase == .hidden)
    }

    @Test func frozenFrameWithNoPricesShowsNotFound() {
        let phase = ScanStatusPhase.resolve(
            isLive: false,
            hasPrices: false,
            isRecognizingStill: false,
            hintElapsed: false
        )
        #expect(phase == .notFound)
    }

    @Test func frozenFrameWithOnlyNumbersShowsNumbersOnly() {
        let phase = ScanStatusPhase.resolve(
            isLive: false,
            hasPrices: false,
            isRecognizingStill: false,
            hintElapsed: false,
            hasOutlines: true
        )
        #expect(phase == .numbersOnly)
    }

    @Test(arguments: [false, true])
    func liveFrameWithOnlyNumbersShowsNumbersOnly(hintElapsed: Bool) {
        let phase = ScanStatusPhase.resolve(
            isLive: true,
            hasPrices: false,
            isRecognizingStill: false,
            hintElapsed: hintElapsed,
            hasOutlines: true
        )
        #expect(phase == .numbersOnly)
    }

    @Test(arguments: [false, true])
    func pricesWinOverNumbers(isLive: Bool) {
        let phase = ScanStatusPhase.resolve(
            isLive: isLive,
            hasPrices: true,
            isRecognizingStill: false,
            hintElapsed: false,
            hasOutlines: true
        )
        #expect(phase == .hidden)
    }

    @Test func frozenFrameStaysSilentWithNumbersWhileStillRecognitionRuns() {
        let phase = ScanStatusPhase.resolve(
            isLive: false,
            hasPrices: false,
            isRecognizingStill: true,
            hintElapsed: false,
            hasOutlines: true
        )
        #expect(phase == .hidden)
    }
}
