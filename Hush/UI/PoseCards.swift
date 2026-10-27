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

/// Book pose (landscape on a Duo), R3 (UX P1-6): "Turn it sideways. Lift the glowing half." ("round" is a half turn,
/// and Settings' "Turn the chest round" means one). Brim's two-page layout: the WHOLE half to lift glows gold, the
/// words, the animated diagram and "I've stood it up" sit on the other page, nothing within 24 pt of the fold. In a
/// narrow window, one stacked column. Drawn in the interface's own orientation (never turned round). A phone never
/// shows it. R3 (QA-2 P2-4): "Play anyway" appears once iOS has refused portrait, or after `wayOutDelay` s.
struct StandUpCard: View {
    let insets: EdgeInsets
    let liftSide: ScreenSide
    let reduceMotion: Bool
    /// iOS refused a portrait request.
    var refused = false
    let onStoodUp: () -> Void
    var onPlayAnyway: () -> Void = {}
    @State private var waited = false

    /// The fold of a Duo in book pose runs down the middle (a 40 pt band). Content keeps ≥ 24 pt clear of it.
    static let creaseHalf: CGFloat = 20
    static let creaseClear: CGFloat = 24
    static let pageMargin: CGFloat = 28
    static let wayOutDelay: Double = 8

    static let title = "Turn it sideways. Lift the glowing half."
    static let bodyText = "Keep the other half flat, nearest you. That's the floor."
    static let wayOut = "Play anyway"

    /// Pure; tested.
    static func showsWayOut(refused: Bool, waited: Bool) -> Bool { refused || waited }

    /// Pure (tested): a Duo inner display in book pose, where the card splits into one column per page.
    static func splitsOnFold(_ size: CGSize) -> Bool {
        size.width > size.height && OrientationLock.looksLikeDuo(size)
    }

    var body: some View {
        ZStack {
            HushTheme.backdrop
            GeometryReader { geo in
                if Self.splitsOnFold(geo.size) {
                    bookPages(geo.size)
                } else {
                    stacked(geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Self.wayOutDelay * 1_000_000_000))
            waited = true
        }
    }

    private func bookPages(_ size: CGSize) -> some View {
        let page = max(size.width / 2 - Self.creaseHalf - Self.creaseClear, 0)
        let liftPage = ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [HushTheme.gold.opacity(0.32), HushTheme.goldDeep.opacity(0.18)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(HushTheme.gold, lineWidth: 5))
            VStack(spacing: 14) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                Text("Lift this half")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                Text("It's the chest's lid.")
                    .font(HushType.body(false))
                    .foregroundStyle(HushTheme.parchment)
            }
            .foregroundStyle(HushTheme.goldLight)
            .multilineTextAlignment(.center)
            .padding(20)
        }
        .padding(.top, insets.top + 16)
        .padding(.bottom, insets.bottom + 16)
        .frame(width: page)
        .accessibilityElement(children: .combine)
        let floorPage = ScrollView(showsIndicators: false) {
            copy(diagram: min(page - 2 * Self.pageMargin, 220))
                .padding(.horizontal, Self.pageMargin)
                .padding(.vertical, 24)
                .frame(width: page)
                .frame(minHeight: max(size.height - insets.top - insets.bottom, 0))
        }
        .frame(width: page)
        .padding(.top, insets.top)
        .padding(.bottom, insets.bottom)
        let gap = Color.clear.frame(width: 2 * (Self.creaseHalf + Self.creaseClear))
        return HStack(spacing: 0) {
            if liftSide == .left {
                liftPage
                gap
                floorPage
            } else {
                floorPage
                gap
                liftPage
            }
        }
        .padding(.leading, liftSide == .left ? insets.leading : 0)
        .padding(.trailing, liftSide == .right ? insets.trailing : 0)
        .frame(width: size.width, height: size.height)
    }

    private func stacked(_ size: CGSize) -> some View {
        ScrollView(showsIndicators: false) {
            copy(diagram: min(size.width - 80, 220))
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: 460)
                .frame(width: size.width)
                .frame(minHeight: max(size.height - insets.top - insets.bottom, 0))
        }
        .padding(.top, insets.top)
        .padding(.bottom, insets.bottom)
    }

    private func copy(diagram: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TurnAndLiftDrawing(liftSide: liftSide, reduceMotion: reduceMotion)
                .frame(width: max(diagram, 120), height: max(diagram, 120))
                .frame(maxWidth: .infinity)
            HushOverline(text: "Hush", color: HushTheme.gold)
            Text(Self.title)
                .font(HushType.title(false))
                .foregroundStyle(HushTheme.parchment)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.bodyText)
                .font(HushType.body(false))
                .foregroundStyle(HushTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
            HushButton(kind: .primary, height: HushTheme.minTap, confirm: true, action: onStoodUp) {
                Label("I've stood it up", systemImage: "checkmark")
            }
            .accessibilityHint("Turns the screen upright for the chest")
            if Self.showsWayOut(refused: refused, waited: waited) {
                HushButton(kind: .quiet, height: HushTheme.minTap, action: onPlayAnyway) {
                    Text(Self.wayOut)
                }
                .accessibilityHint("Plays sideways, with an on-screen lever for the lid")
            }
        }
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

    private func half(lid: Bool, width: CGFloat, height: CGFloat) -> some View {
        let r = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            r.fill(lid ? HushTheme.gold.opacity(0.85) : HushTheme.surfaceRaised)
            r.stroke(lid ? HushTheme.goldLight : HushTheme.haze, lineWidth: 2)
            Image(systemName: lid ? "arrow.up" : "shippingbox.fill")
                .font(.system(size: height * 0.32, weight: .black))
                .foregroundStyle(lid ? HushTheme.ink : HushTheme.mist)
        }
        .frame(width: width, height: height)
    }
}

/// Shut, on the cover display: the sleeping mimic (the Scene's portrait, asleep) and "Open to carry on".
struct CoverCard: View {
    let midRun: Bool
    let portrait: MimicPortraitScene
    let reduceMotion: Bool

    /// Pure; tested.
    static func title(midRun: Bool) -> String { midRun ? "Open to carry on" : "Open me… gently" }
    static func detail(midRun: Bool) -> String {
        midRun ? "Open me gently, then hold still. Your candle waits." : "There's gold in here. And something else."
    }

    /// R3 (UX P2-12, juror P1-11): the group is centred and the mimic fills the card (never top-heavy).
    var body: some View {
        ZStack {
            HushTheme.backdrop
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
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
        }
        .accessibilityElement(children: .combine)
    }
}
