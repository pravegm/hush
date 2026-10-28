import SpriteKit
import SwiftUI

/// The Scene's front-view mimic (`MimicPortraitScene`) in SwiftUI: Home, the cover card and Results (R2, juror P0-1:
/// one art style). Transparent, so it sits on the dungeon backdrop.
struct MimicPortraitView: View {
    let scene: MimicPortraitScene
    var paused = false
    var fps = 60

    var body: some View {
        SpriteView(scene: scene, isPaused: paused, preferredFramesPerSecond: fps, options: [.allowsTransparency])
            .aspectRatio(PortraitScenes.aspect, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// A little drawing of the Duo seen from the side, like a little laptop: the floor flat, the lid raised at `angle`°
/// (gold). The closing card's diagram.
struct DuoDiagram: View {
    enum Style: Equatable {
        case tabletop(angle: Double)
    }

    let style: Style
    var reduceMotion = false
    @State private var rock = false

    var body: some View {
        switch style {
        case let .tabletop(angle):
            GeometryReader { geo in
                tabletop(size: geo.size, angle: rock && !reduceMotion ? angle + 10 : angle)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { rock = true }
            }
            .accessibilityLabel("The Duo stood like a little laptop, lid raised")
        }
    }

    private func tabletop(size: CGSize, angle: Double) -> some View {
        let w = size.width
        let h = size.height
        let thickness = max(h * 0.08, 5)
        let floorLen = w * 0.5
        let hinge = CGPoint(x: w * 0.38, y: h - thickness)
        // The lid's angle from the floor: 180 = flat (pointing away), 90 = upright.
        let a = (180 - angle) * Double.pi / 180
        let dx = CGFloat(cos(a)) * floorLen
        let dy = CGFloat(sin(a)) * floorLen
        let lidEnd = CGPoint(x: hinge.x - dx, y: hinge.y - dy)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: h - 1))
                p.addLine(to: CGPoint(x: w, y: h - 1))
            }
            .stroke(HushTheme.haze.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6]))
            Path { p in
                p.move(to: hinge)
                p.addLine(to: CGPoint(x: hinge.x + floorLen, y: hinge.y))
            }
            .stroke(HushTheme.mist, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            Path { p in
                p.move(to: hinge)
                p.addLine(to: lidEnd)
            }
            .stroke(HushTheme.gold, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            Circle()
                .fill(HushTheme.goldDeep)
                .frame(width: thickness * 1.6, height: thickness * 1.6)
                .position(hinge)
        }
    }
}

/// R6 (ROUND-6 App 4): book pose no longer blocks. On a Duo held like a book (the DEVICE landscape), Home and lesson
/// step 1 show this small, dismissible tip, drawn upright to gravity (RootView turns it by `AppRules.tipTurns`), on the
/// sharp page. It takes touches only on its ✕; everything under it keeps working. Never again after ✕ or after the
/// lesson passes step 1. (The R3 blocking "Turn it sideways" card and its "Play anyway" lever path are gone: they
/// depended on iOS agreeing to rotate, which a Duo lying in tabletop or flat never does.)
struct PoseTip: View {
    let reduceMotion: Bool
    let onClose: () -> Void

    static let text = "Stand it up like a little laptop"
    static let detail = "Lid up, the floor flat and nearest you."
    static let closeLabel = "Dismiss the tip"
    static let maxWidth: CGFloat = 380

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DuoDiagram(style: .tabletop(angle: 115), reduceMotion: reduceMotion)
                .frame(width: 64, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.text)
                    .font(HushType.headline(true))
                    .foregroundStyle(HushTheme.parchment)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.detail)
                    .font(HushType.caption(true))
                    .foregroundStyle(HushTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            HushIconButton(systemName: "xmark", label: Self.closeLabel, visual: 40, action: onClose)
                .accessibilityIdentifier("posetip.close")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(HushTheme.surface.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(HushTheme.gold.opacity(0.7), lineWidth: 2))
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
                .allowsHitTesting(false)
        )
        .frame(maxWidth: Self.maxWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("posetip")
    }
}

/// The Duo seen from above (R2, UX P0-5): it turns from book pose (fold up and down, the glowing half on `liftSide`)
/// a quarter turn so the fold runs side to side, then the glowing half lifts while the other stays flat, nearest you.
/// On a loop; one still (turned, lifted) under Reduce Motion and in demo captures.
struct TurnAndLiftDrawing: View {
    let liftSide: ScreenSide
    let reduceMotion: Bool

