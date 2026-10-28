import Foundation

// MARK: - R7: real hands (design/ROUND-7.md, App items 1–7; design/DEVICE-RISKS-1.md items 3, 4, 8, 9, 11)

extension AppRules {
    // MARK: Item 1: the fresh chest

    /// R7 (ROUND-7 App 1, DEVICE-RISKS-1 item 3): a closing pause over a FRESH chest (`HeistSession.isFreshChest`:
    /// `.ready`, never opened past 0.05, nothing in the bag) resumes as soon as the lid is lifted (at or above Feel's
    /// line in force, `hinge.effectiveResumeAngle`), with no "Hold still…" wait. Nothing can be lost: the lid is silent
    /// under 97° and looting needs ≤ 110° first. A pause over a chest in play keeps the full rule (`canResume`: lifted
    /// AND still). Pure; tested.
    static func closingResumes(canResume: Bool, freshChest: Bool, lifted: Bool) -> Bool {
        canResume || (freshChest && lifted)
    }

    /// Silent lid after a fresh-chest resume (s), like "Carry on" (DEVICE-RISKS-1 item 3: `resumeGrace(0.8)`).
    static let freshResumeGrace: Double = 0.8

    // MARK: Item 2: the pause coin

    /// On a Duo, mid-chest, the pause coin needs a press-and-hold this long (s); a ring fills as it is held.
    static let pauseHoldSeconds: Double = 0.35
    /// A shorter press only says so, beside the coin, for `holdHintSeconds`.
    static let holdToPauseText = "Hold to pause"
    static let holdHintSeconds: Double = 1.6

    /// R7 (ROUND-7 App 2, DEVICE-RISKS-1 item 4): the coin sits where a right hand eases the lid, so on a Duo a LIVE
    /// chest (`.ready` / `.looting`, the lesson included) needs the hold. Elsewhere (phones, the bank and bite
    /// moments) it is a tap. Pure; tested.
    static func pauseNeedsHold(duo: Bool, phase: RunPhase) -> Bool {
        duo && isLive(phase)
    }

    enum CoinPress: Equatable {
        /// Open the pause menu.
        case pause
        /// Too short: show "Hold to pause".
        case hint
    }

    /// What a press of `heldFor` seconds does when it ends. A tap pauses where no hold is needed. Pure; tested.
    static func coinPress(heldFor: Double, needsHold: Bool) -> CoinPress {
        guard needsHold else { return .pause }
        guard heldFor.isFinite else { return .hint }
        return heldFor >= pauseHoldSeconds ? .pause : .hint
    }

    // MARK: Item 4: Settings

    static let sensitivityTitle = "Lid sensitivity"
    static let vibrationTitle = "Vibration"

    /// The row's option names. Pure; tested.
    /// R11 (tester 11: "Careful" read as a quieter lid): the third option is "Strict". Its stored raw value stays
    /// "careful" (Core's `LidSensitivity.careful`), so a saved choice still decodes to it.
    static func sensitivityName(_ s: LidSensitivity) -> String {
        switch s {
        case .forgiving: return "Forgiving"
        case .normal: return "Normal"
        case .careful: return "Strict"
        }
    }

    /// The row's detail line: that the scored Daily always plays Normal. R11 (UX P1-1): what each choice is FOR is now
    /// on its own line under the pills (`sensitivityLine`), whichever is chosen. Pure; tested.
    static func sensitivityDetail(_ chosen: LidSensitivity) -> String {
        scoredDailyLine
    }

    /// The Vibration row's detail line. Pure.
    static func vibrationDetail(chosen: Bool, duo: Bool) -> String {
        if chosen { return "Feel every creak, and every careful step." }
        return duo ? "Strong suits the Duo." : "Feel every creak, and every careful step."
    }

    // MARK: Item 5: the Diagnostics Copy log

    /// The event log, then the raw hinge trace (`HingeLidSource.traceText()`), as one pasteable block. Pure; tested.
    static func diagnosticsCopy(log: String, trace: String) -> String {
        log + "\n\n" + trace
    }

    // MARK: Item 6: Game Center waits for the lesson

    /// R7 (ROUND-7 App 6, DEVICE-RISKS-1 item 9): Game Center's sign-in (and its welcome banner, which iOS draws at
    /// the player's near edge on a turned Duo) waits until the lesson is done and the player is on Home, so it never
    /// lands on the First Chest or the first run after it. Scores and achievements earned before then are queued (and
    /// sent once signed in). Demo runs authenticate at once (it only switches Game Center off for them). Pure; tested.
    static func mayAuthenticateGameCenter(demo: Bool, lessonDone: Bool, route: AppRoute) -> Bool {
        demo || (lessonDone && route == .home)
    }
}
