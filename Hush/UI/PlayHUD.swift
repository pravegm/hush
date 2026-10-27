import SwiftUI

/// The words for Core's hints (Core decides which applies; the UI owns the words). ≤ 6 words each; the slider's
/// words when the lid is the on-screen lever. Pure; tested.
enum HushCopy {
    static func hint(_ hint: HeistHint, slider: Bool) -> String {
        switch hint {
        case .easeLidDown: return slider ? "Slide the lever down first" : "Ease the lid down first"
        case .openSlowly: return slider ? "Slide the lever up… slowly" : "Open the lid… slowly"
        case .slower: return "Slower…"
        case .freeze: return "Freeze!"
        case .dragToBag: return "Drag the loot into your bag"
        case .shutToBank: return slider ? "Slide it down to keep it" : "Ease it shut to keep it"
        case .tooWide: return "That's wide enough"
        case .candleLow: return "Candle's low. Bank it!"
        case .relicDeeper: return "Something glints deeper…"
        }
    }

    /// Every hint, for the tests and the word-count rule (HeistHint isn't CaseIterable).
    static let allHints: [HeistHint] = [.easeLidDown, .openSlowly, .slower, .freeze, .dragToBag, .shutToBank, .tooWide,
                                        .candleLow, .relicDeeper]

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0 == " " }).count
    }

    /// The lesson's last card: the stakes, one icon row each (UX P0-3). ≤ 6 words a row; tested.
    static let stakes: [StakeRow] = [
        StakeRow(icon: "flame.fill", text: "Candle out = run over"),
        StakeRow(icon: "exclamationmark.triangle.fill", text: "Too loud? It bites your bag"),
        StakeRow(icon: "lock.fill", text: "Shut the lid to bank it"),
    ]
}

struct StakeRow: Hashable {
    var icon: String
    var text: String
}

/// Everything SwiftUI draws over a live chest: the one-line hint at the floor's back edge (by the fold), the brass pause
/// coin, the Daily marker, the pause menu, the closing card and the First Chest lesson. Only buttons take touches;
/// everything else lets the fingers through to the loot. R2: turned round by RootView with the rest of the SwiftUI
/// layer (the scene turns itself), so every rect here is in unturned canvas terms.
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    var body: some View {
        let fit = info.fit
        let band = fit.viewRect(canvas: HUDLayout.hintBand)
        ZStack {
            accessibilityHooks(fit)
            if let lesson = controller.lessonDisplay, controller.route == .lesson {
                LessonOverlay(controller: controller, lesson: lesson, fit: fit, info: info,
                              reduceMotion: controller.reduceMotion)
            } else {
                HintLine(hint: hud.hint, banner: hud.banner, slider: controller.sliderWording, scale: fit.textScale,
                         reduceMotion: controller.reduceMotion)
                    .frame(width: band.width, height: band.height)
                    .position(x: band.midX, y: band.midY)
                    .allowsHitTesting(false)
            }
            if let marker = controller.dailyMarker, controller.route == .playing {
                HushPill(text: marker, fill: HushTheme.night.opacity(0.72), foreground: HushTheme.goldLight,
                         fontSize: 12)
                    .position(x: info.safeRect.minX + AppCanvas.pauseInset + 90,
                              y: info.safeRect.minY + AppCanvas.pauseInset + 14)
                    .allowsHitTesting(false)
            }
            if !(controller.lessonDisplay?.isFinal ?? false) {
                let pause = info.pauseCenter()
                BrassCoinButton(systemName: "pause.fill", label: "Pause") { controller.openMenu() }
                    .position(x: pause.x, y: pause.y)
                    .opacity(controller.isMenuOpen || controller.isClosingPaused ? 0 : 1)
            }
            if controller.isMenuOpen {
                PauseMenu(controller: controller, info: info)
                    .transition(.opacity)
            } else if controller.isClosingPaused {
                ClosingCard(controller: controller, info: info)
                    .transition(.opacity)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.isMenuOpen)
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.isClosingPaused)
    }

    /// `hud.bag` (all builds, VoiceOver too) and `debug.loot` (demo runs): pure accessibility elements over where the
    /// pouch and the most-lit item are drawn, for CI's turned-drag UI test. They take no touches.
    @ViewBuilder
    private func accessibilityHooks(_ fit: CanvasFit) -> some View {
        let bag = fit.viewRect(canvas: HUDLayout.bagRect)
        Color.clear
            .frame(width: bag.width, height: bag.height)
            .position(x: bag.midX, y: bag.midY)
            .accessibilityElement()
            .accessibilityIdentifier("hud.bag")
            .accessibilityLabel("In bag")
            .accessibilityValue("\(hud.bagCount)")
            .allowsHitTesting(false)
        if controller.isDemo, let loot = hud.debugLoot {
            let p = fit.viewPoint(canvas: ChestLayout.canvas(fromFloor: loot.floorPoint))
            let side = max(loot.radius * 2 * fit.scale, 8)
            Color.clear
                .frame(width: side, height: side)
                .position(x: p.x, y: p.y)
                .accessibilityElement()
                .accessibilityIdentifier("debug.loot")
                .accessibilityValue("id=\(loot.id) kind=\(loot.kind)")
                .allowsHitTesting(false)
        }
    }
}

