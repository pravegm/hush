import SwiftUI
import UIKit

/// A landscape side of the interface (for the pose card's "Lift this half").
enum InterfaceSide: String, Equatable {
    case landscapeLeft, landscapeRight
}

/// Orientation policy (ported from Swoop/Brim, turned for Hush: play is PORTRAIT, the tabletop pose).
///
/// Info.plist lists portrait and both landscapes (never upside down: full-screen apps are refused it, so the canvas is
/// turned round by drawing, inside the scene and on the SwiftUI overlays). The app itself decides what it supports:
/// - an iPhone Duo (a hinge reported on this device, or the screen looks like a Duo's inner display): portrait and both
///   landscapes, so a Duo held like a book is never letterboxed and shows the "Turn it round" card;
/// - R2 (REVIEW-1-duo P0-1): while a run is live on the Duo's inner display, portrait only, so a sideways tilt in the
///   hand can't drop the run onto the book-pose card;
/// - every other iPhone: portrait only.
///
/// R2 (P0-1, Brim's Release path): a Duo lying flat never rotates on its own, and a Duo lifted from book pose may stay
/// landscape, so Hush ASKS for portrait (`requestPortrait()`): when the pose card shows, when the hinge moves under it,
/// at launch on the inner display, when a live run comes back from the cover display, and from the card's "I've stood
/// it up" button. It never asks for upside down.
@MainActor
enum OrientationLock {
    static let hingeKey = "hush.hasHinge"

    /// A hinge reported in this run.
    private(set) static var hingeSeen = false
    /// A run is live (portrait only on the inner display).
    private(set) static var liveRun = false
    /// What iOS last said to a portrait request (Settings › About in test builds).
    private(set) static var lastRequest = "not asked"

    static func mask(screen: CGSize) -> UIInterfaceOrientationMask {
        let stored = trustsStoredHinge(UserDefaults.standard.bool(forKey: hingeKey), screen: screen)
        let inner = max(screen.width, screen.height) >= AppRules.coverMaxSide
        return mask(isDuo: stored || hingeSeen || looksLikeDuo(screen), liveRun: liveRun, inner: inner,
                    interfacePortrait: interfaceIsPortrait() && screen.height > screen.width)
    }

    /// Pure rule (tested): portrait + landscapes on a Duo, portrait only elsewhere. Never upside down.
    nonisolated static func mask(isDuo: Bool) -> UIInterfaceOrientationMask {
        isDuo ? .allButUpsideDown : .portrait
    }

    /// Pure rule (tested), R2: a live run on the Duo's inner display is held in portrait, but ONLY once the interface
    /// already IS portrait there. Duo run 40506125012: a portrait-only mask handed to a landscape (book-pose) inner
    /// display doesn't rotate it; iOS runs the app as a letterboxed 469 × 669 compatibility column instead (cover-sized,
    /// so it read as the cover display and play never stepped), and it stays there. While the interface is landscape
    /// the mask keeps the landscapes and the App ASKS for portrait (`requestPortrait`), which rotates it properly. The
    /// cover display keeps the Duo mask (Brim run 40343397399). Never upside down.
    nonisolated static func mask(isDuo: Bool, liveRun: Bool, inner: Bool,
                                 interfacePortrait: Bool) -> UIInterfaceOrientationMask {
        guard isDuo else { return .portrait }
        return liveRun && inner && interfacePortrait ? .portrait : .allButUpsideDown
    }

    /// The key window scene runs its interface in portrait now.
    static func interfaceIsPortrait() -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.windows.contains(where: \.isKeyWindow) }) ?? scenes.first
        return scene?.effectiveGeometry.interfaceOrientation.isPortrait ?? false
    }

    /// The interface changed shape (RootView's canvas): a live run that has just reached portrait on the inner display
    /// gets its portrait lock now (iOS only asks for the mask again after this).
    static func interfaceChanged() {
        guard liveRun else { return }
        refreshSupportedOrientations()
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

    /// A run went live or ended (the inner display holds portrait while it is live).
    static func setLiveRun(_ on: Bool) {
        guard on != liveRun else { return }
        liveRun = on
        refreshSupportedOrientations()
    }

    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                if let root = window.rootViewController { adoptMask(root) }
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// Asks every window scene for portrait (Brim's Release path; never upside down). Harmless where portrait is all
    /// there is (a phone) or already in effect.
    static func requestPortrait() {
        lastRequest = "asked"
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            if let root = window?.rootViewController { adoptMask(root) }
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                let text = error.localizedDescription
                Task { @MainActor in requestFailed(text) }
            }
        }
        AppTrace.t("HUSH-T orient portrait requested (release path)")
    }

    /// A portrait request was refused (e.g. the mask didn't allow it yet). Only reported: the card stays, its button
    /// asks again.
    static func requestFailed(_ reason: String) {
        lastRequest = "refused: \(reason)"
        AppTrace.t("HUSH-T orient request failed: \(reason)")
    }

    // MARK: - The root controller's own mask (Brim)

    private static var adopted = Set<ObjectIdentifier>()

    /// iOS intersects the app delegate's mask with the root view controller's `supportedInterfaceOrientations`, and
    /// SwiftUI's root UIHostingController answers with the iPhone default (every orientation but upside down), so a
    /// "portrait only while live" never reached iOS. The SwiftUI App lifecycle gives no way to subclass that
    /// controller, so its class (only SwiftUI's host) answers with `mask(screen:)`, the same rule the app delegate uses.
    static func adoptMask(_ controller: UIViewController) {
        guard let cls = object_getClass(controller) else { return }
        guard NSStringFromClass(cls).contains("UIHostingController") else { return }
        let id = ObjectIdentifier(cls)
        guard !adopted.contains(id) else { return }
        let selector = #selector(getter: UIViewController.supportedInterfaceOrientations)
        guard let method = class_getInstanceMethod(cls, selector) else { return }
        adopted.insert(id)
        let answer: @convention(block) (UIViewController) -> UInt = { vc in
            MainActor.assumeIsolated {
                mask(screen: vc.view.window?.windowScene?.screen.bounds.size ?? screenSize()).rawValue
            }
        }
        class_replaceMethod(cls, selector, imp_implementationWithBlock(answer), method_getTypeEncoding(method))
        AppTrace.t("HUSH-T root mask adopted")
    }

    /// For Settings › About in test builds: which way iOS runs the display, and what it said to the last request.
    static func status() -> String {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let way: String
        switch scenes.first?.effectiveGeometry.interfaceOrientation {
        case .portrait: way = "portrait"
        case .landscapeLeft, .landscapeRight: way = "sideways"
        case .portraitUpsideDown: way = "upside down"
        default: way = "unknown"
        }
        return "Screen: \(way) · portrait ask: \(lastRequest)"
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
