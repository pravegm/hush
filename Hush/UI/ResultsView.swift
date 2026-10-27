import SwiftUI

/// Results (GAME-DESIGN §7, ROUND-1 App). The lid half: the title, the gold banked (a big counting number), "New best!"
/// and one sentence of story. The floor half (sharp, reachable): chests banked, Hushed, bites, the relics found (art),
/// the rank bar's progress, and the buttons: Again, Home.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas
    @State private var shownGold: Double = 0
    @State private var rankFill: Double = 0
    @State private var appeared = false

    var body: some View {
        let c = info.isCompact
        let r = summary.result
        let o = summary.outcome
        let lid = info.lidHalf
        let floor = info.floorHalf
        ZStack {
            HushTheme.backdrop
                .contentShape(Rectangle())
            VStack(spacing: c ? 8 : 12) {
                HushOverline(text: summary.title, compact: c, color: HushTheme.gold)
                HStack(alignment: .center, spacing: 12) {
                    CoinGlyph(size: c ? 40 : 54)
                    CountingNumber(value: shownGold, font: HushType.hero(c))
                        .foregroundStyle(HushTheme.goldLight)
                        .shadow(color: HushTheme.candle.opacity(0.45), radius: 16)
                }
                Text("gold banked")
                    .font(HushType.body(c))
                    .foregroundStyle(HushTheme.mist)
                if o.showsNewBest {
                    HushPill(text: o.practice ? "Practice best!" : "New best!")
                        .scaleEffect(appeared || controller.reduceMotion ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                } else if o.best > 0 && !o.practice {
                    Text("Best \(o.best.formatted())")
                        .font(HushType.caption(c).monospacedDigit())
                        .foregroundStyle(HushTheme.haze)
                }
                Text(summary.story)
                    .font(HushType.headline(c))
                    .foregroundStyle(HushTheme.parchment)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }
            .frame(width: lid.width)
            .position(x: lid.midX, y: lid.midY)

            VStack(spacing: c ? 10 : 14) {
                HStack(spacing: 10) {
                    StatTile(value: r.chestsBanked, label: "Chests banked", compact: c)
                    StatTile(value: r.hushed, label: "Hushed", tint: HushTheme.asleep, compact: c)
                    StatTile(value: r.bites, label: r.bites == 1 ? "Bite" : "Bites",
                             tint: r.bites > 0 ? HushTheme.danger : HushTheme.mist, compact: c)
                }
                if !r.relics.isEmpty {
                    RelicStrip(relics: r.relics, newOnes: Set(o.newRelics), compact: c)
                }
                VStack(spacing: 6) {
                    HStack {
                        Text(o.rankedUp ? "Rank up! \(summary.rankTitle)" : summary.rankTitle)
                            .font(HushType.body(c))
                            .foregroundStyle(o.rankedUp ? HushTheme.goldLight : HushTheme.parchment)
                        Spacer()
                        if let next = summary.nextRankTitle {
                            Text("Next: \(next)")
                                .font(HushType.caption(c))
                                .foregroundStyle(HushTheme.haze)
                        }
                    }
                    HushProgressBar(value: rankFill, height: 8)
                    if !o.newAchievements.isEmpty {
                        Text(o.newAchievements.count == 1 ? "Achievement: \(o.newAchievements[0].title)" :
                                "\(o.newAchievements.count) achievements earned")
                            .font(HushType.caption(c))
                            .foregroundStyle(HushTheme.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                HStack(spacing: 10) {
                    HushButton(kind: .secondary, height: HushTheme.primaryHeight, compact: c,
                               action: { controller.goHome() }) {
                        Label("Home", systemImage: "house.fill")
                    }
                    .frame(maxWidth: 160)
                    HushButton(kind: .primary, compact: c, confirm: true, action: { controller.again() }) {
                        Label(summary.againLabel, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .frame(width: min(floor.width - 32, 540))
            .frame(height: floor.height, alignment: info.hasFold ? .center : .bottom)
            .position(x: floor.midX, y: floor.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
        .onAppear(perform: play)
        .accessibilityElement(children: .contain)
    }

    private func play() {
        let gold = Double(max(summary.result.gold, 0))
        rankFill = summary.outcome.rankedUp ? 0 : summary.rankProgressBefore
        if controller.reduceMotion {
            shownGold = gold
            rankFill = summary.rankProgressAfter
            appeared = true
            return
        }
        shownGold = 0
        let seconds = min(max(gold / 1_500, 0.8), 1.8)
        withAnimation(.easeOut(duration: seconds)) { shownGold = gold }
        withAnimation(.easeInOut(duration: 0.9).delay(seconds * 0.6)) { rankFill = summary.rankProgressAfter }
        withAnimation(HushTheme.pop(false).delay(seconds)) { appeared = true }
    }
}

struct StatTile: View {
    let value: Int
    let label: String
    var tint: Color = HushTheme.parchment
    let compact: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(HushType.number(compact ? 26 : 32))
                .foregroundStyle(tint)
            Text(label)
                .font(HushType.caption(compact))
                .foregroundStyle(HushTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 64 : 76)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HushTheme.surface))
        .accessibilityElement(children: .combine)
    }
}

/// The relics banked this run, drawn from Scene's ChestArt; new Codex pages get a gold "New".
struct RelicStrip: View {
    let relics: [RelicID]
    let newOnes: Set<RelicID>
    let compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(relics.prefix(4).enumerated()), id: \.offset) { item in
                let relic = RelicCatalog.relic(item.element)
                HStack(spacing: 8) {
                    RelicArt(relic: relic, found: true)
                        .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
                    VStack(alignment: .leading, spacing: 1) {
                        if newOnes.contains(item.element) {
                            Text("NEW")
                                .font(HushType.overline(compact))
                                .foregroundStyle(HushTheme.gold)
                        }
                        Text(relic.name)
                            .font(HushType.caption(compact))
                            .foregroundStyle(HushTheme.parchment)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HushTheme.surface))
            }
        }
    }
}

/// A relic drawn from `ChestArt.relicPath` in its tint (found), or a dark silhouette (not yet found).
struct RelicArt: View {
    let relic: Relic
    let found: Bool

    var body: some View {
        // ChestArt paths are y-up (SpriteKit); SwiftUI is y-down, so flip.
        let shape = FittedPathShape(path: Path(ChestArt.relicPath(relic.shape, radius: 50))
            .applying(CGAffineTransform(scaleX: 1, y: -1)))
        ZStack {
            if found {
                shape.fill(Color(hush: relic.tint))
                    .shadow(color: HushTheme.candle.opacity(0.4), radius: 6)
                shape.stroke(HushTheme.goldDeep.opacity(0.6), lineWidth: 1.5)
            } else {
                shape.fill(HushTheme.night)
                shape.stroke(HushTheme.moss, lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}
