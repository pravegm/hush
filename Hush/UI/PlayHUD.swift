import SwiftUI

/// The words for Core's hints (Core decides which applies; the UI owns the words). ≤ 6 words each. R3 (decision 4):
/// `slider` is the LAYOUT's words (no fold: the lever; a fold: the lid). R3 (decision 3): one verb, "bank". Pure; tested.
enum HushCopy {
    /// R12 (founder: "chest closed means lid closed, chest open means lid open"): `lidOpen` (`AppRules.lidReadsOpen`)
    /// is the lid as it is NOW, so a line never asks to open a lid that is already open, even while the hint gate
    /// still holds a hint Core has just stopped wanting.
    static func hint(_ hint: HeistHint, slider: Bool, lidOpen: Bool = false) -> String {
        switch hint {
        // R11 (UX P2-2): "Ease the lid down" was the bank's phrase. R12: the lesson's chest words, "Close the phone…"
        // (Core produces it only in the lesson now).
        case .easeLidDown: return slider ? "Slide the lever down first" : "Close the phone to start"
        case .openSlowly:
            // R12: Core still asks while nothing is lit yet; with the lid already up, it only needs to go wider.
            if lidOpen { return "A little wider… slowly" }
            return slider ? "Slide the lever up… slowly" : "Open the phone… slowly"
        case .slower: return "Slower…"
        case .freeze: return "Freeze!"
        case .dragToBag: return "Drag the loot into your bag"
        case .shutToBank: return slider ? "Slide the lever down to bank" : HushCopy.bankLid
        case .tooWide: return "That's wide enough"
        case .candleLow: return "Candle's low. Bank it!"
        case .relicDeeper: return "Something glints deeper…"
        // R12 rule 4: the robbed chest after a bite. The founder's words on a fold; on a phone "it" (the lever: the
        // 8-word "Slide the lever down for the next chest" measured ~0.70 of its size on a 402 pt phone's plate, the
        // truncation line).
        case .closeForNext: return slider ? HushCopy.closeForNextLever : HushCopy.closeForNextLid
        }
    }

    /// R7 (ROUND-7 App 1): "down", never "shut". R12 rule 3 (founder): bank = close the lid ("closing it all the way is
    /// fine: the bank fires on the way down").
    static let bankLid = "Close the phone to bank"
    /// R12: the stakes card's bank row on a fold.
    static let bankStakeLid = "Close the phone to bank it"
    /// R12 rule 4 (`HeistHint.closeForNext`).
    static let closeForNextLid = "Close the phone for the next chest"
    /// R13 (phone QA P1-1): the lever named ("it" had no subject on the plate). Shorter than before.
    static let closeForNextLever = "Lever down for the next chest"

    /// Every hint, for the tests and the word-count rule (HeistHint isn't CaseIterable).
    static let allHints: [HeistHint] = [.easeLidDown, .openSlowly, .slower, .freeze, .dragToBag, .shutToBank, .tooWide,
                                        .candleLow, .relicDeeper, .closeForNext]

