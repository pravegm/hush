import CoreGraphics
import Foundation

// MARK: - R12: the lid IS the chest (design/ROUND-12.md, App section; founder's real-Duo test of build 6)
//
// "The chest closed means lid closed, chest open means lid open." Nothing the App says may ask to open a lid that is
// already open, and nothing says "Close the lid for the next chest" except over the robbed chest after a bite.

extension AppRules {
    /// R12: the lid reads open past this openness: the shut zone's edge (θ 110° on the hinge, 0.15 on the lever).
    static let lidOpenLine: Double = 0.15

    /// R12: the lid is open (past the shut zone) for the words. NaN reads as shut. Pure; tested.
    static func lidReadsOpen(_ openness: Double) -> Bool {
        openness.isFinite && openness > lidOpenLine
    }

    /// R12: a line asks to open the lid ("Open the lid… slowly", "Now open it… slowly", "Open it gently"). None of
    /// these may show while `lidReadsOpen`. Pure; tested (the sweep in `R12Tests`).
    static func asksToOpen(_ line: String) -> Bool {
        line.lowercased().contains("open")
    }

    /// R12 (CI ask): the `HUSH-T hint <name>` line for the HUD's chosen hint (`none` when it clears). Pure; tested.
    static func hintTraceLine(_ hint: HeistHint?) -> String {
        "HUSH-T hint " + (hint?.rawValue ?? "none")
    }

    /// R12 (founder via CI): `.closeForNext` belongs to the robbed chest alone. After a bank the next chest is dealt
    /// "seen shut", so the App never shows it outside `awaitingClose` (a stale gate hold included). Pure; tested.
    static func allowsCloseForNext(_ hint: HeistHint?, awaitingClose: Bool) -> Bool {
        hint != .closeForNext || awaitingClose
    }

    /// R12 (Core R12 hook 2): Feedback's `playing` flag. Off over the robbed chest (`awaitingClose`): Core puts its
    /// mimic to sleep with noise 0, and the snore bed must not play over a chest that reads angry. The continuous lid
    /// layers go quiet with it (Feedback has no snore-only switch yet: NEEDS, Feel R12). Pure; tested.
    static func feedbackPlays(_ phase: RunPhase, awaitingClose: Bool) -> Bool {
        isLive(phase) && !awaitingClose
    }
}

/// R12 (CI ask, demo `bag=<n>`, DEBUG): puts n of the first chest's items into the bag on its first looting steps, as
/// if dragged there slowly (picked and dropped in the bag at walking pace: the one-off pick and bag clinks only, no
/// drag noise). Pure planning; the controller feeds the session the touches.
struct DemoBagPlan: Equatable {
    /// Synthetic touch ids (never a real finger's `ObjectIdentifier` hash in practice).
    static let touchBase = -9_000
    let wanted: Int
    private(set) var bagged = 0
    private(set) var done = false

    init(_ n: Int) {
        wanted = max(n, 0)
        done = wanted == 0
    }

    /// The grabbable items to bag now (by loot index into `s.loot`), at most what is still wanted. Only while the
    /// first chest (index 0) is being looted. Pure; tested.
    func picks(_ s: HeistSnapshot) -> [Int] {
        guard !done, s.phase == .looting, (s.chest?.index ?? -1) == 0 else { return [] }
        var out: [Int] = []
        for (k, item) in s.loot.enumerated() where item.place == .inChest && item.grabbable {
            if out.count >= wanted - bagged { break }
            out.append(k)
        }
        return out
    }

    mutating func noteBagged(_ n: Int) { bagged += max(n, 0) }

    /// Stop trying: everything wanted is in, or the first chest is no longer looting.
    mutating func finishIfNeeded(_ s: HeistSnapshot) {
        if bagged >= wanted { done = true }
        if let i = s.chest?.index, i > 0 { done = true }
        switch s.phase {
        case .banked, .bitten, .torchOut, .finished: done = true
        case .ready, .looting: break
        }
    }

    /// Where a demo item is dropped: the middle of the bag strip.
    static let bagPoint = CGPoint(x: FloorSpace.width / 2, y: (FloorSpace.bagMinY + FloorSpace.height) / 2)
}