/// The one-line hint (or the run-start banner). Warnings glow amber/red; "Freeze!" pulses.
struct HintLine: View {
    let hint: HeistHint?
    let banner: String?
    let slider: Bool
    var scale: CGFloat = 1
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if let hint {
                let warning = AppRules.isWarning(hint)
                Text(HushCopy.hint(hint, slider: slider))
                    .font(HushType.hint(scale: scale))
                    .foregroundStyle(color(hint))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 18 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Capsule().fill(HushTheme.night.opacity(warning ? 0.82 : 0.66))
                        .overlay(Capsule().stroke(color(hint).opacity(warning ? 0.6 : 0.2), lineWidth: 1.5)))
                    .hushLegible()
                    .scaleEffect(hint == .freeze && pulse && !reduceMotion ? 1.08 : 1)
                    .id(hint)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .accessibilityLabel(HushCopy.hint(hint, slider: slider))
            } else if let banner {
                Text(banner)
                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(HushTheme.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 16 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Capsule().fill(HushTheme.night.opacity(0.6)))
                    .hushLegible()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: hint)
        .animation(.easeOut(duration: 0.25), value: banner)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func color(_ hint: HeistHint) -> Color {
        switch hint {
        case .freeze: return HushTheme.danger
        case .slower, .easeLidDown, .candleLow: return HushTheme.amber
        case .tooWide: return HushTheme.mist
        case .relicDeeper: return HushTheme.goldLight
        case .openSlowly, .dragToBag, .shutToBank: return HushTheme.parchment
        }
    }
}

/// The pause menu: Resume, Restart, Home, on the floor half (the sharp, reachable one).
struct PauseMenu: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    var body: some View {
        let floor = info.floorHalf
        let c = info.isCompact
        ZStack {
            Color.black.opacity(0.55)
                .contentShape(Rectangle())
                .onTapGesture {}
            Text("Shh… it's dozing.")
                .font(HushType.title(c))
                .foregroundStyle(HushTheme.parchment)
                .hushLegible()
                .position(x: info.lidHalf.midX, y: info.lidHalf.midY)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                HushOverline(text: "Paused", compact: c, color: HushTheme.gold)
                HushButton(kind: .primary, compact: c, action: { controller.resume() }) {
                    Label("Resume", systemImage: "play.fill")
                }
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: c,
                           action: { controller.restart() }) {
                    Label(controller.restartLabel, systemImage: "arrow.counterclockwise")
                }
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: c,
                           action: { controller.goHome() }) {
                    Label("Home", systemImage: "house.fill")
                }
                if controller.isScoredDaily {
                    Text("Leaving keeps the gold you've banked.")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: min(floor.width - 40, 400))
            .hushCard()
            .position(x: floor.midX, y: floor.midY)
        }
    }
}