    /// R12: the founder's `.closeForNext` line is 7 words; every other hint keeps the ≤ 6 rule. Tested.
    static func wordLimit(_ hint: HeistHint) -> Int { hint == .closeForNext ? 7 : 6 }

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0 == " " }).count
    }

    /// The lesson's last card: the stakes, one drawn icon each (UX P0-3; R3: no SF Symbols). ≤ 6 words a row; tested.
    static func stakes(slider: Bool) -> [StakeRow] {
        [
            StakeRow(icon: .candle, text: "Candle out = run over"),
            StakeRow(icon: .fang, text: "Too loud? It bites your bag"),
            StakeRow(icon: .lock, text: slider ? "Slide the lever down to bank" : HushCopy.bankStakeLid),
        ]
    }

    /// R11 (ROUND-11 App 2, UX P2-5): the stakes card's fourth row, how to pause: closing the lid on a fold (the
    /// closing pause), the coin on a phone. ≤ 6 words; tested.
    static func pauseStake(slider: Bool) -> StakeRow {
        StakeRow(icon: .pause, text: slider ? "Tap the coin to pause" : "Close the phone to pause")
    }

    /// R3 (UX P1-9): what VoiceOver hears as it happens (nil: nothing to say). Pure; tested.
    /// R11 (UX P2-5): a Hushed bank that raises the Hush Chain says so (`chain`: the bank's `chainUp` multiplier, from
    /// the same frame's events).
    static func announcement(_ event: HeistEvent, chain: Double? = nil) -> String? {
        switch event {
        case let .stageChanged(from, to) where to > from:
            switch to {
            case .stirring: return "It's stirring."
            case .waking: return "It's waking. Freeze!"
            case .asleep, .biting: return nil
            }
        case let .bitten(lost): return lost > 0 ? "Chomp! Lost \(lost.formatted()) gold." : "Chomp!"
        case let .banked(value, _, hushed):
            guard hushed else { return "Banked \(value.formatted()) gold." }
            let line = "Hushed! Banked \(value.formatted()) gold."
            guard let m = chain, m.isFinite, m > 1 else { return line }
            return line + " Hush Chain, times \(String(format: "%.1f", m))."
        case .torchLow: return "Your candle is low."
        default: return nil
        }
    }

    /// R4 (QA-3 P2-4): only "Chomp!" and "It's waking. Freeze!" interrupt VoiceOver; everything else waits its turn,
    /// so a bank and a tip on the same frame are both heard. Pure; tested.
    static func queuesAnnouncement(_ event: HeistEvent) -> Bool {
        switch event {
        case .bitten: return false
        case let .stageChanged(_, to): return to < .waking
        default: return true
        }
    }

    /// R3 (UX P1-9): the noise meter, spoken. Pure; tested.
    static func stageWord(_ stage: MimicStage) -> String {
        switch stage {
        case .asleep: return "quiet, it's asleep"
        case .stirring: return "it's stirring"
        case .waking: return "it's waking"
        case .biting: return "it's biting"
        }
    }
}

struct StakeRow: Hashable {
    var icon: PlateGlyph
    var text: String
}

