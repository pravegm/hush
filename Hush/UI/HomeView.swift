import SwiftUI

/// Home (ROUND-1 App). The lid half: the title and a live chest whose lid follows the hinge (or a drag), with the little
/// mimic peeking out as it opens, a playful hint at the game. The floor half (the sharp, reachable one on a Duo): the
/// thief rank, the best haul, and the big buttons: Play, Daily Dungeon, Codex, Settings, Game Center.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let c = info.isCompact
        let lid = info.lidHalf
        let floor = info.floorHalf
        ZStack {
            HushTheme.backdrop
                .contentShape(Rectangle())
            if info.hasFold {
                // The hinge strip between the halves.
                Rectangle()
                    .fill(LinearGradient(colors: [HushTheme.goldDeep.opacity(0.0), HushTheme.goldDeep.opacity(0.35),
                                                  HushTheme.goldDeep.opacity(0.0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: info.size.width, height: 2)
                    .position(x: info.size.width / 2, y: info.size.height / 2)
                    .accessibilityHidden(true)
            }
            VStack(spacing: c ? 6 : 12) {
                HushWordmark(size: c ? 56 : (lid.height > 380 ? 84 : 70))
                TitleChest(controller: controller, lid: controller.homeLid, interactive: !controller.hasHinge,
                           reduceMotion: controller.reduceMotion)
                    .frame(width: min(lid.width * 0.62, 300), height: min(lid.height * 0.48, 200))
                Text(Self.caption(controller.homeLid, hinge: controller.hasHinge))
                    .font(HushType.body(c))
                    .foregroundStyle(captionColor(controller.homeLid))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .animation(.easeOut(duration: 0.2), value: Self.caption(controller.homeLid, hinge: controller.hasHinge))
            }
            .frame(width: lid.width, height: lid.height)
            .position(x: lid.midX, y: lid.midY)

            HomeMenu(controller: controller, store: store, compact: c)
                .frame(width: min(floor.width - 32, 520))
                .frame(height: floor.height, alignment: info.hasFold ? .center : .bottom)
                .position(x: floor.midX, y: floor.midY)

            if let toast = controller.toast {
                Text(toast)
                    .font(HushType.body(c))
                    .foregroundStyle(HushTheme.parchment)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(HushTheme.surfaceRaised))
                    .position(x: floor.midX, y: floor.minY + 4)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(.easeOut(duration: 0.2), value: controller.toast)
    }

    /// The chest's caption: Home teaches the idea before the first chest. Pure; tested.
    static func caption(_ lid: HomeLid, hinge: Bool) -> String {
        if lid.speed > Tuning.loudSpeed { return "Easy! It's a mimic…" }
        if lid.openness > 0.85 { return "It's watching you." }
        if lid.openness > 0.3 { return "Shh… something's peeking." }
        return hinge ? "Lift the lid… slowly." : "Drag the lid up… slowly."
    }

    private func captionColor(_ lid: HomeLid) -> Color {
        if lid.speed > Tuning.loudSpeed { return HushTheme.amber }
        return lid.openness > 0.3 ? HushTheme.goldLight : HushTheme.mist
    }
}

/// The floor half's menu.
struct HomeMenu: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let compact: Bool

    var body: some View {
        let data = store.data
        let rank = store.rank
        VStack(spacing: compact ? 10 : 14) {
            RankRow(rank: rank, lifetime: data.lifetimeGold, best: data.bestRun, compact: compact)
            HushButton(kind: .primary, height: compact ? 60 : 70, compact: compact, confirm: true,
                       action: { controller.play() }) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                    Text("Play")
                }
            }
            .accessibilityHint("A run: chests until your torch burns out")
            HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                       action: { controller.show(.daily) }) {
                HStack(spacing: 10) {
                    Image(systemName: "sun.max.fill").foregroundStyle(HushTheme.gold)
                    Text("Daily Dungeon")
                    Spacer(minLength: 6)
                    Text(dailyStatus(data))
                        .font(HushType.caption(compact))
                        .foregroundStyle(controller.dailyScoredAvailable ? HushTheme.goldLight : HushTheme.mist)
                }
            }
            HStack(spacing: 10) {
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                           action: { controller.show(.codex) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                        Text("Codex \(data.foundRelics.count)/\(RelicCatalog.all.count)")
                    }
                }
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                           action: { controller.show(.settings) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                }
                Button {
                    FeedbackDirector.shared.uiTap()
                    controller.showGameCenter()
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(HushTheme.gold)
                        .frame(width: HushTheme.secondaryHeight, height: HushTheme.secondaryHeight)
                        .background(RoundedRectangle(cornerRadius: HushTheme.buttonRadius, style: .continuous)
                            .fill(HushTheme.surfaceRaised))
                        .contentShape(Rectangle())
                }
                .buttonStyle(HushPressStyle())
                .accessibilityLabel("Game Center")
            }
        }
    }

    private func dailyStatus(_ data: ProgressData) -> String {
        let today = controller.today
        if controller.dailyScoredAvailable { return "Today's try ready" }
        if let r = data.dailyRecord(day: today) { return "\(r.gold.formatted()) today" }
        return "Practice"
    }
}

