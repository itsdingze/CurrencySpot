//
//  ScanStatusPhaseTests.swift
//  CurrencySpotTests
//

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
}