    private var still: Bool { reduceMotion || DemoMode.current != nil }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 3.0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.6)
            let turn = Self.ease(min(max((t - 0.4) / 0.9, 0), 1))
            let liftIn = Self.ease(min(max((t - 1.8) / 0.8, 0), 1))
            let liftOut = Self.ease(min(max((t - 3.6) / 0.6, 0), 1))
            let lift = still ? 1 : liftIn * (1 - liftOut)
            // Before the turn the glowing (top) half points at `liftSide`.
            let start: Double = liftSide == .left ? -90 : 90
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let w = side * 0.5
                let h = side * 0.36
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: side * 0.9, height: side * 0.9)
                    VStack(spacing: 0) {
                        half(lid: true, width: w, height: h)
                            .rotation3DEffect(.degrees(55 * lift), axis: (x: 1, y: 0, z: 0), anchor: .bottom,
                                              perspective: 0.5)
                            .zIndex(1)
                        Rectangle()
                            .fill(HushTheme.goldDeep)
                            .frame(width: w, height: 3)
                        half(lid: false, width: w, height: h)
                    }
                    .rotationEffect(.degrees(start * (1 - turn)))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityLabel("Turn the Duo a quarter turn, then lift the glowing half")
    }

    private static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    /// R4 (juror P1-4): the Duo drawn as the chest, in the game's own art: the lid half is the wooden lid with the
    /// sleeping mimic's eye and its teeth at the hinge, glowing gold; the floor half is the velvet with a coin.
    private func half(lid: Bool, width: CGFloat, height: CGFloat) -> some View {
        DuoChestHalf(lid: lid)
            .frame(width: width, height: height)
    }
}

/// R4 (juror P1-4): one half of the Duo drawn as the chest (`ChestArt` colours, outline, eye, teeth, loot and plate
/// glyphs; no SF Symbols). `lid`: the half to lift (wood, the sleeping eye, a glowing rim, an up arrow); else the floor
/// (velvet, a coin and a gem, the brass bag-strip edge).
struct DuoChestHalf: View {
    let lid: Bool

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let outline = Color(hush: ChestArt.outline)
            let shape = RoundedRectangle(cornerRadius: min(s.width, s.height) * 0.12, style: .continuous)
            ZStack {
                if lid {
                    // The glow says "this one".
                    shape.fill(HushTheme.gold.opacity(0.35)).blur(radius: 8).scaleEffect(1.08)
                }
                shape.fill(outline)
                shape.inset(by: 3)
                    .fill(LinearGradient(colors: lid ? [Color(hush: ChestArt.palette.wood),
                                                        Color(hush: ChestArt.palette.woodDark)]
                                                     : [Color(hush: ChestArt.palette.velvet),
                                                        Color(hush: ChestArt.palette.velvet.mixed(with: RGBA(0, 0, 0),
                                                                                                  0.45))],
                                         startPoint: .top, endPoint: .bottom))
                if lid { lidArt(s) } else { floorArt(s) }
                shape.inset(by: 1.5)
                    .stroke(lid ? HushTheme.goldLight : Color(hush: ChestArt.palette.woodDark), lineWidth: lid ? 3 : 2)
            }
        }
        .accessibilityHidden(true)
    }

    /// Planks, a brass band, the closed eye (the in-game `mimicEye`, asleep) and the teeth along the hinge edge.
    private func lidArt(_ s: CGSize) -> some View {
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: s.height)
        let eye = ChestArt.mimicEye(wake: 0.06, size: s)
        let bed = Path(ChestArt.mimicEyeBed(size: s)).applying(flip)
        let teeth = Path(ChestArt.flippedVertically(ChestArt.teethRow(width: 40, height: 14, count: 5,
                                                                        pointingDown: true)))
        return ZStack {
            ForEach(1..<3, id: \.self) { i in
                Rectangle()
                    .fill(Color(hush: ChestArt.palette.woodDark).opacity(0.55))
                    .frame(width: s.width * 0.86, height: 1.5)
                    .position(x: s.width / 2, y: s.height * CGFloat(i) / 3.4)
            }
            bed.fill(Color(hush: ChestArt.flesh))
            Path(eye.white).applying(flip).fill(Color(hush: ChestArt.palette.text))
            Path(eye.lidTop).applying(flip).fill(Color(hush: ChestArt.fleshDark))
            bed.stroke(Color(hush: ChestArt.outline), lineWidth: 1.5)
            // The teeth at the hinge edge (the bottom of the drawn lid).
            FittedPathShape(path: teeth)
                .fill(Color(hush: ChestArt.palette.text))
                .overlay(FittedPathShape(path: teeth).stroke(Color(hush: ChestArt.outline), lineWidth: 1))
                .frame(width: s.width * 0.7, height: s.height * 0.14)
                .position(x: s.width / 2, y: s.height * 0.88)
            PlateGlyphView(glyph: .arrowUp, side: max(min(s.height * 0.3, 30), 12))
                .position(x: s.width * 0.86, y: s.height * 0.26)
        }
        .frame(width: s.width, height: s.height)
    }

    /// The velvet floor: a coin and a gem (the in-game loot art), the bag strip's brass edge nearest you.
    private func floorArt(_ s: CGSize) -> some View {
        let r = max(min(s.width, s.height) * 0.14, 6)
        return ZStack {
            lootImage(.copper, radius: r)
                .position(x: s.width * 0.36, y: s.height * 0.42)
            lootImage(.gem(.ruby), radius: r * 0.9)
                .position(x: s.width * 0.62, y: s.height * 0.5)
            Rectangle()
                .fill(LinearGradient(colors: [HushTheme.goldLight, HushTheme.goldDeep], startPoint: .top,
                                     endPoint: .bottom))
                .frame(width: s.width * 0.8, height: max(s.height * 0.07, 3))
                .position(x: s.width / 2, y: s.height * 0.84)
        }
        .frame(width: s.width, height: s.height)
    }

    @ViewBuilder
    private func lootImage(_ kind: LootKind, radius: CGFloat) -> some View {
        if let img = ChestArt.lootImage(kind, radius: radius) {
            Image(decorative: img, scale: 3)
                .resizable()
                .frame(width: radius * 2.4, height: radius * 2.4)
        }
    }
}

