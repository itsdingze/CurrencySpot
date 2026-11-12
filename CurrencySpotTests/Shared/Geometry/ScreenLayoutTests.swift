import Testing
@testable import CurrencySpot

struct ScreenLayoutTests {
    @Test(
        "the screen shape and hinge pick the layout",
        arguments: [
            (isWide: false, isHalfOpen: false, isTent: false, expected: ScreenLayout.compact),
            (isWide: true, isHalfOpen: false, isTent: false, expected: .wide),
            (isWide: true, isHalfOpen: true, isTent: false, expected: .book),
            (isWide: false, isHalfOpen: true, isTent: false, expected: .tabletop),
            (isWide: true, isHalfOpen: false, isTent: true, expected: .tent),
        ]
    )
    func picksLayout(isWide: Bool, isHalfOpen: Bool, isTent: Bool, expected: ScreenLayout) {
        #expect(ScreenLayout(isWide: isWide, isHalfOpen: isHalfOpen, isTent: isTent) == expected)
    }

    @Test(
        "a closed hinge opened partway is the tent pose, a shut one is the phone in hand",
        arguments: [
            (isHingeClosed: true, hingeAngle: 82.0, isTent: true),
            (isHingeClosed: true, hingeAngle: 0.0, isTent: false),
            (isHingeClosed: false, hingeAngle: 82.0, isTent: false),
        ]
    )
    func detectsTentPose(isHingeClosed: Bool, hingeAngle: Double, isTent: Bool) {
        #expect(ScreenLayout.isTentPose(isHingeClosed: isHingeClosed, hingeAngle: hingeAngle) == isTent)
    }

    @Test("History keeps the list beside the chart on sideways screens, folded or flat")
    func sidewaysLayoutsAreWide() {
        #expect(ScreenLayout.wide.isWide)
        #expect(ScreenLayout.book.isWide)
        #expect(!ScreenLayout.compact.isWide)
        #expect(!ScreenLayout.tabletop.isWide)
        #expect(!ScreenLayout.tent.isWide)
    }
}
