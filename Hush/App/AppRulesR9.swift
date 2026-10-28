import CoreGraphics
import Foundation
import SpriteKit
import UIKit

// MARK: - R9 (design/notes/fix-k3-drag.md): the landscape (k = 3) drag on the Duo, made to explain itself

/// R9: what the App did with the LAST floor touch the scene handed it (`GameController.floorTouchBegan/Moved/Ended`).
/// Demo runs read it through the `debug.state` accessibility element, so a failed CI drag says whether the finger
/// reached the app at all, where it landed in floor space, whether it picked an item, and how it ended. Pure value.
struct DebugTouchTrace: Equatable {
    enum Hit: Equatable {
        /// No floor touch has begun yet.
        case none
        /// The touch began while the App was not taking touches (paused, frozen, pilot, not a play route, no session).
        case ignored
        /// It began on empty floor (no grabbable item under it).
        case missed
        /// It picked this item id.
        case picked(Int)
    }

    enum End: String, Equatable {
        /// Not ended yet (or no touch).
        case open = "-"
        case inBag
        case dropped
        /// It ended without bagging or dropping anything (no item held, or ended while not on a play route).
        case ignored
    }

    var began = 0
    var moved = 0
    var ended = 0
    /// The last floor point a began/moved/ended carried (floor space: y down from the fold, bag at y ≥ 346).
    var lastFloor: CGPoint?
    var hit: Hit = .none
    var end: End = .open

    /// A floor touch began at `p`. `accepted`: the App took it; `picked`: the item id it picked up (nil: none).
    mutating func began(at p: CGPoint, accepted: Bool, picked: Int?) {
        began += 1
        lastFloor = p
        end = .open
        if !accepted {
            hit = .ignored
        } else if let id = picked {
            hit = .picked(id)
        } else {
            hit = .missed
        }
    }

    mutating func moved(to p: CGPoint) {
        moved += 1
        lastFloor = p
    }

    /// A floor touch ended at `p`; `events` are what the session answered.
    mutating func ended(at p: CGPoint, events: [HeistEvent]) {
        ended += 1
        lastFloor = p
        var e = End.ignored
        for event in events {
            if case .itemBagged = event { e = .inBag; break }
            if case .itemDropped = event { e = .dropped }
        }
        end = e
    }

    /// `hit=` value: `none`, `ignored`, `missed` or the picked item's id.
    var hitText: String {
        switch hit {
        case .none: return "none"
        case .ignored: return "ignored"
        case .missed: return "missed"
        case .picked(let id): return "\(id)"
        }
    }
}

extension AppRules {
    /// R9: the run phase's short name (logs, `debug.state`). Pure.
    static func phaseName(_ p: RunPhase) -> String {
        switch p {
        case .ready: return "ready"
        case .looting: return "looting"
        case .banked: return "banked"
        case .bitten: return "bitten"
        case .torchOut: return "torchOut"
        case .finished: return "finished"
        }
    }

    /// R9 (fix-k3-drag): `debug.state`'s value:
    /// `phase=<p> paused=<0|reason+reason> input=<kind> k=<k> lastTouch=floor(x,y)|none hit=<id|none|ignored|missed>
    /// ended=<inBag|dropped|ignored|-> touches=<began>/<moved>/<ended> route=<r> frozen=<0|1> scene=<w>x<h> view=<w>x<h>
    /// mode=<fill|fit|other>`. Integers only (points rounded). Pure; tested.
    static func debugStateValue(phase: RunPhase?, paused: [String], input: AppInputKind, quarterTurns k: Int,
                                trace: DebugTouchTrace, route: AppRoute, frozen: Bool, sceneSize: CGSize?,
                                viewSize: CGSize?, scaleMode: SKSceneScaleMode?) -> String {
        func n(_ v: CGFloat) -> String { v.isFinite ? "\(Int(v.rounded()))" : "nan" }
        func size(_ s: CGSize?) -> String { s.map { "\(n($0.width))x\(n($0.height))" } ?? "-" }
        let touch = trace.lastFloor.map { "floor(\(n($0.x)),\(n($0.y)))" } ?? "none"
        let pausedText = paused.isEmpty ? "0" : paused.sorted().joined(separator: "+")
        let mode: String
        switch scaleMode {
        case .aspectFill?: mode = "fill"
        case .aspectFit?: mode = "fit"
        case nil: mode = "-"
        default: mode = "other"
        }
        return "phase=\(phase.map { phaseName($0) } ?? "-") paused=\(pausedText) input=\(input.rawValue) "
            + "k=\(normalisedTurns(k)) lastTouch=\(touch) hit=\(trace.hitText) ended=\(trace.end.rawValue) "
            + "touches=\(trace.began)/\(trace.moved)/\(trace.ended) route=\(route.rawValue) frozen=\(frozen ? 1 : 0) "
            + "scene=\(size(sceneSize)) view=\(size(viewSize)) mode=\(mode)"
    }

