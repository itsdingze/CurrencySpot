import Observation
import UIKit

@Observable
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    private(set) var supportedOrientations = UIInterfaceOrientationMask.portrait
    @ObservationIgnored private weak var windowScene: UIWindowScene?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        windowScene = scene as? UIWindowScene
    }

    @available(iOS 27, *)
    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        supportedOrientations
    }

    func allowLandscape(_ allowed: Bool) {
        let requested: UIInterfaceOrientationMask = allowed ? .landscape : .portrait
        guard requested != supportedOrientations else { return }
        supportedOrientations = requested
        guard let windowScene else { return }
        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: requested))
    }
}