/// Shut, on the cover display: the sleeping mimic (the Scene's portrait, asleep) and "Open to carry on".
/// R8 (QA-5 P1-B, belt and braces): if the card has been up 3 s while the hinge says the Duo is open (≥ 92°), the app
/// may be misjudging the display (iOS's letterboxed column on the inner display looks cover-sized), so the card offers
/// a way on: "Carry on" in a run, and "Home" (`escape`).
struct CoverCard: View {
    let midRun: Bool
    let portrait: MimicPortraitScene
    let reduceMotion: Bool
    var escape = false
    var onCarryOn: () -> Void = {}
    var onHome: () -> Void = {}
    /// R11 (QA-6 P2-10, UX P2-1): VoiceOver moves to the escape's first button when the plate appears.
    @AccessibilityFocusState private var escapeFocused: Bool

    /// Pure; tested.
    static func title(midRun: Bool) -> String { midRun ? "Open to carry on" : "Open me… gently" }
    static func detail(midRun: Bool) -> String {
        midRun ? "Open me gently, then hold still. Your candle waits." : "There's gold in here. And something else."
    }
    /// R8: the escape plate's line and buttons. Pure; tested.
    static let escapeLine = "Already open?"
    static let carryOnLabel = "Carry on"
    static let homeLabel = "Home"
    /// The escape plate's buttons, in order (a run: Carry on, then Home; menus: Home). Pure; tested.
    static func escapeButtons(midRun: Bool) -> [String] { midRun ? [carryOnLabel, homeLabel] : [homeLabel] }

    /// R3 (UX P2-12, juror P1-11): the group is centred and the mimic fills the card (never top-heavy).
    var body: some View {
        ZStack {
            HushTheme.backdrop
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(spacing: 16) {
                            MimicPortraitView(scene: portrait, fps: 30)
                                .frame(width: min(geo.size.width * 0.82, 380))
                            Text(Self.title(midRun: midRun))
                                .font(HushType.title(true))
                                .foregroundStyle(HushTheme.parchment)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(Self.detail(midRun: midRun))
                                .font(HushType.body(true))
                                .foregroundStyle(HushTheme.mist)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        if escape {
                            escapePlate(width: min(geo.size.width - 48, 380))
                                .transition(.opacity)
                        }
                    }
                    .animation(HushTheme.settle(reduceMotion), value: escape)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                    .frame(width: geo.size.width)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            portrait.openness = 0
            portrait.wake = 0
            portrait.reduceMotion = reduceMotion
            // R3 (Scene): asleep, a sliver open, the eye glinting through the seam, the chest filling the card.
            portrait.applyCoverStyle()
            if escape { escapeFocused = true }
        }
        .onChange(of: escape) { _, on in
            if on { escapeFocused = true }
        }
        .accessibilityElement(children: .contain)
    }

    /// "Already open?" with "Carry on" (a run) and "Home".
    private func escapePlate(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            Text(Self.escapeLine)
                .font(HushType.headline(true))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
            if midRun {
                HushButton(kind: .primary, height: 56, compact: true, confirm: true, action: onCarryOn) {
                    Text(Self.carryOnLabel)
                }
                .accessibilityHint("Resumes the chest now")
                .accessibilityFocused($escapeFocused)
                HushButton(kind: .leather, height: HushTheme.minTap, compact: true, action: onHome) {
                    Text(Self.homeLabel)
                }
            } else {
                HushButton(kind: .leather, height: HushTheme.minTap, compact: true, action: onHome) {
                    Text(Self.homeLabel)
                }
                .accessibilityFocused($escapeFocused)
            }
        }
        // R11b (CI frame 50): the buttons sat wider than the leather plate, over its brass end caps.
        .padding(.horizontal, 22)
        .frame(width: max(width, 200))
        .hushPlate(padding: 14, radius: 22)
    }
}
