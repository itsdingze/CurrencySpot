import Testing
import UIKit
@testable import CurrencySpot

struct SceneDelegateTests {
    @Test func theTentPoseTurnsTheSceneToLandscape() {
        let sceneDelegate = SceneDelegate()

        sceneDelegate.allowLandscape(true)

        #expect(sceneDelegate.supportedOrientations == .landscape)
    }

    @Test func leavingTheTentPoseTurnsTheSceneBackToPortrait() {
        let sceneDelegate = SceneDelegate()
        sceneDelegate.allowLandscape(true)

        sceneDelegate.allowLandscape(false)

        #expect(sceneDelegate.supportedOrientations == .portrait)
    }
}
