import CoreGraphics
import Foundation
import UIKit

// MARK: - R8: the player can never get stuck (design/QA-5.md, P1-A … P1-D and the P2s)

extension AppRules {
    // MARK: P1-B: the cover display is a SCREEN, not a window size

    /// R8 (QA-5 P1-B): a cover-sized WINDOW on the INNER screen is iOS's letterboxed compatibility column (the R2
    /// mechanism, Duo run 40506125012: a 469 × 669 column on the 951 × 669 inner display), never the cover display. It
    /// is told apart from the real cover display by the screen: the screen is inner-sized (long side ≥ `coverMaxSide`)
    /// and the window shares one of its sides (the column runs the full height or width; either way round, in case iOS
    /// reports the screen in the column's own orientation). A cover window on a screen that reports nothing, or shares
    /// no side with it (466 × 678 against 669 × 951: a stale screen can never make the real cover display play), keeps
    /// the window rule. Pure; tested.
    static func isLetterbox(window: CGSize, screen: CGSize) -> Bool {
        guard window.width > 10, window.height > 10, screen.width > 10, screen.height > 10 else { return false }
        guard max(window.width, window.height) < coverMaxSide, max(screen.width, screen.height) >= coverMaxSide
        else { return false }
        for w in [window.width, window.height] {
            for s in [screen.width, screen.height] where abs(w - s) < 2 { return true }
        }
        return false
    }

    /// R8 (QA-5 P1-B): the pose judged on the window's SCREEN. A letterbox on the inner display plays (it has every
    /// control; the App asks iOS to un-letterbox it, `GameController.updateCanvas`); `coverOverridden` (the cover card's
    /// "Carry on" / "Home", offered when the hinge says the Duo is open) plays too. Else R3's window rule. Pure; tested.
    static func pose(window: CGSize, screen: CGSize, hingeSeen: Bool, isShut: Bool,
                     coverOverridden: Bool = false) -> AppPose {
        if coverOverridden { return .play }
        if isLetterbox(window: window, screen: screen) { return .play }
        return pose(canvas: window, hingeSeen: hingeSeen, isShut: isShut)
    }

    /// R8 (QA-5 P1-B, P2-6): the DISPLAY the app is on: a letterbox is the inner display (so it never counts as a
    /// hand-off, never bars a resume, never pollutes the Diagnostics hand-off angle); else the window's class. Pure;
    /// tested.
    static func displayClass(window: CGSize, screen: CGSize) -> CanvasClass? {
        if isLetterbox(window: window, screen: screen) { return .inner }
        return canvasClass(window)
    }

    /// R8 (QA-5 P1-B, belt and braces): the cover card offers "Carry on" (in a run) and "Home" once it has been up this
    /// long while the hinge says the Duo is open at least `coverEscapeAngle`.
    static let coverEscapeDelay: Double = 3
    static let coverEscapeAngle: Double = 92

    /// Pure; tested. The angle is the last KNOWN one (the raw report).
    static func coverOffersEscape(coverFor: Double, angle: Double?) -> Bool {
        guard coverFor.isFinite, coverFor >= coverEscapeDelay, let a = angle, a.isFinite else { return false }
        return a >= coverEscapeAngle
    }

    // MARK: P1-C / P2-5: a silent hinge

    /// R8 (QA-5 P1-C, P2-5): no hinge report has arrived since `since` (the closing card went up): the subscription is
    /// re-made and the card says "Move the lid a little" (the last angle can't be trusted). Pure; tested.
    static func hingeSilent(lastSample: TimeInterval?, since: TimeInterval) -> Bool {
        guard let last = lastSample, last.isFinite else { return true }
        return last < since
    }

    /// R8 (QA-5 P1-C): after "Carry on" re-subscribes the hinge, the reports it delivers in this window are the
    /// re-subscription's own (the current state), not the player moving the lid, so they never close the card again.
    static let carryOnRefreshGrace: Double = 0.5