/// Everything SwiftUI draws over a live chest: the one-line hint at the floor's back edge (by the fold), the brass pause
/// coin, the Daily marker, the pause menu, the closing card and the First Chest lesson. Only buttons take touches;
/// everything else lets the fingers through to the loot. R2: turned round by RootView with the rest of the SwiftUI
/// layer (the scene turns itself), so every rect here is in unturned canvas terms. R3 (decision 5): every card and
/// hint is the in-world plate, one prompt at a time.
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    var body: some View {
        let fit = info.fit
        // R4 (UX P1-1): the hint plate never reaches the pause stud (16 pt clear). R5: measured against the seat as
        // drawn at this scale, 20 pt off the fold. R10: against the seat where it is really drawn (the coin's own
        // centre, safe-area clamp included: the Duo at k = 1).
        let band = fit.viewRect(canvas: HUDLayout.hintPlateRect(seat: info.pauseSeatCanvasRect()))
        let paused = controller.isMenuOpen || controller.isClosingPaused
        ZStack {
            accessibilityHooks(fit)
            if let lesson = controller.lessonDisplay, controller.route == .lesson {
                if !paused {
                    LessonOverlay(controller: controller, lesson: lesson, fit: fit, info: info,
                                  reduceMotion: controller.reduceMotion)
                }
            } else if !paused {
                // R5 (juror P2-1, tester 9): on the chest's centre line (not the band's middle), 20 pt off the fold.
                let axis = fit.viewPoint(canvas: CGPoint(x: HUDLayout.chestAxisX, y: 0)).x
                AxisCentredLayout(axisX: axis - band.minX) {
                    HintLine(hint: hud.hint, banner: hud.banner, slider: controller.sliderWording,
                             scale: fit.textScale, reduceMotion: controller.reduceMotion, lidOpen: hud.lidOpen)
                }
                .frame(width: band.width, height: band.height)
                .position(x: band.midX, y: band.midY)
                .allowsHitTesting(false)
            }
            if let marker = controller.dailyMarker, controller.route == .playing, !paused {
                // R5 (juror P2-2, frame 26): centred on the chest, 12 pt clear above the phone's plaque.
                let spot = HUDLayout.dailyMarkerCenter(info)
                Text(marker.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(PlateArt.text(.parchment))
                    .lineLimit(1)
                    .hushPlate(.parchment, padding: 6, radius: 10)
                    .frame(maxWidth: max(info.safeRect.width - 2 * AppCanvas.pauseInset, 120))
                    .position(x: spot.x, y: spot.y)
                    .allowsHitTesting(false)
            }
            if !AppRules.pauseCoinHidden(menuOpen: controller.isMenuOpen, closingPaused: controller.isClosingPaused,
                                         finalLessonCard: controller.lessonDisplay?.isFinal ?? false) {
                // R10: the scene's seat is drawn at this same point (`AppCanvas.pauseSeatCanvasCenter`).
                let pause = info.pauseCenter()
                // R5 (juror P2-3, frame 13): the bite's teeth own the screen; the coin steps away for the moment.
                // R7 (ROUND-7 App 2): on a Duo, mid-chest, a 0.35 s press-and-hold (a ring fills); a tap says
                // "Hold to pause". Elsewhere a tap.
                PauseCoin(needsHold: controller.pauseNeedsHold, reduceMotion: controller.reduceMotion,
                          scale: fit.textScale, demoHint: controller.demoHoldHint) { controller.openMenu() }
                    .opacity(hud.biting ? 0 : 1)
                    .allowsHitTesting(!hud.biting)
                    .accessibilityHidden(hud.biting)
                    .animation(.easeOut(duration: 0.15), value: hud.biting)
                    .position(x: pause.x, y: pause.y)
            }
            if controller.isMenuOpen {
                PauseMenu(controller: controller, info: info)
                    .transition(.opacity)
            } else if controller.isClosingPaused {
                // R15 (walkthrough P2-2): fades in after 0.25 s, so a relight that resumes at once (an open phone
                // over a fresh chest) never flashes the card; it goes at once.
                ClosingCard(controller: controller, info: info)
                    .transition(.asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.15).delay(0.25)),
                                            removal: .identity))
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.isMenuOpen)
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.isClosingPaused)
    }

    /// `hud.bag` (all builds, VoiceOver too) and `debug.loot` (demo runs): pure accessibility elements over where the
    /// pouch and the most-lit item are drawn, for CI's turned-drag UI test. They take no touches. R3 (UX P1-9): BANKED,
    /// the candle and the noise meter are named too. `hud.bag`'s VALUE stays the item count (CI reads it).
    @ViewBuilder
    private func accessibilityHooks(_ fit: CanvasFit) -> some View {
        let spoken = hud.spoken
        let bag = fit.viewRect(canvas: HUDLayout.bagRect)
        Color.clear
            .frame(width: bag.width, height: bag.height)
            .position(x: bag.midX, y: bag.midY)
            .accessibilityElement()
            .accessibilityIdentifier("hud.bag")
            .accessibilityLabel(spoken.bagGold > 0 ? "In bag, \(spoken.bagGold.formatted()) gold, not safe yet"
                                : "In bag")
            .accessibilityValue("\(hud.bagCount)")
            .allowsHitTesting(false)
        spokenElement(fit.viewRect(canvas: ChestLayout.counterRect), id: "hud.banked",
                      label: "Banked, \(spoken.banked.formatted()) gold")
        spokenElement(fit.viewRect(canvas: ChestLayout.torchRect), id: "hud.candle",
                      label: "Candle, \(spoken.candleSeconds) seconds")
        spokenElement(fit.viewRect(canvas: ChestLayout.meterRect), id: "hud.noise",
                      label: "Noise, " + HushCopy.stageWord(spoken.stage))
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

    private func spokenElement(_ r: CGRect, id: String, label: String) -> some View {
        Color.clear
            .frame(width: max(r.width, 1), height: max(r.height, 1))
            .position(x: r.midX, y: r.midY)
            .accessibilityElement()
            .accessibilityIdentifier(id)
            .accessibilityLabel(label)
            .allowsHitTesting(false)
    }
}

/// The one-line hint (or a callout: the run-start banner, a one-time tip, the golden banner) on the in-world plate.
/// Warnings stitch amber/red; "Freeze!" pulses.
struct HintLine: View {
    let hint: HeistHint?
    let banner: String?
    let slider: Bool
    var scale: CGFloat = 1
    let reduceMotion: Bool
    /// R12: the lid is open now (`AppRules.lidReadsOpen`): the words never ask to open it.
    var lidOpen: Bool = false
    @State private var pulse = false