/// "Rank 4 · Cat Burglar", the bar to the next rank, and the best haul.
struct RankRow: View {
    let rank: Int
    let lifetime: Int
    let best: Int
    let compact: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ThiefRanks.title(rank))
                    .font(HushType.headline(compact))
                    .foregroundStyle(HushTheme.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Rank \(rank + 1)")
                    .font(HushType.caption(compact))
                    .foregroundStyle(HushTheme.mist)
                Spacer(minLength: 8)
                if best > 0 {
                    HStack(spacing: 5) {
                        CoinGlyph(size: 16)
                        Text("Best \(best.formatted())")
                            .font(HushType.caption(compact).monospacedDigit())
                            .foregroundStyle(HushTheme.goldLight)
                    }
                }
            }
            HushProgressBar(value: ProgressRules.rankProgress(lifetime: lifetime, rank: rank), height: 8)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank + 1), \(ThiefRanks.title(rank)). Best haul \(best) gold.")
    }
}

/// Home's title chest: a chunky chest whose lid opens with the hinge (or a drag on an iPhone without one). As it
/// opens, gold glows inside and the mimic's eye peeks out of the dark; open fast and it glares.
struct TitleChest: View {
    @ObservedObject var controller: GameController
    let lid: HomeLid
    let interactive: Bool
    let reduceMotion: Bool
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let o = CGFloat(min(max(lid.openness, 0), 1))
            let palette = ChestArt.palette
            let wood = Color(hush: palette.wood)
            let woodDark = Color(hush: palette.woodDark)
            let iron = Color(hush: palette.iron)
            let gold = Color(hush: palette.gold)
            let bodyTop = h * 0.5
            let gap = o * h * 0.26
            let lidH = h * 0.3 * (1 - o * 0.45)
            ZStack {
                // Glow spilling out.
                Ellipse()
                    .fill(RadialGradient(colors: [HushTheme.candle.opacity(0.55 * Double(o)), .clear],
                                         center: .center, startRadius: 4, endRadius: w * 0.5))
                    .frame(width: w * 1.1, height: h * 0.7)
                    .position(x: w / 2, y: bodyTop - gap / 2)
                // The dark mouth between the lid and the body, and what peeks out of it.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hush: palette.dungeonDeep))
                    .frame(width: w * 0.84, height: max(gap, 1))
                    .position(x: w / 2, y: bodyTop - gap / 2)
                PeekingEye(openness: Double(o), glare: lid.speed > Tuning.loudSpeed, reduceMotion: reduceMotion)
                    .frame(width: w * 0.26, height: max(gap * 0.8, 1))
                    .position(x: w / 2, y: bodyTop - gap / 2)
                    .opacity(o > 0.12 ? Double(min((o - 0.12) * 4, 1)) : 0)
                Teeth(count: 7)
                    .fill(HushTheme.parchment)
                    .frame(width: w * 0.8, height: min(gap * 0.3, h * 0.07))
                    .position(x: w / 2, y: bodyTop - gap + min(gap * 0.15, h * 0.035))
                    .opacity(o > 0.5 ? 1 : 0)
                // The body.
                RoundedRectangle(cornerRadius: h * 0.08, style: .continuous)
                    .fill(LinearGradient(colors: [wood, woodDark], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.9, height: h * 0.46)
                    .position(x: w / 2, y: bodyTop + h * 0.23)
                ForEach([0.22, 0.78], id: \.self) { fx in
                    Rectangle()
                        .fill(iron)
                        .frame(width: w * 0.06, height: h * 0.46)
                        .position(x: w * CGFloat(fx), y: bodyTop + h * 0.23)
                }
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(gold)
                    .frame(width: w * 0.12, height: h * 0.16)
                    .position(x: w / 2, y: bodyTop + h * 0.12)
                // The lid, tilting back as it opens.
                ChestLidShape()
                    .fill(LinearGradient(colors: [wood, woodDark], startPoint: .top, endPoint: .bottom))
                    .overlay(ChestLidShape().stroke(iron, lineWidth: 4))
                    .frame(width: w * 0.9, height: lidH)
                    .position(x: w / 2, y: bodyTop - gap - lidH / 2)
                if o < 0.08 {
                    Text("z z")
                        .font(.system(size: h * 0.12, weight: .black, design: .rounded))
                        .foregroundStyle(HushTheme.goldLight.opacity(0.8))
                        .position(x: w * 0.82, y: bodyTop - lidH - h * 0.06)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .gesture(interactive ? drag(height: h) : nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A treasure chest. Something inside is asleep.")
    }

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? lid.openness
                if dragStart == nil {
                    dragStart = start
                    controller.homeChestDrag(began: true, ended: false, fraction: start)
                }
                let f = start + Double(-value.translation.height / max(height * 0.8, 1))
                controller.homeChestDrag(began: false, ended: false, fraction: f)
            }
            .onEnded { value in
                let start = dragStart ?? lid.openness
                let f = start + Double(-value.translation.height / max(height * 0.8, 1))
                controller.homeChestDrag(began: false, ended: true, fraction: f)
                dragStart = nil
            }
    }
}

/// The domed lid, seen from the front.
struct ChestLidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.45))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.45),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.35))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A row of round teeth hanging from the top edge.
struct Teeth: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let n = max(count, 1)
        let tw = rect.width / CGFloat(n)
        for i in 0..<n {
            let x = rect.minX + CGFloat(i) * tw
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: x + tw, y: rect.minY), control: CGPoint(x: x + tw / 2, y: rect.maxY * 1.6))
            p.closeSubpath()
        }
        return p
    }
}

/// The mimic's one big eye, peeking: its lid lifts with the chest's, and the iris drifts (or glares when it's loud).
struct PeekingEye: View {
    let openness: Double
    let glare: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let drift = reduceMotion || glare ? 0 : sin(t * 0.9) * 0.22
                let open = glare ? 1.0 : min(max((openness - 0.12) / 0.6, 0.15), 1)
                ZStack {
                    Ellipse()
                        .fill(HushTheme.parchment)
                    Circle()
                        .fill(glare ? HushTheme.danger : HushTheme.gold)
                        .frame(width: min(h * 0.9, w * 0.5), height: min(h * 0.9, w * 0.5))
                        .overlay(Circle().fill(Color.black).frame(width: min(h, w) * 0.22,
                                                                  height: min(h, w) * 0.22))
                        .offset(x: w * CGFloat(drift))
                }
                .frame(width: w, height: h)
                .mask(Ellipse().frame(width: w, height: h * CGFloat(open)))
            }
        }
        .accessibilityHidden(true)
    }
}
