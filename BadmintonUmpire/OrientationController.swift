import UIKit

/// Per-screen orientation lock. The generated Info.plist allows all iPhone
/// orientations; `AppDelegate.supportedInterfaceOrientationsFor` answers with
/// this mask. MatchView locks landscape on appear and releases on disappear.
final class OrientationController {
    static let shared = OrientationController()

    private(set) var supportedMask: UIInterfaceOrientationMask = .portrait

    func lock(to mask: UIInterfaceOrientationMask) {
        guard mask != supportedMask else { return }
        supportedMask = mask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        scenes.first?.requestGeometryUpdate(
            UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: supportedMask)
        ) { _ in }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationController.shared.supportedMask
    }
}
