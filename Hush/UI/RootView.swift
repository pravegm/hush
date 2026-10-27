import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit chest underneath (R2: filling the screen, no bars), the SwiftUI screens on top, the
/// pose cards above all.
///
/// TURNED ROUND (GAME-DESIGN §3, the blurred-half rule): on a Duo's portrait canvas with "Turn the chest round" on (the
/// default), the floor (and every time-critical thing) is drawn on the half iOS keeps sharp, and the player lifts the
/// half that blurs as the lid. R2: the SCENE turns itself (`ChestScene.turned`, touches read in its world, so they are
/// right by construction); SwiftUI turns only its own layer (HUD, cards, the lesson, the pages) by 180°. Hush never
/// asks iOS for upside down. The safe areas are turned with it (`AppRules.insets`), and both screen ends defer system
/// gestures during play. A Game Center sheet (UIKit, in iOS's own orientation) un-turns the app while it is up.
///
/// The hinge is read here, once, for the whole app (HingeReader → GameController.hingeSample → HingeLidSource).
struct RootView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var launched = false
    @State private var windowInsets = EdgeInsets()
    @State private var interfaceSide: InterfaceSide = .landscapeRight

    var body: some View {
        GeometryReader { safeGeo in
            let safe = safeGeo.safeAreaInsets
            GeometryReader { geo in
                let canvas = geo.size
                let pose = currentPose(canvas)
                let fold = AppRules.hasFold(canvas: canvas, hingeSeen: controller.hingeSeen,
                                            demoFold: controller.demoFold)
                let turned = turnsRound(canvas, pose: pose, fold: fold)
                let raw = merged(safe, windowInsets)
                content(canvas: canvas, pose: pose, fold: fold, turned: turned, rawInsets: raw)
                    .frame(width: canvas.width, height: canvas.height)
                    .onAppear {
                        refreshWindowInsets()
                        handleCanvas(canvas, fold: fold, turned: turned, pose: pose)
                        launchOnce()
                    }
                    .onChange(of: canvas) { _, newSize in
                        refreshWindowInsets()
                        let p = currentPose(newSize)
                        let f = AppRules.hasFold(canvas: newSize, hingeSeen: controller.hingeSeen,
                                                 demoFold: controller.demoFold)
                        handleCanvas(newSize, fold: f, turned: turnsRound(newSize, pose: p, fold: f), pose: p)
                    }
                    .onChange(of: fold) { _, f in handleCanvas(canvas, fold: f, turned: turned, pose: pose) }
                    .onChange(of: turned) { _, t in handleCanvas(canvas, fold: fold, turned: t, pose: pose) }
                    .onChange(of: pose) { _, p in handleCanvas(canvas, fold: fold, turned: turned, pose: p) }
            }
            .ignoresSafeArea()
        }
        .background(HushTheme.night.ignoresSafeArea())
        .modifier(HingeReader(onUpdate: { angle, time in
            controller.hingeSample(angle: angle, time: time)
        }, onUnavailable: {
            controller.hingeUnavailable()
        }))
        .onChange(of: scenePhase) { _, phase in
            controller.setScenePhase(phase)
            if phase == .active { refreshWindowInsets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshWindowInsets()
            controller.deviceOrientationChanged()
        }
        .onChange(of: systemReduceMotion) { _, on in controller.setSystemReduceMotion(on) }
        .onChange(of: settings.reduceMotion) { _, _ in controller.refreshMotion() }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private func turnsRound(_ canvas: CGSize, pose: AppPose, fold: Bool) -> Bool {
        AppRules.turnsRound(wanted: controller.wantsTurnRound, pose: pose, portrait: canvas.height >= canvas.width,
                            hasFold: fold, systemSheet: controller.systemSheetUp)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(canvas: CGSize, pose: AppPose, fold: Bool, turned: Bool, rawInsets: EdgeInsets) -> some View {
        let info = AppCanvas(size: canvas, insets: AppRules.insets(rawInsets, turnedRound: turned), hasFold: fold,
                             turned: turned)
        ZStack {
            HushTheme.night
            // The scene is never rotated by SwiftUI (it turns itself).
            gameLayer(canvas, hidden: pose != .play)
            switch pose {
            case .play:
                screenLayer(info)
                    .rotationEffect(turned ? .degrees(180) : .zero)
                    .animation(nil, value: turned)
            case .standUp:
                StandUpCard(insets: rawInsets,
                            liftSide: AppRules.liftSide(interface: interfaceSide,
                                                        turned: controller.wantsTurnRound),
                            reduceMotion: controller.reduceMotion,
                            onStoodUp: { controller.stoodItUp() })
                    .transition(.opacity)
            case .cover:
                CoverCard(midRun: controller.isLiveRun, portrait: controller.portraits.cover,
                          reduceMotion: controller.reduceMotion)
                    .transition(.opacity)
            }
            if controller.showsHoldHint && pose == .play {
                HoldHintBanner(size: canvas)
                    .allowsHitTesting(false)
            }
            if controller.showsIcon {
                iconLayer(canvas)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: pose)
        .defersSystemGestures(on: AppRules.deferredEdges(live: controller.isLiveRun && !controller.isPaused,
                                                         turnedRound: turned))
    }

    private func currentPose(_ canvas: CGSize) -> AppPose {
        if let forced = controller.forcedPose { return forced }
        return AppRules.pose(canvas: canvas, hingeSeen: controller.hingeSeen, isShut: controller.isShut)
    }

    private func handleCanvas(_ canvas: CGSize, fold: Bool, turned: Bool, pose: AppPose) {
        guard canvas.width > 1, canvas.height > 1 else { return }
        controller.setPose(pose)
        // Every layout change prints `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1>` (GameController.updateCanvas).
        controller.updateCanvas(canvas, hasFold: fold, turned: turned)
    }

    private func merged(_ a: EdgeInsets, _ b: EdgeInsets) -> EdgeInsets {
        EdgeInsets(top: max(a.top, b.top), leading: max(a.leading, b.leading),
                   bottom: max(a.bottom, b.bottom), trailing: max(a.trailing, b.trailing))
    }

    private func refreshWindowInsets() {
        let read = OrientationLock.windowSafeArea()
        if read != windowInsets { windowInsets = read }
        if let side = OrientationLock.interfaceSide(), side != interfaceSide { interfaceSide = side }
        // The window settles its insets a beat after a rotation or a display handover.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let later = OrientationLock.windowSafeArea()
            if later != windowInsets { windowInsets = later }
            if let side = OrientationLock.interfaceSide(), side != interfaceSide { interfaceSide = side }
        }
    }

    private func launchOnce() {
        guard !launched else { return }
        launched = true
        controller.setSystemReduceMotion(systemReduceMotion)
        OrientationLock.refreshSupportedOrientations()
        controller.launch()
    }

    // MARK: - Layers

    /// The scene renders only while a chest is on screen (real runs; CI's demo launches always render, they wait for
    /// `HUSH-T frame 120`), and holds still on a demo event freeze.
    private func sceneIdle(hidden: Bool) -> Bool {
        if controller.sceneHeld { return true }
        guard !controller.isDemo else { return false }
        return hidden || !controller.route.isPlay
    }

    /// R2: the SpriteView fills the screen; the scene is laid out for it (`ScreenLayout.make(hasFold:viewSize:)`,
    /// aspect-fill) and turns itself. Its frame rate follows Feel (`FeedbackDirector.preferredFPS`: 60 under Low Power
    /// or a hot device).
    @ViewBuilder
    private func gameLayer(_ canvas: CGSize, hidden: Bool) -> some View {
        if let scene = controller.scene {
            SpriteView(scene: scene, isPaused: sceneIdle(hidden: hidden),
                       preferredFramesPerSecond: controller.preferredFPS)
                .id(controller.sceneGeneration)
                .frame(width: canvas.width, height: canvas.height)
                .opacity(controller.route.isPlay && !hidden ? 1 : 0.001)
                .allowsHitTesting(controller.route.isPlay && !hidden)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func screenLayer(_ info: AppCanvas) -> some View {
        ZStack {
            switch controller.route {
            case .home:
                HomeView(controller: controller, store: store, info: info)
                    .transition(.opacity)
            case .playing, .lesson:
                PlayLayer(controller: controller, hud: controller.hud, info: info)
                    .transition(.opacity)
            case .results:
                if let summary = controller.summary {
                    ResultsView(controller: controller, summary: summary, info: info)
                        .transition(HushTheme.pageTransition(controller.reduceMotion))
                }
            case .codex:
                CodexView(controller: controller, store: store, info: info)
                    .transition(HushTheme.pageTransition(controller.reduceMotion))
            case .badges:
                BadgesView(controller: controller, store: store, info: info)
                    .transition(HushTheme.pageTransition(controller.reduceMotion))
            case .settings:
                SettingsView(controller: controller, settings: settings, info: info)
                    .transition(HushTheme.pageTransition(controller.reduceMotion))
            case .daily:
                DailyView(controller: controller, store: store, info: info)
                    .transition(HushTheme.pageTransition(controller.reduceMotion))
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.route)
    }

    @ViewBuilder
    private func iconLayer(_ canvas: CGSize) -> some View {
        let side = min(canvas.width, canvas.height)
        ZStack {
            Color.black
            AppIconArt()
                .frame(width: side, height: side)
        }
        .frame(width: canvas.width, height: canvas.height)
        .onAppear { IconExport.render() }
    }
}

/// R2 (REVIEW-1-duo P1-7): held upright the normal way (camera end up) while the chest is drawn turned round, the
/// whole game reads upside down. This banner is drawn UN-turned, once on each half, so it reads right as held.
struct HoldHintBanner: View {
    let size: CGSize

    static let text = "Other way round: lift the glowing half ↻"

    var body: some View {
        ZStack {
            ForEach([0.25, 0.75], id: \.self) { f in
                Text(Self.text)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(HushTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(HushTheme.gold))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .frame(maxWidth: size.width - 48)
                    .position(x: size.width / 2, y: size.height * f)
            }
        }
        .frame(width: size.width, height: size.height)
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Turn the phone the other way round, and lift the glowing half")
    }
}