    /// R4 (ROUND-4 App 1): every plate's line shrinks to this, never further.
    static let minScale: CGFloat = 0.7

    var body: some View {
        ZStack {
            // R4 (juror P0-1, UX P1-1): one line, laid out inside the plate's text rect (clear of the brass
            // end-caps), shrinking to 0.7 before it ever touches them.
            if let hint {
                Text(HushCopy.hint(hint, slider: slider, lidOpen: lidOpen))
                    .font(HushType.hint(scale: scale))
                    .foregroundStyle(color(hint))
                    .lineLimit(1)
                    .minimumScaleFactor(HintLine.minScale)
                    .onPlate(hint == .freeze ? .urgent : .parchment, radius: 14 * scale)
                    .scaleEffect(hint == .freeze && pulse && !reduceMotion ? 1.06 : 1)
                    .id(hint)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .accessibilityLabel(HushCopy.hint(hint, slider: slider, lidOpen: lidOpen))
            } else if let banner {
                Text(banner)
                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(PlateArt.text(.parchment))
                    .lineLimit(1)
                    .minimumScaleFactor(HintLine.minScale)
                    .onPlate(.parchment, radius: 14 * scale)
                    .id(banner)
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

    /// Ink on the plate: "Freeze!" is cream on the urgent plate; warnings and the glimmer are the parchment's red-brown
    /// accent; teaching lines are its ink.
    private func color(_ hint: HeistHint) -> Color {
        switch hint {
        case .freeze: return PlateArt.text(.urgent)
        case .slower, .candleLow, .relicDeeper: return PlateArt.accent(.parchment)
        case .tooWide: return PlateArt.muted(.parchment)
        // R14: "Close the phone to start" is the first instruction, not a warning.
        case .easeLidDown, .openSlowly, .dragToBag, .shutToBank, .closeForNext: return PlateArt.text(.parchment)
        }
    }
}

/// The pause menu: Resume, Restart, Home, on a leather plate on the floor half (the sharp, reachable one).
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
            VStack(spacing: c ? 8 : 12) {
                HushOverline(text: "Paused", compact: c, color: HushTheme.gold)
                HushButton(kind: .primary, height: c ? 56 : HushTheme.primaryHeight, compact: c,
                           action: { controller.resume() }) {
                    Text("Resume")
                }
                HushButton(kind: .leather, height: HushTheme.secondaryHeight, compact: c,
                           action: { controller.restart() }) {
                    Text(controller.restartLabel)
                }
                HushButton(kind: .leather, height: HushTheme.secondaryHeight, compact: c,
                           action: { controller.goHome() }) {
                    Text("Home")
                }
                if controller.isScoredDaily {
                    Text("Leaving keeps the gold you've banked.")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: min(floor.width - 64, 380))
            .hushPlate(padding: c ? 14 : 18, radius: 24)
            .position(x: floor.midX, y: floor.midY)
        }
    }
}

/// The closing pause: "Lift the lid a little to carry on", then, once it's back up, "Hold still…" until Feel says it
/// is still (R2 P0-2: never resumes mid-motion). R3: one plate, one prompt, between the noise meter and the fold
/// (never over the meter), with "Move the phone a little" before the first hinge report (P1-4).
struct ClosingCard: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas

    /// Pure; tested. R7 (ROUND-7 App 1): over a fresh chest (`HeistSession.isFreshChest`) lifting the lid is enough,
    /// so the card never says "Hold still…" there.
    static func title(lifted: Bool, awaitingHinge: Bool = false, fresh: Bool = false, first: Bool = false) -> String {
        if awaitingHinge { return "Move the phone a little" }
        // R13: the lid is shut, so is the chest; it opens with the phone, from the first degree. R14: the run's first
        // chest (closed to start) says "start".
        if fresh && first { return "Open slowly. Don't wake it." }
        if fresh { return "Open the phone slowly for the next chest" }
        // R15 (walkthrough P2-1): no "Hold still…" any more (R14: the lift alone carries on).
        _ = lifted
        return "Open the phone slowly to carry on"
    }

    /// R6: the escape hatch's words.
    static let carryOn = "Carry on"

