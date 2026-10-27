import SpriteKit
import SwiftUI

/// Results (GAME-DESIGN §7). R2 (UX P1-13, juror P1-12): the mimic itself (smug if it bit, still asleep if hushed),
/// the haul counting up, "New best!" or "312 short of your best", one sentence of story; then the chest-by-chest strip
/// (`chestLog`), the tiles with their meaning ("Hushed: banked while it slept"), the relics, the rank bar, the named
/// achievements, and Again / Home. On a Duo: the hero on the lid half, the rest on the floor half (sharp, reachable).
/// Elsewhere one column that scrolls before it ever clips (Dynamic Type).
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas
    @State private var shownGold: Double = 0
    @State private var rankFill: Double = 0
    @State private var appeared = false

    var body: some View {
        let c = info.isCompact
        ZStack {
            HushTheme.backdrop
                .contentShape(Rectangle())
            if info.hasFold {
                let lid = info.lidHalf
                let floor = info.floorHalf
                fitting(hero(c, portrait: min(lid.height * 0.34, 170)), height: lid.height)
                    .frame(width: lid.width, height: lid.height)
                    .position(x: lid.midX, y: lid.midY)
                VStack(spacing: c ? 10 : 12) {
                    fitting(details(c), height: max(floor.height - HushTheme.primaryHeight - 24, 120))
                    buttons(c)
                }
                .frame(width: min(floor.width - 32, 560), height: floor.height)
                .position(x: floor.midX, y: floor.midY)
            } else {
                let safe = info.safeRect
                VStack(spacing: 10) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: c ? 12 : 18) {
                            hero(c, portrait: min(safe.height * 0.2, 150))
                            details(c)
                        }
                        .padding(.top, 12)
                        .frame(width: min(safe.width - 32, 560))
                        .frame(maxWidth: .infinity)
                    }
                    buttons(c)
                        .frame(width: min(safe.width - 32, 560))
                        .padding(.bottom, 8)
                }
                .frame(width: safe.width, height: safe.height)
                .position(x: safe.midX, y: safe.midY)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .onAppear(perform: play)
        .accessibilityElement(children: .contain)
    }

    /// The content as is when it fits the height, else scrolling (never clipped).
    private func fitting<V: View>(_ content: V, height: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(showsIndicators: false) { content }
                .frame(maxHeight: height)
        }
    }

    private func hero(_ c: Bool, portrait: CGFloat) -> some View {
        let o = summary.outcome
        return VStack(spacing: c ? 6 : 10) {
            HushOverline(text: summary.title, compact: c, color: HushTheme.gold)
            MimicPortraitView(scene: controller.portraits.results, fps: min(controller.preferredFPS, 60))
                .frame(height: max(portrait, 70))
            HStack(alignment: .center, spacing: 12) {
                CoinGlyph(size: c ? 36 : 48)
                CountingNumber(value: shownGold, font: HushType.hero(c))
                    .foregroundStyle(HushTheme.goldLight)
                    .shadow(color: HushTheme.candle.opacity(0.45), radius: 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.result.gold) gold banked")
            Text("gold banked")
                .font(HushType.body(c))
                .foregroundStyle(HushTheme.mist)
                .accessibilityHidden(true)
            if o.showsNewBest {
                HushPill(text: o.practice ? "Practice best!" : "New best!")
                    .scaleEffect(appeared || controller.reduceMotion ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            } else if let near = summary.nearMiss {
                Text(near)
                    .font(HushType.caption(c).monospacedDigit())
                    .foregroundStyle(HushTheme.amber)
            } else if o.best > 0 {
                Text("Best \(o.best.formatted())")
                    .font(HushType.caption(c).monospacedDigit())
                    .foregroundStyle(HushTheme.mist)
            }
            Text(summary.story)
                .font(HushType.headline(c))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 2)
        }
    }

    private func details(_ c: Bool) -> some View {
        let r = summary.result
        let o = summary.outcome
        return VStack(spacing: c ? 10 : 12) {
            if !r.chestLog.isEmpty {
                ChestStrip(log: r.chestLog, compact: c)
            }
            HStack(spacing: 10) {
                StatTile(value: r.chestsBanked, label: "Chests banked", detail: nil, compact: c)
                StatTile(value: r.hushed, label: "Hushed", detail: "banked while it slept", tint: HushTheme.asleep,
                         compact: c)
                StatTile(value: r.bites, label: r.bites == 1 ? "Bite" : "Bites",
                         detail: r.lostToBites > 0 ? "\(r.lostToBites.formatted()) lost" : nil,
                         tint: r.bites > 0 ? HushTheme.danger : HushTheme.mist, compact: c)
            }
            if r.bestChain >= 2 {
                Text("Longest Hush Chain: \(r.bestChain)")
                    .font(HushType.caption(c))
                    .foregroundStyle(HushTheme.asleep)
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
                            .foregroundStyle(HushTheme.mist)
                    }
                }
                HushProgressBar(value: rankFill, height: 8)
            }
            .accessibilityElement(children: .combine)
            if !o.newAchievements.isEmpty {
                AchievementRow(earned: o.newAchievements, compact: c, onTap: { controller.show(.badges) })
            }
        }
    }

    private func buttons(_ c: Bool) -> some View {
        HStack(spacing: 10) {
            HushButton(kind: .secondary, height: HushTheme.primaryHeight, compact: c, action: { controller.goHome() }) {
                Label("Home", systemImage: "house.fill")
            }
            .frame(maxWidth: 160)
            HushButton(kind: .primary, compact: c, confirm: true, action: { controller.again() }) {
                Label(summary.againLabel, systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func play() {
        let gold = Double(max(summary.result.gold, 0))
        rankFill = summary.outcome.rankedUp ? 0 : summary.rankProgressBefore
        if controller.reduceMotion || controller.isDemo {
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
    var detail: String?
    var tint: Color = HushTheme.parchment
    let compact: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(HushType.number(compact ? 26 : 32))
                .foregroundStyle(tint)
            Text(label)
                .font(HushType.caption(compact))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(HushType.overline(compact))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: compact ? 64 : 76)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HushTheme.surface))
        .accessibilityElement(children: .combine)
    }
}

/// R2 (UX P1-13): the run's story at a glance, one small chest per chest opened: its tier, the gold it banked, a "zzz"
/// if Hushed, teeth if it bit, a gold glow if it was a golden mimic.
struct ChestStrip: View {
    let log: [ChestOutcome]
    let compact: Bool

    var body: some View {
        let side: CGFloat = compact ? 40 : 46
        LazyVGrid(columns: [GridItem(.adaptive(minimum: side + 4, maximum: side + 14), spacing: 6)], spacing: 6) {
            ForEach(Array(log.enumerated()), id: \.offset) { item in
                ChestChip(outcome: item.element, side: side, compact: compact)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HushTheme.surface.opacity(0.8)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(log))
    }

    /// "8 chests: 5 banked, 2 hushed, 1 bitten". Pure; tested.
    static func spoken(_ log: [ChestOutcome]) -> String {
        let banked = log.filter { $0.value > 0 }.count
        let hushed = log.filter(\.hushed).count
        let bitten = log.filter(\.bitten).count
        return "\(log.count) chests: \(banked) banked, \(hushed) hushed, \(bitten) bitten"
    }
}

struct ChestChip: View {
    let outcome: ChestOutcome
    let side: CGFloat
    let compact: Bool

    /// The tier's wood and metal (the in-game chest colours).
    static func colors(_ tier: ChestTier) -> (body: Color, band: Color) {
        switch tier {
        case .wooden: return (Color(hush: ChestArt.palette.wood), Color(hush: ChestArt.palette.woodDark))
        case .iron: return (Color(hush: ChestArt.palette.wood), Color(hush: ChestArt.palette.iron))
        case .gilded: return (Color(hushHex: 0x7A4A2A), HushTheme.gold)
        case .royal: return (Color(hush: ChestArt.palette.velvet), HushTheme.goldLight)
        }
    }

    var body: some View {
        let c = Self.colors(outcome.tier)
        let outline = Color(hush: ChestArt.outline)
        VStack(spacing: 2) {
            ZStack {
                if outcome.golden {
                    Circle().fill(HushTheme.gold.opacity(0.35)).frame(width: side, height: side).blur(radius: 4)
                }
                // A little chest front in the in-game style: outline, wood, a metal band, a lock.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(outcome.golden ? HushTheme.gold : c.body)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(outline, lineWidth: 2.5))
                    .frame(width: side * 0.72, height: side * 0.5)
                    .offset(y: side * 0.08)
                Rectangle().fill(c.band).frame(width: side * 0.72, height: side * 0.08).offset(y: -side * 0.05)
                Circle().fill(HushTheme.goldLight).overlay(Circle().stroke(outline, lineWidth: 1.5))
                    .frame(width: side * 0.14, height: side * 0.14).offset(y: side * 0.1)
                if outcome.bitten {
                    FittedPathShape(path: Path(ChestArt.flippedVertically(
                        ChestArt.teethRow(width: 40, height: 14, count: 4, pointingDown: false))))
                        .fill(HushTheme.parchment)
                        .overlay(FittedPathShape(path: Path(ChestArt.flippedVertically(
                            ChestArt.teethRow(width: 40, height: 14, count: 4, pointingDown: false))))
                            .stroke(HushTheme.danger, lineWidth: 1.5))
                        .frame(width: side * 0.6, height: side * 0.22)
                        .offset(y: -side * 0.3)
                } else if outcome.hushed {
                    Image(systemName: "zzz")
                        .font(.system(size: side * 0.24, weight: .black))
                        .foregroundStyle(HushTheme.asleep)
                        .offset(x: side * 0.24, y: -side * 0.3)
                }
            }
            .frame(width: side, height: side * 0.8)
            Text(outcome.value > 0 ? "+\(outcome.value.formatted())" : (outcome.bitten ? "bit" : "0"))
                .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(outcome.bitten ? HushTheme.danger : (outcome.value > 0 ? HushTheme.goldLight :
                                                                        HushTheme.haze))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// The relics banked this run, drawn from ChestArt; new Codex pages get a gold "New".
struct RelicStrip: View {
    let relics: [RelicID]
    let newOnes: Set<RelicID>
    let compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(relics.prefix(3).enumerated()), id: \.offset) { item in
                let relic = RelicCatalog.relic(item.element)
                HStack(spacing: 8) {
                    RelicArt(relic: relic, found: true)
                        .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                        .padding(4)
                        .background(VelvetTile(radius: 12))
                    VStack(alignment: .leading, spacing: 1) {
                        if newOnes.contains(item.element) {
                            Text("NEW")
                                .font(HushType.overline(compact))
                                .foregroundStyle(HushTheme.gold)
                        }
                        Text(relic.name)
                            .font(HushType.caption(compact))
                            .foregroundStyle(HushTheme.parchment)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HushTheme.surface))
            }
        }
    }
}

/// R2 (UX P1-13): up to two achievements named with their badge, "+1 more" beyond; taps through to the Badges page.
struct AchievementRow: View {
    let earned: [AchievementDef]
    let compact: Bool
    let onTap: () -> Void

    /// "+2 more" past the first two (nil when they all show). Pure; tested.
    static func moreLine(_ count: Int) -> String? { count > 2 ? "+\(count - 2) more" : nil }

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            onTap()
        } label: {
            HStack(spacing: 10) {
                ForEach(Array(earned.prefix(2).enumerated()), id: \.offset) { item in
                    let index = Achievements.all.firstIndex(of: item.element) ?? 0
                    HStack(spacing: 6) {
                        AchievementBadge(def: item.element, index: index, side: compact ? 34 : 40)
                            .clipShape(Circle())
                        Text(item.element.title)
                            .font(HushType.caption(compact))
                            .foregroundStyle(HushTheme.gold)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let more = Self.moreLine(earned.count) {
                    Text(more)
                        .font(HushType.caption(compact))
                        .foregroundStyle(HushTheme.mist)
                        .fixedSize()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HushTheme.mist)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HushTheme.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(HushPressStyle())
        .accessibilityLabel("Achievements earned: " + earned.map(\.title).joined(separator: ", "))
    }
}
