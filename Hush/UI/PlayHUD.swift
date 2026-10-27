import SwiftUI

/// The words for Core's hints (Core decides which applies; the UI owns the words). ≤ 6 words each; the slider's
/// words when the lid is the on-screen slider. Pure; tested.
enum HushCopy {
    static func hint(_ hint: HeistHint, slider: Bool) -> String {
        switch hint {
        case .easeLidDown: return slider ? "Slide the lid down first" : "Ease the lid down first"
        case .openSlowly: return slider ? "Slide the lid up… slowly" : "Open the lid… slowly"
        case .slower: return "Slower…"
        case .freeze: return "Freeze!"
        case .dragToBag: return "Drag the loot into your bag"
        case .shutToBank: return slider ? "Slide it down to keep it" : "Ease it shut to keep it"
        case .tooWide: return "That's wide enough"
        }
    }

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0 == " " }).count
    }
}

/// Everything SwiftUI draws over a live chest: the one-line hint above the scene's noise meter, the pause button in
/// the floor half's top-right, the pause menu, the closing card and the First Chest lesson. Only buttons take touches;
/// everything else lets the fingers through to the loot.
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    var body: some View {
        let fit = info.fit
        ZStack {
            if let lesson = controller.lessonDisplay, controller.route == .lesson {
                LessonOverlay(controller: controller, lesson: lesson, fit: fit, compact: info.isCompact,
                              reduceMotion: controller.reduceMotion)
            } else {
                HintLine(hint: hud.hint, banner: hud.banner, slider: controller.sliderWording,
                         compact: info.isCompact, reduceMotion: controller.reduceMotion)
                    .frame(width: fit.viewRect(canvas: HUDLayout.hintBand).width,
                           height: fit.viewRect(canvas: HUDLayout.hintBand).height)
                    .position(x: fit.viewRect(canvas: HUDLayout.hintBand).midX,
                              y: fit.viewRect(canvas: HUDLayout.hintBand).midY)
                    .allowsHitTesting(false)
            }
            if !(controller.lessonDisplay?.isFinal ?? false) {
                let pause = fit.viewRect(canvas: HUDLayout.pauseRect)
                HushIconButton(systemName: "pause.fill", label: "Pause") { controller.openMenu() }
                    .position(x: pause.midX, y: pause.midY)
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
}

/// The one-line hint (or the run-start banner). Warnings glow amber/red; "Freeze!" pulses.
struct HintLine: View {
    let hint: HeistHint?
    let banner: String?
    let slider: Bool
    let compact: Bool
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if let hint {
                let warning = AppRules.isWarning(hint)
                Text(HushCopy.hint(hint, slider: slider))
                    .font(HushType.hint(compact))
                    .foregroundStyle(color(hint))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(HushTheme.night.opacity(warning ? 0.82 : 0.66))
                        .overlay(Capsule().stroke(color(hint).opacity(warning ? 0.6 : 0.2), lineWidth: 1.5)))
                    .hushLegible()
                    .scaleEffect(hint == .freeze && pulse && !reduceMotion ? 1.08 : 1)
                    .id(hint)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .accessibilityLabel(HushCopy.hint(hint, slider: slider))
            } else if let banner {
                Text(banner)
                    .font(HushType.headline(compact))
                    .foregroundStyle(HushTheme.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
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
        case .slower, .easeLidDown: return HushTheme.amber
        case .tooWide: return HushTheme.mist
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
                }
            }
            .frame(width: min(floor.width - 40, 400))
            .hushCard()
            .position(x: floor.midX, y: floor.midY)
        }
    }
}

