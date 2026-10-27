import SwiftUI
import UIKit

/// A landscape side of the interface (for the pose card's "Lift this half").
enum InterfaceSide: String, Equatable {
    case landscapeLeft, landscapeRight
}

/// Orientation policy (ported from Swoop/Brim, turned for Hush: play is PORTRAIT, the tabletop pose).
///
/// Info.plist lists portrait and both landscapes (never upside down: full-screen apps are refused it, so the canvas is
/// turned round by drawing, RootView). The app itself decides what it supports:
/// - an iPhone Duo (a hinge reported on this device, or the screen looks like a Duo's inner display): portrait and both
///   landscapes, so a Duo held like a book is never letterboxed and shows the "Stand it up" card;
/// - every other iPhone: portrait only.
@MainActor
enum OrientationLock {
    static let hingeKey = "hush.hasHinge"

    /// A hinge reported in this run.
    private(set) static var hingeSeen = false

    static func mask(screen: CGSize) -> UIInterfaceOrientationMask {
        let stored = trustsStoredHinge(UserDefaults.standard.bool(forKey: hingeKey), screen: screen)
        return mask(isDuo: stored || hingeSeen || looksLikeDuo(screen))
    }

    /// Pure rule (tested): portrait + landscapes on a Duo, portrait only elsewhere. Never upside down.
    nonisolated static func mask(isDuo: Bool) -> UIInterfaceOrientationMask {
        isDuo ? .allButUpsideDown : .portrait
    }

    /// Both Duo displays are ~0.7 short-to-long; other iPhones ~0.46. The inner display is ≥ 600 pt on its short side.
    nonisolated static func looksLikeDuo(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0 else { return false }
        return short / long > 0.62 && short >= 600
    }

    /// `hush.hasHinge` travels in backups, so a saved "this device has a hinge" is only believed on a Duo-shaped screen.
    nonisolated static func trustsStoredHinge(_ stored: Bool, screen: CGSize) -> Bool {
        stored && looksLikeDuo(screen)
    }

    /// A hinge just reported: let the windows use the Duo mask from now on.
    static func hingeArrived() {
        guard !hingeSeen else { return }
        hingeSeen = true
        refreshSupportedOrientations()
    }

    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// The key window's real safe-area insets.
    static func windowSafeArea() -> EdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return EdgeInsets() }
        let i = window.safeAreaInsets
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }

    /// The window scene's landscape side (nil in portrait or before a scene connects).
    static func interfaceSide() -> InterfaceSide? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let o = scenes.first?.interfaceOrientation else { return nil }
        switch o {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }

    /// The main screen's size in points (zero before the first scene connects).
    static func screenSize() -> CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first { return scene.screen.bounds.size }
        return .zero
    }
}

/// Supplies the orientation policy (`OrientationLock`) to UIKit.
@MainActor
final class HushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask(screen: window?.windowScene?.screen.bounds.size ?? OrientationLock.screenSize())
    }
}