    static func detail(lifted: Bool, awaitingHinge: Bool = false, fresh: Bool = false, first: Bool = false) -> String {
        if awaitingHinge { return "Then hold it still. The mimic waits." }
        // R14 (UX audit E): the run's first chest gives the three rules (the lesson no longer runs first).
        if fresh && first { return "Drag loot to your bag. Close the phone to bank. Your candle is the clock." }
        if fresh { return "The mimic waits. Your candle does too." }
        _ = lifted
        return "The mimic waits. Your candle does too."
    }

    @Environment(\.dynamicTypeSize) private var typeSize
    /// R11 (UX P2-1): VoiceOver moves to Carry on when it appears.
    @AccessibilityFocusState private var carryOnFocused: Bool

    /// R11 (UX P2-4, ROUND-11 App 3): at the accessibility sizes the card fits or scrolls: the full card, then without
    /// the diagram and the detail line, then a bottom-anchored fading scroll (Carry on and Home stay whole). The default
    /// sizes keep R6–R10's plate exactly. Pure; tested.
    static func fitsByStages(_ size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }

    var body: some View {
        let c = info.isCompact
        let area = info.fit.viewRect(canvas: HUDLayout.cardArea)
        let width = max(min(area.width - 40, 440), 220)
        ZStack {
            Color.black.opacity(0.5)
                .contentShape(Rectangle())
                .onTapGesture {}
            if Self.fitsByStages(typeSize) {
                // Laid out in the floor half (the card may be taller than the band between the meter and the fold).
                let floor = info.floorHalf
                ViewThatFits(in: .vertical) {
                    plate(c, width: width, full: true)
                    plate(c, width: width, full: false)
                    FadingScroll(anchor: .bottom) { plate(c, width: width, full: false) }
                }
                .frame(maxHeight: max(floor.height - 16, 120))
                .position(x: floor.midX, y: floor.midY)
            } else {
                plate(c, width: width, full: true)
                    .position(x: area.midX, y: area.midY)
            }
        }
        .onChange(of: controller.closingEscape) { _, on in
            if on { carryOnFocused = true }
        }
    }

