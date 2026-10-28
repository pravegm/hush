import Foundation

// MARK: - R11: last polish before launch (design/ROUND-11.md, App items 1–9; design/panel/REVIEW-5-ux.md; QA-6 P2s)

extension AppRules {
    // MARK: Item 1: make "Forgiving" findable (UX P1-1, tester 11)

    /// The Lid sensitivity row's own line (the scored Daily line stays; every option has its own line below).
    static let scoredDailyLine = "The scored Daily always plays Normal."

    /// Each option's line: what it is for, so the player who needs Forgiving can find it. Also each pill's VoiceOver
    /// hint. Pure; tested.
    static func sensitivityLine(_ s: LidSensitivity) -> String {
        switch s {
        // R13 (phone QA P2): words for the lid and the lever alike.
        case .forgiving: return "For shaky hands. Easier to stay quiet."
        case .normal: return "If it wakes while you're being gentle, try Forgiving."
        case .careful: return "For thieves who never creak."
        }
    }

    /// The `seenTips` key of the one-time Results nudge.
    static let forgivingTipKey = "forgivingTip"
    static let forgivingNudgeLine = "Keeps waking? Try a forgiving lid."
    static let forgivingNudgeButton = "Make it forgiving"
    static let forgivingNudgeDone = "Forgiving on. Change it in Settings."
    /// A run with at least this many bites…
    static let forgivingNudgeBites = 3
    /// …among the player's first this-many runs (counted after this one is filed).
    static let forgivingNudgeRuns = 2

    /// R11 (UX P1-1): the one-time Results nudge towards a forgiving lid. Only at Normal (never at Forgiving or Strict),
    /// after a run with ≥ 3 bites that is one of the player's first 2 (`runsSoFar` counts this run), never on the scored
    /// Daily (it always plays Normal), the lesson or attract, and only once ever (`seen`). Pure; tested.
    static func offersForgivingNudge(mode: RunMode, bites: Int, runsSoFar: Int, sensitivity: LidSensitivity,
                                     seen: Bool) -> Bool {
        guard !seen, sensitivity == .normal, bites >= forgivingNudgeBites,
              runsSoFar >= 1, runsSoFar <= forgivingNudgeRuns else { return false }
        switch mode {
        case .run: return true
        case let .daily(_, scored): return !scored
        case .attract, .lesson: return false
        }
    }

    // MARK: The Scene's callouts never touch the hint plate (ROUND-11 Scene 1, juror P2-1)

    /// While the scene shows a callout (`ChestScene.calloutActive`) the hint plate's hint is hidden. Pure; tested.
    static func hintYieldsToScene(sceneCallout: Bool) -> Bool { sceneCallout }

    // MARK: Item 2: a first Skip goes to the stakes card (UX P1-2)

    /// The stakes card's title when the first lesson was skipped (it hasn't earned "Lovely work…").
    static let gistTitle = "Here's the gist, little thief."

    // MARK: Item 6: VoiceOver on the never-stuck cards (UX P2-1)

    static let carryOnReady = "Carry on is ready."
    static let homeReady = "Already open? Home is ready."
    /// What VoiceOver hears when an escape appears (the closing card's Carry on, the cover card's plate). Pure; tested.
    static func escapeAnnouncement(midRun: Bool) -> String { midRun ? carryOnReady : homeReady }

    // MARK: Item 8: QA-6 P2s

    /// QA-6 P2-2: the closing card re-subscribes a silent hinge at 3 s, but only says "Move the phone a little" if
    /// nothing has arrived this long AFTER that refresh (a healthy hinge at rest re-delivers at once: no flicker).
    static let closingCopyCheckDelay: Double = 1

    /// QA-6 P2-5: the menu hold never holds a system sheet sideways: while one is up, menus don't hold. Pure; tested.
    static func menuHoldCountsMenus(systemSheetUp: Bool) -> Bool { !systemSheetUp }
}