/// "Lift the lid a little to carry on" (the closing pause).
struct ClosingCard: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    var body: some View {
        let floor = info.floorHalf
        let c = info.isCompact
        ZStack {
            Color.black.opacity(0.6)
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(HushTheme.gold)
                Text("Lift me")
                    .font(HushType.headline(c))
                    .foregroundStyle(HushTheme.goldLight)
            }
            .position(x: info.lidHalf.midX, y: info.lidHalf.midY)
            .accessibilityHidden(true)
            VStack(spacing: 14) {
                DuoDiagram(style: .tabletop(angle: 115), reduceMotion: controller.reduceMotion)
                    .frame(width: 150, height: 96)
                Text("Lift the lid a little to carry on")
                    .font(HushType.headline(c))
                    .foregroundStyle(HushTheme.parchment)
                    .multilineTextAlignment(.center)
                Text("The mimic waits. Your torch does too.")
                    .font(HushType.caption(c))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
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

/// The First Chest lesson over the chest: the step card on the floor (above the meter), the lid marker in the pose
/// step, and the final card.
struct LessonOverlay: View {
    @ObservedObject var controller: GameController
    let lesson: LessonDisplay
    let fit: CanvasFit
    let compact: Bool
    let reduceMotion: Bool
    @State private var glow = false

    var body: some View {
        let band = fit.viewRect(canvas: HUDLayout.lessonBand)
        let lid = fit.lidRect
        ZStack {
            if lesson.marksLid {
                // "Lift THIS half": the lid half glows, with an arrow and the words.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(HushTheme.gold.opacity(glow ? 0.95 : 0.45), lineWidth: 5)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(HushTheme.gold.opacity(glow ? 0.12 : 0.05)))
                    .frame(width: lid.width - 24, height: lid.height - 24)
                    .position(x: lid.midX, y: lid.midY)
                    .allowsHitTesting(false)
                VStack(spacing: 10) {
                    Image(systemName: lesson.usesSlider ? "hand.draw.fill" : "arrow.up")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .offset(y: glow && !reduceMotion ? -8 : 0)
                    Text(lesson.usesSlider ? "Slide up here" : "Lift this half")
                        .font(HushType.title(compact))
                }
                .foregroundStyle(HushTheme.goldLight)
                .hushLegible()
                .position(x: lid.midX, y: lid.midY)
                .allowsHitTesting(false)
            }
            if lesson.isFinal {
                LessonFinalCard(controller: controller, compact: compact)
                    .position(x: fit.floorRect.midX, y: fit.floorRect.midY)
            } else {
                LessonStepCard(controller: controller, lesson: lesson, compact: compact, reduceMotion: reduceMotion)
                    .frame(width: band.width, height: band.height)
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
}

struct LessonStepCard: View {
    @ObservedObject var controller: GameController
    let lesson: LessonDisplay
    let compact: Bool
    let reduceMotion: Bool

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
                        .font(HushType.overline(compact))
                        .kerning(1.4)
                        .foregroundStyle(HushTheme.mist)
                        .padding(.leading, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("First Chest, step \(lesson.step) of 5")
                Text(lesson.line)
                    .font(compact ? .system(size: 19, weight: .heavy, design: .rounded) :
                            .system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(lineColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
                        .font(HushType.body(compact))
                        .foregroundStyle(HushTheme.mist)
                        .frame(minWidth: HushTheme.minTap, minHeight: HushTheme.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HushPressStyle())
                .accessibilityLabel("Skip the lesson")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(HushTheme.night.opacity(0.84))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(lineColor.opacity(lesson.warning ? 0.7 : 0.25), lineWidth: 1.5)))
        .animation(.easeOut(duration: 0.2), value: lesson.line)
        .accessibilityElement(children: .contain)
    }

    private var lineColor: Color {
        if lesson.praise { return HushTheme.asleep }
        if lesson.warning { return lesson.line.hasPrefix("Slower") ? HushTheme.amber : HushTheme.danger }
        return HushTheme.parchment
    }
}

/// Step 6: "Your torch burns down. Loot all you can, gently." Then the first Run.
struct LessonFinalCard: View {
    @ObservedObject var controller: GameController
    let compact: Bool

    var body: some View {
        VStack(spacing: 14) {
            CoinGlyph(size: 40)
            Text("Lovely work, little thief.")
                .font(HushType.title(compact))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
            Text("Your torch burns down. Loot all you can, gently.")
                .font(HushType.body(compact))
                .foregroundStyle(HushTheme.mist)
                .multilineTextAlignment(.center)
            HushButton(kind: .primary, compact: compact, confirm: true, action: { controller.finishLesson() }) {
                Text(controller.lessonReplaying ? "Start a run" : "Start my first run")
            }
            HushButton(kind: .quiet, height: HushTheme.minTap, compact: compact,
                       action: { controller.finishLessonHome() }) {
                Text("Home")
            }
        }
        .frame(width: 380)
        .hushCard(padding: 22)
    }
}
