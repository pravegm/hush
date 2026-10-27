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
/// pose card (book pose, the cover display). R2 (REVIEW-1-duo P0-2):
/// - while paused the session RESTS (`HeistSession.rest(dt:)`: the noise settles, no candle, no bites), every frame the
///   scene still draws and, for the time it didn't (cover display, background), in one catch-up on the next frame;
/// - a hinge run resumes only when Feel says the lid is open and still (`HingeLidSource.canResume`); a run coming back
///   from the cover display or the book-pose card waits the same way (the closing card says "Hold still…");
/// - every resume resets the hinge filters and gives `resumeGrace(seconds: 0.5)` of silent lid;
/// - the pause menu opens only on `.background` (P1-8), never while the Duo is shut.
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
    /// A gap this long between frames (the scene wasn't drawing: cover display, background) is rested through.
    static let catchUpGap: Double = 0.1
    /// Portrait requests are throttled to one per this many seconds.
    static let portraitAskInterval: Double = 1.0
    /// Held camera-end-up this long while turned round: "Other way round" (P1-7).
    static let holdHintDelay: Double = 0.7
    /// An event freeze also pauses the scene this long after it lands (CI: the moment stays on screen).
    static let sceneHoldDelay: Double = 0.4

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
    /// The lid is back up (≥ 95°) but not yet still: the closing card says "Hold still…".
    @Published private(set) var closingLifted = false
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var lessonDisplay: LessonDisplay?
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover` forces a pose.
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
    /// A cover-sized canvas while the hinge is held open: a compatibility column, played (`AppRules.pose`).
    @Published private(set) var smallCanvasOpen = false
    private var smallCanvasOpenSince: TimeInterval?
    private var smallCanvasTask: Task<Void, Never>?
    /// The scene's frame rate (Feel: 60 under Low Power or a hot device, else 120).
    @Published private(set) var preferredFPS = 120

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
    private var lastAdvanceNow: TimeInterval?
    private var hintGate = HintGate()
    private var glimmerOn = false
    private var recorded = false
    private var checkpointSaved = false
    private var resultsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var holdHintTask: Task<Void, Never>?
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
    /// The hinge angle when the book-pose card appeared (P0-1: a ≥ 15° lift asks iOS for portrait).
    private var standUpAngle: Double?
    private var lastPortraitAsk: TimeInterval = -100
    private(set) var isTurned = false
    /// R2: the gold counter must equal the sum of the banks (checked every frame in demo runs).
    private var bankedSum = 0
    private var goldMismatchLogged = false

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.demo = DemoMode.current
        // `hush.hasHinge` comes back with a backup restored onto another iPhone: believe it only on a Duo-shaped screen.
        let stored = UserDefaults.standard.bool(forKey: OrientationLock.hingeKey)
        let trusted = OrientationLock.trustsStoredHinge(stored, screen: UIScreen.main.bounds.size)
        if stored && !trusted { UserDefaults.standard.removeObject(forKey: OrientationLock.hingeKey) }
        self.hingeSeen = trusted
        self.reduceMotion = settings.reduceMotion
        GameCenterManager.shared.bannersAllowed = !trusted
        self.preferredFPS = FeedbackDirector.shared.preferredFPS
        // Feel calls this on the main actor (its notification observers run on the main queue).
        FeedbackDirector.shared.onPreferredFPSChange = { [weak self] fps in
            MainActor.assumeIsolated { self?.preferredFPS = fps }
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
    /// The lid speaks in the slider's words (no hinge in this run).
    var sliderWording: Bool { input != .hinge }
    var lessonReplaying: Bool { lessonReplay }
    /// "Daily Dungeon · 27 Oct" for the run's day (nil outside a Daily).
    var dailyMarker: String? {
        guard case let .daily(day, scored) = mode else { return nil }
        return (scored ? "Daily Dungeon · " : "Daily practice · ") + AppRules.dailyDate(day: day)
    }

    // MARK: - SceneDriver

    /// R2 (UX P0-4): on an iPhone without a fold the lever is always drawn, whoever drives the lid (CI's pilot and
    /// `lid=` frames included); only the player's slider takes its touches (`sliderTouch`).
    var usesSlider: Bool {
        guard route.isPlay else { return false }
        switch input {
        case .slider: return true
        case .pilot, .fixed: return !(layout?.hasFold ?? false)
        case .hinge: return false
        }
    }

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("HUSH-T frame 120") }
        var out = pendingSceneEvents
        pendingSceneEvents.removeAll()
        let wall = lastAdvanceNow.map { max(now - $0, 0) } ?? 0
        lastAdvanceNow = now
        guard let session else { return (HeistSnapshot(), out) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, out) }
        checkClosing(now: now)
        if frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, dragSpeed: 0, playing: false,
                                                              paused: true))
            return (session.snapshot, out)
        }
        if isPaused {
            // Keep the hinge filters warm (Feel's `canResume` reads them) and let the mimic settle.
            if input == .hinge { _ = hinge.lid(at: now) }
            out += rest(session, seconds: wall)
            let s = session.snapshot
            feedback.handle([], telemetry: AppRules.telemetry(s, dragSpeed: 0, playing: false, paused: true))
            publishHUD(s, now: now)
            return (s, out)
        }
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (session.snapshot, out) }
        // The scene wasn't drawing (cover display, background): the time it missed is rest, not play.
        if wall > Self.catchUpGap { out += rest(session, seconds: wall - step) }

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

        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, dragSpeed: session.dragSpeed,
                                                              playing: AppRules.isLive(snapshot.phase)))
        for event in events {
            if case let .banked(value, _, _) = event { bankedSum += value }
            if case .chestArrived = event, snapshot.chest?.golden == true { feedback.goldenArrived() }
            AppTrace.t("HUSH-T event " + traceLine(event, snapshot: snapshot))
        }
        checkGold(snapshot)
        if AppTrace.enabled && now - lastLidLog >= Self.lidLogInterval {
            lastLidLog = now
            AppTrace.t(AppTrace.lidLine(openness: lid.openness, speed: lid.speed,
                                        angle: input == .hinge ? hinge.angle : nil, noise: snapshot.noise,
                                        stage: snapshot.stage))
        }
        publishHUD(snapshot, now: now)
        demoAfterStep(snapshot, events: events)
        if session.isFinished { handleFinished(immediate: false) }
        out += events
        return (snapshot, out)
    }

    /// Rests the session through `seconds` (the noise settles; no candle, no bites). Returns a `stageChanged` if the
    /// mimic's stage dropped, so the scene and Feedback hear it.
    private func rest(_ session: HeistSession, seconds: Double) -> [HeistEvent] {
        let (count, step) = AppRules.restChunks(seconds)
        guard count > 0 else { return [] }
        let before = session.snapshot.stage
        for _ in 0..<count { _ = session.rest(dt: step) }
        let after = session.snapshot.stage
        guard after != before else { return [] }
        let change = HeistEvent.stageChanged(from: before, to: after)
        feedback.handle([change], telemetry: AppRules.telemetry(session.snapshot, dragSpeed: 0, playing: false,
                                                                paused: true))
        AppTrace.t("HUSH-T event " + AppTrace.describe(change) + " rest=1")
        return [change]
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
        guard input == .slider, route.isPlay else { return }
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

    private func chooseInput() -> AppInputKind {
        if demo?.pilot != nil { return .pilot }
        if demo?.lid != nil { return .fixed }
        if hinge.hasHinge { return .hinge }
        return .slider
    }

    private func setInput(_ kind: AppInputKind) {
        let changed = input != kind
        input = kind
        if changed || session != nil { AppTrace.t("HUSH-T input \(kind.rawValue)") }
    }

    /// The first hinge sample of a launch upgrades a slider run to the hinge (the slider's last state is dropped).
    func refreshInput() {
        guard session != nil else { return }
        let kind = chooseInput()
        guard kind != input else { return }
        setInput(kind)
    }

    // MARK: - Lifecycle hooks from RootView

    func launch() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        if let demo {
            launchDemo(demo)
            return
        }
        // A run killed in the background is filed as left early (its relics, gold and achievements are kept).
        if let recovered = store.recoverPendingRun(today: today) {
            GameCenterManager.shared.report(result: recovered.0, outcome: recovered.1, progress: store.data)
        }
        // P0-1: on a Duo's inner display, ask iOS for portrait at launch (a Duo lying flat never rotates by itself).
        if hingeSeen || OrientationLock.looksLikeDuo(OrientationLock.screenSize()) { askPortrait() }
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
        isTurned = turned
        if !turned && showsHoldHint { showsHoldHint = false }
        let newLayout = ScreenLayout.make(hasFold: hasFold, viewSize: size)
        if newLayout != layout || scene == nil {
            layout = newLayout
            if let scene {
                scene.layout = newLayout
            } else {
                makeScene(newLayout)
            }
        }
        if let scene, scene.turned != turned { scene.turned = turned }
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
        if newPose == .cover { watchSmallCanvas() }
        if newPose == .standUp {
            standUpAngle = hinge.angle
            askPortrait()
        }
        if old == .cover && newPose != .cover && isLiveRun { askPortrait() }
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

    /// P0-1: ask iOS for portrait (throttled; never while CI holds the Duo sim in landscape on purpose).
    func askPortrait() {
        guard demo?.orient != .landscape else { return }
        let now = CACurrentMediaTime()
        guard now - lastPortraitAsk >= Self.portraitAskInterval else { return }
        lastPortraitAsk = now
        OrientationLock.requestPortrait()
    }

    /// The book-pose card's "I've stood it up" (always asks, unthrottled).
    func stoodItUp() {
        lastPortraitAsk = CACurrentMediaTime()
        OrientationLock.requestPortrait()
    }

    /// P1-7: the device's physical orientation changed (UIDevice notifications, begun at launch).
    func deviceOrientationChanged() {
        let o = UIDevice.current.orientation
        AppTrace.t("HUSH-T device-orient \(o.rawValue)")
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
        // A cover-sized canvas with the hinge held well open isn't the cover display (`AppRules.smallCanvasIsOpen`).
        if angle >= AppRules.smallCanvasOpenAngle {
            if smallCanvasOpenSince == nil { smallCanvasOpenSince = CACurrentMediaTime() }
        } else {
            smallCanvasOpenSince = nil
            if smallCanvasOpen { smallCanvasOpen = false }
        }
        // P0-1: the book card is up and the hinge moved into the play range: they lifted it. Ask for portrait.
        if pose == .standUp {
            if standUpAngle == nil { standUpAngle = angle }
            if AppRules.liftedFromBook(angle: angle, angleAtCard: standUpAngle) {
                standUpAngle = angle
                askPortrait()
            }
        }
        refreshInput()
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    /// While the cover card is up: if the hinge stays well open (≥ 60° for 2.5 s; the Duo sends no reports while
    /// still, so this is polled), the small canvas is a compatibility column on the inner display, not the cover
    /// display. Ask for portrait again and play there rather than sit on the cover card with nothing stepping.
    private func watchSmallCanvas() {
        smallCanvasTask?.cancel()
        smallCanvasTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, self.pose == .cover || self.smallCanvasOpen else { return }
                let open = AppRules.smallCanvasIsOpen(angle: self.hinge.angle, openSince: self.smallCanvasOpenSince,
                                                      now: CACurrentMediaTime())
                if open != self.smallCanvasOpen {
                    self.smallCanvasOpen = open
                    if open {
                        AppTrace.t("HUSH-T pose cover-open angle=\(AppTrace.fixed(self.hinge.angle ?? 0, 1)): "
                                   + "a small canvas with the hinge open, asking for portrait")
                        self.askPortrait()
                    }
                }
                if !open && self.pose != .cover { return }
            }
        }
    }

    /// The closing pause (`ClosingPause`): Feel's gate (θ < `Tuning.closingAngle`, 70° in R2, for 0.4 s) or shut
    /// pauses; it lifts only when `hinge.canResume` (open ≥ 95° and still).
    private func checkClosing(now: TimeInterval) {
        guard input == .hinge, route.isPlay, session != nil else {
            if closingPause.paused || isClosingPaused {
                closingPause.clear()
                setClosing(false)
            }
            return
        }
        let angle = hinge.angle
        let lifted = (angle ?? 0) >= AppRules.resumeAngle
        if lifted != closingLifted { closingLifted = lifted }
        switch closingPause.update(angle: angle, gateClosing: hinge.isClosing, isShut: isShut,
                                   canResume: hinge.canResume, now: now) {
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

    func resume() {
        guard isMenuOpen else { return }
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
        session = nil
        pilot = nil
        lessonScript = nil
        lessonDisplay = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        setGlimmer(false)
        lockForLiveRun(false)
        feedback.silence()
        feedback.idle = true
        hud.update(hint: nil, banner: nil, stage: .asleep, bagCount: 0, debugLoot: nil)
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
    }

    // MARK: - The First Chest lesson

    func startLesson(replay: Bool, at step: LessonScript.Step = .pose) {
        lessonReplay = replay
        start(.lesson)
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
        if display != lessonDisplay { lessonDisplay = display }
    }

    // MARK: - Runs

    private func start(_ newMode: RunMode) {
        abandonLiveRun()
        resultsTask?.cancel()
        summary = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        freezePendingAt = nil
        freezePendingTag = nil
        noiseReleased = false
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
        setInput(chooseInput())
        if input == .hinge { hinge.reset() }
        hud.update(hint: nil, banner: bannerText, stage: .asleep, bagCount: 0, debugLoot: nil)
        setRoute(m == .lesson ? .lesson : .playing)
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

    private func handleFinished(immediate: Bool) {
        guard !recorded, let session, let result = session.result else { return }
        recorded = true
        checkpointSaved = false
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
                                                         newBest: outcome.isNewBest))
    }

    private func publishHUD(_ s: HeistSnapshot, now: TimeInterval) {
        var wanted = s.hint
        if let h = wanted, !AppRules.showsHint(h, runs: store.data.runs) { wanted = nil }
        if route == .lesson || isPaused { wanted = nil }
        if AppRules.silencesHints(s.phase) {
            // A bite (or the candle's end): "Freeze!" goes at once, it never stays up under CHOMP.
            wanted = nil
            if hintGate.shown != nil { hintGate.clear() }
        }
        let shown = hintGate.update(wanted, now: s.time)
        setGlimmer(shown == .relicDeeper)
        let banner = shown == nil && s.time < bannerUntil ? bannerText : nil
        var bagged = 0
        for item in s.loot where item.place == .inBag { bagged += 1 }
        let urgent = shown != hud.hint || banner != hud.banner || bagged != hud.bagCount
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        hud.update(hint: shown, banner: banner, stage: s.stage, bagCount: bagged,
                   debugLoot: isDemo ? Self.mostLit(s) : nil)
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
            if inserted && route.isPlay && demo?.noiseUntilPause == true && !noiseReleased {
                noiseReleased = true
                AppTrace.t("HUSH-T noise released \(AppTrace.fixed(session?.snapshot.noise ?? 0, 2))")
            }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
            setGlimmer(false)
        } else if !isPaused && was && route.isPlay {
            // Every resume: fresh hinge filters and half a second of silent lid (P0-2).
            if input == .hinge { hinge.reset() }
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
    }

    /// QA-1 P2-4: the screen may sleep while paused (a Duo left half-closed), never mid-chest.
    private func refreshIdleTimer() {
        let keepAwake = !isDemo && isLiveRun && !isPaused
        if UIApplication.shared.isIdleTimerDisabled != keepAwake { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    /// P0-1: portrait only while a run is live on the inner display (not while CI holds the sim in landscape).
    private func lockForLiveRun(_ on: Bool) {
        guard demo?.orient != .landscape else { return }
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
            // A phone never shows the book-pose card (UX: frame 25).
            var screen = OrientationLock.screenSize()
            if screen.width < 1 { screen = UIScreen.main.bounds.size }
            if AppRules.allowsForcedPose(.standUp, screen: screen, demoFold: d.fold) { forcedPose = .standUp }
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
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events) else { return }
            if tag.isEvent {
                freezePendingAt = playTime + DemoMode.freezeDelay(tag)
                freezePendingTag = tag
            } else {
                freeze(tag.rawValue, holdScene: false)
            }
        } else if demo.holdAfter != nil {
            freeze("after", holdScene: false)
        }
    }

    /// Whether this frame is the demo freeze moment `tag`. Pure; tested.
    nonisolated static func matches(_ tag: DemoMode.Freeze, _ s: HeistSnapshot, events: [HeistEvent]) -> Bool {
        switch tag {
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
