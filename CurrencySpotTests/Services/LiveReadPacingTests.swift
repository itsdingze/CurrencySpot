import Foundation
import Testing
@testable import CurrencySpot

struct LiveReadPacingTests {
    @Test(
        "a cool phone starts the next read as soon as the last one ends",
        arguments: [ProcessInfo.ThermalState.nominal, .fair]
    )
    func coolPhoneReadsWithoutPause(state: ProcessInfo.ThermalState) {
        #expect(LiveReadPacing.allowsRead(thermalState: state, sinceLastReadStart: .milliseconds(40)))
    }

    @Test("a hot phone starts at most two reads a second")
    func seriousHeatHalvesTheReadRate() {
        #expect(LiveReadPacing.allowsRead(thermalState: .serious, sinceLastReadStart: nil))
        #expect(!LiveReadPacing.allowsRead(thermalState: .serious, sinceLastReadStart: .milliseconds(499)))
        #expect(LiveReadPacing.allowsRead(thermalState: .serious, sinceLastReadStart: .milliseconds(500)))
    }

    @Test("a critically hot phone pauses reading")
    func criticalHeatPausesReads() {
        #expect(!LiveReadPacing.allowsRead(thermalState: .critical, sinceLastReadStart: nil))
        #expect(!LiveReadPacing.allowsRead(thermalState: .critical, sinceLastReadStart: .seconds(10)))
    }
}
