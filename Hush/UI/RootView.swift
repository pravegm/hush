import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit chest underneath (framed to the aspect-fit canvas), the SwiftUI screens on top, the pose
/// cards above all.
///
/// TURNED ROUND (GAME-DESIGN §3, the blurred-half rule; Brim's method, simpler): on a Duo's portrait canvas with "Turn
/// the chest round" on (the default), everything portrait is drawn rotated 180°, so the floor (and every
/// time-critical thing) lands on the half iOS keeps sharp, and the player lifts the half that blurs as the lid. Hush
/// never asks iOS for upside down (it isn't in the plist), so there is no "already upside down" case. The safe areas
/// are turned with it (`AppRules.insets`), and both screen ends defer system gestures during play.
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
                let turned = AppRules.turnsRound(wanted: controller.wantsTurnRound, pose: pose,
                                                 portrait: canvas.height >= canvas.width, hasFold: fold)
                let insets = AppRules.insets(merged(safe, windowInsets), turnedRound: turned)
                content(canvas: canvas, pose: pose, fold: fold, turned: turned, insets: insets,
                        rawInsets: merged(safe, windowInsets))
                    .frame(width: canvas.width, height: canvas.height)
                    .rotationEffect(turned ? .degrees(180) : .zero)
                    .animation(nil, value: turned)
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
                        let t = AppRules.turnsRound(wanted: controller.wantsTurnRound, pose: p,
                                                    portrait: newSize.height >= newSize.width, hasFold: f)
                        handleCanvas(newSize, fold: f, turned: t, pose: p)
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
            controller.setAppActive(phase == .active)
            if phase == .active { refreshWindowInsets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshWindowInsets()
        }
        .onChange(of: systemReduceMotion) { _, on in controller.setSystemReduceMotion(on) }
        .onChange(of: settings.reduceMotion) { _, _ in controller.refreshMotion() }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(canvas: CGSize, pose: AppPose, fold: Bool, turned: Bool, insets: EdgeInsets,
                         rawInsets: EdgeInsets) -> some View {
        let info = AppCanvas(size: canvas, insets: insets, hasFold: fold, turned: turned)
        ZStack {
            HushTheme.night
            switch pose {
            case .play:
                gameLayer(info, hidden: false)
                screenLayer(info)
            case .standUp:
                gameLayer(info, hidden: true)
                StandUpCard(insets: rawInsets,
                            liftSide: AppRules.liftSide(interface: interfaceSide,
                                                        turned: controller.wantsTurnRound),
                            reduceMotion: controller.reduceMotion)
                    .transition(.opacity)
            case .cover:
                gameLayer(info, hidden: true)
                CoverCard(midRun: controller.isLiveRun, reduceMotion: controller.reduceMotion)
                    .transition(.opacity)
            }
            if controller.showsIcon {
                iconLayer(canvas)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: pose)
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
    /// `HUSH-T frame 120`).
    private func sceneIdle(hidden: Bool) -> Bool {
        guard !controller.isDemo else { return false }
        return hidden || !controller.route.isPlay
    }

    @ViewBuilder
    private func gameLayer(_ info: AppCanvas, hidden: Bool) -> some View {
        if let scene = controller.scene {
            let fit = info.fit
            SpriteView(scene: scene, isPaused: sceneIdle(hidden: hidden), preferredFramesPerSecond: 120)
                .id(controller.sceneGeneration)
                .frame(width: fit.rect.width, height: fit.rect.height)
                .position(x: fit.rect.midX, y: fit.rect.midY)
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
        .defersSystemGestures(on: AppRules.deferredEdges(live: controller.isLiveRun && !controller.isPaused,
                                                         turnedRound: info.turned))
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
