import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit chest underneath (R2: filling the screen, no bars), the SwiftUI screens on top.
///
/// R6 (founder P0, "when i open the whole phone it gets stuck"): ANY WAY UP. Correctness never depends on iOS's
/// interface orientation. We always know where the blurring half is (the physical half that is the bottom in iOS
/// portrait), so the portrait canvas is drawn with k clockwise quarter turns (`AppRules.quarterTurns`: the lid's edge
/// on the blurring side with "Turn the chest round" on, the opposite side with it off; k = 0 without a fold):
/// - the SpriteView is the REAL window and is never rotated by SwiftUI: the scene turns itself
///   (`ChestScene.quarterTurns`, touches read in its world) and sizes itself (never `scene.size`);
/// - every SwiftUI screen is laid out in a PORTRAIT frame (the window with w and h swapped when k is odd), with the
///   safe-area insets turned with it (`AppRules.insets(_:quarterTurns:)`), then turned `90 * k` degrees about the
///   window's centre, the same point the scene turns about, so canvas rects line up;
/// - the system-gesture edges follow (`AppRules.deferredEdges(live:quarterTurns:)`);
/// - k changes without animation, and nothing here is rebuilt when it does: the hinge reader sits on the outermost
///   view, and the SpriteView keeps one identity (only `sceneGeneration` re-identifies it);
/// - a Game Center sheet (UIKit, in iOS's own orientation) draws the app with "Turn the chest round" off while it is up.
/// Book pose no longer blocks: Home and lesson step 1 show a small dismissible tip (`PoseTip`) instead.
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
    /// The interface orientation iOS last reported (only known values are kept).
    @State private var interface: UIInterfaceOrientation = .unknown

    var body: some View {
        GeometryReader { safeGeo in
            let safe = safeGeo.safeAreaInsets
            GeometryReader { geo in
                let window = geo.size
                let frame = rootFrame(window)
                let raw = merged(safe, windowInsets)
                let tipOn = controller.showsPoseTip && frame.pose == .play
                content(window: window, frame: frame, rawInsets: raw, tipOn: tipOn)
                    .frame(width: window.width, height: window.height)
                    .onAppear {
                        refreshWindowInsets()
                        handleCanvas(window, rootFrame(window))
                        launchOnce()
                        if tipOn { controller.poseTipShown(true) }
                    }
                    .onChange(of: window) { _, newSize in
                        refreshWindowInsets()
                        handleCanvas(newSize, rootFrame(newSize))
                    }
                    .onChange(of: frame) { _, f in handleCanvas(window, f) }
                    .onChange(of: raw) { _, _ in refreshInterface() }
                    .onChange(of: tipOn) { _, on in controller.poseTipShown(on) }
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

    /// The pose, the fold (judged on the portrait-equivalent canvas, so a Duo's inner display is a fold in landscape
    /// too), the interface orientation (made to agree with the window's shape) and k.
    private func rootFrame(_ window: CGSize) -> RootFrame {
        let pose = currentPose(window)
        let iface = AppRules.settledInterface(interface, window: window, last: interface)
        let fold = AppRules.hasFold(canvas: AppRules.portraitSize(window), hingeSeen: controller.hingeSeen,
                                    demoFold: controller.demoFold)
        let onFold = fold && pose == .play
        var k = AppRules.quarterTurns(interface: iface,
                                      turnRound: controller.wantsTurnRound && !controller.systemSheetUp,
                                      hasFold: onFold, last: controller.quarterTurns)
        if let forced = controller.demoQuarterTurns, AppRules.forcedTurnsFit(forced, window: window, hasFold: onFold) {
            k = forced
        }
        return RootFrame(pose: pose, fold: onFold, turns: k, interface: iface)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(window: CGSize, frame: RootFrame, rawInsets: EdgeInsets, tipOn: Bool) -> some View {
        let k = frame.turns
        let drawn = AppRules.drawnSize(window: window, quarterTurns: k)
        let info = AppCanvas(size: drawn, insets: AppRules.insets(rawInsets, quarterTurns: k), hasFold: frame.fold,
                             turned: k == 2)
        ZStack {
            HushTheme.night
            // The scene is never rotated by SwiftUI (it turns itself), and keeps one identity whatever k does.
            gameLayer(window, hidden: frame.pose != .play)
            // Every SwiftUI screen: laid out portrait, then turned k quarter turns about the window's centre.
            ZStack {
                if frame.pose == .play {
                    screenLayer(info)
                }
            }
            .frame(width: drawn.width, height: drawn.height)
            .rotationEffect(.degrees(90 * Double(k)))
            .animation(nil, value: k)
            .frame(width: window.width, height: window.height)
            if frame.pose == .cover {
                CoverCard(midRun: controller.isLiveRun, portrait: controller.portraits.cover,
                          reduceMotion: controller.reduceMotion)
                    .transition(.opacity)
            }
            if tipOn {
                poseTipLayer(window: window, interface: frame.interface)
                    .transition(.opacity)
            }
            if controller.showsHoldHint && frame.pose == .play {
                HoldHintBanner(size: window, inMenus: !controller.route.isPlay)
                    .allowsHitTesting(false)
            }
            if controller.isDemo {
                canvasProbe(window: window, frame: frame)
            }
            if controller.showsIcon {
                iconLayer(window)
            }
        }
        .frame(width: window.width, height: window.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: frame.pose)
        .animation(HushTheme.settle(controller.reduceMotion), value: tipOn)
        .defersSystemGestures(on: AppRules.deferredEdges(live: controller.isLiveRun && !controller.isPaused,
                                                         quarterTurns: k))
    }

    private func currentPose(_ canvas: CGSize) -> AppPose {
        if let forced = controller.forcedPose { return forced }
        return AppRules.pose(canvas: canvas, hingeSeen: controller.hingeSeen, isShut: controller.isShut)
    }

    private func handleCanvas(_ window: CGSize, _ frame: RootFrame) {
        guard window.width > 1, window.height > 1 else { return }
        controller.setPose(frame.pose, canvas: window)
        // Every layout change prints `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<k>` (the real window).
        controller.updateCanvas(window, hasFold: frame.fold, quarterTurns: frame.turns)
    }

    private func merged(_ a: EdgeInsets, _ b: EdgeInsets) -> EdgeInsets {
        EdgeInsets(top: max(a.top, b.top), leading: max(a.leading, b.leading),
                   bottom: max(a.bottom, b.bottom), trailing: max(a.trailing, b.trailing))
    }

    /// The window's insets and the interface orientation; again a beat later (the window settles after a rotation or
    /// a display handover, and a 180° flip doesn't change the window's size).
    private func refreshWindowInsets() {
        let read = OrientationLock.windowSafeArea()
        if read != windowInsets { windowInsets = read }
        refreshInterface()
        Task { @MainActor in
            for delay in [UInt64(350_000_000), UInt64(550_000_000)] {
                try? await Task.sleep(nanoseconds: delay)
                let later = OrientationLock.windowSafeArea()
                if later != windowInsets { windowInsets = later }
                refreshInterface()
            }
        }
    }

    private func refreshInterface() {
        let o = OrientationLock.interfaceOrientation()
        guard o != .unknown else { return }
        if o != interface { interface = o }
        controller.interfaceChanged(o)
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
    /// aspect-fill) and turns itself. R6: it is the REAL window whatever k is. Its frame rate follows Feel
    /// (`FeedbackDirector.preferredFPS`: 60 under Low Power or a hot device).
    @ViewBuilder
    private func gameLayer(_ window: CGSize, hidden: Bool) -> some View {
        if let scene = controller.scene {
            SpriteView(scene: scene, isPaused: sceneIdle(hidden: hidden),
                       preferredFramesPerSecond: controller.preferredFPS)
                .id(controller.sceneGeneration)
                .frame(width: window.width, height: window.height)
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

    /// R6: the pose tip, upright to gravity (`AppRules.tipTurns`), on the book's sharp page, in the window's frame.
    @ViewBuilder
    private func poseTipLayer(window: CGSize, interface: UIInterfaceOrientation) -> some View {
        let device = controller.deviceOrientation
        let r = AppRules.tipTurns(device: device, interface: interface) ?? 0
        let area = AppRules.drawnSize(window: window, quarterTurns: r)
        let landscape = area.width > area.height
        let left = AppRules.poseTipOnLeft(device: device)
        let width = min(PoseTip.maxWidth, (landscape ? area.width / 2 : area.width) - 48)
        let x = landscape ? (left ? area.width * 0.25 : area.width * 0.75) : area.width / 2
        let y = landscape ? max(area.height * 0.18, 72) : max(area.height / 2 - AppCanvas.foldHalf - 64, 72)
        PoseTip(reduceMotion: controller.reduceMotion, onClose: { controller.dismissPoseTip() })
            .frame(maxWidth: max(width, 200))
            .position(x: x, y: y)
            .frame(width: area.width, height: area.height)
            .rotationEffect(.degrees(90 * Double(r)))
            .animation(nil, value: r)
            .frame(width: window.width, height: window.height)
    }

    /// R6 (CI NEEDS): `debug.canvas` (demo runs only): a pure accessibility element, no hit testing, valued
    /// `k=<k> w=<w> h=<h> fold=<0|1>` (the real window).
    private func canvasProbe(window: CGSize, frame: RootFrame) -> some View {
        Color.clear
            .frame(width: 2, height: 2)
            .position(x: 1, y: 1)
            .accessibilityElement()
            .accessibilityIdentifier("debug.canvas")
            .accessibilityValue("k=\(frame.turns) w=\(Int(window.width.rounded())) h=\(Int(window.height.rounded())) "
                                + "fold=\(frame.fold ? 1 : 0)")
            .allowsHitTesting(false)
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
/// R7 (DEVICE-RISKS-1 item 9): in menus it also shows for a Duo held flat (170–180°), with its own words: there is no
/// glowing half on Home.
struct HoldHintBanner: View {
    let size: CGSize
    var inMenus = false

    static let text = "Other way round: lift the glowing half ↻"
    static let menuText = "Upside down on purpose: turn your Duo round ↻"

    /// Pure; tested.
    static func line(inMenus: Bool) -> String { inMenus ? menuText : text }

    var body: some View {
        ZStack {
            ForEach([0.25, 0.75], id: \.self) { f in
                Text(Self.line(inMenus: inMenus))
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
        .accessibilityLabel(inMenus ? "Upside down on purpose: turn your Duo the other way round"
                            : "Turn the phone the other way round, and lift the glowing half")
    }
}