    // MARK: P2-2: "Turn the chest round" applies when Settings closes

    /// R8 (QA-5 P2-2): the turn-round the canvas is DRAWN with: while Settings is open it keeps the value it had when
    /// Settings opened (`frozen`), so the page never flips under the finger; the new value applies when Settings closes.
    /// Pure; tested.
    static func drawnTurnRound(wanted: Bool, frozen: Bool?) -> Bool {
        frozen ?? wanted
    }

    /// The Settings row's extra line while a change waits for Settings to close.
    static let turnAppliesLater = "Turns round when you close Settings."

    // MARK: P2-3: the pose tip never covers a card

    /// R8 (QA-5 P2-3): the pose tip (which draws above everything) hides while the closing card or the pause menu is
    /// up, so it can never cover "Carry on" or "Home". Pure; tested.
    static func poseTipAllowed(closingCard: Bool, menu: Bool) -> Bool {
        !closingCard && !menu
    }

    // MARK: P2-1: a landscape window before iOS's report

    /// R8 (QA-5 P2-1): the landscape interface the DEVICE implies (UIDeviceOrientation names the landscapes the other
    /// way round): device landscapeRight → interface landscapeLeft, and back. Nil for anything else. Pure; tested.
    static func interfaceForDevice(_ device: UIDeviceOrientation) -> UIInterfaceOrientation? {
        switch device {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }

    // MARK: P1-D: the probe explains itself

    /// R8 (QA-5 P1-D): `debug.canvas`'s value: `k=<k> w=<w> h=<h> fold=<0|1> iface=<o> held=<o>` (the real window, the
    /// interface the frame was drawn for, and the orientation a hold has captured). Pure; tested.
    static func canvasProbeValue(window: CGSize, frame: RootFrame, held: UIInterfaceOrientation) -> String {
        "k=\(normalisedTurns(frame.turns)) w=\(Int(window.width.rounded())) h=\(Int(window.height.rounded())) "
            + "fold=\(frame.fold ? 1 : 0) iface=\(interfaceName(frame.interface)) held=\(interfaceName(held))"
    }
}

// MARK: - P2-4: menus don't re-rotate in the hand at a tabletop angle

/// R8 (QA-5 P2-4, DEVICE-RISKS watch item 1): in menus on a Duo's inner display, while the hinge reads a tabletop angle,
/// the app HOLDS the interface orientation it is in (the same hold a live run has, `OrientationLock`), so tilting the
/// Duo in the hand never plays iOS's rotation animation over an instant k redraw. The drawing never needs iOS to rotate
/// (k keeps the lid at the blurring half whatever the interface is), so holding loses nothing.
/// - It engages only once the interface has been the same for `settleSeconds` (a rotation that is really happening
///   finishes first, and the hold never captures an orientation on its way out), at 60…172°.
/// - It lets go below 55° or above 178° (a Duo lying flat), off the inner display, on a play route, and off a Duo.
/// - k itself is never held against a real interface change (that would draw wrong-way up, P1-A's class): when the
///   interface does change, k follows at once.
/// Pure; tested.
struct MenuOrientationHold: Equatable {
    static let enterMin: Double = 60
    static let enterMax: Double = 172
    static let exitMin: Double = 55
    static let exitMax: Double = 178
    static let settleSeconds: Double = 1

    private(set) var on = false

    init() {}

    /// `stableFor`: seconds since the interface orientation (or the display) last changed.
    mutating func update(duo: Bool, menus: Bool, inner: Bool, angle: Double?, stableFor: Double) -> Bool {
        guard duo, menus, inner, let a = angle, a.isFinite else {
            on = false
            return on
        }
        if on {
            on = a >= Self.exitMin && a <= Self.exitMax
        } else {
            on = a >= Self.enterMin && a <= Self.enterMax && stableFor.isFinite && stableFor >= Self.settleSeconds
        }
        return on
    }
}
