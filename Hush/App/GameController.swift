import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): ChestScene.update → advance(dt:now:) → lid source
/// (hinge, slider, pilot) → HeistSession.step → FeedbackDirector → HUD. Owns the session, the scene, the lid sources, the
/// app's route, the First Chest lesson and the Duo states (pose, closing, shut).
///
/// Pauses (no stepping): the lid closing (`ClosingPause`), the app inactive or in the background, the pause menu, and a
/// pose card (book pose, the cover display).
/// - R3 (founder decision 2): a pause is simply NO stepping. Nothing rests, so the noise, the stage and the candle are
///   frozen (closing the lid is no free calm-down), and the first step back gets a frame-sized dt, never the pause.
/// - a hinge run resumes only when Feel says the lid is open and still (`HingeLidSource.canResume`); a run coming back
///   from the cover display or the book-pose card waits the same way (the closing card says "Hold still…").
/// - R3 (decision 1): the cover display is ALWAYS a pause. Any small ↔ inner canvas change during a live hinge run
///   holds the closing pause, and a live run never resumes on a small canvas.
/// - R3: the first hinge report of a live run holds the pause too, and the menu's Resume goes through the same gate.
/// - every resume resets the hinge filters and gives `resumeGrace(seconds: 0.5)` of silent lid;
/// - the pause menu opens only on `.background` (P1-8), never while the Duo is shut;
/// - R3 (QA-2 P2-2): the bank, bite and candle-out moments play out under a closing or pose pause, so finishing a run
///   always reaches Results.
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: String, Hashable { case menu, closing, background, pose }

    // MARK: Tuning (named so they're easy to find)

    /// HUD publishing cap.
    static let hudInterval: Double = 1.0 / 15.0
    /// `HUSH-T lid …` at 10 Hz.
    static let lidLogInterval: Double = 0.1
    /// The Duo counts as shut (cover display) at or below this hinge angle, and open again from the release angle.
    static let shutBelow: Double = 10
    static let shutReleaseAbove: Double = 15
    /// The candle's ending is Core's 2 s moment; the Results card follows after this beat.
    static let resultsDelay: Double = 0.5
    /// The run-start line's life (session s).
    static let bannerSeconds: Double = 2.6
    /// Home's title chest publishes at most this often.
    static let homeLidInterval: Double = 1.0 / 30.0
    static let toastSeconds: Double = 2.4
    /// R3: an in-run callout (a one-time tip, the golden banner) stays up this long (wall s).
    static let calloutSeconds: Double = AppRules.calloutSecondsDefault
    /// Portrait requests are throttled to one per this many seconds.
    static let portraitAskInterval: Double = 1.0
    /// Held camera-end-up this long while turned round: "Other way round" (P1-7).
    static let holdHintDelay: Double = 0.7
    /// An event freeze also pauses the scene this long after it lands (CI: the moment stays on screen).
    static let sceneHoldDelay: Double = 0.4
    /// R3 (QA-2 P2-2): if the candle-out moment hasn't finished this long after it began (the scene stopped drawing:
    /// the cover display), the run is finished headless and Results shown.
    static let endWatchSeconds: Double = 2.6
    /// R3 (Feel note): stage announcements wait this long, so VoiceOver's ducking doesn't swallow the audio cue.
    static let announceDelay: Double = 0.3

    // MARK: Published state (the HUD lives in `hud`)

    @Published private(set) var route: AppRoute = .home
    @Published private(set) var scene: ChestScene?
    @Published private(set) var sceneGeneration = 0
    /// A hinge has reported this launch (or on an earlier launch of this Duo).
    @Published private(set) var hingeSeen = false
    /// The Duo is shut (hinge ≤ 10°, released at ≥ 15°).
    @Published private(set) var isShut = false
    @Published private(set) var input: AppInputKind = .slider
    @Published private(set) var isMenuOpen = false
    /// "Lift the lid a little to carry on" / "Hold still…".
    @Published private(set) var isClosingPaused = false
    /// The lid is back up (≥ the resume angle) but not yet still: the closing card says "Hold still…".
    @Published private(set) var closingLifted = false
    /// R3 (P1-4): no hinge report yet this run: the closing card says "Move the lid a little".
    @Published private(set) var closingAwaitsHinge = false
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var lessonDisplay: LessonDisplay?
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover` (and `pose=book`) forces a pose.
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon`: the app icon full screen (and rendered to Documents).
    @Published private(set) var showsIcon = false
    @Published private(set) var mode: RunMode = .run
    /// A short line over Home ("Sign in to Game Center in Settings").
    @Published private(set) var toast: String?
    @Published private(set) var reduceMotion = false
    /// A Game Center sheet is up: the app is drawn un-turned under it (QA-1 P2-6). R11 (QA-6 P2-5): the menu hold lets
    /// go while one is up (a sheet never stays sideways), and is judged again when it goes.
    @Published private(set) var systemSheetUp = false {
        didSet {
            guard systemSheetUp != oldValue else { return }
            refreshMenuHold()
            if !systemSheetUp { scheduleMenuHoldCheck() }
        }
    }
    /// Held camera end up while turned round: the un-turned "Other way round" banner (P1-7).
    @Published private(set) var showsHoldHint = false
    /// Demo event freezes: the scene is paused too, so the moment stays on screen.
    @Published private(set) var sceneHeld = false
    /// The scene's frame rate (R3, Feel: the ceiling while something moves, 60 when idle; 60 under Low Power or heat).
    @Published private(set) var preferredFPS = 120
    /// R6: the canvas's clockwise screen quarter turns (`AppRules.quarterTurns`; 2 = R2's "turned round").
    @Published private(set) var quarterTurns = 0
    /// R6 (ROUND-6 App 6): the closing card has been up `AppRules.carryOnDelay` s: it offers "Carry on".
    @Published private(set) var closingEscape = false
    /// R6: the device's physical orientation (the pose tip shows while it is landscape, like a book).
    @Published private(set) var deviceOrientation: UIDeviceOrientation = .unknown
    /// R6: demo `screen=pose` / `pose=book` force the pose tip on Home (and lesson step 1).
    @Published private(set) var forcedPoseTip = false
    /// R7 (ROUND-7 App 2): on a Duo, mid-chest, the pause coin needs a 0.35 s press-and-hold (`AppRules.pauseNeedsHold`).
    @Published private(set) var pauseNeedsHold = false
    /// R7 (ROUND-7 App 1): the closing card is over a fresh chest (`HeistSession.isFreshChest`): lifting is enough.
    @Published private(set) var closingFresh = false
    /// R8 (QA-5 P1-A): bumped on every mask the app hands iOS; RootView re-reads the interface orientation on it (a
    /// hold let go can make iOS rotate with no size, inset or device change).
    @Published private(set) var orientationEpoch = 0
    /// R8 (QA-5 P1-C): bumped to make `HingeReader` re-subscribe (every cover ↔ inner change, 3 s of silence on the
    /// closing card, "Carry on"), so a hinge gone silent after a hand-off is heard again without backgrounding.
    @Published private(set) var hingeRefresh = 0
    /// R8 (QA-5 P1-B): the cover card has been up `AppRules.coverEscapeDelay` s with the hinge open ≥ 92°: it offers
    /// "Carry on" (in a run) and "Home".
    @Published private(set) var coverEscape = false
    /// R8 (QA-5 P1-B): the player chose the cover card's "Carry on" or "Home": the pose is play until the display
    /// changes or the Duo is shut.
    @Published private(set) var coverOverridden = false
    /// R7 (ROUND-7 App 6): Game Center's sign-in, asked for once the lesson is done (tests replace it).
    var authenticateGameCenter: @MainActor () -> Void = { GameCenterManager.shared.authenticate() }
    /// R7: the sign-in has been asked for this launch.
    private(set) var gameCenterRequested = false
    /// R6: demo `quarter=<0…3>` (DEBUG) forces k where it fits the window (`AppRules.forcedTurnsFit`).
    var demoQuarterTurns: Int? { demo?.quarter }

    let hud = HUDState()
    /// R6 (ROUND-6 App 8): the Diagnostics event log (the last 80 events, kept across launches, on this device only).
    let events: EventLog
    let homeLid = HomeLidState()
    let portraits = PortraitScenes()
    let store: ProgressStore
    let settings: SettingsStore
    let hinge = HingeLidSource()
    /// The play slider: a fresh one each run, so Home's drag never leaks a lid jump (= a speed spike) into a chest.
    private(set) var slider = SliderLidSource()
    /// Home's title chest on an iPhone without a hinge.
    let homeSlider = SliderLidSource()
    private let fixedSource = FixedLidSource()
    private let feedback = FeedbackDirector.shared
    let demo: DemoMode?

    private var session: HeistSession?
    private var pilot: ThiefPilot?
    private var lessonScript: LessonScript?
    private var lessonReplay = false
    private var layout: ScreenLayout?
    private var pauseReasons: Set<PauseReason> = []
    private var closingPause = ClosingPause()
    /// Touch events reach Feedback at once and the scene on the next frame (ARCHITECTURE).
    private var pendingSceneEvents: [HeistEvent] = []
    private var pendingLessonEvents: [HeistEvent] = []
    private var frames = 0
    private var lastHUD: TimeInterval = -1
    private var lastLesson: TimeInterval = -1
    private var lastLidLog: TimeInterval = -1
    private var hintGate = HintGate()
    private var glimmerOn = false
    private var recorded = false
    private var checkpointSaved = false
    private var resultsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var holdHintTask: Task<Void, Never>?
    private var endWatchTask: Task<Void, Never>?
    /// Session seconds stepped this run (the demo freeze-after key).
    private var playTime: Double = 0
    /// Demo freeze: the session no longer steps (the scene keeps drawing the held frame).
    private(set) var frozen = false
    private var freezePendingAt: Double?
    private var freezePendingTag: DemoMode.Freeze?
    /// Demo `noiseUntil=pause`: the `noise=` hold has been let go.
    private var noiseReleased = false
    private var systemReduceMotion = false
    private var homeTicker: FrameTicker?
    private var lastHomeLid: TimeInterval = -1
    private var lastCanvasLine = ""
    private var bannerText: String?
    private var bannerUntil: Double = 0
    /// R12 (CI ask): the hint last logged as `HUSH-T hint <name>` (nil = none).
    private var tracedHint: HeistHint?
    /// R12 (demo `bag=<n>`, DEBUG): the first chest's demo bag, until it is filled.
    private var demoBag: DemoBagPlan?
    /// R12: the run's first step has been logged (`HUSH-T first chest …`).
    private var firstStepLogged = false
    /// R3: the in-run callout (a one-time tip, the golden banner) and until when it shows (wall clock).
    private var callout: String?
    private var calloutUntil: TimeInterval = 0
    /// R5 (ROUND-5 App 7): until then (wall clock) only "Freeze!" or nothing may replace the callout (the first Hush
    /// Chain tip's 3 s).
    private var calloutHoldUntil: TimeInterval = 0
    /// R4: a callout that arrived during the bank beat or the relic card (shown once the next chest is live).
    private var pendingCallout: String?
    /// R4: the relic card is on screen until then. R5 (QA-4 P2-D): on SESSION time (`HeistSnapshot.time`), like the
    /// card itself, so a pause (the menu) can't run the gate out while the card is frozen on screen.
    private var relicCardUntil: TimeInterval = 0
    /// R5 (QA-4 P2-E): VoiceOver's lesson lines ("Slower…" once a step, nothing repeated within 3 s).
    private var lessonSpeech = LessonSpeechGate()
    /// R4 (QA-3 P2-4/5): VoiceOver's stage lines: once per chest for Stirring, and the late one cancellable.
    private var announceGate = AnnounceGate()
    private var stageAnnounceTask: Task<Void, Never>?
    private var lastPortraitAsk: TimeInterval = -100
    /// R2's "turned round" (R6: k == 2).
    var isTurned: Bool { quarterTurns == 2 }
    /// R6: the Carry-on timer and the watchdog (wall clock), while the closing card is up.
    private var closingWatchTask: Task<Void, Never>?
    /// R6: after "Carry on" or a watchdog resume, the closing pause re-engages only on a hinge report newer than this
    /// (a stale low reading can't snap the card straight back).
    private var resumeGuardStamp: TimeInterval?
    /// R6: a nil hinge context is logged once until the next real sample.
    private var hingeNilNoted = false
    private var lastInterfaceNoted: UIInterfaceOrientation?
    /// R2: the gold counter must equal the sum of the banks (checked every frame in demo runs).
    private var bankedSum = 0
    private var goldMismatchLogged = false
    /// R3 (decision 1): the class of the canvas on screen (the cover display is `.small`).
    private var canvasClass: AppRules.CanvasClass?
    /// R3 (REVIEW-2-duo P1-3, Diagnostics): the hinge angle when iOS last handed the app to the cover display, and when
    /// it last relit the inner display.
    private(set) var handoffAngle: Double?
    private(set) var relightAngle: Double?
    /// The Scene's frame rate is published only when it changes.
    private var lastFPS = 120
    /// Tips already looked up this launch (shown, or seen on an earlier one): never looked up again per frame.
    private var tipsChecked: Set<RunTip> = []
    /// R3 (CI `freezeOn=creak`): a CREAK fired since the last frame.
    private var creakPending = false
    /// R3: the first-hinge-report guard is being set (it doesn't release `noiseUntil=pause`).
    private var guardHold = false
    /// R8 (QA-5 P2-2): "Turn the chest round" as it was when Settings opened (nil outside Settings).
    private var frozenTurnRound: Bool?
    /// R8 (QA-5 P2-4): menus hold their orientation at a tabletop angle.
    private var menuHold = MenuOrientationHold()
    /// R8: when the interface orientation (or the display) last changed (the menu hold waits 1 s of calm).
    private var interfaceStableSince: TimeInterval = CACurrentMediaTime()
    private var menuHoldTask: Task<Void, Never>?
    /// R8 (QA-5 P1-B): the cover card's escape timer.
    private var coverWatchTask: Task<Void, Never>?
    private var coverSince: TimeInterval?
    /// R8 (QA-5 P1-B): asking iOS to un-letterbox, while the column lasts.
    private var letterboxTask: Task<Void, Never>?
    /// R8 (QA-5 P2-8): polls a Game Center sheet whose dismissal handler may never fire.
    private var sheetPollTask: Task<Void, Never>?
    /// The last real window size `updateCanvas` saw (the pose lines).
    private var lastCanvasSize: CGSize = .zero
    /// R8 (QA-5 P2-7, demo `hold=closing`): the closing card is held for CI's odd-k tap test until "Carry on".
    private var demoClosingHold = false

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.demo = DemoMode.current
        self.events = EventLog(defaults: Self.keepsEventLog(demo: DemoMode.current) ? .standard : nil)
        // `hush.hasHinge` comes back with a backup restored onto another iPhone: believe it only on a Duo-shaped
        // screen (R3: the cover display counts).
        let stored = UserDefaults.standard.bool(forKey: OrientationLock.hingeKey)
        let trusted = OrientationLock.trustsStoredHinge(stored, screen: UIScreen.main.bounds.size)
        if stored && !trusted { UserDefaults.standard.removeObject(forKey: OrientationLock.hingeKey) }
        self.hingeSeen = trusted
        self.reduceMotion = settings.reduceMotion
        GameCenterManager.shared.bannersAllowed = !trusted
        self.preferredFPS = FeedbackDirector.shared.preferredFPS
        self.lastFPS = self.preferredFPS
        // Feel calls this on the main actor (its notification observers run on the main queue): the CEILING changed.
        FeedbackDirector.shared.onPreferredFPSChange = { [weak self] fps in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.route.isPlay || fps < self.lastFPS { self.publishFPS(fps) }
            }
        }
        // R3 (Feel): the slam's CREAK, picture and sound from one detector.
        FeedbackDirector.shared.onCreakAccent = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.scene?.showCreak()
                self.creakPending = true
                AppTrace.t("HUSH-T event creak")
            }
        }
        OrientationLock.onRefused = { [weak self] in
            MainActor.assumeIsolated { self?.note("portrait ask refused") }
        }
        OrientationLock.onMask = { [weak self] line in
            MainActor.assumeIsolated { self?.maskChanged(line) }
        }
        note("launch \(BuildChannel.versionLine)")
    }

    /// R6: the event log is kept on the device (UserDefaults) except in demo runs and unit tests (in memory).
    nonisolated static func keepsEventLog(demo: DemoMode?) -> Bool {
        demo == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    /// R6 (ROUND-6 App 8): one event for Diagnostics, with the hinge angle now.
    func note(_ event: String) {
        events.add(event, angle: hinge.angle)
    }

    // MARK: - Derived state

    var isDemo: Bool { demo != nil }
    var hasHinge: Bool { hinge.hasHinge }
    var isPaused: Bool { !pauseReasons.isEmpty }
    /// "Turn the chest round" in effect (demo `turn=` wins).
    var wantsTurnRound: Bool { demo?.turn ?? settings.turnRound }
    /// R8 (QA-5 P2-2): the turn-round the canvas is DRAWN with: frozen while Settings is open, so the page never flips
    /// under the finger; the change applies when Settings closes.
    var drawnTurnRound: Bool { AppRules.drawnTurnRound(wanted: wantsTurnRound, frozen: frozenTurnRound) }
    /// R8: a "Turn the chest round" change is waiting for Settings to close.
    var turnRoundPending: Bool { drawnTurnRound != wantsTurnRound }
    var demoFold: Bool { demo?.fold ?? false }
    /// A chest is in play (not finished) on a play route.
    var isLiveRun: Bool {
        guard route.isPlay, let session else { return false }
        return !session.isFinished
    }
    var isScoredDaily: Bool {
        if case let .daily(_, scored) = mode { return scored }
        return false
    }
    var today: Int { DailyClock.today() }
    var dailyScoredAvailable: Bool { store.canPlayScoredDaily(today: today) }
    /// R3 (founder decision 4): the copy follows the LAYOUT, not the input. A fold (a real Duo, or demo `fold=1`)
    /// speaks of the lid; no fold speaks of the lever.
    var layoutHasFold: Bool { layout?.hasFold ?? false }
    var sliderWording: Bool { !layoutHasFold }
    var lessonReplaying: Bool { lessonReplay }
    /// R4 (QA-3 P2-3): the lesson has been banked ("Banked! Gently does it." or the final card is up).
    var lessonFinishing: Bool { mode == .lesson && (lessonScript?.isFinishing ?? false) }
    /// "Daily Dungeon · 27 Oct" for the run's day (nil outside a Daily).
    var dailyMarker: String? {
        guard case let .daily(day, scored) = mode else { return nil }
        return (scored ? "Daily Dungeon · " : "Daily practice · ") + AppRules.dailyDate(day: day)
    }

    /// Settings › About › Diagnostics (DEBUG, or the hidden 2 s press on the version line): the founder's device test
    /// (LAUNCH-RUNBOOK step 9). R4: one fact a line, the hinge angle live (the panel redraws 4 times a second), and
    /// the last hand-off and relight angles kept across launches.
    var diagnosticsLines: [String] {
        AppRules.diagnosticsLines(channel: BuildChannel.current.label, version: BuildChannel.versionLine,
                                  hinge: hinge.angle, input: hasHinge ? "hinge" : "lever",
                                  handoff: handoffAngle ?? Self.storedAngle(Self.handoffKey),
                                  relight: relightAngle ?? Self.storedAngle(Self.relightKey),
                                  resumeAngle: hinge.effectiveResumeAngle,
                                  orientation: OrientationLock.status()
                                      + " · device \(AppRules.deviceName(UIDevice.current.orientation))"
                                      + " · k=\(quarterTurns) fold=\(layoutHasFold ? 1 : 0)")
    }

    /// R7 (ROUND-7 App 5): what Diagnostics' "Copy log" puts on the pasteboard: the event log, then the raw hinge trace
    /// (the last 10 s of reports, `HingeLidSource.traceText()`).
    var diagnosticsCopyText: String {
        AppRules.diagnosticsCopy(log: events.text, trace: hinge.traceText())
    }

    static let handoffKey = "hush.diag.handoff"
    static let relightKey = "hush.diag.relight"

    private static func storedAngle(_ key: String) -> Double? {
        UserDefaults.standard.object(forKey: key) as? Double
    }

    // MARK: - SceneDriver

    /// R2 (UX P0-4): on an iPhone without a fold the lever is always drawn, whoever drives the lid (CI's pilot and
    /// `lid=` frames included); only the player's slider takes its touches (`sliderTouch`). R3 (decision 4): a fold
    /// layout never draws or uses the lever.
    /// R4 (founder, CI R4 frame 32): keyed on the LAYOUT only (`AppRules.usesSlider`): a fold layout never draws or
    /// takes the lever, turned round or not. R6: a Duo is a fold in every orientation, so only phones have a lever.
    var usesSlider: Bool {
        AppRules.usesSlider(playRoute: route.isPlay, layoutHasFold: layoutHasFold, input: input)
    }

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("HUSH-T frame 120") }
        // R10 (VISUAL-REGRESSION-R9 R5): the scene's brass seat fades out whenever PlayLayer hides the coin (the bite
        // is the scene's own flag), so no empty recess sits by a card.
        scene?.pauseSeatHidden = AppRules.pauseCoinHidden(menuOpen: isMenuOpen, closingPaused: isClosingPaused,
                                                          finalLessonCard: route == .lesson
                                                              && (lessonDisplay?.isFinal ?? false))
        var out = pendingSceneEvents
        pendingSceneEvents.removeAll()
        guard let session else { return (HeistSnapshot(), out) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, out) }
        checkClosing(now: now, phase: session.snapshot.phase)
        if frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, dragSpeed: 0, playing: false,
                                                              paused: true))
            return (session.snapshot, out)
        }
        if isPaused {
            let modal = pauseReasons.contains(.menu) || pauseReasons.contains(.background)
            if !AppRules.stepsThroughPause(session.snapshot.phase, menuOrBackground: modal) {
                // R3 (decision 2): no stepping, no rest. Keep the hinge filters warm (Feel's `canResume` reads them).
                if input == .hinge { _ = hinge.lid(at: now) }
                publishFPS(min(feedback.preferredFPS, 60))
                let s = session.snapshot
                feedback.handle([], telemetry: AppRules.telemetry(s, dragSpeed: 0, playing: false, paused: true))
                publishHUD(s, now: now)
                return (s, out)
            }
        }
        // A frame-sized step (clamped at 1/30 s), never the time the game was paused or not drawn (Core R3).
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (session.snapshot, out) }

        var events: [HeistEvent] = []
        let lid = currentLid(now: now, step: step, session: session, events: &events)
        if let level = demo?.noise, !noiseReleased { session.nudgeNoise(to: level) }
        events += session.step(dt: step, lid: lid)
        playTime += step
        // R12 (CI ask, demo `noiseUntil=bite`): the held noise lets go at the first bite.
        if demo?.noiseUntilBite == true, !noiseReleased, events.contains(where: Self.isBite) {
            noiseReleased = true
            AppTrace.t("HUSH-T noise released \(AppTrace.fixed(session.snapshot.noise, 2))")
        }
        if demoBag != nil { events += fillDemoBag(session, now: now) }
        var snapshot = session.snapshot
        if !firstStepLogged {
            // R12 (CI START-OPEN): how the run's first chest began: open at once (rule 2) or closed.
            firstStepLogged = true
            AppTrace.t("HUSH-T first chest phase=\(snapshot.phase == .looting ? "looting" : "ready") "
                       + "openness=\(AppTrace.fixed(snapshot.openness, 2))")
        }

        if var script = lessonScript {
            let lessonIn = lessonInput(snapshot, events: pendingLessonEvents + events, dragSpeed: session.dragSpeed)
            let force = !pendingLessonEvents.isEmpty || !events.isEmpty
            pendingLessonEvents.removeAll()
            let actions = script.update(lessonIn)
            lessonScript = script
            for action in actions {
                switch action {
                case let .nudgeNoise(level): session.nudgeNoise(to: level)
                }
            }
            if !actions.isEmpty { snapshot = session.snapshot }
            publishLesson(script, hint: snapshot.hint, now: now, force: force || !actions.isEmpty)
        }

        let live = AppRules.isLive(snapshot.phase)
        let dragSpeed = session.dragSpeed
        // R12 (Core R12 hook 2): the robbed chest reads angry, so Feedback swaps the sleeping mimic's snore bed for a
        // grumble over it (Core sets its mimic asleep, noise 0, while `awaitingClose`); the creak and tick play on.
        feedback.setRobbed(AppRules.feedbackRobbed(snapshot.phase, awaitingClose: session.awaitingClose))
        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, dragSpeed: dragSpeed, playing: live))
        // R11 (UX P2-5): VoiceOver's bank line names the Hush Chain the same bank raised.
        let chain = Self.chainMultiplier(in: events)
        for event in events {
            if case let .banked(value, _, _) = event { bankedSum += value }
            if case .chestArrived = event, snapshot.chest?.golden == true { feedback.goldenArrived() }
            if case .torchOut = event { watchTheEnd() }
            if case .relicFound = event { noteRelicCard(at: snapshot.time) }
            AppTrace.t("HUSH-T event " + traceLine(event, snapshot: snapshot))
            callouts(for: event, snapshot: snapshot, now: now)
            announce(event, chain: chain)
        }
        if snapshot.noiseFloor >= RunTip.jingleFloor, mode != .lesson { showTip(.jingle, now: now) }
        checkGold(snapshot)
        if AppTrace.enabled && now - lastLidLog >= Self.lidLogInterval {
            lastLidLog = now
            AppTrace.t(AppTrace.lidLine(openness: lid.openness, speed: lid.speed,
                                        angle: input == .hinge ? hinge.angle : nil, noise: snapshot.noise,
                                        stage: snapshot.stage))
        }
        // R3 (Feel, REVIEW-2-duo P2-7): 120 fps only while the lid moves or something animates, else 60.
        let animating = dragSpeed > 0 || !live || now < calloutUntil
        publishFPS(feedback.preferredFPS(lidSpeed: lid.speed, animating: animating))
        publishHUD(snapshot, now: now)
        demoAfterStep(snapshot, events: events)
        if session.isFinished { handleFinished(immediate: false) }
        out += events
        return (snapshot, out)
    }

    private func publishFPS(_ fps: Int) {
        lastFPS = fps
        if preferredFPS != fps { preferredFPS = fps }
    }

    func floorTouchBegan(_ id: Int, at point: CGPoint, time: TimeInterval) {
        guard acceptsTouches, let session else {
            noteTouch { $0.began(at: point, accepted: false, picked: nil) }
            return
        }
        let events = session.touchBegan(id: id, at: point, time: time)
        if isDemo {
            var picked: Int?
            for e in events { if case let .itemPicked(itemID, _) = e { picked = itemID } }
            noteTouch { $0.began(at: point, accepted: true, picked: picked) }
        }
        deliver(events)
    }

    func floorTouchMoved(_ id: Int, to point: CGPoint, time: TimeInterval) {
        if isDemo { debugTrace.moved(to: point) }
        guard acceptsTouches, let session else { return }
        deliver(session.touchMoved(id: id, to: point, time: time))
    }

    /// Ends always arrive (even paused), so an item is never left "held" by a finger that has gone.
    func floorTouchEnded(_ id: Int, at point: CGPoint, time: TimeInterval) {
        guard route.isPlay, input != .pilot, let session, !session.isFinished else {
            noteTouch { $0.ended(at: point, events: []) }
            return
        }
        let events = session.touchEnded(id: id, at: point, time: time)
        noteTouch { $0.ended(at: point, events: events) }
        deliver(events)
    }

    // MARK: - R9: `debug.state` (demo runs; design/notes/fix-k3-drag.md)

    /// The last floor touch, as the App saw it (demo runs only).
    private(set) var debugTrace = DebugTouchTrace()
    /// `debug.state`'s value, in its own object (RootView's probe view observes it, nothing else).
    let debugState = DebugStateProbe()
    private var lastDebugState: TimeInterval = -1

    /// Records a touch step (demo runs only), logs it, and republishes `debug.state` at once.
    private func noteTouch(_ change: (inout DebugTouchTrace) -> Void) {
        guard isDemo else { return }
        change(&debugTrace)
        let p = debugTrace.lastFloor.map { "\(Int($0.x.rounded())),\(Int($0.y.rounded()))" } ?? "-"
        AppTrace.t("HUSH-T touch floor=\(p) hit=\(debugTrace.hitText) ended=\(debugTrace.end.rawValue) "
                   + "paused=\(isPaused ? 1 : 0) input=\(input.rawValue)")
        refreshDebugState(now: CACurrentMediaTime(), force: true)
    }

    /// The `debug.state` line now (pure formatting in `AppRules.debugStateValue`).
    var debugStateLine: String {
        AppRules.debugStateValue(phase: session?.snapshot.phase, paused: pauseReasons.map(\.rawValue), input: input,
                                 quarterTurns: scene?.quarterTurns ?? quarterTurns, trace: debugTrace, route: route,
                                 frozen: frozen, sceneSize: scene?.size, viewSize: scene?.view?.bounds.size,
                                 scaleMode: scene?.scaleMode)
            + Self.rawTouchSummary(scene) + Self.windowTouchSummary
    }

    /// R9b: every touch the scene got, wherever it landed (raw=0 means nothing reached the SKView at all). R11 (QA-6
    /// P2-1): the scene keeps those counters in DEBUG only, so this reads them in DEBUG only (empty in Release).
    private static func rawTouchSummary(_ scene: ChestScene?) -> String {
        #if DEBUG
        return " raw=\(scene?.rawTouchesBegan ?? -1) rawAt=\(scene?.lastRawTouch ?? "-")"
        #else
        return ""
        #endif
    }

    /// R9c: window-level touch counts (DEBUG demo runs only; empty in Release).
    private static var windowTouchSummary: String {
        #if DEBUG
        return " " + DebugWindowTouchCounter.summary
        #else
        return ""
        #endif
    }

    /// Demo runs: republish `debug.state` (at most 4 times a second unless `force`).
    func refreshDebugState(now: TimeInterval, force: Bool = false) {
        guard isDemo, force || now - lastDebugState >= 0.25 || now < lastDebugState else { return }
        lastDebugState = now
        #if DEBUG
        DebugWindowTouchCounter.install()
        #endif
        debugState.set(debugStateLine)
    }

    func sliderTouch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval) {
        guard input == .slider, usesSlider else { return }
        if (isPaused || frozen) && !ended { return }
        let f = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        slider.touch(began: began, ended: ended, fraction: f, time: time)
    }

    private var acceptsTouches: Bool {
        route.isPlay && !isPaused && !frozen && input != .pilot
    }

    private func deliver(_ events: [HeistEvent]) {
        guard !events.isEmpty, let session else { return }
        let s = session.snapshot
        feedback.handle(events, telemetry: AppRules.telemetry(s, dragSpeed: session.dragSpeed,
                                                              playing: AppRules.isLive(s.phase)))
        for event in events { AppTrace.t("HUSH-T event " + traceLine(event, snapshot: s)) }
        pendingSceneEvents += events
        if lessonScript != nil { pendingLessonEvents += events }
    }

    /// R12b: a bank made outside a step (`noteLidShut` under the pause): `deliver` plus what the frame loop does for a
    /// bank (the drawn total, the golden shimmer, the relic card, callouts, VoiceOver).
    private func deliverShutBank(_ events: [HeistEvent]) {
        guard !events.isEmpty, let session else { return }
        deliver(events)
        let s = session.snapshot
        let now = CACurrentMediaTime()
        let chain = Self.chainMultiplier(in: events)
        for event in events {
            if case let .banked(value, _, _) = event { bankedSum += value }
            if case .chestArrived = event, s.chest?.golden == true { feedback.goldenArrived() }
            if case .relicFound = event { noteRelicCard(at: s.time) }
            callouts(for: event, snapshot: s, now: now)
            announce(event, chain: chain)
        }
    }

    /// `HUSH-T event …`, with `golden=1` on a golden chest's arrival (CI's golden-mimic scenario).
    private func traceLine(_ event: HeistEvent, snapshot: HeistSnapshot) -> String {
        let line = AppTrace.describe(event)
        if case .chestArrived = event, snapshot.chest?.golden == true { return line + " golden=1" }
        return line
    }

    /// Demo runs: the drawn counter must be the sum of the banks (testers saw 379 → 179).
    private func checkGold(_ s: HeistSnapshot) {
        guard AppTrace.enabled, !goldMismatchLogged, bankedSum != s.banked else { return }
        goldMismatchLogged = true
        AppTrace.t("HUSH-T gold mismatch banked=\(s.banked) sum=\(bankedSum)")
    }

    // MARK: - Callouts and announcements (R3)

    /// UX P1-3 / P1-8 / P2-11: the first Hush Chain, its first break, the bag jingle (once ever each), and every
    /// golden chest's arrival.
    private func callouts(for event: HeistEvent, snapshot: HeistSnapshot, now: TimeInterval) {
        guard mode != .lesson else { return }
        switch event {
        case .chainUp: showTip(.chain, now: now)
        case .chainBroken: showTip(.chainBroken, now: now)
        case .chestArrived:
            if snapshot.chest?.golden == true { showCallout(RunTip.golden, now: now) }
        default: break
        }
    }

    private func showTip(_ tip: RunTip, now: TimeInterval) {
        guard !tipsChecked.contains(tip) else { return }
        tipsChecked.insert(tip)
        guard !store.data.seenTips.contains(tip.rawValue) else { return }
        store.markTip(tip.rawValue)
        showCallout(tip.text, now: now)
    }

    /// R4 (ROUND-4 App 2): one prompt at a time. A callout that lands under the relic card (or, R5, in the bank beat,
    /// unless it is the bank's own Hush Chain tip) waits until the next chest is live, then shows its full time. R5
    /// (ROUND-5 App 7): the first Hush Chain tip shows AT the bank that earns it and is held 3 s (`AppRules.calloutHold`):
    /// a callout arriving meanwhile waits for it.
    private func showCallout(_ text: String, now: TimeInterval) {
        guard let session else { return }
        let s = session.snapshot
        let heldByAnother = callout != nil && callout != text && now < calloutHoldUntil
        guard !AppRules.calloutBlocked(text, phase: s.phase, relicCardUp: s.time < relicCardUntil), !heldByAnother
        else {
            if pendingCallout == nil { pendingCallout = text }
            return
        }
        if pendingCallout == text { pendingCallout = nil }
        callout = text
        calloutUntil = now + AppRules.calloutSeconds(text)
        calloutHoldUntil = now + AppRules.calloutHold(text)
        AppTrace.t("HUSH-T callout \(text)")
        announceNow(text)
    }

    /// The relic card shows after the bank's stack, one per relic (`SceneMoments`): hints and callouts wait for it.
    /// R5 (QA-4 P2-D): `time` is the session's, the clock the card itself runs on.
    private func noteRelicCard(at time: TimeInterval) {
        let start = max(relicCardUntil, time + SceneMoments.bankGroupEnd)
        relicCardUntil = start + SceneMoments.bannerTime
    }

    /// UX P1-9: VoiceOver hears the stages, the bites and the banks (stages a beat late, after Feel's cue).
    /// R4 (QA-3 P2-4/5): the late stage line is kept, cancelled by a bite, a bank or a pause, and re-checked when it
    /// fires, so it never cuts "Chomp!"; "It's stirring." is said at most once per chest; everything but "Chomp!" and
    /// "It's waking. Freeze!" queues behind what VoiceOver is saying instead of cutting it. In the lesson the step
    /// line speaks for the stages.
    private func announce(_ event: HeistEvent, chain: Double? = nil) {
        switch event {
        case let .chestArrived(index, _, _, _): announceGate.chestArrived(index)
        case .bitten, .banked: cancelStageAnnouncement()
        default: break
        }
        guard let text = HushCopy.announcement(event, chain: chain) else { return }
        if case let .stageChanged(_, to) = event {
            guard mode != .lesson, announceGate.allowsStage(to) else { return }
            cancelStageAnnouncement()
            let queued = HushCopy.queuesAnnouncement(event)
            stageAnnounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(GameController.announceDelay * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                self.stageAnnounceTask = nil
                guard let s = self.session?.snapshot,
                      AppRules.stageAnnouncementDue(to, current: s.stage, phase: s.phase, paused: self.isPaused)
                else { return }
                self.announceNow(text, queued: queued)
            }
        } else {
            announceNow(text, queued: HushCopy.queuesAnnouncement(event))
        }
    }

    /// R11: the multiplier of a `chainUp` among one frame's events (a Hushed bank raises it in the same step). Pure;
    /// tested.
    nonisolated static func chainMultiplier(in events: [HeistEvent]) -> Double? {
        for e in events {
            if case let .chainUp(_, multiplier) = e { return multiplier }
        }
        return nil
    }

    private func cancelStageAnnouncement() {
        stageAnnounceTask?.cancel()
        stageAnnounceTask = nil
    }

    /// `queued`: wait for VoiceOver to finish what it is saying (NSAttributedString +
    /// `.accessibilitySpeechQueueAnnouncement`), else interrupt it.
    private func announceNow(_ text: String, queued: Bool = true) {
        guard !isDemo, UIAccessibility.isVoiceOverRunning else { return }
        if queued {
            let line = NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true])
            UIAccessibility.post(notification: .announcement, argument: line)
        } else {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }

    private func currentLid(now: TimeInterval, step: Double, session: HeistSession,
                            events: inout [HeistEvent]) -> LidInput {
        switch input {
        case .hinge:
            return hinge.lid(at: now)
        case .slider:
            return slider.lid(at: now)
        case .fixed:
            return fixedSource.lid(at: now)
        case .pilot:
            guard var p = pilot else { return fixedSource.lid(at: now) }
            let output = p.step(dt: step, snapshot: session.snapshot)
            pilot = p
            // The pilot's fingers are real touches (ROUND-1 App: "fed to the session as real touches").
            for touch in output.touches {
                switch touch.phase {
                case .began: events += session.touchBegan(id: touch.id, at: touch.point, time: now)
                case .moved: events += session.touchMoved(id: touch.id, to: touch.point, time: now)
                case .ended: events += session.touchEnded(id: touch.id, at: touch.point, time: now)
                }
            }
            return output.lid
        }
    }

    /// R3 (REVIEW-2-duo P1-4): on a Duo (a hinge seen, or a fold layout) a run never plays on the lever. Before the
    /// first hinge report it waits in the closing pause ("Move the lid a little"); demo runs without a hinge hold a
    /// shut lid instead (`.fixed`), so CI's fold frames still draw. R6: "Play anyway" is gone; a Duo always uses the
    /// hinge, in every orientation, and a nil hinge context (fully open) never hands it to the lever.
    private func chooseInput() -> AppInputKind {
        if demo?.pilot != nil { return .pilot }
        if demo?.lid != nil { return .fixed }
        if hinge.hasHinge { return .hinge }
        if hingeSeen || layoutHasFold { return isDemo ? .fixed : .hinge }
        return .slider
    }

    private func setInput(_ kind: AppInputKind) {
        let changed = input != kind
        input = kind
        if changed || session != nil { AppTrace.t("HUSH-T input \(kind.rawValue)") }
    }

    /// The first hinge sample of a launch (or a fold appearing) re-chooses the input (the slider's state is dropped).
    /// R4 (QA-3 P1-1): a live run whose input CHANGES to the hinge (a fold appearing) is never played straight away:
    /// fresh filters, then the closing pause until the lid is open and still. The reverse (QA-3 P2) hands the lever
    /// the lid where it is, so the chest never snaps shut or auto-banks.
    func refreshInput() {
        guard let session else { return }
        let kind = chooseInput()
        guard kind != input else { return }
        let old = input
        let live = isLiveRun
        if AppRules.switchKeepsOpenness(from: old, to: kind, liveRun: live) {
            slider.reset(openness: session.snapshot.openness)
        }
        setInput(kind)
        if AppRules.switchHolds(from: old, to: kind, liveRun: live) {
            hinge.reset()
            closingPause.hold()
            if !hinge.hasHinge { closingAwaitsHinge = true }
            // Not the player's close: CI's `noiseUntil=pause` keeps waiting.
            guardHold = true
            setClosing(true)
            guardHold = false
            AppTrace.t("HUSH-T input switch hold \(old.rawValue)->\(kind.rawValue)")
        }
    }

    // MARK: - Lifecycle hooks from RootView

    func launch() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceOrientation = UIDevice.current.orientation
        if let demo {
            AppTrace.t("HUSH-T dynamic-type \(UIApplication.shared.preferredContentSizeCategory.rawValue)")
            launchDemo(demo)
            return
        }
        // A run killed in the background is filed as left early (its relics, gold and achievements are kept).
        if let recovered = store.recoverPendingRun(today: today) {
            GameCenterManager.shared.report(result: recovered.0, outcome: recovered.1, progress: store.data)
        }
        // P0-1: on a Duo's inner display, ask iOS for portrait at launch (a Duo lying flat never rotates by itself).
        // R3 (P1-2): not while it is held landscape, like a book: then the card speaks.
        if hingeSeen || OrientationLock.looksLikeDuo(OrientationLock.screenSize()) { autoAskPortrait(reason: "launch") }
        if store.data.lessonDone {
            goHome()
        } else {
            // First launch: the First Chest (GAME-DESIGN §8).
            startLesson(replay: false)
        }
    }

    /// R2-compatible form (tests): `turned` is k = 2.
    func updateCanvas(_ size: CGSize, hasFold: Bool, turned: Bool) {
        updateCanvas(size, hasFold: hasFold, quarterTurns: turned ? 2 : 0)
    }

    /// The play canvas changed (fold, quarter turns, size). The scene is built once and then re-laid out. R2: the
    /// scene fills the screen (`ScreenLayout.make(hasFold:viewSize:)`). R6: `size` is the REAL window (the SpriteView's
    /// size); the layout is made from the portrait-equivalent size (w and h swapped when k is odd), and the scene turns
    /// itself k clockwise quarter turns (`ChestScene.quarterTurns`; it sizes itself, never set `scene.size`).
    /// Every change logs `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<k>`.
    /// R8 (QA-5 P1-B, P2-6): `screen` is the window's SCREEN (zero when unknown: tests, before a scene). The display
    /// class is judged with it (`AppRules.displayClass`), so iOS's letterboxed column on the inner display is never a
    /// hand-off; a letterbox drops any hold and asks iOS to un-letterbox (`watchLetterbox`).
    func updateCanvas(_ size: CGSize, hasFold: Bool, quarterTurns k: Int, screen: CGSize = .zero) {
        guard size.width > 10, size.height > 10 else { return }
        lastCanvasSize = size
        let turns = AppRules.normalisedTurns(k)
        let line = AppRules.canvasLine(size, hasFold: hasFold, quarterTurns: turns)
        let letterbox = AppRules.isLetterbox(window: size, screen: screen)
        OrientationLock.setLetterboxed(letterbox)
        let classNow = AppRules.displayClass(window: size, screen: screen)
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
            note(String(line.dropFirst("HUSH-T ".count)))
            // R6: a live run holds the orientation iOS is in now on the inner display (dropped off it). R8: a menu
            // hold too; never while letterboxed (that would keep the column).
            OrientationLock.interfaceChanged(inner: classNow == .inner)
        }
        if letterbox { watchLetterbox(size, screen: screen) }
        noteCanvasClass(classNow)
        if quarterTurns != turns { quarterTurns = turns }
        if turns != 2 && showsHoldHint { showsHoldHint = false }
        let drawn = AppRules.drawnSize(window: size, quarterTurns: turns)
        let newLayout = ScreenLayout.make(hasFold: hasFold, viewSize: drawn)
        let foldChanged = newLayout.hasFold != layout?.hasFold
        if newLayout != layout || scene == nil {
            layout = newLayout
            if let scene {
                scene.layout = newLayout
            } else {
                makeScene(newLayout)
            }
        }
        // A landscape layout (no fold) shows the whole portrait chest (aspect-fit), never a crop. R9: one rule shared
        // with the tests (`AppRules.sceneScaleMode`), the same as `CanvasFit`'s, judged on the DRAWN (pre-turn) frame.
        let mode = AppRules.sceneScaleMode(drawn: drawn)
        if scene?.scaleMode != mode { scene?.scaleMode = mode }
        if let scene, scene.quarterTurns != turns { scene.quarterTurns = turns }
        if foldChanged { refreshInput() }
    }

    /// R3 (decision 1): a small ↔ inner canvas change during a live hinge run holds the closing pause, whatever the
    /// pose does. The hand-off and relight angles are kept for Diagnostics, and a relight lowers Feel's resume angle
    /// to what the player can already see (REVIEW-2-duo P1-3).
    private func noteCanvasClass(_ new: AppRules.CanvasClass?) {
        guard let new, new != canvasClass else { return }
        let old = canvasClass
        canvasClass = new
        // R8 (QA-5 P2-4): a new display restarts the menu hold's calm.
        interfaceStableSince = CACurrentMediaTime()
        scheduleMenuHoldCheck()
        refreshMenuHold()
        guard old != nil else { return }
        // R8 (QA-5 P1-B): a real hand-off ends the cover card's override.
        if coverOverridden { coverOverridden = false }
        // R8 (QA-5 P1-C): iOS may send nothing after a hand-off: re-subscribe, which delivers the current state.
        if hingeSeen { refreshHinge("display \(old?.rawValue ?? "-")->\(new.rawValue)") }
        let angle = hinge.angle
        let a = angle.map { AppTrace.fixed($0, 1) } ?? "-"
        if hingeSeen {
            if new == .small {
                handoffAngle = angle
                if !isDemo, let angle { UserDefaults.standard.set(angle, forKey: Self.handoffKey) }
                AppTrace.t("HUSH-T handoff angle=\(a)")
            } else {
                relightAngle = angle
                if !isDemo, let angle { UserDefaults.standard.set(angle, forKey: Self.relightKey) }
                AppTrace.t("HUSH-T relight angle=\(a)")
                if isLiveRun { hinge.requiredResumeAngle = HingeLidSource.coverResumeAngle(relight: angle) }
            }
        }
        if AppRules.handoverHolds(from: old, to: new, liveHingeRun: isLiveRun && input == .hinge) {
            // R12 rule 4: the cover display took over, so the lid is shut: a robbed chest gets its next chest.
            if new == .small { noteLidShutIfRobbed("cover") }
            closingPause.hold()
            setClosing(true)
            AppTrace.t("HUSH-T handover hold \(old?.rawValue ?? "-")->\(new.rawValue) angle=\(a)")
        }
    }

    /// R10 (VISUAL-REGRESSION-R9 R1): the pause coin's centre in canvas points, from the SwiftUI frame RootView lays
    /// out (`AppCanvas.pauseSeatCanvasCenter`: the safe-area clamp included, after the insets are turned with k).
    private(set) var pauseSeatCanvas: CGPoint?

    /// R10: RootView hands over every drawn frame (k, size, insets); the scene draws the coin's brass seat exactly
    /// where PlayLayer puts the coin.
    func placePauseSeat(_ info: AppCanvas) {
        guard info.size.width > 10, info.size.height > 10 else { return }
        let c = info.pauseSeatCanvasCenter()
        guard c.x.isFinite, c.y.isFinite else { return }
        if let old = pauseSeatCanvas, abs(old.x - c.x) < 0.01, abs(old.y - c.y) < 0.01 { return }
        pauseSeatCanvas = c
        scene?.pauseSeatCanvasCenter = c
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = ChestScene(layout: layout)
        newScene.scaleMode = .aspectFill
        newScene.reduceMotion = reduceMotion
        newScene.quarterTurns = quarterTurns
        newScene.pauseSeatCanvasCenter = pauseSeatCanvas
        newScene.driver = self
        scene = newScene
        sceneGeneration += 1
        newScene.reset()
    }

    /// R2 (P1-8): only `.background` opens the pause menu (folding shut may pass through `.inactive` on hardware, and
    /// then every close would end on the menu). Inactive (Control Centre, a call banner) pauses quietly.
    func setScenePhase(_ phase: ScenePhase) {
        note("phase \(phase == .active ? "active" : (phase == .background ? "background" : "inactive"))")
        if phase == .active {
            AppTrace.t("HUSH-T phase active")
            if input == .hinge { hinge.reset() }
            if checkpointSaved {
                checkpointSaved = false
                store.clearCheckpoint()
            }
            // R3 (QA-2 P2-7): if Game Center's dismissal handler never fired, turn round again now.
            if systemSheetUp && !GameCenterManager.shared.sheetIsUp() {
                systemSheetUp = false
                AppTrace.t("HUSH-T gc sheet cleared on activation")
            }
            setPause(.background, false)
            if route == .home { startHomeTicker() }
            return
        }
        let background = phase == .background
        AppTrace.t("HUSH-T phase \(background ? "background" : "inactive")")
        if background, isLiveRun, !isDemo, let session, !recorded {
            // A kill in the background must not lose the run: keep its result so far until we're back.
            let partial = session.partialResult()
            if AppRules.worthRecording(partial) {
                store.saveCheckpoint(partial)
                checkpointSaved = true
            }
            let shut = input == .hinge && (hinge.angle ?? 180) < AppRules.menuShutAngle
            if !shut { openMenu() }
        }
        setPause(.background, true)
        homeTicker?.stop()
        feedback.silence()
    }

    /// The display's pose changed (the cover display; R6: book pose no longer is one). Every change logs
    /// `HUSH-T pose <pose> reason=<…>`.
    func setPose(_ newPose: AppPose, canvas: CGSize = .zero) {
        guard newPose != pose else { return }
        let old = pose
        pose = newPose
        let reason = AppRules.poseReason(newPose, canvas: canvas, forced: forcedPose != nil, angle: hinge.angle)
        AppTrace.t("HUSH-T pose \(newPose.rawValue) reason=" + reason)
        note("pose \(newPose.rawValue) \(reason)")
        if old == .cover && newPose != .cover && isLiveRun { autoAskPortrait(reason: "cover") }
        // R12 rule 4: the cover display means a shut lid.
        if newPose == .cover && isLiveRun { noteLidShutIfRobbed("cover") }
        if newPose == .play && old != .play && isLiveRun && input == .hinge {
            // Back from the cover display mid-run: wait for an open, still lid (P0-2).
            closingPause.hold()
            setClosing(true)
        }
        setPause(.pose, newPose != .play)
        // R8 (QA-5 P1-B): never on a demo-forced cover card (CI's frame; the forced pose ignores an override).
        if newPose == .cover && forcedPose == nil { startCoverWatch() } else { stopCoverWatch() }
        // R11 (ROUND-11 App 3, demo `escape=1`): CI's frame of the forced cover card with "Already open?" up.
        if newPose == .cover && forcedPose != nil && demo?.coverEscape == true {
            coverEscape = true
            AppTrace.t("HUSH-T cover escape shown forced midRun=\(isLiveRun ? 1 : 0)")
        }
        if newPose == .cover && !isDemo { UIAccessibility.post(notification: .screenChanged, argument: nil) }
    }

    // MARK: - R8: the cover card's escape (QA-5 P1-B, belt and braces)

    private func startCoverWatch() {
        coverWatchTask?.cancel()
        coverSince = CACurrentMediaTime()
        if coverEscape { coverEscape = false }
        coverWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AppRules.coverEscapeDelay * 1_000_000_000))
            // R11 (QA-6 P2-3): a hinge silent since the card went up (a stale ≤ 10° on an open Duo would never offer
            // the escape) is re-subscribed once, like the closing card's.
            if !Task.isCancelled { self?.coverSilenceCheck() }
            while !Task.isCancelled {
                guard let me = self else { return }
                me.checkCoverEscape(now: CACurrentMediaTime())
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopCoverWatch() {
        coverWatchTask?.cancel()
        coverWatchTask = nil
        coverSince = nil
        if coverEscape { coverEscape = false }
    }

    /// Shows (or hides) the cover card's "Carry on" / "Home" (`AppRules.coverOffersEscape`): up 3 s, the last known
    /// hinge angle ≥ 92°. Internal for the tests (they pass a later `now`).
    @discardableResult
    func checkCoverEscape(now: TimeInterval) -> Bool {
        guard pose == .cover, let since = coverSince else {
            if coverEscape { coverEscape = false }
            return false
        }
        let show = AppRules.coverOffersEscape(coverFor: now - since, angle: hinge.lastRawAngle ?? hinge.angle)
        if show != coverEscape {
            coverEscape = show
            if show {
                AppTrace.t("HUSH-T cover escape shown angle=\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
                note("cover escape shown")
                // R11 (QA-6 P2-10): VoiceOver hears it (the card moves focus onto its first button).
                announceEscape(midRun: isLiveRun)
            }
        }
        return show
    }

    /// R11 (QA-6 P2-3): on the cover card, no hinge report since it went up → re-subscribe the hinge once (iOS may have
    /// gone silent after the hand-off). Internal for the tests.
    @discardableResult
    func coverSilenceCheck() -> Bool {
        guard pose == .cover, hingeSeen, let since = coverSince,
              AppRules.hingeSilent(lastSample: hinge.lastSampleTime, since: since) else { return false }
        refreshHinge("cover silent")
        return true
    }

    /// The cover card's "Carry on" (a run): the pose is play from now (until the display changes or the Duo is shut),
    /// the hinge is re-subscribed and the run resumes at once, like the closing card's "Carry on".
    func coverCarryOn() {
        AppTrace.t("HUSH-T cover carry on angle=\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
        note("cover carry on")
        coverOverridden = true
        setPose(.play, canvas: lastCanvasSize)
        if isClosingPaused {
            carryOn()
        } else if hingeSeen {
            refreshHinge("cover carry on")
        }
    }

    /// The cover card's "Home": Home, drawn in play pose (until the display changes or the Duo is shut).
    func coverHome() {
        AppTrace.t("HUSH-T cover home")
        note("cover home")
        coverOverridden = true
        if hingeSeen { refreshHinge("cover home") }
        goHome()
        setPose(.play, canvas: lastCanvasSize)
    }

    // MARK: - R8: a letterboxed column on the inner display (QA-5 P1-B)

    /// The window is cover-sized on the inner screen: iOS's compatibility column. After 0.5 s (a rotation's passing
    /// mismatch never counts), drop any hold and ask for the wide mask; again every 2 s while it lasts (5 tries).
    private func watchLetterbox(_ window: CGSize, screen: CGSize) {
        guard letterboxTask == nil else { return }
        let w = "\(Int(window.width))x\(Int(window.height))"
        let s = "\(Int(screen.width))x\(Int(screen.height))"
        AppTrace.t("HUSH-T letterbox window=\(w) screen=\(s)")
        note("letterbox window=\(w) screen=\(s)")
        letterboxTask = Task { [weak self] in
            for attempt in 0..<5 {
                try? await Task.sleep(nanoseconds: attempt == 0 ? 500_000_000 : 2_000_000_000)
                guard !Task.isCancelled, let me = self else { return }
                guard AppRules.isLetterbox(window: OrientationLock.keyWindowSize(),
                                           screen: OrientationLock.windowScreenSize()) else { break }
                OrientationLock.healLetterbox()
                me.note("letterbox heal")
            }
            self?.letterboxTask = nil
        }
    }

    func setSystemReduceMotion(_ on: Bool) {
        systemReduceMotion = on
        refreshMotion()
    }

    func refreshMotion() {
        let on = systemReduceMotion || settings.reduceMotion
        if reduceMotion != on { reduceMotion = on }
        scene?.reduceMotion = on
        portraits.setReduceMotion(on)
    }

    /// Never while CI holds the Duo sim in landscape on purpose (`orient=landscape`, `pose=book`).
    private var demoHoldsLandscape: Bool { demo?.orient == .landscape || demo?.poseBook == true }

    /// P0-1: ask iOS for portrait (throttled). Logs `HUSH-T orient ask reason=<…> device=<raw>`.
    func askPortrait(reason: String) {
        guard !demoHoldsLandscape else { return }
        let now = CACurrentMediaTime()
        guard now - lastPortraitAsk >= Self.portraitAskInterval else { return }
        lastPortraitAsk = now
        AppTrace.t("HUSH-T orient ask reason=\(reason) device=\(UIDevice.current.orientation.rawValue)")
        OrientationLock.requestPortrait()
    }

    /// R3 (REVIEW-2-duo P1-2): the automatic asks only fire while the device isn't held landscape (like a book).
    private func autoAskPortrait(reason: String) {
        guard AppRules.mayAutoAskPortrait(UIDevice.current.orientation) else {
            AppTrace.t("HUSH-T orient ask skipped reason=\(reason) device=\(UIDevice.current.orientation.rawValue)")
            return
        }
        askPortrait(reason: reason)
    }

    /// R6: RootView's interface orientation changed (logged for Diagnostics, once per change). R8: a hold (run or menu)
    /// is re-captured in it if iOS turned anyway (the mask never disagrees with the interface), and the menu hold's
    /// 1 s of calm starts again.
    func interfaceChanged(_ o: UIInterfaceOrientation) {
        guard o != lastInterfaceNoted else { return }
        lastInterfaceNoted = o
        interfaceStableSince = CACurrentMediaTime()
        OrientationLock.interfaceChanged(inner: canvasClass != .small)
        let held = AppRules.interfaceName(OrientationLock.lockedInterface)
        AppTrace.t("HUSH-T iface \(AppRules.interfaceName(o)) held=\(held)")
        note("interface \(AppRules.interfaceName(o))")
        scheduleMenuHoldCheck()
        refreshMenuHold()
    }

    /// R8 (QA-5 P1-A): every mask handed to iOS: logged, and RootView re-reads the interface (`orientationEpoch`).
    func maskChanged(_ line: String) {
        note(line)
        orientationEpoch &+= 1
    }

    // MARK: - R8: menus hold their orientation at a tabletop angle (QA-5 P2-4)

    /// What the menu hold wants now (`MenuOrientationHold`). Never in demo runs: CI turns the sims itself
    /// (`DemoOrientation`), and a hold would refuse its asks.
    private func menuHoldWanted(menus: Bool, now: TimeInterval) -> Bool {
        guard !isDemo else { return false }
        // R11 (QA-6 P2-5): a system sheet (Game Center, share, copy) is never held sideways under the hold.
        let holdsMenus = menus && AppRules.menuHoldCountsMenus(systemSheetUp: systemSheetUp)
        return menuHold.update(duo: isDuo, menus: holdsMenus, inner: canvasClass != .small,
                               angle: hinge.lastRawAngle ?? hinge.angle, stableFor: now - interfaceStableSince)
    }

    /// Re-judges the menu hold (hinge samples, route, interface and display changes, the 1 s calm). A live run has
    /// its own hold. Internal for the tests (they pass a later `now`).
    func refreshMenuHold(now: TimeInterval = CACurrentMediaTime()) {
        // A live run's hold is handed over in ONE mask by `lockForLiveRun` (a run starting from a held menu never
        // passes through an unlocked mask, in which iOS could start a rotation the run's hold would then capture).
        guard !isLiveRun else { return }
        let on = menuHoldWanted(menus: true, now: now)
        guard on != OrientationLock.menuHold, !demoHoldsLandscape else { return }
        OrientationLock.setMenuHold(on)
        AppTrace.t("HUSH-T menu hold \(on ? "on" : "off")")
    }

    /// The menu hold engages only after 1 s of calm: look again then (nothing else may happen meanwhile).
    private func scheduleMenuHoldCheck() {
        guard !isDemo else { return }
        menuHoldTask?.cancel()
        menuHoldTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((MenuOrientationHold.settleSeconds + 0.05) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshMenuHold()
        }
    }

    // MARK: - R6: the pose tip (book pose never blocks)

    /// A Duo: a hinge seen, or a fold layout.
    var isDuo: Bool { hingeSeen || layoutHasFold }

    /// "Stand it up like a little laptop": a small, dismissible tip on Home and lesson step 1, while the device is held
    /// landscape (like a book). Never blocks anything.
    /// R8 (QA-5 P2-3): hidden while the closing card or the pause menu is up (it would cover their buttons).
    var showsPoseTip: Bool {
        AppRules.showsPoseTip(duo: isDuo, route: route, lessonStep: lessonDisplay?.step, device: deviceOrientation,
                              dismissed: store.data.seenTips.contains(AppRules.poseTipKey), forced: forcedPoseTip,
                              cardUp: !AppRules.poseTipAllowed(closingCard: isClosingPaused, menu: isMenuOpen))
    }

    /// The tip's ✕: never again.
    func dismissPoseTip() {
        forcedPoseTip = false
        store.markTip(AppRules.poseTipKey)
        AppTrace.t("HUSH-T pose tip dismissed")
        note("pose tip dismissed")
    }

    /// RootView saw the tip appear or go: `HUSH-T pose tip shown|hidden` (CI's POSE-CARD).
    func poseTipShown(_ on: Bool) {
        AppTrace.t("HUSH-T pose tip \(on ? "shown" : "hidden")")
        note("pose tip \(on ? "shown" : "hidden")")
    }

    /// P1-7: the device's physical orientation changed (UIDevice notifications, begun at launch).
    func deviceOrientationChanged() {
        let o = UIDevice.current.orientation
        AppTrace.t("HUSH-T device-orient \(o.rawValue)")
        if o != deviceOrientation {
            deviceOrientation = o
            note("device \(AppRules.deviceName(o))")
        }
        refreshHoldHint()
    }

    /// The "Other way round" banner: held camera end up while drawn turned round (`AppRules.readsUpsideDown`), for
    /// `holdHintDelay` s. R7 (DEVICE-RISKS-1 item 9): in menus the hinge may be open to 180° (a Duo picked up flat).
    private func refreshHoldHint() {
        holdHintTask?.cancel()
        let o = UIDevice.current.orientation
        guard AppRules.readsUpsideDown(turned: isTurned, cameraUp: o == .portrait, angle: hinge.angle,
                                       inMenus: !route.isPlay) else {
            if showsHoldHint { showsHoldHint = false }
            return
        }
        holdHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.holdHintDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            let still = AppRules.readsUpsideDown(turned: self.isTurned,
                                                 cameraUp: UIDevice.current.orientation == .portrait,
                                                 angle: self.hinge.angle, inMenus: !self.route.isPlay)
            if still != self.showsHoldHint { self.showsHoldHint = still }
        }
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval) {
        guard angle.isFinite else { return }
        let first = !hinge.hasHinge
        hinge.ingest(angleDegrees: angle, at: time)
        if !hingeSeen {
            hingeSeen = true
            if !isDemo { UserDefaults.standard.set(true, forKey: OrientationLock.hingeKey) }
            OrientationLock.hingeArrived()
            feedback.deviceHasFold = true
            GameCenterManager.shared.bannersAllowed = false
        }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
            // R8 (QA-5 P1-B): shut for real: the cover card's override ends.
            if coverOverridden { coverOverridden = false }
            // R12 rule 4: shut is shut; a robbed chest waiting for the close gets its next chest.
            if isLiveRun { noteLidShutIfRobbed("shut") }
        }
        // R8 (QA-5 P2-4): the menu hold follows the hinge (cheap: it only touches the mask when it flips).
        refreshMenuHold()
        if hingeNilNoted {
            hingeNilNoted = false
            note("hinge back \(AppTrace.fixed(angle, 1))")
        }
        refreshInput()
        if closingAwaitsHinge { closingAwaitsHinge = false }
        // R3 (REVIEW-2-duo P1-4): the first report of a live run is never played straight away. Fresh filters, then
        // the closing pause: the run carries on once the lid is open and still.
        if first && isLiveRun && input == .hinge {
            hinge.reset()
            closingPause.hold()
            // Not the "first pause" CI's `noiseUntil=pause` waits for (that is the player's close).
            guardHold = true
            setClosing(true)
            guardHold = false
            AppTrace.t("HUSH-T first hinge sample held angle=\(AppTrace.fixed(angle, 1))")
        }
    }

    /// After a hinge has been seen, a nil is a display handover (or the Duo fully open), never "no hinge" (Brim
    /// research). R6 (ROUND-6 App 7): it changes nothing: the last angle and the hinge input are kept (never the
    /// lever). It is only logged, once until the next sample.
    func hingeUnavailable() {
        guard !hingeNilNoted else { return }
        hingeNilNoted = true
        AppTrace.t("HUSH-T hinge nil angle=\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
        note("hinge nil")
    }

    /// The closing pause (`ClosingPause`): Feel's gate (θ < `Tuning.closingAngle`, 70°, for 0.4 s) or shut pauses; it
    /// lifts only when `hinge.canResume` (open ≥ the resume angle and still) AND the canvas is the inner display.
    /// R3 (QA-2 P2-2): it only engages while a chest is live; a hold made during a moment waits for the next chest.
    private func checkClosing(now: TimeInterval, phase: RunPhase) {
        // R8 (demo `hold=closing`): CI's odd-k tap test keeps the card up until it taps "Carry on".
        if demoClosingHold { return }
        guard input == .hinge, route.isPlay, session != nil else {
            if closingPause.paused || isClosingPaused {
                closingPause.clear()
                setClosing(false)
            }
            return
        }
        let angle = hinge.angle
        let lifted = (angle ?? 0) >= hinge.effectiveResumeAngle
        if lifted != closingLifted { closingLifted = lifted }
        // R4 (QA-3 P2-3): the lesson's pay-off ("Banked!", then the final card) is never hidden by the closing card.
        let finishing = lessonFinishing
        if finishing && (closingPause.paused || isClosingPaused) {
            closingPause.clear()
            setClosing(false)
        }
        guard AppRules.closingApplies(phase, lessonFinishing: finishing) else { return }
        // R6: after "Carry on" (or the watchdog) only a NEW hinge report may close the card again.
        if let stamp = resumeGuardStamp {
            if let t = hinge.lastSampleTime, t > stamp {
                resumeGuardStamp = nil
            } else {
                return
            }
        }
        if closingPause.paused && !isClosingPaused { setClosing(true) }
        // R12 rule 4: under any closing card (a menu Resume's hold included), a lid seen in the shut zone is a closed
        // lid: a robbed chest still waiting gets its next chest (the session doesn't step while paused).
        if isClosingPaused, let a = angle, a.isFinite, a <= Tuning.hingeShutZoneAngle { noteLidShutIfRobbed("closing") }
        // R7 (ROUND-7 App 1, DEVICE-RISKS-1 item 3): over a fresh chest (banked, then folded on down), lifting the lid
        // to Feel's line is enough: no "Hold still…". A chest in play keeps the full rule.
        let fresh = session?.isFreshChest ?? false
        if fresh != closingFresh { closingFresh = fresh }
        let still = hinge.canResume
        let resumable = AppRules.mayResume(canResume: AppRules.closingResumes(canResume: still, freshChest: fresh,
                                                                              lifted: lifted),
                                           canvas: canvasClass)
        switch closingPause.update(angle: angle, gateClosing: hinge.isClosing, isShut: isShut,
                                   canResume: resumable, now: now) {
        case .resumed? where fresh && !still:
            setClosing(false)
            session?.resumeGrace(seconds: AppRules.freshResumeGrace)
            AppTrace.t("HUSH-T fresh chest resume angle=\(angle.map { AppTrace.fixed($0, 1) } ?? "-")")
            note("fresh chest resume")
        case .paused?:
            // R12 rule 4: a robbed chest folded shut too fast for a step in the shut zone still gets its next chest
            // (Core deals it now; `chestArrived` comes with the first step back), so the reopen is a fresh chest.
            noteLidShutIfRobbed("closing")
            setClosing(true)
            #if DEBUG
            // A literal of its own, DEBUG only: CI's TestFlight guard greps the Release binary for it.
            if AppTrace.enabled {
                print("HUSH-T paused closing")
                fflush(stdout)
            }
            #endif
        case .resumed?:
            setClosing(false)
        case nil:
            break
        }
    }

    /// R12 rule 4 (Core's `noteLidShut`): the lid was seen shut (the closing pause began, the cover display took over,
    /// the Duo folded flat) while the robbed chest waited, perhaps with no step in the shut zone: Core deals the next
    /// chest now (`chestArrived` with the first step back), so the reopen opens a fresh chest. Never from a hold that
    /// isn't the lid closing (the menu's Resume, the first hinge report, an input switch): the lid may be open then.
    /// R12b (CI BANK-CLOSE-FULL): the same signals bank a chest with loot in the bag (`canBankOnShut`): the cover
    /// display took over, or the pause began, before the shut-zone hold finished. Its events are delivered now.
    private func noteLidShutIfRobbed(_ reason: String) {
        guard let session else { return }
        if session.canBankOnShut {
            deliverShutBank(session.noteLidShut())
            let fresh = session.isFreshChest
            if fresh != closingFresh { closingFresh = fresh }
            AppTrace.t("HUSH-T banked under the pause reason=\(reason)")
            note("banked on shut (\(reason))")
            return
        }
        guard session.awaitingClose else { return }
        session.noteLidShut()
        let fresh = session.isFreshChest
        if fresh != closingFresh { closingFresh = fresh }
        AppTrace.t("HUSH-T next chest dealt under the pause reason=\(reason)")
        note("next chest dealt (\(reason))")
    }

    private func setClosing(_ on: Bool) {
        let changed = isClosingPaused != on
        if changed { isClosingPaused = on }
        if on { resumeGuardStamp = nil }
        setPause(.closing, on)
        if changed {
            if on { startClosingWatch() } else { stopClosingWatch() }
            // R11 (UX P2-1): VoiceOver is told the card is up, with its title (the coin it was on has gone).
            if on {
                postAccessibility(.screenChanged, ClosingCard.title(lifted: closingLifted,
                                                                    awaitingHinge: closingAwaitsHinge,
                                                                    fresh: closingFresh))
            }
        }
    }

    /// R11 (UX P2-1, QA-6 P2-10): a VoiceOver notification (never in demo runs, only while VoiceOver runs).
    private func postAccessibility(_ notification: UIAccessibility.Notification, _ text: String) {
        guard !isDemo, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: notification, argument: text)
    }

    /// R11 (UX P2-1): an escape (Carry on, or the cover card's plate) has appeared: say so. The card itself moves
    /// VoiceOver's focus onto its first button.
    private func announceEscape(midRun: Bool) {
        announceNow(AppRules.escapeAnnouncement(midRun: midRun))
    }

    // MARK: - R6: never stuck (Carry on, the watchdog)

    /// The closing card's "Carry on" (shown after `AppRules.carryOnDelay` s): resumes at once, whatever the hinge
    /// says. Fresh filters, then `AppRules.carryOnGrace` s of silent lid. Only a NEW hinge report may close it again.
    /// R8 (QA-5 P1-C): it also re-subscribes the hinge (a dead subscription would otherwise play a frozen lid); the
    /// reports that re-subscription delivers in the next `AppRules.carryOnRefreshGrace` s never close the card again.
    func carryOn() {
        guard isClosingPaused else { return }
        AppTrace.t("HUSH-T carry on angle=\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
        note("carry on")
        let refresh = input == .hinge
        if refresh { refreshHinge("carry on") }
        forceResumeFromClosing(refreshGrace: refresh ? AppRules.carryOnRefreshGrace : 0)
    }

    /// Shared by "Carry on" and the watchdog.
    private func forceResumeFromClosing(refreshGrace: Double = 0) {
        demoClosingHold = false
        hinge.reset()
        closingPause.clear()
        if closingAwaitsHinge { closingAwaitsHinge = false }
        setClosing(false)
        let last = hinge.lastSampleTime ?? -Double.infinity
        resumeGuardStamp = refreshGrace > 0 ? max(last, CACurrentMediaTime() + refreshGrace) : last
        if let session { session.resumeGrace(seconds: AppRules.carryOnGrace) }
    }

    /// R8 (QA-5 P1-C): make `HingeReader` re-subscribe (it delivers the current hinge state). Logged.
    func refreshHinge(_ reason: String) {
        hingeRefresh &+= 1
        AppTrace.t("HUSH-T hinge refresh \(reason)")
        note("hinge refresh \(reason)")
    }

    /// Seconds the current closing card has been up (wall clock), nil when none is.
    private var closingSince: TimeInterval?

    private func startClosingWatch() {
        closingWatchTask?.cancel()
        closingSince = CACurrentMediaTime()
        if closingEscape { closingEscape = false }
        closingWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AppRules.carryOnDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if self.isClosingPaused && !self.closingEscape {
                self.closingEscape = true
                self.announceEscape(midRun: true)
            }
            // R11 (QA-6 P2-2): re-subscribe a silent hinge now, but change the words only if it is still silent 1 s
            // later (a healthy hinge at rest re-delivers at once, so the title never flickers as Carry on appears).
            if self.closingSilenceRefresh() {
                try? await Task.sleep(nanoseconds: UInt64(AppRules.closingCopyCheckDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.closingSilenceCopy()
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                if self.watchdogCheck(now: CACurrentMediaTime()) { return }
            }
        }
    }

    /// R8 (QA-5 P1-C, P2-5): 3 s on the closing card with no hinge report since it went up: re-subscribe the hinge
    /// (iOS may have gone silent after a hand-off), and say "Move the lid a little" (the last angle can't be trusted:
    /// it may say "Lift the lid" on a flat Duo). The next report puts the true words back. Internal for the tests.
    @discardableResult
    func closingSilenceCheck() -> Bool {
        guard closingSilenceRefresh() else { return false }
        closingSilenceCopy()
        return true
    }

    /// R11 (QA-6 P2-2): the 3 s half: no report since the card went up → re-subscribe the hinge. Internal for the
    /// tests.
    @discardableResult
    func closingSilenceRefresh() -> Bool {
        guard closingHingeSilent else { return false }
        refreshHinge("closing silent")
        return true
    }

    /// R11 (QA-6 P2-2): the 4 s half: still nothing → "Move the lid a little". Internal for the tests.
    @discardableResult
    func closingSilenceCopy() -> Bool {
        guard closingHingeSilent else { return false }
        if !closingAwaitsHinge { closingAwaitsHinge = true }
        return true
    }

    /// No hinge report has arrived since the closing card went up.
    private var closingHingeSilent: Bool {
        guard isClosingPaused, input == .hinge, let since = closingSince else { return false }
        return AppRules.hingeSilent(lastSample: hinge.lastSampleTime, since: since)
    }

    private func stopClosingWatch() {
        closingWatchTask?.cancel()
        closingWatchTask = nil
        closingSince = nil
        if closingEscape { closingEscape = false }
    }

    /// R6 (ROUND-6 App 6): the watchdog (`AppRules.watchdogResumes`). Returns true once it has resumed (or there is
    /// nothing left to watch). Internal for the tests.
    @discardableResult
    func watchdogCheck(now: TimeInterval) -> Bool {
        guard isClosingPaused, let since = closingSince else { return true }
        let only = pauseReasons == [.closing] && pose == .play
        // The last KNOWN angle: the raw report (the filtered angle may still be gliding after a reset).
        guard AppRules.watchdogResumes(pausedFor: now - since, onlyClosing: only, liveRun: isLiveRun && !frozen,
                                       canvas: canvasClass, angle: hinge.lastRawAngle ?? hinge.angle,
                                       resumeAngle: hinge.effectiveResumeAngle)
        else { return false }
        AppTrace.t("HUSH-T watchdog resume angle=\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
        note("watchdog resume")
        forceResumeFromClosing()
        return true
    }

    /// Tests: pretend the closing card went up `seconds` ago.
    func backdateClosing(by seconds: TimeInterval) {
        if let since = closingSince { closingSince = since - seconds }
    }

    // MARK: - Home's title chest

    /// Home on an iPhone without a hinge: the drag on the title chest (fraction 0 shut … 1 wide).
    func homeChestDrag(began: Bool, ended: Bool, fraction: Double) {
        let f = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        homeSlider.touch(began: began, ended: ended, fraction: f, time: CACurrentMediaTime())
    }

    private func startHomeTicker() {
        if homeTicker == nil {
            homeTicker = FrameTicker { [weak self] now in self?.tickHome(now) }
        }
        homeTicker?.start()
    }

    private func tickHome(_ now: TimeInterval) {
        guard route == .home else {
            homeTicker?.stop()
            return
        }
        let lid: LidInput
        if let held = demo?.lid {
            lid = LidInput(openness: held, speed: 0, inShutZone: held <= 0.15, tooWide: false)
        } else if hinge.hasHinge {
            lid = hinge.lid(at: now)
        } else {
            lid = homeSlider.lid(at: now)
        }
        feedback.homeLid(speed: lid.speed, openness: lid.openness)
        let portrait = portraits.home
        let tier = PortraitScenes.homeTier(rank: store.rank)
        if portrait.tier != tier { portrait.tier = tier }
        portrait.openness = lid.openness
        portrait.wake = PortraitScenes.wake(speed: lid.speed)
        guard now - lastHomeLid >= Self.homeLidInterval else { return }
        lastHomeLid = now
        homeLid.update(HomeLid(openness: (lid.openness * 100).rounded() / 100, speed: lid.speed.rounded()))
    }

    // MARK: - Navigation

    func show(_ newRoute: AppRoute) {
        guard !newRoute.isPlay else { return }
        if newRoute == .home {
            goHome()
            return
        }
        setRoute(newRoute)
    }

    func play() { start(.run) }

    func playDaily() { start(.daily(day: today, scored: true)) }

    func practiseDaily() { start(.daily(day: today, scored: false)) }

    /// Results' Again (a Daily is always practised: `AppRules.againMode`).
    func again() {
        start(summary.map { AppRules.againMode($0.result.mode) } ?? .run)
    }

    func openMenu() {
        guard route.isPlay, !isMenuOpen else { return }
        isMenuOpen = true
        setPause(.menu, true)
    }

    /// R3 (QA-2 P2-10, REVIEW-2-duo P2-6): a hinge run's Resume goes through the hinge gate: the closing pause holds
    /// it (taken BEFORE the menu reason is dropped, so the run never steps in between) until the lid is open and still.
    func resume() {
        guard isMenuOpen else { return }
        if input == .hinge && isLiveRun {
            closingPause.hold()
            setClosing(true)
        }
        isMenuOpen = false
        setPause(.menu, false)
    }

    /// The pause menu's Restart: a scored Daily restarts as practice (one scored try a day).
    func restart() {
        switch mode {
        case .lesson:
            startLesson(replay: lessonReplay)
        case let .daily(day, _):
            start(.daily(day: day, scored: false))
        case .run, .attract:
            start(mode)
        }
    }

    var restartLabel: String { isScoredDaily ? "Restart as practice" : "Restart" }

    func goHome() {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        session = nil
        pilot = nil
        lessonScript = nil
        lessonDisplay = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        callout = nil
        calloutHoldUntil = 0
        pendingCallout = nil
        cancelStageAnnouncement()
        setGlimmer(false)
        lockForLiveRun(false)
        feedback.silence()
        feedback.idle = true
        hud.update(hint: nil, banner: nil, stage: .asleep, bagCount: 0, debugLoot: nil, spoken: SpokenHUD(),
                   biting: false)
        setRoute(.home)
        refreshIdleTimer()
    }

    func showGameCenter() {
        let result = GameCenterManager.shared.showDashboard(onDismiss: { [weak self] in
            self?.systemSheetUp = false
        })
        switch result {
        case .shown, .signingIn:
            systemSheetUp = true
            watchSystemSheet()
        case .signedOut: showToast("Sign in to Game Center in Settings")
        }
    }

    /// R8 (QA-5 P2-8): if the dismissal handler never fires, the app turns round again once no sheet has been up for
    /// two polls in a row (1 Hz, from 2 s after it was asked for, so a sheet still on its way never counts).
    private func watchSystemSheet() {
        sheetPollTask?.cancel()
        sheetPollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            var missing = 0
            while !Task.isCancelled {
                guard let me = self, me.systemSheetUp else { return }
                missing = GameCenterManager.shared.sheetIsUp() ? 0 : missing + 1
                if missing >= 2 {
                    me.systemSheetUp = false
                    AppTrace.t("HUSH-T gc sheet cleared by poll")
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.toastSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func setRoute(_ newRoute: AppRoute) {
        let changed = newRoute != route
        if changed {
            // R8 (QA-5 P2-2): Settings keeps the turn-round it opened with; the new one applies as it closes. Set
            // before the route is published, so RootView never draws a frame with the other value.
            if newRoute == .settings {
                frozenTurnRound = wantsTurnRound
            } else if frozenTurnRound != nil {
                frozenTurnRound = nil
                if route == .settings { AppTrace.t("HUSH-T turn round applied \(wantsTurnRound ? 1 : 0)") }
            }
            route = newRoute
            AppTrace.t("HUSH-T screen \(newRoute.rawValue)")
        }
        // R8 (QA-5 P2-4): menus and runs hold orientation differently.
        refreshMenuHold()
        if newRoute == .home { startHomeTicker() } else { homeTicker?.stop() }
        feedback.idle = !newRoute.isPlay
        if !newRoute.isPlay { publishFPS(min(feedback.preferredFPS, 60)) }
        // R7 (ROUND-7 App 6): Game Center signs in only once the lesson is done and off screen.
        authenticateGameCenterIfReady()
        // R7 (DEVICE-RISKS-1 item 9): menus and runs judge "Other way round" differently (170 vs 180°).
        if changed { refreshHoldHint() }
    }

    /// R7 (ROUND-7 App 6, DEVICE-RISKS-1 item 9): Game Center's sign-in (and its welcome banner, drawn by iOS at the
    /// player's near edge on a turned Duo) waits until the First Chest is done and the player is on Home. Called at
    /// launch (the App's `onAppear`) and on every route change; it asks once.
    func authenticateGameCenterIfReady() {
        guard !gameCenterRequested,
              AppRules.mayAuthenticateGameCenter(demo: isDemo, lessonDone: store.data.lessonDone, route: route)
        else { return }
        gameCenterRequested = true
        AppTrace.t("HUSH-T gc authenticate route=\(route.rawValue)")
        authenticateGameCenter()
    }

    // MARK: - The First Chest lesson

    func startLesson(replay: Bool, at step: LessonScript.Step = .pose) {
        lessonReplay = replay
        start(.lesson)
        lessonSpeech = LessonSpeechGate()
        let script = LessonScript(start: step, replay: replay)
        lessonScript = script
        publishLesson(script, hint: nil, now: 0, force: true)
    }

    func replayLesson() { startLesson(replay: true) }

    /// Skip (offered after step 2): the lesson counts as done.
    /// R11 (UX P1-2): a FIRST lesson's Skip lands on the stakes card ("Here's the gist, little thief.": the candle, the
    /// bite, the bank and how to pause), whose "Got it" starts the first run and "Not yet, take me home" goes Home. A
    /// replay's Skip still goes straight Home.
    func skipLesson() {
        store.markLessonDone()
        guard !lessonReplay, route == .lesson, var script = lessonScript else {
            goHome()
            return
        }
        script.skipToStakes()
        lessonScript = script
        AppTrace.t("HUSH-T lesson skipped to the gist")
        note("lesson skipped")
        publishLesson(script, hint: nil, now: CACurrentMediaTime(), force: true)
    }

    /// R11 (UX P1-1): the Results nudge's "Make it forgiving": Lid sensitivity is Forgiving from the next run on.
    func makeLidForgiving() {
        settings.lidSensitivity = .forgiving
        AppTrace.t("HUSH-T forgiving chosen on results")
        note("forgiving chosen on results")
    }

    /// The final card's "Got it": the first run.
    func finishLesson() {
        store.markLessonDone()
        start(.run)
    }

    func finishLessonHome() {
        store.markLessonDone()
        goHome()
    }

    private func lessonInput(_ s: HeistSnapshot, events: [HeistEvent], dragSpeed: Double) -> LessonScript.Input {
        var bagged = 0
        var grabbable = false
        var held: [Int: CGPoint] = [:]
        for item in s.loot {
            if item.place == .inBag { bagged += 1 }
            if item.place == .inChest && item.grabbable { grabbable = true }
            // R7 (DEVICE-RISKS-1 item 11): the Freeze step judges held items by displacement.
            if case .held = item.place { held[item.id] = item.position }
        }
        return LessonScript.Input(time: s.time, angle: input == .hinge ? hinge.angle : nil, hasHinge: input == .hinge,
                                  openness: s.openness, lidSpeed: s.lidSpeed, dragSpeed: dragSpeed,
                                  anyGrabbable: grabbable, bagCount: bagged, noise: s.noise, hint: s.hint,
                                  events: events, held: held)
    }

    /// The card's strings are built at ≤ 15 Hz (QA-1 P2-14), at once when something happened.
    private func publishLesson(_ script: LessonScript, hint: HeistHint?, now: TimeInterval, force: Bool) {
        guard force || now - lastLesson >= Self.hudInterval else { return }
        lastLesson = now
        // R12 rule 7: the session's openness, so the open step never says "open" to an open lid.
        let display = script.display(slider: sliderWording, angle: input == .hinge ? hinge.angle : nil, hint: hint,
                                     openness: session?.snapshot.openness)
        if display != lessonDisplay {
            if display.step != lessonDisplay?.step || display.praise != lessonDisplay?.praise
                || display.line != lessonDisplay?.line {
                AppTrace.t("HUSH-T lesson step \(display.step) praise=\(display.praise ? 1 : 0) line '\(display.line)'")
            }
            // R6: past step 1 the pose tip never shows again.
            if display.step > 1 && !store.data.seenTips.contains(AppRules.poseTipKey) {
                store.markTip(AppRules.poseTipKey)
            }
            // R4 (QA-3 P2, UX P2-9): VoiceOver hears each step, praise and warning, and the final card.
            // R5 (QA-4 P2-E): "Slower…" once a step, and no line again within 3 s (it used to alternate).
            if let said = LessonDisplay.announcement(from: lessonDisplay, to: display),
               lessonSpeech.allows(said, step: display.step, now: now) {
                announceNow(said)
            }
            lessonDisplay = display
        }
    }

    // MARK: - Runs

    private func start(_ newMode: RunMode) {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        summary = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        freezePendingAt = nil
        freezePendingTag = nil
        noiseReleased = false
        callout = nil
        calloutUntil = 0
        calloutHoldUntil = 0
        pendingCallout = nil
        relicCardUntil = 0
        announceGate = AnnounceGate()
        cancelStageAnnouncement()
        var m = newMode
        if case let .daily(day, scored) = m, scored {
            if store.canPlayScoredDaily(today: day) {
                store.startDaily(day: day)
            } else {
                m = .daily(day: day, scored: false)
            }
        }
        mode = m
        let runSeed = seed(for: m)
        // R7 (ROUND-7 App 4): the player's Lid sensitivity (the scored Daily is forced to Normal by Core).
        let options: SessionOptions = m == .lesson ? LessonChest.options
            : SessionOptions.`for`(m, sensitivity: settings.lidSensitivity)
        session = HeistSession(mode: m, seed: runSeed, bestRun: store.best(for: m), foundRelics: store.data.foundRelics,
                               options: options)
        slider = SliderLidSource()
        fixedSource.reset()
        pilot = demo?.pilot.map { ThiefPilot(skill: $0, seed: runSeed &+ 101) }
        if m != .lesson {
            lessonScript = nil
            lessonDisplay = nil
        }
        recorded = false
        playTime = 0
        bankedSum = 0
        goldMismatchLogged = false
        hintGate = HintGate()
        setGlimmer(false)
        lastHUD = -1
        lastLesson = -1
        pendingSceneEvents.removeAll()
        pendingLessonEvents.removeAll()
        debugTrace = DebugTouchTrace()
        bannerText = Self.startBanner(m)
        bannerUntil = bannerText == nil ? 0 : Self.bannerSeconds
        tracedHint = nil
        firstStepLogged = false
        demoBag = m == .lesson ? nil : demo?.bagItems.map { DemoBagPlan($0) }
        scene?.reset()
        // R3 (decision 3): "not safe yet" under IN BAG while the teaching runs last.
        scene?.showsBagSublabel = store.data.runs < AppRules.teachingRuns
        setInput(chooseInput())
        if input == .hinge {
            hinge.reset()
            hinge.requiredResumeAngle = HingeLidSource.resumeAngle
        }
        // R12 rule 2: Play pressed with the lid up goes straight into an open first chest, so the first frame's
        // banner already follows the lid (the HUD follows it every frame after).
        let startOpen = input == .hinge && hinge.hasHinge && AppRules.lidReadsOpen(hinge.lastLid.openness)
        hud.update(hint: nil, banner: Self.startBanner(m, lidOpen: startOpen) ?? bannerText, stage: .asleep,
                   bagCount: 0, debugLoot: nil, spoken: SpokenHUD(), biting: false, lidOpen: startOpen)
        setRoute(m == .lesson ? .lesson : .playing)
        // R3 (P1-4): a Duo run with no hinge report yet waits, shut and paused, for the lid to move.
        if input == .hinge && !hinge.hasHinge {
            closingAwaitsHinge = true
            closingPause.hold()
            setClosing(true)
        }
        lockForLiveRun(true)
        refreshIdleTimer()
    }

    /// The run-start line (≤ 6 words), shown while no hint is up. R12: with the lid already open (the run started with
    /// it up, rule 2) it never says "open": "Candle lit. Gently does it."
    nonisolated static func startBanner(_ mode: RunMode, lidOpen: Bool = false) -> String? {
        switch mode {
        case .run: return lidOpen ? "Candle lit. Gently does it." : "Candle lit. Open it gently."
        case let .daily(day, scored):
            return scored ? "Daily Dungeon · " + AppRules.dailyDate(day: day) : "Practice: no score today"
        case .attract, .lesson: return nil
        }
    }

    private func seed(for mode: RunMode) -> UInt64 {
        switch mode {
        case .run:
            if demo?.golden == true { return DemoMode.goldenSeed(from: demo?.seed ?? DemoMode.defaultSeed) }
            if let s = demo?.seed { return s }
            if isDemo { return DemoMode.defaultSeed }
            return UInt64.random(in: 1...UInt64.max)
        case let .daily(day, _):
            return DailySeed.seed(day: day)
        case .attract:
            if demo?.golden == true { return DemoMode.goldenSeed(from: demo?.seed ?? DemoMode.defaultSeed) }
            return demo?.seed ?? DemoMode.defaultSeed
        case .lesson:
            return 1
        }
    }

    /// R2 (QA-1 P1-3): leaving a live run (Home, Restart, a new run) files its result so far: relics into the Codex,
    /// gold into the rank, achievements, and a scored Daily's gold as the day's score (plus the Game Center boards).
    private func abandonLiveRun() {
        guard let session, !recorded, !session.isFinished else { return }
        recorded = true
        checkpointSaved = false
        let partial = session.partialResult()
        guard AppRules.worthRecording(partial) else {
            store.clearCheckpoint()
            return
        }
        let outcome = store.recordAbandoned(partial, today: today)
        GameCenterManager.shared.report(result: partial, outcome: outcome, progress: store.data)
        AppTrace.t("HUSH-T abandoned gold=\(partial.gold) chests=\(partial.chestsBanked) relics=\(partial.relics.count)")
    }

    /// R3 (QA-2 P2-2): the candle-out moment normally finishes in 2 s of drawn frames. If the scene stopped drawing
    /// (the Duo was folded onto the cover display), finish the run headless so Results never wait on the lid.
    private func watchTheEnd() {
        endWatchTask?.cancel()
        endWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.endWatchSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishIfStuck()
        }
    }

    private func finishIfStuck() {
        guard let session, !recorded, !session.isFinished, route.isPlay, !frozen, freezePendingAt == nil else { return }
        guard case .torchOut = session.snapshot.phase else { return }
        var steps = 0
        while !session.isFinished && steps < 600 {
            _ = session.step(dt: AppRules.maxStep, lid: LidInput())
            steps += 1
        }
        AppTrace.t("HUSH-T ending finished headless steps=\(steps)")
        if session.isFinished { handleFinished(immediate: true) }
    }

    private func handleFinished(immediate: Bool) {
        guard !recorded, let session, let result = session.result else { return }
        recorded = true
        checkpointSaved = false
        endWatchTask?.cancel()
        lockForLiveRun(false)
        setGlimmer(false)
        let outcome = store.record(result, today: today)
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("HUSH-T run gold=\(result.gold) chests=\(result.chestsBanked) bites=\(result.bites) "
                   + "seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        summary = makeSummary(result, outcome: outcome)
        refreshIdleTimer()
        resultsTask?.cancel()
        if immediate {
            showResults()
        } else {
            resultsTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(GameController.resultsDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.showResults()
            }
        }
    }

    private func showResults() {
        guard let summary else { return }
        clearRunPauses()
        feedback.silence()
        let look = PortraitScenes.resultsPose(summary.result)
        let portrait = portraits.results
        portrait.tier = summary.result.highestTier
        portrait.golden = summary.result.goldenBanked > 0
        portrait.openness = look.openness
        portrait.wake = look.wake
        setRoute(.results)
        if summary.outcome.rankedUp || !summary.outcome.newRelics.isEmpty { feedback.celebrate() }
        if demo?.freezeOn == .results { AppTrace.t("HUSH-T freeze results") }
    }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        let title: String
        let again: String
        switch result.mode {
        case .run:
            title = "Run over"
            again = "Again"
        case let .daily(day, scored):
            title = (scored ? "Daily Dungeon · " : "Daily practice · ") + AppRules.dailyDate(day: day)
            again = "Practise this dungeon"
        case .attract:
            title = "Demo run"
            again = "Again"
        case .lesson:
            title = "First Chest"
            again = "Play"
        }
        let rank = outcome.rankAfter
        let next = rank + 1 < ThiefRanks.count ? ThiefRanks.title(rank + 1) : nil
        let before = outcome.rankedUp ? 0 : ProgressRules.rankProgress(lifetime: outcome.lifetimeBefore, rank: rank)
        let after = ProgressRules.rankProgress(lifetime: outcome.lifetimeAfter, rank: rank)
        let story = AppRules.story(result, outcome: outcome, relicName: { RelicCatalog.relic($0).name },
                                   slider: sliderWording)
        // R11 (UX P1-1): the one-time "Keeps waking? Try a forgiving lid." (seen once it is offered).
        let forgiving = AppRules.offersForgivingNudge(mode: result.mode, bites: result.bites, runsSoFar: store.data.runs,
                                                      sensitivity: settings.lidSensitivity,
                                                      seen: store.data.seenTips.contains(AppRules.forgivingTipKey))
        if forgiving {
            store.markTip(AppRules.forgivingTipKey)
            AppTrace.t("HUSH-T forgiving nudge shown bites=\(result.bites) runs=\(store.data.runs)")
            note("forgiving nudge shown")
        }
        return ResultSummary(result: result, outcome: outcome, title: title, story: story,
                             rankTitle: ThiefRanks.title(rank), nextRankTitle: next, rankProgressBefore: before,
                             rankProgressAfter: after, againLabel: again,
                             nearMiss: AppRules.nearMiss(gold: result.gold, best: outcome.best,
                                                         newBest: outcome.isNewBest),
                             cause: AppRules.causeLine(result), offersForgiving: forgiving)
    }

    /// R3 (QA-2 P2-3): the hint gate runs on WALL time (`now`), so it settles even while the session is paused.
    private func publishHUD(_ s: HeistSnapshot, now: TimeInterval) {
        // R9: demo runs keep `debug.state` current (phase, pauses, input), 4 times a second.
        refreshDebugState(now: now)
        // R12: the lid as the chest sees it now (the words never ask to open an open lid).
        let lidOpen = AppRules.lidReadsOpen(s.openness)
        var wanted = s.hint
        // R12 (founder via CI): "Close the lid for the next chest" belongs to the robbed chest alone, never after a bank.
        if !AppRules.allowsCloseForNext(wanted, awaitingClose: session?.awaitingClose ?? false) { wanted = nil }
        if let h = wanted, !AppRules.showsHint(h, runs: store.data.runs) { wanted = nil }
        if route == .lesson || isPaused { wanted = nil }
        if AppRules.silencesHints(s.phase) {
            // A bite (or the candle's end): "Freeze!" goes at once, it never stays up under CHOMP.
            wanted = nil
            if hintGate.shown != nil { hintGate.clear() }
        }
        // R4 (ROUND-4 App 2, juror P1-5): one prompt at a time. The bank beat and the relic card hide the hint at
        // once (a live warning still shows), and a callout that waited for them shows now.
        // R5 (QA-4 P2-D): the relic card's gate runs on session time, like the card.
        let relicUp = s.time < relicCardUntil
        if let h = wanted, AppRules.hintSuppressed(h, phase: s.phase, relicCardUp: relicUp) { wanted = nil }
        let blocked = AppRules.promptBlocked(phase: s.phase, relicCardUp: relicUp)
        if blocked, let h = hintGate.shown, AppRules.hintSuppressed(h, phase: s.phase, relicCardUp: relicUp) {
            hintGate.clear()
        }
        if let text = callout, now < calloutUntil,
           AppRules.calloutBlocked(text, phase: s.phase, relicCardUp: relicUp) {
            // A callout caught by the bank beat or the relic card finishes later, in full (R5: the bank's own Hush
            // Chain tip stays through its bank beat; only the relic card defers it).
            pendingCallout = text
            callout = nil
            calloutUntil = 0
            calloutHoldUntil = 0
        } else if !blocked, let waiting = pendingCallout, !isPaused, route != .lesson, AppRules.isLive(s.phase),
                  !(callout != nil && now < calloutUntil) {
            showCallout(waiting, now: now)
        }
        var shown = hintGate.update(wanted, now: now)
        // R12: the gate's minimum show never keeps the robbed chest's prompt up over the next (closed) chest.
        let awaiting = session?.awaitingClose ?? false
        if !AppRules.allowsCloseForNext(shown, awaitingClose: awaiting) {
            hintGate.clear()
            shown = hintGate.update(wanted, now: now)
        }
        if isPaused { shown = nil }
        // R12 (CI ask): `HUSH-T hint <name>` whenever the chosen hint changes (`none` when it clears), before a scene
        // callout hides it, so CI sees every hint the player would have been given.
        if shown != tracedHint {
            tracedHint = shown
            AppTrace.t(AppRules.hintTraceLine(shown))
        }
        setGlimmer(shown == .relicDeeper)
        // R11 (juror P2-1, tester 11: "CREAK!" on "Freeze!", "Hushed!" on the plate): one prompt at a time. While the
        // scene has a callout up (`ChestScene.calloutActive`: CREAK!, the bank stack, the bite, the relic card, "Next
        // chest…") the hint steps aside; the gate keeps it, so it is back the frame the callout ends. A callout of our
        // own (the bank's Hush Chain tip, the golden banner) stays: the scene keeps its stack 12 pt under the plate.
        if AppRules.hintYieldsToScene(sceneCallout: scene?.calloutActive ?? false) { shown = nil }
        // One prompt at a time: a warning hint wins; then a callout (a tip, the golden banner); then the hint; then the
        // run-start banner. R5: during the first Hush Chain tip's 3 s hold only "Freeze!" wins.
        var banner: String?
        let held = now < calloutHoldUntil
        if let text = callout, now < calloutUntil, !isPaused,
           !(shown.map({ AppRules.calloutYields(to: $0, held: held) }) ?? false), route != .lesson {
            banner = text
            shown = nil
        } else if shown == nil && s.time < bannerUntil && !isPaused && bannerText != nil {
            // R12: the run-start line follows the lid ("Open it gently." only while it is closed).
            banner = Self.startBanner(mode, lidOpen: lidOpen) ?? bannerText
        }
        var bagged = 0
        for item in s.loot where item.place == .inBag { bagged += 1 }
        // R5 (juror P2-3): the pause coin hides on the scene's own bite flag (its seat dims on it too).
        let biting = scene?.biteActive ?? AppRules.isBiteMoment(s.phase)
        // R7 (ROUND-7 App 2): a Duo's live chest needs the press-and-hold coin.
        let hold = AppRules.pauseNeedsHold(duo: isDuo, phase: s.phase)
        if hold != pauseNeedsHold { pauseNeedsHold = hold }
        // R6 (CI FLAT-OPEN): "That's wide enough" is a hint, never a pause (R12: logged with every hint, above).
        let urgent = shown != hud.hint || banner != hud.banner || bagged != hud.bagCount || biting != hud.biting
            || lidOpen != hud.lidOpen
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        hud.update(hint: shown, banner: banner, stage: s.stage, bagCount: bagged,
                   debugLoot: isDemo ? Self.mostLit(s) : nil, spoken: SpokenHUD(s), biting: biting, lidOpen: lidOpen)
    }

    /// The most-lit item that can be grabbed now (CI's turned-drag UI test aims at it). Pure.
    nonisolated static func mostLit(_ s: HeistSnapshot) -> DebugLoot? {
        var best: LootState?
        for item in s.loot where item.place == .inChest && item.grabbable {
            if best.map({ item.light > $0.light }) ?? true { best = item }
        }
        guard let b = best else { return nil }
        return DebugLoot(id: b.id, kind: AppTrace.kindName(b.item.kind), floorPoint: b.position, radius: b.item.radius)
    }

    private func setGlimmer(_ on: Bool) {
        guard on != glimmerOn else { return }
        glimmerOn = on
        feedback.glimmer(on: on)
    }

    // MARK: - Pauses

    private func setPause(_ reason: PauseReason, _ on: Bool) {
        let was = isPaused
        if on {
            let inserted = pauseReasons.insert(reason).inserted
            if inserted && route.isPlay && reason != .closing { AppTrace.t("HUSH-T paused \(reason.rawValue)") }
            if inserted && route.isPlay { note("paused \(reason.rawValue)") }
            if inserted && route.isPlay && demo?.noiseUntilPause == true && !noiseReleased && !guardHold {
                noiseReleased = true
                AppTrace.t("HUSH-T noise released \(AppTrace.fixed(session?.snapshot.noise ?? 0, 2))")
            }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
            cancelStageAnnouncement()
            setGlimmer(false)
            // R3 (QA-2 P2-3): nothing stays drawn under a pause card.
            hintGate.clear()
            hud.update(hint: nil, banner: nil, stage: hud.stage, bagCount: hud.bagCount, debugLoot: hud.debugLoot)
        } else if !isPaused && was && route.isPlay {
            // Every resume: fresh hinge filters and half a second of silent lid (P0-2).
            if input == .hinge {
                hinge.reset()
                hinge.requiredResumeAngle = HingeLidSource.resumeAngle
            }
            if let session { _ = session.resumeGrace(seconds: AppRules.resumeGraceSeconds) }
            let angle = input == .hinge ? hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-" : "-"
            AppTrace.t("HUSH-T resumed angle \(angle)")
            note("resumed")
        }
        if isPaused != was { refreshIdleTimer() }
    }

    private func clearRunPauses() {
        pauseReasons.remove(.menu)
        pauseReasons.remove(.closing)
        closingPause.clear()
        if isMenuOpen { isMenuOpen = false }
        if isClosingPaused { isClosingPaused = false }
        if closingAwaitsHinge { closingAwaitsHinge = false }
        stopClosingWatch()
        resumeGuardStamp = nil
        demoClosingHold = false
    }

    /// QA-1 P2-4: the screen may sleep while paused (a Duo left half-closed), never mid-chest.
    private func refreshIdleTimer() {
        let keepAwake = !isDemo && isLiveRun && !isPaused
        if UIApplication.shared.isIdleTimerDisabled != keepAwake { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    /// P0-1: portrait only while a run is live on the inner display (not while CI holds the sim in landscape).
    /// R8 (QA-5 P2-4): a run ending hands straight over to the menu hold when the Duo is at a tabletop angle (both in
    /// one mask, so iOS never sees an unlocked moment to rotate in, P1-A's trigger); otherwise the mask widens and
    /// RootView re-reads the interface (`orientationEpoch`, and the scene's geometry).
    private func lockForLiveRun(_ on: Bool) {
        guard !demoHoldsLandscape else { return }
        if on {
            menuHold = MenuOrientationHold()
            OrientationLock.setHolds(liveRun: true, menu: false)
        } else {
            OrientationLock.setHolds(liveRun: false, menu: menuHoldWanted(menus: true, now: CACurrentMediaTime()))
        }
    }

    // MARK: - Demo

    private func launchDemo(_ d: DemoMode) {
        AppTrace.t("HUSH-T demo '\(d.raw)' starts")
        // R6: a `fold=1;orient=landscape` demo (the phone sim's landscape drag) gets the Duo's mask, so CI can turn it.
        if d.fold && d.orient == .landscape { OrientationLock.setDemoDuo(true) }
        let day = today
        store.replace(DemoPresets.progress(d.progress, today: day))
        if !d.sound { settings.muted = true }
        fixedSource.openness = d.lid ?? 0
        // R12 (demo `startOpen=1`): the held lid is up from the first frame (Play pressed with the lid open).
        fixedSource.startsOpen = d.opensAtStart
        if d.opensAtStart { AppTrace.t("HUSH-T demo start open lid=\(AppTrace.fixed(d.lid ?? 0, 2))") }
        switch d.effectiveScreen {
        case .home:
            goHome()
        case .run:
            start(d.runMode(today: day))
            if let skip = d.skipTo, skip > 0, let session {
                var sum = 0
                let played = DemoRunner.play(session, skill: d.pilot ?? .expert, seed: session.seed, seconds: skip,
                                             time0: CACurrentMediaTime() - skip, onEvent: { e in
                                                 if case let .banked(value, _, _) = e { sum += value }
                                             })
                bankedSum = sum
                playTime = played
                AppTrace.t("HUSH-T skipped \(AppTrace.fixed(played, 1)) banked=\(session.snapshot.banked)")
                if session.isFinished { handleFinished(immediate: true) }
            }
            if d.holdClosing { holdClosingForDemo() }
        case .results:
            start(d.runMode(today: day))
            if let session {
                DemoRunner.playToEnd(session, skill: d.pilot ?? .casual, seed: session.seed)
                if session.isFinished {
                    handleFinished(immediate: true)
                } else {
                    goHome()
                }
            }
        case .codex:
            goHome()
            setRoute(.codex)
        case .settings:
            goHome()
            setRoute(.settings)
        case .daily:
            goHome()
            setRoute(.daily)
        case .lesson:
            let step = LessonScript.Step(rawValue: d.lessonStep ?? 1) ?? .pose
            startLesson(replay: false, at: step)
        case .pose:
            // R6: book pose never blocks. `screen=pose` / `pose=book` force the small pose tip on Home (a phone never
            // shows it, unless CI asks by name with `pose=book`). With `mode=`, the run starts and plays (no tip, no
            // block): the tip is a Home / lesson-step-1 thing.
            var screen = OrientationLock.screenSize()
            if screen.width < 1 { screen = UIScreen.main.bounds.size }
            if d.poseBook || AppRules.allowsForcedPoseTip(screen: screen, demoFold: d.fold) {
                forcedPoseTip = true
            }
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            forcedPose = .cover
            // R11: `midRun=1` is a run under the card ("Open to carry on", and the escape's Carry on).
            if d.mode != nil || d.midRun { start(d.runMode(today: day)) } else { goHome() }
        case .icon:
            showsIcon = true
            goHome()
        case .badges:
            goHome()
            setRoute(.badges)
            BadgeExport.renderAll()
        }
        if let orient = d.orient { DemoOrientation.request(orient) }
        if d.holdHint { AppTrace.t("HUSH-T hold hint forced") }
    }

    /// R12 (tests): sets the live session's noise, as the demo `noise=` key does (a bite while looting). Internal.
    func nudgeSessionNoise(to level: Double) {
        session?.nudgeNoise(to: level)
    }

    /// R12 (tests and Diagnostics): the robbed chest is waiting for the lid to close.
    var awaitingClose: Bool { session?.awaitingClose ?? false }

    /// R12: a `bitten` event. Pure.
    nonisolated static func isBite(_ e: HeistEvent) -> Bool {
        if case .bitten = e { return true }
        return false
    }

    /// R12 (CI ask, demo `bag=<n>`, DEBUG): on the first chest's first looting steps, n lit items go straight into the
    /// bag, picked and dropped in the bag strip at walking pace (`DemoBagPlan`): the pick and bag clinks only, never
    /// drag noise. Logs `HUSH-T demo bag <n> value <v>` once the bag is full (or the first chest is over).
    private func fillDemoBag(_ session: HeistSession, now: TimeInterval) -> [HeistEvent] {
        guard var plan = demoBag else { return [] }
        var out: [HeistEvent] = []
        let s = session.snapshot
        for (i, k) in plan.picks(s).enumerated() where k < s.loot.count {
            let id = DemoBagPlan.touchBase - plan.bagged - i
            let from = s.loot[k].position
            out += session.touchBegan(id: id, at: from, time: now)
            // 3 s for the trip: well under the drag's quiet speed (350 pt/s), and ended in the same frame.
            out += session.touchMoved(id: id, to: DemoBagPlan.bagPoint, time: now + 3)
            out += session.touchEnded(id: id, at: DemoBagPlan.bagPoint, time: now + 3)
        }
        let bagged = out.filter { e in
            if case .itemBagged = e { return true }
            return false
        }.count
        plan.noteBagged(bagged)
        let after = session.snapshot
        plan.finishIfNeeded(after)
        if plan.done {
            demoBag = nil
            AppTrace.t("HUSH-T demo bag \(plan.bagged) value \(after.bagValue)")
        } else {
            demoBag = plan
        }
        return out
    }

    /// R11 (ROUND-11 App 3, demo `hint=holdToPause`): the pause coin shows "Hold to pause" and a half-full ring.
    var demoHoldHint: Bool { demo?.holdHint ?? false }

    /// R8 (QA-5 P2-7, demo `hold=closing`): the closing card, held whatever the input, until "Carry on" (after 3 s)
    /// or Home. CI taps "Carry on" at an odd k (HushUITests).
    private func holdClosingForDemo() {
        guard isLiveRun else { return }
        demoClosingHold = true
        closingPause.hold()
        guardHold = true
        setClosing(true)
        guardHold = false
        AppTrace.t("HUSH-T demo hold closing")
    }

    private func demoAfterStep(_ s: HeistSnapshot, events: [HeistEvent]) {
        guard let demo, !frozen else { return }
        if let at = freezePendingAt {
            if playTime >= at { freeze(freezePendingTag?.rawValue ?? "after", holdScene: freezePendingTag != nil) }
            return
        }
        if let after = demo.holdAfter, playTime < after { return }
        let creak = creakPending
        creakPending = false
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events, creak: creak) else { return }
            if tag.isEvent {
                freezePendingAt = playTime + demo.holdDelay(tag, lesson: mode == .lesson)
                freezePendingTag = tag
            } else {
                freeze(tag.rawValue, holdScene: false)
            }
        } else if demo.holdAfter != nil {
            freeze("after", holdScene: false)
        }
    }

    /// Whether this frame is the demo freeze moment `tag`. Pure; tested.
    nonisolated static func matches(_ tag: DemoMode.Freeze, _ s: HeistSnapshot, events: [HeistEvent],
                                    creak: Bool = false) -> Bool {
        switch tag {
        case .creak:
            return creak
        case .ready:
            if case .ready = s.phase { return true }
            return false
        case .reveal:
            return s.openness >= 0.75 && s.loot.filter { $0.light >= 0.5 }.count >= 3
        case .stirring:
            return s.stage >= .stirring
        case .waking:
            return s.stage >= .waking
        case .bite:
            return events.contains { e in
                if case .bitten = e { return true }
                return false
            }
        case .bank:
            return events.contains { e in
                if case .banked = e { return true }
                return false
            }
        case .relic:
            return events.contains { e in
                if case .relicFound = e { return true }
                return false
            }
        case .torchLow:
            return events.contains(.torchLow)
        case .torchOut:
            return events.contains(.torchOut)
        case .results:
            return false
        }
    }

    /// Stops stepping. An event freeze also pauses the scene after a beat, so "Too loud! −N", "−10s" and the chomp are
    /// still on screen when CI's slow Duo shot lands (NEEDS, CI R2).
    private func freeze(_ tag: String, holdScene: Bool) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        AppTrace.t("HUSH-T freeze \(tag)")
        guard holdScene else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.sceneHoldDelay * 1_000_000_000))
            guard let self, self.frozen else { return }
            self.sceneHeld = true
            self.scene?.isPaused = true
        }
    }
}
