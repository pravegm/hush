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
    /// A Game Center sheet is up: the app is drawn un-turned under it (QA-1 P2-6).
    @Published private(set) var systemSheetUp = false
    /// Held camera end up while turned round: the un-turned "Other way round" banner (P1-7).
    @Published private(set) var showsHoldHint = false
    /// Demo event freezes: the scene is paused too, so the moment stays on screen.
    @Published private(set) var sceneHeld = false
    /// The scene's frame rate (R3, Feel: the ceiling while something moves, 60 when idle; 60 under Low Power or heat).
    @Published private(set) var preferredFPS = 120
    /// R3 (QA-2 P2-4): iOS refused a portrait request: the book-pose card offers "Play anyway".
    @Published private(set) var portraitRefused = false
    /// R3 (QA-2 P2-4): the player chose "Play anyway" on the book-pose card: landscape is played, on the lever.
    @Published private(set) var playAnyway = false

    let hud = HUDState()
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
    /// The hinge angle when the book-pose card appeared (P0-1: a ≥ 15° lift asks iOS for portrait).
    private var standUpAngle: Double?
    private var lastPortraitAsk: TimeInterval = -100
    private(set) var isTurned = false
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

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.demo = DemoMode.current
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
            MainActor.assumeIsolated { self?.portraitRefused = true }
        }
    }

    // MARK: - Derived state

    var isDemo: Bool { demo != nil }
    var hasHinge: Bool { hinge.hasHinge }
    var isPaused: Bool { !pauseReasons.isEmpty }
    /// "Turn the chest round" in effect (demo `turn=` wins).
    var wantsTurnRound: Bool { demo?.turn ?? settings.turnRound }
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
                                      + " · device \(UIDevice.current.orientation.rawValue)")
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
    /// takes the lever, turned round or not; "Play anyway" (landscape, no fold) is the one Duo case that does.
    var usesSlider: Bool {
        AppRules.usesSlider(playRoute: route.isPlay, layoutHasFold: layoutHasFold, input: input)
    }

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("HUSH-T frame 120") }
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
        var snapshot = session.snapshot

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
        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, dragSpeed: dragSpeed, playing: live))
        for event in events {
            if case let .banked(value, _, _) = event { bankedSum += value }
            if case .chestArrived = event, snapshot.chest?.golden == true { feedback.goldenArrived() }
            if case .torchOut = event { watchTheEnd() }
            if case .relicFound = event { noteRelicCard(at: snapshot.time) }
            AppTrace.t("HUSH-T event " + traceLine(event, snapshot: snapshot))
            callouts(for: event, snapshot: snapshot, now: now)
            announce(event)
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
        guard acceptsTouches, let session else { return }
        deliver(session.touchBegan(id: id, at: point, time: time))
    }

    func floorTouchMoved(_ id: Int, to point: CGPoint, time: TimeInterval) {
        guard acceptsTouches, let session else { return }
        deliver(session.touchMoved(id: id, to: point, time: time))
    }

    /// Ends always arrive (even paused), so an item is never left "held" by a finger that has gone.
    func floorTouchEnded(_ id: Int, at point: CGPoint, time: TimeInterval) {
        guard route.isPlay, input != .pilot, let session, !session.isFinished else { return }
        deliver(session.touchEnded(id: id, at: point, time: time))
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
    private func announce(_ event: HeistEvent) {
        switch event {
        case let .chestArrived(index, _, _, _): announceGate.chestArrived(index)
        case .bitten, .banked: cancelStageAnnouncement()
        default: break
        }
        guard let text = HushCopy.announcement(event) else { return }
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
    /// shut lid instead (`.fixed`), so CI's fold frames still draw. "Play anyway" (landscape) uses the lever.
    private func chooseInput() -> AppInputKind {
        if demo?.pilot != nil { return .pilot }
        if demo?.lid != nil { return .fixed }
        if playAnyway { return .slider }
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
    /// R4 (QA-3 P1-1): a live run whose input CHANGES to the hinge (leaving "Play anyway", a fold appearing) is never
    /// played straight away: fresh filters, then the closing pause until the lid is open and still. The reverse (QA-3
    /// P2, "Play anyway" mid-run) hands the lever the lid where it is, so the chest never snaps shut or auto-banks.
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

    /// The play canvas changed (fold, turned round, size). The scene is built once and then re-laid out. R2: the scene
    /// fills the screen (`ScreenLayout.make(hasFold:viewSize:)`) and turns itself round (`ChestScene.turned`).
    func updateCanvas(_ size: CGSize, hasFold: Bool, turned: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        let line = "HUSH-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) turned=\(turned ? 1 : 0)"
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
            // A live run that has just reached portrait gets its portrait lock now (never before: Duo run 40506125012).
            OrientationLock.interfaceChanged()
        }
        noteCanvasClass(AppRules.canvasClass(size))
        // Back in portrait: "Play anyway" is over.
        if playAnyway && size.height > size.width {
            playAnyway = false
            refreshInput()
        }
        isTurned = turned
        if !turned && showsHoldHint { showsHoldHint = false }
        let newLayout = ScreenLayout.make(hasFold: hasFold, viewSize: size)
        let foldChanged = newLayout.hasFold != layout?.hasFold
        if newLayout != layout || scene == nil {
            layout = newLayout
            if let scene {
                scene.layout = newLayout
            } else {
                makeScene(newLayout)
            }
        }
        // "Play anyway" in landscape shows the whole portrait chest (aspect-fit), never a crop.
        scene?.scaleMode = size.width > size.height ? .aspectFit : .aspectFill
        if let scene, scene.turned != turned { scene.turned = turned }
        if foldChanged { refreshInput() }
    }

    /// R3 (decision 1): a small ↔ inner canvas change during a live hinge run holds the closing pause, whatever the
    /// pose does. The hand-off and relight angles are kept for Diagnostics, and a relight lowers Feel's resume angle
    /// to what the player can already see (REVIEW-2-duo P1-3).
    private func noteCanvasClass(_ new: AppRules.CanvasClass?) {
        guard let new, new != canvasClass else { return }
        let old = canvasClass
        canvasClass = new
        guard old != nil else { return }
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
            closingPause.hold()
            setClosing(true)
            AppTrace.t("HUSH-T handover hold \(old?.rawValue ?? "-")->\(new.rawValue) angle=\(a)")
        }
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = ChestScene(layout: layout)
        newScene.scaleMode = .aspectFill
        newScene.reduceMotion = reduceMotion
        newScene.turned = isTurned
        newScene.driver = self
        scene = newScene
        sceneGeneration += 1
        newScene.reset()
    }

    /// R2 (P1-8): only `.background` opens the pause menu (folding shut may pass through `.inactive` on hardware, and
    /// then every close would end on the menu). Inactive (Control Centre, a call banner) pauses quietly.
    func setScenePhase(_ phase: ScenePhase) {
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

    /// The display's pose changed (book pose, the cover display). Every change logs `HUSH-T pose <pose> reason=<…>`.
    func setPose(_ newPose: AppPose, canvas: CGSize = .zero) {
        guard newPose != pose else { return }
        let old = pose
        pose = newPose
        AppTrace.t("HUSH-T pose \(newPose.rawValue) reason="
                   + AppRules.poseReason(newPose, canvas: canvas, forced: forcedPose != nil, angle: hinge.angle))
        if newPose == .standUp {
            standUpAngle = hinge.angle
            autoAskPortrait(reason: "card")
        }
        if old == .cover && newPose != .cover && isLiveRun { autoAskPortrait(reason: "cover") }
        if newPose == .play && old != .play && isLiveRun && input == .hinge {
            // Back from the cover display or the book card mid-run: wait for an open, still lid (P0-2).
            closingPause.hold()
            setClosing(true)
        }
        setPause(.pose, newPose != .play)
        if newPose == .cover && !isDemo { UIAccessibility.post(notification: .screenChanged, argument: nil) }
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

    /// The book-pose card's "I've stood it up" (always asks, unthrottled).
    func stoodItUp() {
        lastPortraitAsk = CACurrentMediaTime()
        AppTrace.t("HUSH-T orient ask reason=button device=\(UIDevice.current.orientation.rawValue)")
        if demo?.poseBook == true { forcedPose = nil }
        OrientationLock.requestPortrait()
    }

    /// R3 (QA-2 P2-4): the book-pose card's way out: play in landscape, on the lever.
    func choosePlayAnyway() {
        AppTrace.t("HUSH-T pose play-anyway")
        if forcedPose == .standUp { forcedPose = nil }
        playAnyway = true
        refreshInput()
    }

    /// P1-7: the device's physical orientation changed (UIDevice notifications, begun at launch).
    func deviceOrientationChanged() {
        let o = UIDevice.current.orientation
        AppTrace.t("HUSH-T device-orient \(o.rawValue)")
        // R3 (P1-2): the card is up and the Duo left landscape (the floor went flat): that's "stood it up".
        if pose == .standUp && o != .unknown && AppRules.mayAutoAskPortrait(o) { askPortrait(reason: "device") }
        holdHintTask?.cancel()
        guard AppRules.readsUpsideDown(turned: isTurned, cameraUp: o == .portrait, angle: hinge.angle) else {
            if showsHoldHint { showsHoldHint = false }
            return
        }
        holdHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.holdHintDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            let still = AppRules.readsUpsideDown(turned: self.isTurned,
                                                 cameraUp: UIDevice.current.orientation == .portrait,
                                                 angle: self.hinge.angle)
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
        }
        // P0-1: the book card is up and the hinge moved into the play range: they lifted it. Ask for portrait.
        if pose == .standUp {
            if standUpAngle == nil { standUpAngle = angle }
            if AppRules.liftedFromBook(angle: angle, angleAtCard: standUpAngle) {
                standUpAngle = angle
                askPortrait(reason: "lift")
            }
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

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    /// The closing pause (`ClosingPause`): Feel's gate (θ < `Tuning.closingAngle`, 70°, for 0.4 s) or shut pauses; it
    /// lifts only when `hinge.canResume` (open ≥ the resume angle and still) AND the canvas is the inner display.
    /// R3 (QA-2 P2-2): it only engages while a chest is live; a hold made during a moment waits for the next chest.
    private func checkClosing(now: TimeInterval, phase: RunPhase) {
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
        if closingPause.paused && !isClosingPaused { setClosing(true) }
        let resumable = AppRules.mayResume(canResume: hinge.canResume, canvas: canvasClass)
        switch closingPause.update(angle: angle, gateClosing: hinge.isClosing, isShut: isShut,
                                   canResume: resumable, now: now) {
        case .paused?:
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

    private func setClosing(_ on: Bool) {
        if isClosingPaused != on { isClosingPaused = on }
        setPause(.closing, on)
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
        case .shown, .signingIn: systemSheetUp = true
        case .signedOut: showToast("Sign in to Game Center in Settings")
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
        if newRoute != route {
            route = newRoute
            AppTrace.t("HUSH-T screen \(newRoute.rawValue)")
        }
        if newRoute == .home { startHomeTicker() } else { homeTicker?.stop() }
        feedback.idle = !newRoute.isPlay
        if !newRoute.isPlay { publishFPS(min(feedback.preferredFPS, 60)) }
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
    func skipLesson() {
        store.markLessonDone()
        goHome()
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
        for item in s.loot {
            if item.place == .inBag { bagged += 1 }
            if item.place == .inChest && item.grabbable { grabbable = true }
        }
        return LessonScript.Input(time: s.time, angle: input == .hinge ? hinge.angle : nil, hasHinge: input == .hinge,
                                  openness: s.openness, lidSpeed: s.lidSpeed, dragSpeed: dragSpeed,
                                  anyGrabbable: grabbable, bagCount: bagged, noise: s.noise, hint: s.hint,
                                  events: events)
    }

    /// The card's strings are built at ≤ 15 Hz (QA-1 P2-14), at once when something happened.
    private func publishLesson(_ script: LessonScript, hint: HeistHint?, now: TimeInterval, force: Bool) {
        guard force || now - lastLesson >= Self.hudInterval else { return }
        lastLesson = now
        let display = script.display(slider: sliderWording, angle: input == .hinge ? hinge.angle : nil, hint: hint)
        if display != lessonDisplay {
            if display.step != lessonDisplay?.step || display.praise != lessonDisplay?.praise
                || display.line != lessonDisplay?.line {
                AppTrace.t("HUSH-T lesson step \(display.step) praise=\(display.praise ? 1 : 0) line '\(display.line)'")
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
        let options: SessionOptions = m == .lesson ? LessonChest.options : SessionOptions.`for`(m)
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
        bannerText = Self.startBanner(m)
        bannerUntil = bannerText == nil ? 0 : Self.bannerSeconds
        scene?.reset()
        // R3 (decision 3): "not safe yet" under IN BAG while the teaching runs last.
        scene?.showsBagSublabel = store.data.runs < AppRules.teachingRuns
        setInput(chooseInput())
        if input == .hinge {
            hinge.reset()
            hinge.requiredResumeAngle = HingeLidSource.resumeAngle
        }
        hud.update(hint: nil, banner: bannerText, stage: .asleep, bagCount: 0, debugLoot: nil, spoken: SpokenHUD(),
                   biting: false)
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

    /// The run-start line (≤ 6 words), shown while no hint is up.
    nonisolated static func startBanner(_ mode: RunMode) -> String? {
        switch mode {
        case .run: return "Candle lit. Open it gently."
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
        let story = AppRules.story(result, outcome: outcome, relicName: { RelicCatalog.relic($0).name })
        return ResultSummary(result: result, outcome: outcome, title: title, story: story,
                             rankTitle: ThiefRanks.title(rank), nextRankTitle: next, rankProgressBefore: before,
                             rankProgressAfter: after, againLabel: again,
                             nearMiss: AppRules.nearMiss(gold: result.gold, best: outcome.best,
                                                         newBest: outcome.isNewBest),
                             cause: AppRules.causeLine(result))
    }

    /// R3 (QA-2 P2-3): the hint gate runs on WALL time (`now`), so it settles even while the session is paused.
    private func publishHUD(_ s: HeistSnapshot, now: TimeInterval) {
        var wanted = s.hint
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
        if isPaused { shown = nil }
        setGlimmer(shown == .relicDeeper)
        // One prompt at a time: a warning hint wins; then a callout (a tip, the golden banner); then the hint; then the
        // run-start banner. R5: during the first Hush Chain tip's 3 s hold only "Freeze!" wins.
        var banner: String?
        let held = now < calloutHoldUntil
        if let text = callout, now < calloutUntil, !isPaused,
           !(shown.map({ AppRules.calloutYields(to: $0, held: held) }) ?? false), route != .lesson {
            banner = text
            shown = nil
        } else if shown == nil && s.time < bannerUntil && !isPaused {
            banner = bannerText
        }
        var bagged = 0
        for item in s.loot where item.place == .inBag { bagged += 1 }
        // R5 (juror P2-3): the pause coin hides on the scene's own bite flag (its seat dims on it too).
        let biting = scene?.biteActive ?? AppRules.isBiteMoment(s.phase)
        let urgent = shown != hud.hint || banner != hud.banner || bagged != hud.bagCount || biting != hud.biting
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        hud.update(hint: shown, banner: banner, stage: s.stage, bagCount: bagged,
                   debugLoot: isDemo ? Self.mostLit(s) : nil, spoken: SpokenHUD(s), biting: biting)
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
    }

    /// QA-1 P2-4: the screen may sleep while paused (a Duo left half-closed), never mid-chest.
    private func refreshIdleTimer() {
        let keepAwake = !isDemo && isLiveRun && !isPaused
        if UIApplication.shared.isIdleTimerDisabled != keepAwake { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    /// P0-1: portrait only while a run is live on the inner display (not while CI holds the sim in landscape).
    private func lockForLiveRun(_ on: Bool) {
        guard !demoHoldsLandscape else { return }
        OrientationLock.setLiveRun(on)
    }

    // MARK: - Demo

    private func launchDemo(_ d: DemoMode) {
        AppTrace.t("HUSH-T demo '\(d.raw)' starts")
        let day = today
        store.replace(DemoPresets.progress(d.progress, today: day))
        if !d.sound { settings.muted = true }
        fixedSource.openness = d.lid ?? 0
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
            // A phone never shows the book-pose card (UX: frame 25), unless CI asks for it by name (`pose=book`).
            var screen = OrientationLock.screenSize()
            if screen.width < 1 { screen = UIScreen.main.bounds.size }
            if d.poseBook || AppRules.allowsForcedPose(.standUp, screen: screen, demoFold: d.fold) {
                forcedPose = .standUp
            }
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            forcedPose = .cover
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .icon:
            showsIcon = true
            goHome()
        case .badges:
            goHome()
            setRoute(.badges)
            BadgeExport.renderAll()
        }
        if let orient = d.orient { DemoOrientation.request(orient) }
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
