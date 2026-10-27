import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): ChestScene.update → advance(dt:now:) → lid source
/// (hinge, slider, pilot) → HeistSession.step → FeedbackDirector → HUD. Owns the session, the scene, the lid sources, the
/// app's route, the First Chest lesson and the Duo states (pose, closing, shut).
///
/// Pauses (no stepping): the lid closing (θ < 85° for 0.4 s), the app inactive, the pause menu, and a pose card
/// (book pose, the cover display).
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
    /// A closing pause lifts once the lid is back above this (a little hysteresis over Tuning.closingAngle).
    static let closingResumeAbove: Double = 88
    /// The torch's ending is Core's 2 s moment; the Results card follows after this beat.
    static let resultsDelay: Double = 0.5
    /// The run-start line's life (session s).
    static let bannerSeconds: Double = 2.6
    /// Home's title chest publishes at most this often.
    static let homeLidInterval: Double = 1.0 / 30.0
    static let toastSeconds: Double = 2.4

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
    /// "Lift the lid a little to carry on".
    @Published private(set) var isClosingPaused = false
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var lessonDisplay: LessonDisplay?
    @Published private(set) var homeLid = HomeLid()
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover` forces a pose.
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon`: the app icon full screen (and rendered to Documents).
    @Published private(set) var showsIcon = false
    @Published private(set) var mode: RunMode = .run
    /// A short line over Home ("Sign in to Game Center in Settings").
    @Published private(set) var toast: String?
    @Published private(set) var reduceMotion = false

    let hud = HUDState()
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
    /// Touch events reach Feedback at once and the scene on the next frame (ARCHITECTURE).
    private var pendingSceneEvents: [HeistEvent] = []
    private var pendingLessonEvents: [HeistEvent] = []
    private var frames = 0
    private var lastHUD: TimeInterval = -1
    private var lastLidLog: TimeInterval = -1
    private var hintGate = HintGate()
    private var recorded = false
    private var resultsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var belowClosingSince: TimeInterval?
    /// Session seconds stepped this run (the demo freeze-after key).
    private var playTime: Double = 0
    /// Demo freeze: the session no longer steps (the scene keeps drawing the held frame).
    private(set) var frozen = false
    private var freezePendingAt: Double?
    private var freezePendingTag: DemoMode.Freeze?
    private var systemReduceMotion = false
    private var homeTicker: FrameTicker?
    private var lastHomeLid: TimeInterval = -1
    private var lastCanvasLine = ""
    /// The day of the scored Daily try in play (a quit files its gold so far).
    private var scoredDailyDay: Int?
    private var bannerText: String?
    private var bannerUntil: Double = 0

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

    // MARK: - SceneDriver

    var usesSlider: Bool { input == .slider && route.isPlay }

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("HUSH-T frame 120") }
        var out = pendingSceneEvents
        pendingSceneEvents.removeAll()
        guard let session else { return (HeistSnapshot(), out) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, out) }
        checkClosing(now: now)
        if isPaused || frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, dragSpeed: 0, playing: false))
            return (session.snapshot, out)
        }
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (session.snapshot, out) }

        var events: [HeistEvent] = []
        let lid = currentLid(now: now, step: step, session: session, events: &events)
        if let level = demo?.noise { session.nudgeNoise(to: level) }
        events += session.step(dt: step, lid: lid)
        playTime += step
        var snapshot = session.snapshot

        if var script = lessonScript {
            let lessonIn = lessonInput(snapshot, events: pendingLessonEvents + events, dragSpeed: session.dragSpeed)
            pendingLessonEvents.removeAll()
            let actions = script.update(lessonIn)
            lessonScript = script
            for action in actions {
                switch action {
                case let .nudgeNoise(level): session.nudgeNoise(to: level)
                }
            }
            if !actions.isEmpty { snapshot = session.snapshot }
            publishLesson(script, hint: snapshot.hint)
        }

        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, dragSpeed: session.dragSpeed,
                                                              playing: AppRules.isLive(snapshot.phase)))
        for event in events { AppTrace.t("HUSH-T event " + AppTrace.describe(event)) }
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
        for event in events { AppTrace.t("HUSH-T event " + AppTrace.describe(event)) }
        pendingSceneEvents += events
        if lessonScript != nil { pendingLessonEvents += events }
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
        if let demo {
            launchDemo(demo)
            return
        }
        if store.data.lessonDone {
            goHome()
        } else {
            // First launch: the First Chest (GAME-DESIGN §8).
            startLesson(replay: false)
        }
    }

    /// The play canvas changed (fold, turned round). The scene is built once and then re-laid out.
    func updateCanvas(_ size: CGSize, hasFold: Bool, turned: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        let line = "HUSH-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) turned=\(turned ? 1 : 0)"
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
        }
        let newLayout = ScreenLayout.make(hasFold: hasFold)
        guard newLayout != layout || scene == nil else { return }
        layout = newLayout
        if let scene {
            scene.layout = newLayout
        } else {
            makeScene(newLayout)
        }
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = ChestScene(layout: layout)
        newScene.scaleMode = .aspectFit
        newScene.reduceMotion = reduceMotion
        newScene.driver = self
        scene = newScene
        sceneGeneration += 1
        newScene.reset()
    }

    func setAppActive(_ active: Bool) {
        if active {
            setPause(.background, false)
            if route == .home { startHomeTicker() }
        } else {
            // A kill after the scored Daily started must not lose the day's gold.
            if let day = scoredDailyDay, let session, !recorded {
                store.recordPartialDaily(day: day, gold: session.snapshot.banked)
            }
            if isLiveRun && !isDemo { openMenu() }
            setPause(.background, true)
            homeTicker?.stop()
            feedback.silence()
        }
    }

    /// The display's pose changed (book pose, cover display).
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        pose = newPose
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
        }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
        }
        refreshInput()
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    /// θ < 85° for 0.4 s pauses a hinge run: "Lift the lid a little to carry on". Back above 88° resumes it.
    private func checkClosing(now: TimeInterval) {
        guard input == .hinge, route.isPlay, session != nil else {
            if isClosingPaused {
                isClosingPaused = false
                setPause(.closing, false)
            }
            belowClosingSince = nil
            return
        }
        let angle = hinge.angle
        if let a = angle, a < Tuning.closingAngle {
            if belowClosingSince == nil { belowClosingSince = now }
        } else {
            belowClosingSince = nil
        }
        let dwelled = belowClosingSince.map { now - $0 >= Tuning.closingDwell } ?? false
        let closing = hinge.isClosing || dwelled || isShut
        if closing {
            guard !isClosingPaused else { return }
            isClosingPaused = true
            setPause(.closing, true)
            #if DEBUG
            // A literal of its own, DEBUG only: CI's TestFlight guard greps the Release binary for it.
            if AppTrace.enabled {
                print("HUSH-T paused closing")
                fflush(stdout)
            }
            #endif
        } else if isClosingPaused && (angle ?? 180) >= Self.closingResumeAbove {
            isClosingPaused = false
            setPause(.closing, false)
        }
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
        guard now - lastHomeLid >= Self.homeLidInterval else { return }
        lastHomeLid = now
        let fresh = HomeLid(openness: (lid.openness * 100).rounded() / 100, speed: lid.speed.rounded())
        if fresh != homeLid { homeLid = fresh }
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

    func again() {
        guard let summary else {
            start(.run)
            return
        }
        switch summary.result.mode {
        case .run: start(.run)
        case let .daily(day, _): start(.daily(day: day == today ? day : today, scored: day != today))
        case .attract: start(.attract)
        case .lesson: start(.run)
        }
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
        UIApplication.shared.isIdleTimerDisabled = false
        feedback.silence()
        feedback.idle = true
        hud.update(hint: nil, banner: nil, stage: .asleep)
        setRoute(.home)
    }

    func showGameCenter() {
        switch GameCenterManager.shared.showDashboard() {
        case .shown, .signingIn: break
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
        publishLesson(script, hint: nil)
    }

    func replayLesson() { startLesson(replay: true) }

    /// Skip (offered after step 2): the lesson counts as done.
    func skipLesson() {
        store.markLessonDone()
        goHome()
    }

    /// The final card's "Start my first run".
    func finishLesson() {
        store.markLessonDone()
        start(.run)
    }

    func finishLessonHome() {
        store.markLessonDone()
        goHome()
    }

    private func lessonInput(_ s: HeistSnapshot, events: [HeistEvent], dragSpeed: Double) -> LessonScript.Input {
        LessonScript.Input(time: s.time, angle: input == .hinge ? hinge.angle : nil, hasHinge: input == .hinge,
                           openness: s.openness, lidSpeed: s.lidSpeed, dragSpeed: dragSpeed,
                           anyGrabbable: s.loot.contains { $0.place == .inChest && $0.grabbable },
                           bagCount: s.loot.filter { $0.place == .inBag }.count, noise: s.noise, hint: s.hint,
                           events: events)
    }

    private func publishLesson(_ script: LessonScript, hint: HeistHint?) {
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
        freezePendingAt = nil
        freezePendingTag = nil
        var m = newMode
        if case let .daily(day, scored) = m, scored {
            if store.canPlayScoredDaily(today: day) {
                store.startDaily(day: day)
                scoredDailyDay = day
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
        hintGate = HintGate()
        lastHUD = -1
        pendingSceneEvents.removeAll()
        pendingLessonEvents.removeAll()
        bannerText = Self.startBanner(m)
        bannerUntil = bannerText == nil ? 0 : Self.bannerSeconds
        scene?.reset()
        setInput(chooseInput())
        UIApplication.shared.isIdleTimerDisabled = !isDemo
        hud.update(hint: nil, banner: bannerText, stage: .asleep)
        setRoute(m == .lesson ? .lesson : .playing)
    }

    /// The run-start line (≤ 6 words), shown while no hint is up.
    nonisolated static func startBanner(_ mode: RunMode) -> String? {
        switch mode {
        case .run: return "Torch lit. Open it gently."
        case let .daily(_, scored): return scored ? "Daily Dungeon: your scored try" : "Practice: no score today"
        case .attract, .lesson: return nil
        }
    }

    private func seed(for mode: RunMode) -> UInt64 {
        switch mode {
        case .run:
            if let s = demo?.seed { return s }
            if isDemo { return DemoMode.defaultSeed }
            return UInt64.random(in: 1...UInt64.max)
        case let .daily(day, _):
            return DailySeed.seed(day: day)
        case .attract:
            return demo?.seed ?? DemoMode.defaultSeed
        case .lesson:
            return 1
        }
    }

    /// Leaving a live scored Daily (Home, Restart, a new run): its gold so far is the day's score.
    private func abandonLiveRun() {
        guard let day = scoredDailyDay else { return }
        scoredDailyDay = nil
        guard let session, !recorded else { return }
        let gold = session.snapshot.banked
        store.recordPartialDaily(day: day, gold: gold)
        GameCenterManager.shared.reportDailyPartial(gold: gold, day: day)
    }

    private func handleFinished(immediate: Bool) {
        guard !recorded, let session, let result = session.result else { return }
        recorded = true
        scoredDailyDay = nil
        UIApplication.shared.isIdleTimerDisabled = false
        let outcome = store.record(result, today: today)
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("HUSH-T run gold=\(result.gold) chests=\(result.chestsBanked) bites=\(result.bites) "
                   + "seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        summary = makeSummary(result, outcome: outcome)
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
            title = scored ? "Daily Dungeon #\(day)" : "Daily practice"
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
                             rankProgressAfter: after, againLabel: again)
    }

    private func publishHUD(_ s: HeistSnapshot, now: TimeInterval) {
        var wanted = s.hint
        if let h = wanted, !AppRules.showsHint(h, runs: store.data.runs) { wanted = nil }
        if route == .lesson { wanted = nil }
        let shown = hintGate.update(wanted, now: s.time)
        let banner = shown == nil && s.time < bannerUntil ? bannerText : nil
        let urgent = shown != hud.hint || banner != hud.banner
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        hud.update(hint: shown, banner: banner, stage: s.stage)
    }

    // MARK: - Pauses

    private func setPause(_ reason: PauseReason, _ on: Bool) {
        let was = isPaused
        if on {
            let inserted = pauseReasons.insert(reason).inserted
            if inserted && route.isPlay && reason != .closing { AppTrace.t("HUSH-T paused \(reason.rawValue)") }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
        } else if !isPaused && was && route.isPlay {
            AppTrace.t("HUSH-T resumed")
        }
    }

    private func clearRunPauses() {
        pauseReasons.remove(.menu)
        pauseReasons.remove(.closing)
        if isMenuOpen { isMenuOpen = false }
        if isClosingPaused { isClosingPaused = false }
        belowClosingSince = nil
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
                let played = DemoRunner.play(session, skill: d.pilot ?? .expert, seed: session.seed, seconds: skip,
                                             time0: CACurrentMediaTime() - skip)
                playTime = played
                AppTrace.t("HUSH-T skipped \(AppTrace.fixed(played, 1))")
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
            forcedPose = .standUp
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            forcedPose = .cover
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .icon:
            showsIcon = true
            goHome()
        case .badges:
            goHome()
            BadgeExport.renderAll()
        }
        if let orient = d.orient { DemoOrientation.request(orient) }
    }

    private func demoAfterStep(_ s: HeistSnapshot, events: [HeistEvent]) {
        guard let demo, !frozen else { return }
        if let at = freezePendingAt {
            if playTime >= at { freeze(freezePendingTag?.rawValue ?? "after") }
            return
        }
        if let after = demo.holdAfter, playTime < after { return }
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events) else { return }
            if tag.isEvent {
                freezePendingAt = playTime + DemoMode.freezeEventDelay
                freezePendingTag = tag
            } else {
                freeze(tag.rawValue)
            }
        } else if demo.holdAfter != nil {
            freeze("after")
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

    private func freeze(_ tag: String) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        AppTrace.t("HUSH-T freeze \(tag)")
    }
}
