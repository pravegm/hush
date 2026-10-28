import CoreGraphics
import Foundation
import SwiftUI
import UIKit

// MARK: - R6: "any way up", never stuck (design/ROUND-6.md, App items 1–8)

/// What RootView settles for one window size: the pose, the fold, the quarter turns and the interface orientation
/// they were judged in.
struct RootFrame: Equatable {
    var pose: AppPose
    var fold: Bool
    var turns: Int
    var interface: UIInterfaceOrientation
}

extension AppRules {
    /// R6 (founder rule, ROUND-6 "The fix"): how many CLOCKWISE screen quarter turns the portrait canvas (lid = canvas
    /// top) is drawn with, so the lid's edge points at the blurring half (the physical half that is the bottom in iOS
    /// portrait) with "Turn the chest round" on, and at the opposite side with it off:
    ///
    /// | interface          | on | off |
    /// |--------------------|----|-----|
    /// | portrait           | 2  | 0   |
    /// | landscapeRight     | 1  | 3   |
    /// | landscapeLeft      | 3  | 1   |
    /// | portraitUpsideDown | 0  | 2   |
    ///
    /// No fold (other iPhones): 0 always. `.unknown` keeps `last` (the last known value). Pure; table-tested.
    static func quarterTurns(interface: UIInterfaceOrientation, turnRound: Bool, hasFold: Bool,
                             last: Int = 0) -> Int {
        guard hasFold else { return 0 }
        let off: Int
        switch interface {
        case .portrait: off = 0
        case .landscapeRight: off = 3
        case .landscapeLeft: off = 1
        case .portraitUpsideDown: off = 2
        case .unknown: return normalisedTurns(last)
        @unknown default: return normalisedTurns(last)
        }
        return turnRound ? (off + 2) % 4 : off
    }

    /// Any Int as 0…3. Pure.
    static func normalisedTurns(_ k: Int) -> Int { ((k % 4) + 4) % 4 }

    /// The interface orientation RootView draws for: what iOS reported, made to agree with the window's shape (a
    /// landscape window is a landscape interface, a portrait one is portrait or upside down), so the drawn frame is
    /// always portrait on a fold. `.unknown`, or a report that disagrees with the shape (a beat before iOS updates
    /// it), falls back to `last` if that fits, else to landscapeRight / portrait. Pure; tested.
    /// R8 (QA-5 P2-1): a landscape window with neither the report nor `last` landscape falls back on the DEVICE's
    /// landscape (`interfaceForDevice`: device landscapeRight → interface landscapeLeft) before the constant, so a
    /// portrait → landscapeLeft turn is never drawn 180° wrong for the beat before iOS reports it.
    static func settledInterface(_ reported: UIInterfaceOrientation, window: CGSize,
                                 last: UIInterfaceOrientation,
                                 device: UIDeviceOrientation = .unknown) -> UIInterfaceOrientation {
        let landscape = window.width > window.height
        if landscape {
            if isLandscape(reported) { return reported }
            if isLandscape(last) { return last }
            return interfaceForDevice(device) ?? .landscapeRight
        }
        if isPortrait(reported) { return reported }
        return isPortrait(last) ? last : .portrait
    }

    static func isLandscape(_ o: UIInterfaceOrientation) -> Bool { o == .landscapeLeft || o == .landscapeRight }
    static func isPortrait(_ o: UIInterfaceOrientation) -> Bool { o == .portrait || o == .portraitUpsideDown }

    /// `size` with its long side as the height (the portrait-equivalent canvas). Pure.
    static func portraitSize(_ size: CGSize) -> CGSize {
        size.width > size.height ? CGSize(width: size.height, height: size.width) : size
    }

    /// The frame the SwiftUI root is laid out in before it is turned `k` quarter turns: the window, with w and h
    /// swapped when k is odd. Pure; tested.
    static func drawnSize(window: CGSize, quarterTurns k: Int) -> CGSize {
        normalisedTurns(k) % 2 == 1 ? CGSize(width: window.height, height: window.width) : window
    }

    /// Demo `quarter=<k>` (DEBUG): a forced k is used only on a fold, and only when its parity fits the window (odd k
    /// on a landscape window, even k on a portrait one), so the drawn frame stays portrait. Pure; tested.
    static func forcedTurnsFit(_ k: Int, window: CGSize, hasFold: Bool) -> Bool {
        guard hasFold else { return false }
        return (normalisedTurns(k) % 2 == 1) == (window.width > window.height)
    }

    /// The window edge a DRAWN edge lands on after `k` clockwise quarter turns (top → trailing → bottom → leading).
    /// Pure; tested.
    static func windowEdge(drawn: Edge, quarterTurns k: Int) -> Edge {
        let ring: [Edge] = [.top, .trailing, .bottom, .leading]
        let i = ring.firstIndex(of: drawn) ?? 0
        return ring[(i + normalisedTurns(k)) % 4]
    }

    private static func inset(_ safe: EdgeInsets, _ edge: Edge) -> CGFloat {
        switch edge {
        case .top: return safe.top
        case .leading: return safe.leading
        case .bottom: return safe.bottom
        case .trailing: return safe.trailing
        }
    }

