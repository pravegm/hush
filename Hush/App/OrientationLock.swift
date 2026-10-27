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
/// landscape, so Hush ASKS for portrait (`requestPortrait()`) at launch on the inner display and when a live run comes
/// back from the cover display. It never asks for upside down.
///
/// R6 (founder P0, "it gets stuck"): NOTHING depends on iOS's orientation any more. Every orientation plays (RootView
/// draws the canvas with `AppRules.quarterTurns`); the portrait asks are kept only because they are harmless. A live run
/// on the inner display holds the orientation it is in (`mask(isDuo:liveRun:inner:interface:)`), menus are unlocked.
@MainActor
enum OrientationLock {
    static let hingeKey = "hush.hasHinge"

    /// A hinge reported in this run.
    private(set) static var hingeSeen = false
    /// A run is live (its orientation is held on the inner display).
    private(set) static var liveRun = false
    /// R6: the interface orientation a live run is held in (captured when it goes live, re-captured whenever the
    /// interface turns anyway or the app comes back to the inner display; `.unknown` = not held).
    private(set) static var lockedInterface: UIInterfaceOrientation = .unknown
    /// What iOS last said to a portrait request (Settings › About in test builds).
    private(set) static var lastRequest = "not asked"
    /// R6: told of every mask the app hands iOS (the Diagnostics event log).
    static var onMask: ((String) -> Void)?

    /// R6 (DEBUG demos only): `fold=1;orient=landscape` on a phone sim uses the Duo's mask.
    private(set) static var demoDuo = false

    static func setDemoDuo(_ on: Bool) {
        guard on != demoDuo else { return }
        demoDuo = on
        refreshSupportedOrientations()
    }

    static func mask(screen: CGSize) -> UIInterfaceOrientationMask {
        let stored = trustsStoredHinge(UserDefaults.standard.bool(forKey: hingeKey), screen: screen)
        let inner = max(screen.width, screen.height) >= AppRules.coverMaxSide || demoDuo
        return mask(isDuo: stored || hingeSeen || looksLikeDuo(screen) || demoDuo, liveRun: liveRun, inner: inner,
                    interface: lockedInterface)
    }

    /// Pure rule (tested), R6 (ROUND-6 App 5): a Duo allows portrait and both landscapes (never upside down). While a
    /// run is live on the inner display the mask is the CURRENT orientation only (`interface`, captured when the run
    /// went live), so iOS never flips the picture mid-chest, and never a mask that disagrees with the interface (the
    /// R2 letterboxed column, Duo run 40506125012). Unknown or upside down: unlocked. Menus: unlocked. Phones: portrait.
    nonisolated static func mask(isDuo: Bool, liveRun: Bool, inner: Bool,
                                 interface: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        guard isDuo else { return .portrait }
        guard liveRun && inner else { return .allButUpsideDown }
        switch interface {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .allButUpsideDown
        }
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
        mask(isDuo: isDuo, liveRun: liveRun, inner: inner, interface: interfacePortrait ? .portrait : .unknown)
    }

    /// The key window scene runs its interface in portrait now.
    static func interfaceIsPortrait() -> Bool {
        let o = interfaceOrientation()
        return o == .portrait || o == .portraitUpsideDown
    }

    /// R6: the key window scene's interface orientation now (`.unknown` before a scene connects).
    static func interfaceOrientation() -> UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.windows.contains(where: \.isKeyWindow) }) ?? scenes.first
        return scene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }

    /// The canvas changed (RootView: a rotation, a display handover). R6: off the inner display the hold is dropped
    /// (the cover display keeps the Duo mask); on it, a live run is held in whatever orientation iOS is in NOW, so the
    /// mask never disagrees with the interface.
    static func interfaceChanged(inner: Bool = true) {
        guard liveRun else { return }
        let now = inner ? interfaceOrientation() : .unknown
        guard now != lockedInterface else { return }
        lockedInterface = now
        refreshSupportedOrientations()
    }

    /// Both Duo displays are ~0.7 short-to-long; other iPhones ~0.46. The inner display is ≥ 600 pt on its short side.
    nonisolated static func looksLikeDuo(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0 else { return false }
        return short / long > 0.62 && short >= 600
    }

    /// R3 (QA-2 P2-5): the Duo's cover display (466 × 678 on the sim: ~0.69 short-to-long, ≥ 440 pt on its short side,
    /// under the cover size). No other iPhone has that shape.
    nonisolated static func looksLikeDuoCover(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0 else { return false }
        let ratio = short / long
        return ratio > 0.62 && ratio < 0.78 && short >= 440 && long < AppRules.coverMaxSide
    }

    /// `hush.hasHinge` travels in backups, so a saved "this device has a hinge" is only believed on a Duo-shaped screen
    /// (R3: the cover display counts, so a launch on it no longer forgets the hinge).
    nonisolated static func trustsStoredHinge(_ stored: Bool, screen: CGSize) -> Bool {
        stored && (looksLikeDuo(screen) || looksLikeDuoCover(screen))
    }

    /// R3 (QA-2 P2-4): told when iOS refuses a portrait request (the book-pose card then offers "Play anyway").
    static var onRefused: (() -> Void)?

    /// A hinge just reported: let the windows use the Duo mask from now on.
    static func hingeArrived() {
        guard !hingeSeen else { return }
        hingeSeen = true
        refreshSupportedOrientations()
    }

    /// A run went live or ended. R6: while it is live the inner display holds the orientation it is in now.
    static func setLiveRun(_ on: Bool) {
        guard on != liveRun else { return }
        liveRun = on
        lockedInterface = on ? interfaceOrientation() : .unknown
        refreshSupportedOrientations()
    }

    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                if let root = window.rootViewController { adoptMask(root) }
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        // R3 (REVIEW-2-duo P2-9): the lock can be seen in the log (and in Settings › About's Diagnostics).
        let iface = interfaceOrientation()
        AppTrace.t("HUSH-T mask \(maskName()) live=\(liveRun ? 1 : 0) iface=\(iface == .portrait ? "portrait" : "other") "
                   + "held=\(AppRules.interfaceName(lockedInterface))")
        onMask?("mask \(maskName()) live=\(liveRun ? 1 : 0) iface=\(AppRules.interfaceName(iface))")
    }

    /// "portrait", "landscapeLeft", "landscapeRight" or "allButUpsideDown" for the main screen now.
    static func maskName() -> String {
        let m = mask(screen: screenSize())
        if m == .portrait { return "portrait" }
        if m == .landscapeLeft { return "landscapeLeft" }
        if m == .landscapeRight { return "landscapeRight" }
        return "allButUpsideDown"
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
        onRefused?()
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
        return "Screen: \(way) · mask: \(maskName()) · held: \(AppRules.interfaceName(lockedInterface))"
            + " · portrait ask: \(lastRequest)"
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