/// The closing pause: "Lift the lid a little to carry on", then, once it's back up, "Hold still…" until Feel says it
/// is still (R2 P0-2: never resumes mid-motion).
struct ClosingCard: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    /// Pure; tested.
    static func title(lifted: Bool) -> String { lifted ? "Hold still…" : "Lift the lid a little to carry on" }
    static func detail(lifted: Bool) -> String {
        lifted ? "Then we tiptoe on." : "The mimic waits. Your candle does too."
    }

    var body: some View {
        let floor = info.floorHalf
        let c = info.isCompact
        let lifted = controller.closingLifted
        ZStack {
            Color.black.opacity(0.6)
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(spacing: 8) {
                Image(systemName: lifted ? "hand.raised.fill" : "arrow.up")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(HushTheme.gold)
                Text(lifted ? "Shh…" : "Lift me")
                    .font(HushType.headline(c))
                    .foregroundStyle(HushTheme.goldLight)
            }
            .position(x: info.lidHalf.midX, y: info.lidHalf.midY)
            .accessibilityHidden(true)
            VStack(spacing: 14) {
                DuoDiagram(style: .tabletop(angle: 115), reduceMotion: controller.reduceMotion || lifted)
                    .frame(width: 150, height: 96)
                Text(Self.title(lifted: lifted))
                    .font(HushType.headline(c))
                    .foregroundStyle(HushTheme.parchment)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.detail(lifted: lifted))
                    .font(HushType.caption(c))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if controller.isScoredDaily {
                    Text("Leaving keeps the gold you've banked.")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.haze)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HushButton(kind: .quiet, height: HushTheme.minTap, compact: c, action: { controller.goHome() }) {
                    Text("Home")
                }
            }
            .frame(width: min(floor.width - 40, 400))
            .hushCard()
            .position(x: floor.midX, y: floor.midY)
            .accessibilityElement(children: .contain)
        }
    }
}

/// The First Chest lesson over the chest: the step card above the noise meter (R2: never over it), the lid marker in
/// the pose step (the lever on a phone), a ring round the meter when the line talks about the noise, and the final
/// card.
struct LessonOverlay: View {
    @ObservedObject var controller: GameController
    let lesson: LessonDisplay
    let fit: CanvasFit
    let info: AppCanvas
    let reduceMotion: Bool
    @State private var glow = false