    /// The window's safe-area insets in the drawn (portrait) layout's terms after `k` quarter turns: each drawn edge
    /// takes the inset of the window edge it lands on. k = 2 is R2's turned-round swap. Pure; tested.
    static func insets(_ safe: EdgeInsets, quarterTurns k: Int) -> EdgeInsets {
        EdgeInsets(top: inset(safe, windowEdge(drawn: .top, quarterTurns: k)),
                   leading: inset(safe, windowEdge(drawn: .leading, quarterTurns: k)),
                   bottom: inset(safe, windowEdge(drawn: .bottom, quarterTurns: k)),
                   trailing: inset(safe, windowEdge(drawn: .trailing, quarterTurns: k)))
    }

    /// The window edges whose system gestures wait for a second swipe while a chest is live: the window's bottom (the
    /// Home indicator, in iOS's own orientation) and the window edge under the drawn floor's front (where the fingers
    /// work). k = 0: the bottom; k = 2: top and bottom (R2). Pure; tested.
    static func deferredEdges(live: Bool, quarterTurns k: Int) -> Edge.Set {
        guard live else { return [] }
        var set: Edge.Set = .bottom
        set.insert(Edge.Set(windowEdge(drawn: .bottom, quarterTurns: k)))
        return set
    }

    // MARK: The pose tip (book pose no longer blocks)

    /// The `seenTips` key: the player tapped ✕, or the lesson passed step 1. It never shows again.
    static let poseTipKey = "poseTip"

    /// The small "Stand it up like a little laptop" tip: on a Duo, on Home and lesson step 1 only, while the DEVICE is
    /// held landscape (like a book), until dismissed. A demo can force it on those screens. Pure; tested.
    /// R8 (QA-5 P2-3): never while a card is up (`cardUp`: the closing card or the pause menu), forced or not.
    static func showsPoseTip(duo: Bool, route: AppRoute, lessonStep: Int?, device: UIDeviceOrientation,
                             dismissed: Bool, forced: Bool = false, cardUp: Bool = false) -> Bool {
        guard !cardUp else { return false }
        let place = route == .home || (route == .lesson && (lessonStep ?? 1) <= 1)
        guard place else { return false }
        if forced { return true }
        guard duo, !dismissed else { return false }
        return device == .landscapeLeft || device == .landscapeRight
    }

    /// Clockwise quarter turns (in the WINDOW's frame) that draw the tip upright to gravity: the device's physical
    /// "up" against the interface's. Nil when the device orientation says nothing (flat, unknown). Pure; tested.
    static func tipTurns(device: UIDeviceOrientation, interface: UIInterfaceOrientation) -> Int? {
        let d: Int
        switch device {
        case .portrait: d = 0
        case .landscapeLeft: d = 1      // the home edge on the right = interface landscapeRight
        case .portraitUpsideDown: d = 2
        case .landscapeRight: d = 3     // the home edge on the left = interface landscapeLeft
        default: return nil
        }
        let i: Int
        switch interface {
        case .landscapeRight: i = 1
        case .portraitUpsideDown: i = 2
        case .landscapeLeft: i = 3
        default: i = 0
        }
        return normalisedTurns(d - i)
    }

    /// Which page of the book the tip sits on (in its upright frame): the SHARP one, away from the blurring half (the
    /// physical portrait-bottom: on the right with the home edge right, on the left with it left). Pure; tested.
    static func poseTipOnLeft(device: UIDeviceOrientation) -> Bool {
        device != .landscapeRight
    }

    // MARK: Never stuck: Carry on and the watchdog

    /// The closing card shows "Carry on" after this long (wall s).
    static let carryOnDelay: Double = 3
    /// "Carry on" and the watchdog resume with this much silent lid.
    static let carryOnGrace: Double = 0.8
    /// The watchdog resumes a closing pause after this long (wall s), when the hinge is at least `resumeAngle` open.
    static let watchdogSeconds: Double = 6

    /// R6 (ROUND-6 App 6, with the founder's correction): a live run held ONLY by the closing pause (never the menu,
    /// the background or the cover display), paused ≥ 6 s, resumes by itself when the LAST KNOWN hinge angle is ≥ 95°
    /// AND the canvas is the inner display. Nothing else: a lid sitting shut sends no samples and must stay paused (no
    /// "silent hinge" clause), and an unknown angle never resumes. Pure; tested.
    /// R7 (feel-R7): `resumeAngle` is Feel's line in force (the controller passes `hinge.effectiveResumeAngle`, 92° /
    /// 88° with hysteresis), so the watchdog never asks for more than the hinge does. Default: `AppRules.resumeAngle`
    /// (92°); NaN falls back to it.
    static func watchdogResumes(pausedFor: Double, onlyClosing: Bool, liveRun: Bool, canvas: CanvasClass?,
                                angle: Double?, resumeAngle line: Double = AppRules.resumeAngle) -> Bool {
        guard liveRun, onlyClosing, canvas == .inner, pausedFor.isFinite, pausedFor >= watchdogSeconds else {
            return false
        }
        guard let a = angle, a.isFinite else { return false }
        return a >= (line.isFinite ? line : resumeAngle)
    }

    // MARK: Names for the logs

    static func interfaceName(_ o: UIInterfaceOrientation) -> String {
        switch o {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "upsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    static func deviceName(_ o: UIDeviceOrientation) -> String {
        switch o {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "upsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    /// `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<k>`: the REAL window size (CI's `is_portrait` reads it),
    /// `turned` = k == 2 (CI greps `fold=` and `turned=`), then k. Pure; tested.
    static func canvasLine(_ size: CGSize, hasFold: Bool, quarterTurns k: Int) -> String {
        let t = normalisedTurns(k)
        return "HUSH-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) turned=\(t == 2 ? 1 : 0) k=\(t)"
    }
}