    /// R9: the scene's scale mode for a DRAWN (pre-turn) frame: aspect-fit when the drawn frame is landscape (no fold:
    /// the whole portrait chest, never a crop), else aspect-fill. The same rule as `CanvasFit` (landscape view → min,
    /// else max), so the SwiftUI overlays and the scene always agree (`GameController.updateCanvas`). Pure; tested.
    static func sceneScaleMode(drawn: CGSize) -> SKSceneScaleMode {
        drawn.width > drawn.height ? .aspectFit : .aspectFill
    }

    /// R9: where a point of the DRAWN (portrait, pre-turn) SwiftUI frame lands in the WINDOW after RootView's
    /// `.rotationEffect(.degrees(90 * k))` about the window's centre (SwiftUI's y is down, so +90° is a clockwise
    /// quarter turn on screen: up → right). The drawn frame is centred in the window. Pure; tested against the scene.
    static func windowPoint(fromDrawn p: CGPoint, drawn: CGSize, window: CGSize, quarterTurns k: Int) -> CGPoint {
        var dx = p.x - drawn.width / 2
        var dy = p.y - drawn.height / 2
        for _ in 0..<normalisedTurns(k) {
            (dx, dy) = (-dy, dx)
        }
        return CGPoint(x: window.width / 2 + dx, y: window.height / 2 + dy)
    }

    /// R9: view points per scene point for an aspect scale mode, as SKView scales (`.aspectFill`: the larger ratio,
    /// `.aspectFit`: the smaller; anything else is treated as fit). The same numbers as
    /// `ChestScene.scaleFor(view:scene:mode:)`. Pure.
    static func sceneViewScale(view: CGSize, scene: CGSize, mode: SKSceneScaleMode) -> CGFloat {
        guard view.width > 0, view.height > 0, scene.width > 0, scene.height > 0 else { return 1 }
        let sx = view.width / scene.width, sy = view.height / scene.height
        return mode == .aspectFill ? max(sx, sy) : min(sx, sy)
    }

    /// R9: where SpriteKit draws a SCENE point (y up) in its view (y down) for `mode` (the view is the window): the
    /// scene scaled by `sceneViewScale` and centred, as SKView does. Pure; tested.
    static func viewPoint(fromScene p: CGPoint, scene: CGSize, view: CGSize, mode: SKSceneScaleMode) -> CGPoint {
        let s = sceneViewScale(view: view, scene: scene, mode: mode)
        let ox = (view.width - scene.width * s) / 2
        let oy = (view.height - scene.height * s) / 2
        return CGPoint(x: ox + p.x * s, y: oy + (scene.height - p.y) * s)
    }

    /// R9: the inverse (a finger's window point → the scene point SKView hands `touch.location(in:)`). Pure; tested.
    static func scenePoint(fromView p: CGPoint, scene: CGSize, view: CGSize, mode: SKSceneScaleMode) -> CGPoint {
        let s = sceneViewScale(view: view, scene: scene, mode: mode)
        guard s > 0 else { return .zero }
        let ox = (view.width - scene.width * s) / 2
        let oy = (view.height - scene.height * s) / 2
        return CGPoint(x: (p.x - ox) / s, y: scene.height - (p.y - oy) / s)
    }
}