    var body: some View {
        let band = fit.viewRect(canvas: HUDLayout.lessonBand)
        let lid = fit.lidRect
        let meter = fit.viewRect(canvas: ChestLayout.meterRect)
        ZStack {
            if lesson.marksLid {
                if lesson.usesSlider {
                    leverMarker
                } else {
                    // "Lift THIS half": the lid half glows, with an arrow and the words.
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(HushTheme.gold.opacity(glow ? 0.95 : 0.45), lineWidth: 5)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(HushTheme.gold.opacity(glow ? 0.12 : 0.05)))
                        .frame(width: lid.width - 24, height: lid.height - 24)
                        .position(x: lid.midX, y: lid.midY)
                        .allowsHitTesting(false)
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 44 * fit.textScale, weight: .black, design: .rounded))
                            .offset(y: glow && !reduceMotion ? -8 : 0)
                        Text("Lift this half")
                            .font(.system(size: 32 * fit.textScale, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(HushTheme.goldLight)
                    .hushLegible()
                    .position(x: lid.midX, y: lid.midY)
                    .allowsHitTesting(false)
                }
            }
            if lesson.pointsAtMeter {
                Capsule()
                    .stroke(HushTheme.goldLight.opacity(glow ? 0.95 : 0.35), lineWidth: 3)
                    .frame(width: meter.width + 16, height: meter.height + 12)
                    .position(x: meter.midX, y: meter.midY)
                    .allowsHitTesting(false)
            }
            if lesson.isFinal {
                LessonFinalCard(controller: controller, compact: info.isCompact,
                                width: min(info.size.width - 32, 380))
                    .position(x: info.floorHalf.midX, y: info.floorHalf.midY)
            } else {
                LessonStepCard(controller: controller, lesson: lesson, scale: fit.textScale)
                    .frame(width: band.width)
                    .fixedSize(horizontal: false, vertical: true)
                    .position(x: band.midX, y: band.midY)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                glow = true
                return
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    /// Phone, step 1: an arrow up the lever's track and "Slide this up… slowly" beside it (UX P0-4).
    private var leverMarker: some View {
        let track = fit.viewRect(canvas: HUDLayout.leverTrack)
        return ZStack {
            Capsule()
                .stroke(HushTheme.gold.opacity(glow ? 0.95 : 0.4), lineWidth: 4)
                .frame(width: track.width + 18, height: track.height + 18)
                .position(x: track.midX, y: track.midY)
            Image(systemName: "arrow.up")
                .font(.system(size: 40 * fit.textScale, weight: .black, design: .rounded))
                .foregroundStyle(HushTheme.goldLight)
                .offset(y: glow && !reduceMotion ? -14 : 0)
                .position(x: track.minX - 34 * fit.textScale, y: track.midY)
            Text("Slide this up… slowly")
                .font(.system(size: 26 * fit.textScale, weight: .heavy, design: .rounded))
                .foregroundStyle(HushTheme.goldLight)
                .multilineTextAlignment(.trailing)
                .frame(width: max(track.minX - 80 * fit.textScale, 80), alignment: .trailing)
                .position(x: (track.minX - 70 * fit.textScale) / 2, y: track.midY)
        }
        .hushLegible()
        .allowsHitTesting(false)
    }
}

struct LessonStepCard: View {
    @ObservedObject var controller: GameController
    let lesson: LessonDisplay
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { i in
                        Capsule()
                            .fill(i < lesson.step ? HushTheme.gold : (i == lesson.step ? HushTheme.goldLight :
                                                                        HushTheme.moss))
                            .frame(width: i == lesson.step ? 22 : 10, height: 8)
                    }
                    Text("FIRST CHEST")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .kerning(1.4)
                        .foregroundStyle(HushTheme.mist)
                        .padding(.leading, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("First Chest, step \(lesson.step) of 5")
                Text(lesson.line)
                    .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(lineColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(lesson.line)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            if lesson.canSkip {
                Button {
                    FeedbackDirector.shared.uiTap()
                    controller.skipLesson()
                } label: {
                    Text("Skip")
                        .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(HushTheme.mist)
                        .frame(minWidth: HushTheme.minTap, minHeight: HushTheme.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HushPressStyle())
                .accessibilityLabel("Skip the lesson")
            }
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 8 * scale)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(HushTheme.night.opacity(0.84))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(lineColor.opacity(lesson.warning ? 0.7 : 0.25), lineWidth: 1.5))
            .allowsHitTesting(false))
        .animation(.easeOut(duration: 0.2), value: lesson.line)
        .accessibilityElement(children: .contain)
    }

    private var lineColor: Color {
        if lesson.praise { return HushTheme.asleep }
        if lesson.warning { return lesson.line.hasPrefix("Slower") ? HushTheme.amber : HushTheme.danger }
        return HushTheme.parchment
    }
}

/// Step 6 (UX P0-3): the stakes, three icon rows, then "Got it" (the first run).
struct LessonFinalCard: View {
    @ObservedObject var controller: GameController
    let compact: Bool
    let width: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            Text("Lovely work, little thief.")
                .font(HushType.title(compact))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(HushCopy.stakes, id: \.text) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(HushTheme.gold)
                            .frame(width: 30)
                        Text(row.text)
                            .font(HushType.body(compact))
                            .foregroundStyle(HushTheme.parchment)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            HushButton(kind: .primary, compact: compact, confirm: true, action: { controller.finishLesson() }) {
                Text("Got it")
            }
            HushButton(kind: .quiet, height: HushTheme.minTap, compact: compact,
                       action: { controller.finishLessonHome() }) {
                Text(controller.lessonReplaying ? "Home" : "Not yet, take me home")
            }
        }
        .frame(width: max(width - 44, 200))
        .hushCard(padding: 22)
    }
}