    private func plate(_ c: Bool, width: CGFloat, full: Bool) -> some View {
        let lifted = controller.closingLifted
        let waiting = controller.closingAwaitsHinge
        let fresh = controller.closingFresh
        return VStack(spacing: c ? 8 : 12) {
            HStack(spacing: 14) {
                // R14 (UX audit): no laptop-pose diagram (any pose plays); the words are enough.
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.title(lifted: lifted, awaitingHinge: waiting, fresh: fresh,
                                    first: controller.closingFirstChest))
                        .font(HushType.headline(c))
                        .foregroundStyle(HushTheme.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                    if full {
                        Text(Self.detail(lifted: lifted, awaitingHinge: waiting, fresh: fresh,
                                         first: controller.closingFirstChest))
                            .font(HushType.caption(c))
                            .foregroundStyle(HushTheme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            if controller.isScoredDaily {
                Text("Leaving keeps the gold you've banked.")
                    .font(HushType.caption(c))
                    .foregroundStyle(HushTheme.haze)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // R6 (ROUND-6 App 6, never stuck): after 3 s, a big "Carry on" that resumes at once, whatever the
            // hinge says (the watchdog does the same by itself after 6 s with the lid open).
            // R15 (walkthrough P1-2): never with no hinge report yet: it would play a lid at 0 (a closed chest on an
            // open phone). The card says "Move the phone a little" then, and Home is always there.
            if controller.closingEscape && (controller.hasHinge || controller.input != .hinge) {
                HushButton(kind: .primary, height: c ? 56 : HushTheme.primaryHeight, compact: c, confirm: true,
                           action: { controller.carryOn() }) {
                    Text(Self.carryOn)
                }
                .accessibilityHint("Resumes the chest now")
                .accessibilityFocused($carryOnFocused)
                .transition(.opacity)
            }
            HushButton(kind: .leather, height: HushTheme.minTap, compact: c, action: { controller.goHome() }) {
                Text("Home")
            }
            .frame(maxWidth: controller.closingEscape ? .infinity : 220)
        }
        .animation(HushTheme.settle(controller.reduceMotion), value: controller.closingEscape)
        .frame(width: width)
        .hushPlate(padding: 14, radius: 22)
    }
}

/// The First Chest lesson over the chest: the step card above the noise meter (R2: never over it), the lid marker in
/// the pose step (the lever on a phone), a ring round the meter when the line talks about the noise, and the final
/// card. R3: the marker's arrow and words come from the same angle branch as the line (UX P0-1), the words sit in the
/// Scene's slot above the brow plate (never on the lashes), and every card is the in-world plate.
struct LessonOverlay: View {
    @ObservedObject var controller: GameController
    let lesson: LessonDisplay
    let fit: CanvasFit
    let info: AppCanvas
    let reduceMotion: Bool
    @State private var glow = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let band = fit.viewRect(canvas: HUDLayout.lessonBand)
        let lid = fit.lidRect
        let meter = fit.viewRect(canvas: ChestLayout.meterRect)
        ZStack {
            if lesson.marksLid {
                if lesson.usesSlider {
                    leverMarker
                } else if let cue = lesson.liftCue {
                    // The lid half glows; the cue's arrow and words sit above the brow plate.
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(HushTheme.gold.opacity(glow ? 0.95 : 0.45), lineWidth: 5)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(HushTheme.gold.opacity(glow ? 0.12 : 0.05)))
                        .frame(width: lid.width - 24, height: lid.height - 24)
                        .position(x: lid.midX, y: lid.midY)
                        .allowsHitTesting(false)
                    lidCue(cue)
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
                // R5 (UX P1-1, juror P1-1, frame 39): a short fold floor gets the compact card, which fits at the
                // default size; only the accessibility sizes (or a last resort) scroll, fading, anchored on "Got it".
                let card = LessonFinalCard(controller: controller, compact: info.isCompact,
                                           width: LessonFinalCard.width(info), tight: info.tightFloor)
                Group {
                    if typeSize.isAccessibilitySize {
                        FadingScroll(anchor: .bottom) { card }
                    } else {
                        ViewThatFits(in: .vertical) {
                            card
                            FadingScroll(anchor: .bottom) { card }
                        }
                    }
                }
                .frame(maxHeight: info.floorHalf.height)
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

    /// "↑ Lift this half" / "↓ Lower this half a little" / "✓ Hold it there…" in the slot above the brow plate.
    private func lidCue(_ cue: LessonScript.LiftCue) -> some View {
        let slot = fit.viewRect(canvas: HUDLayout.lidLabelBand)
        let s = fit.textScale
        let bob: CGFloat = glow && !reduceMotion ? (cue.pointsUp == false ? 5 : -5) : 0
        return HStack(spacing: 10 * s) {
            if let up = cue.pointsUp {
                ArrowGlyph(up: up)
                    .fill(HushTheme.goldLight)
                    .overlay(ArrowGlyph(up: up).stroke(Color(hush: ChestArt.outline), lineWidth: 2))
                    .frame(width: 26 * s, height: 32 * s)
                    .offset(y: bob)
            } else {
                TickGlyph()
                    .fill(PlateArt.calm)
                    .frame(width: 28 * s, height: 28 * s)
            }
            Text(cue.label)
                .font(.system(size: 26 * s, weight: .heavy, design: .rounded))
                .foregroundStyle(cue == .hold ? PlateArt.calm : PlateArt.text(.parchment))
                .lineLimit(1)
                .minimumScaleFactor(HintLine.minScale)
        }
        .onPlate(.parchment, radius: 12 * s)
        .frame(maxWidth: slot.width)
        .position(x: slot.midX, y: slot.midY)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cue.label)
    }

    /// Phone, step 1: a ring round the lever and an arrow up its track (UX P0-4). R3: no second sentence on the lid
    /// (the card already says "Slide the lever up… slowly"; tester 5 read it twice).
    private var leverMarker: some View {
        let track = fit.viewRect(canvas: HUDLayout.leverTrack)
        return ZStack {
            Capsule()
                .stroke(HushTheme.gold.opacity(glow ? 0.95 : 0.4), lineWidth: 4)
                .frame(width: track.width + 18, height: track.height + 18)
                .position(x: track.midX, y: track.midY)
            ArrowGlyph(up: true)
                .fill(HushTheme.goldLight)
                .overlay(ArrowGlyph(up: true).stroke(Color(hush: ChestArt.outline), lineWidth: 2))
                .frame(width: 28 * fit.textScale, height: 36 * fit.textScale)
                .offset(y: glow && !reduceMotion ? -14 : 0)
                .position(x: track.minX - 30 * fit.textScale, y: track.midY)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The lever: slide it up slowly")
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
                                                                        Color.black.opacity(0.35)))
                            .frame(width: i == lesson.step ? 22 : 10, height: 8)
                    }
                    Text("FIRST CHEST")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .kerning(1.4)
                        .foregroundStyle(PlateArt.muted(plateStyle))
                        .padding(.leading, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("First Chest, step \(lesson.step) of 5")
                // R4: up to two lines, inside the plate's text rect (never on the caps or the border).
                Text(lesson.line)
                    .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(lineColor)
                    .lineLimit(2)
                    .minimumScaleFactor(HintLine.minScale)
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
                        .foregroundStyle(PlateArt.muted(plateStyle))
                        .frame(minWidth: HushTheme.minTap, minHeight: HushTheme.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HushPressStyle())
                .accessibilityLabel("Skip the lesson")
            }
        }
        .padding(.vertical, 2 * scale)
        .onPlate(plateStyle, radius: 20)
        .animation(.easeOut(duration: 0.2), value: lesson.line)
        .accessibilityElement(children: .contain)
    }

    /// Parchment, or the urgent plate for "It's stirring. Freeze!".
    private var plateStyle: PlateStyle {
        lesson.warning && !lesson.line.hasPrefix("Slower") ? .urgent : .parchment
    }

    private var lineColor: Color {
        if lesson.praise { return PlateArt.calm }
        if plateStyle == .urgent { return PlateArt.text(.urgent) }
        if lesson.warning { return PlateArt.accent(.parchment) }
        return PlateArt.text(.parchment)
    }
}

/// Step 6 (UX P0-3): the stakes, three drawn icon rows, then "Got it" (the first run). R3: the leather plate, the
/// layout's words (R12: "Close the phone to bank it" on a fold, the lever otherwise).
struct LessonFinalCard: View {
    @ObservedObject var controller: GameController
    let compact: Bool
    let width: CGFloat
    /// R5 (UX P1-1): a short fold floor's compact metrics (`AppCanvas.tightFloor`): the compact title, closer rows,
    /// a 56 pt "Got it" (still ≥ the tap minimum) and less padding.
    var tight = false

    /// The width the card is laid out for on `info`. Pure; tested.
    static func width(_ info: AppCanvas) -> CGFloat { min(info.size.width - 32, 400) }

    /// R11 (ROUND-11 App 2, UX P2-5): the stakes rows: the candle, the bite, the bank, then, on a Duo's full floor, how
    /// to pause ("Close the phone to pause"). Not on a short fold floor (`tight`) or a phone (its pause is the plain tap
    /// coin, and the card must fit its floor half at the default size). Pure; tested.
    static func rows(slider: Bool, tight: Bool) -> [StakeRow] {
        HushCopy.stakes(slider: slider) + (slider || tight ? [] : [HushCopy.pauseStake(slider: slider)])
    }

    var body: some View {
        VStack(spacing: tight ? 8 : 14) {
            // R11 (UX P1-2): a skipped first lesson's card is "the gist" (it hasn't earned "Lovely work…").
            Text(controller.lessonDisplay?.finalCardTitle ?? LessonDisplay.finalTitle)
                .font(HushType.title(compact || tight))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: tight ? 6 : 10) {
                ForEach(Self.rows(slider: controller.sliderWording, tight: tight), id: \.text) { row in
                    HStack(spacing: 12) {
                        PlateGlyphView(glyph: row.icon, side: tight ? 24 : 28)
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
            HushButton(kind: .primary, height: tight ? HushTheme.minTap : HushTheme.primaryHeight, compact: compact,
                       confirm: true, action: { controller.finishLesson() }) {
                Text("Got it")
            }
            HushButton(kind: .leather, height: HushTheme.minTap, compact: compact,
                       action: { controller.finishLessonHome() }) {
                Text(controller.lessonReplaying ? "Home" : "Not yet, take me home")
            }
        }
        .frame(width: max(width - 60, 200))
        .hushPlate(padding: tight ? 14 : 20, radius: 26)
    }
}

/// R7 (ROUND-7 App 2, DEVICE-RISKS-1 item 4): the pause coin. It sits in the floor's right corner, where a right hand
/// easing the lid rests, so on a Duo, mid-chest (`GameController.pauseNeedsHold`), it needs a 0.35 s press-and-hold: a
/// ring fills round it while held, and a shorter press only shows "Hold to pause" beside it. Elsewhere (phones, the
/// bank and bite moments) it is the plain tap coin. VoiceOver's activate pauses at once (no hold to perform).
/// The coin's place is unchanged, so `Tuning.lootKeepOut` and the Daily's deal are untouched.
struct PauseCoin: View {
    let needsHold: Bool
    let reduceMotion: Bool
    var scale: CGFloat = 1
    /// R11 (ROUND-11 App 3, demo `hint=holdToPause`): show "Hold to pause" and a half-full ring for CI's frame.
    var demoHint = false
    let action: () -> Void

    static let visual: CGFloat = 50
    /// R11 (UX P2-1): VoiceOver's double-tap pauses at once (the hold is for fingers), so its hint says what it does.
    static let accessibilityHintText = "Pauses the chest"
    /// R11: the demo frame's ring.
    static let demoFill: CGFloat = 0.5

    @State private var pressStart: Date?
    @State private var fill: CGFloat = 0
    @State private var fired = false
    @State private var holdTask: Task<Void, Never>?
    @State private var hintShown = false
    @State private var hintTask: Task<Void, Never>?

    var body: some View {
        if needsHold {
            holdCoin
        } else {
            BrassCoinButton(label: "Pause", visual: Self.visual, action: action)
        }
    }

    private var side: CGFloat { max(Self.visual, HushTheme.minTap) }

    private var holdCoin: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(pressStart == nil && !demoHint ? 0 : 0.35), lineWidth: 5)
                .frame(width: Self.visual + 12, height: Self.visual + 12)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(HushTheme.goldLight, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: Self.visual + 12, height: Self.visual + 12)
            BrassCoinFace(visual: Self.visual)
                .scaleEffect(pressStart == nil ? 1 : 0.94)
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in begin() }
                .onEnded { _ in end() }
        )
        .overlay(alignment: .trailing) { holdHint }
        .onAppear {
            guard demoHint else { return }
            fill = Self.demoFill
            hintShown = true
        }
        .onDisappear { reset() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pause")
        .accessibilityHint(Self.accessibilityHintText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    @ViewBuilder
    private var holdHint: some View {
        if hintShown {
            Text(AppRules.holdToPauseText)
                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(PlateArt.text(.parchment))
                .lineLimit(1)
                .fixedSize()
                .onPlate(.parchment, radius: 10)
                .fixedSize()
                .offset(x: -(side + 6))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
        }
    }

    private func begin() {
        guard pressStart == nil else { return }
        pressStart = Date()
        fired = false
        fill = 0
        withAnimation(.linear(duration: AppRules.pauseHoldSeconds)) { fill = 1 }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppRules.pauseHoldSeconds * 1_000_000_000))
            guard !Task.isCancelled, pressStart != nil, !fired else { return }
            firePause()
        }
    }

    private func end() {
        guard let start = pressStart else { return }
        holdTask?.cancel()
        holdTask = nil
        let held = Date().timeIntervalSince(start)
        if !fired {
            switch AppRules.coinPress(heldFor: held, needsHold: true) {
            case .pause: firePause()
            case .hint: showHint()
            }
        }
        pressStart = nil
        withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.15)) { fill = 0 }
    }

    private func firePause() {
        fired = true
        FeedbackDirector.shared.uiConfirm()
        action()
    }

    private func showHint() {
        FeedbackDirector.shared.uiTap()
        withAnimation(.easeOut(duration: 0.15)) { hintShown = true }
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppRules.holdHintSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { hintShown = false }
        }
    }

    private func reset() {
        holdTask?.cancel()
        hintTask?.cancel()
        holdTask = nil
        hintTask = nil
        pressStart = nil
        fired = false
        fill = 0
        hintShown = false
    }
}
