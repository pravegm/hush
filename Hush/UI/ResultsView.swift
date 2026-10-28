import SpriteKit
import SwiftUI

/// Results (GAME-DESIGN §7). The mimic itself (smug if it bit, still asleep if hushed), the haul counting up, "New
/// best!", "First haul!" or "312 short of your best", why the run ended, one sentence of story; then the stat tiles,
/// the chest-by-chest strip (`chestLog`) with its legend, the relics, the rank bar, the named achievements, and Again /
/// Home. On a Duo: the hero on the lid half, the rest on the floor half (sharp, reachable). Elsewhere one column.
///
/// R3 (UX P1-4, juror P1-9): the tiles come FIRST (equal height, never under the buttons), the strip is capped at two
/// rows plus "+N more", and a scroll that overflows fades out above the buttons with a chevron.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let info: AppCanvas
    @State private var shownGold: Double = 0
    @State private var rankFill: Double = 0
    @State private var appeared = false
    /// R5 (UX P2-7): the phone column's measured scroll height, the strip's bottom in it, and the hero portrait's
    /// fitted height (nil: the full height).
    @State private var scrollHeight: CGFloat = 0
    @State private var stripBottom: CGFloat = 0
    @State private var portraitFit: CGFloat? = nil
    /// R11 (UX P1-1): the nudge's "Make it forgiving" was tapped.
    @State private var forgivingChosen = false

    /// The phone column's coordinate space (the scroll's content, so scrolling never moves what's measured in it).
    static let columnSpace = "hush.results.column"
    /// The hero portrait never shrinks below this (it is still the mimic). R10 (VISUAL-REGRESSION-R9 R4: the chest
    /// drew 45–50 pt wide, "a speck" by the total): 110, so the chest itself draws ≥ 90 pt wide
    /// (`drawnChestWidth(portrait:)`); the outcome line now shares the "gold banked" row to pay for it.
    static let minPortrait: CGFloat = 110
    /// R10: the chest's drawn width per point of portrait height. The 600 × 480 portrait scene is shown aspect-fit in
    /// the frame (so 480 scene points span its height), its 400-unit art box is fitted to the short side (480), and
    /// the chest (the lid's face) is 330 units wide: 330 / 400 of the frame's height. Pure; tested.
    static let chestWidthPerPortraitPoint: CGFloat = 330.0 / 400.0
    static func drawnChestWidth(portrait: CGFloat) -> CGFloat {
        max(portrait.isFinite ? portrait : 0, minPortrait) * chestWidthPerPortraitPoint
    }
    /// R10: the Duo's lid-half portrait (larger than a phone's: the lid half is all hero).
    static func duoPortrait(lidHeight: CGFloat) -> CGFloat {
        min(max(lidHeight.isFinite ? lidHeight : 0, 0) * 0.4, 190)
    }

    private var phonePortraitMax: CGFloat { min(info.safeRect.height * 0.2, 150) }

    /// R5 (UX P2-7): the portrait height that puts the strip's bottom `fade` above the viewport's foot, within
    /// `minimum…maximum`. One step settles it: the strip moves by exactly the change. Pure; tested.
    static func fittedPortrait(current: CGFloat, stripBottom: CGFloat, viewport: CGFloat, fade: CGFloat,
                               minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard stripBottom > 0, viewport > 0, current.isFinite, stripBottom.isFinite, viewport.isFinite else {
            return current
        }
        let spare = viewport - fade - stripBottom
        return min(max(current + spare, minimum), max(maximum, minimum))
    }

    private func refitPortrait() {
        guard !info.hasFold else { return }
        let current = portraitFit ?? phonePortraitMax
        let fitted = Self.fittedPortrait(current: current, stripBottom: stripBottom,
                                         viewport: scrollHeight - FadingScroll<EmptyView>.chevronStrip,
                                         fade: FadingScroll<EmptyView>.fadeHeight, minimum: Self.minPortrait,
                                         maximum: phonePortraitMax)
        if abs(fitted - current) > 0.5 { portraitFit = fitted }
    }

    var body: some View {
        let c = info.isCompact
        ZStack {
            HushTheme.backdrop
                .contentShape(Rectangle())
            if info.hasFold {
                let lid = info.lidHalf
                let floor = info.floorHalf
                let width = min(floor.width - 32, 560)
                FadingScroll {
                    hero(c, portrait: Self.duoPortrait(lidHeight: lid.height))
                        .frame(width: lid.width)
                        .frame(minHeight: lid.height)
                }
                    .frame(width: lid.width, height: lid.height)
                    .position(x: lid.midX, y: lid.midY)
                VStack(spacing: c ? 10 : 12) {
                    FadingScroll { details(c, width: width).frame(width: width).padding(.top, 8) }
                    buttons(c)
                        .frame(width: width)
                }
                .frame(width: floor.width, height: floor.height)
                .position(x: floor.midX, y: floor.midY)
            } else {
                let safe = info.safeRect
                let width = min(safe.width - 32, 560)
                VStack(spacing: 10) {
                    FadingScroll {
                        VStack(spacing: c ? 12 : 18) {
                            hero(c, portrait: portraitFit ?? phonePortraitMax)
                            details(c, width: width)
                        }
                        .padding(.top, 12)
                        .coordinateSpace(.named(Self.columnSpace))
                        .frame(width: width)
                        .frame(maxWidth: .infinity)
                    }
                    // R5 (UX P2-7, frames 20 and 38): the hero's mimic gives way so the strip's two rows (the
                    // second ending in "+N more") sit above the scroll's fade.
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        scrollHeight = height
                        refitPortrait()
                    }
                    buttons(c)
                        .frame(width: width)
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

    private func hero(_ c: Bool, portrait: CGFloat) -> some View {
        let o = summary.outcome
        return VStack(spacing: c ? 6 : 10) {
            VStack(spacing: 3) {
                HushOverline(text: summary.title, compact: c, color: HushTheme.gold)
                if !summary.cause.isEmpty {
                    Text(summary.cause)
                        .font(HushType.caption(c))
                        .foregroundStyle(summary.result.bites > 0 ? HushTheme.amber : HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            // R11b (CI frame 52): on a fold the lid half is its own short scroll, and the nudge pushed the gold number
            // into its bottom fade; there the nudge leads the floor's details instead.
            if summary.offersForgiving && !info.hasFold {
                forgivingNudge(c)
            }
            MimicPortraitView(scene: controller.portraits.results, fps: min(controller.preferredFPS, 60))
                .frame(height: max(portrait, Self.minPortrait))
            HStack(alignment: .center, spacing: 12) {
                CoinGlyph(size: c ? 36 : 48)
                CountingNumber(value: shownGold, font: HushType.hero(c))
                    .foregroundStyle(HushTheme.goldLight)
                    .shadow(color: HushTheme.candle.opacity(0.45), radius: 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.result.gold) gold banked")
            // R10 (VISUAL-REGRESSION-R9 R4): the outcome ("New best!", "First haul!", "751 short…", "Best N") shares
            // the "gold banked" row while it fits (one line less: the room the bigger mimic needs), else sits under it.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    goldBankedLabel(c)
                    outcomeLine(c)
                }
                VStack(spacing: c ? 6 : 10) {
                    goldBankedLabel(c)
                    outcomeLine(c)
                }
            }
            if o.isFirstHaul && !o.showsNewBest {
                Text("Now beat it.")
                    .font(HushType.caption(c))
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

    /// R11 (UX P1-1): the one-time nudge under the cause line: "Keeps waking? Try a forgiving lid." with a small leather
    /// "Make it forgiving", which sets Forgiving and becomes "Forgiving on. Change it in Settings."
    private func forgivingNudge(_ c: Bool) -> some View {
        VStack(spacing: 6) {
            Text(forgivingChosen ? AppRules.forgivingNudgeDone : AppRules.forgivingNudgeLine)
                .font(HushType.caption(c).weight(.semibold))
                .foregroundStyle(PlateArt.text(.parchment))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !forgivingChosen {
                HushButton(kind: .leather, height: HushTheme.minTap, compact: true, action: {
                    controller.makeLidForgiving()
                    forgivingChosen = true
                }) {
                    Text(AppRules.forgivingNudgeButton)
                }
                .frame(maxWidth: 240)
                .accessibilityHint(AppRules.sensitivityLine(.forgiving))
                .accessibilityIdentifier("results.forgiving")
            }
        }
        .hushPlate(.parchment, padding: 10, radius: 16)
        .padding(.horizontal, 24)
        .animation(HushTheme.settle(controller.reduceMotion), value: forgivingChosen)
    }

    private func goldBankedLabel(_ c: Bool) -> some View {
        Text("gold banked")
            .font(HushType.body(c))
            .foregroundStyle(HushTheme.mist)
            .accessibilityHidden(true)
    }

    /// The run's outcome beside (or under) "gold banked": the pill, the near miss or the best.
    @ViewBuilder
    private func outcomeLine(_ c: Bool) -> some View {
        let o = summary.outcome
        if o.showsNewBest {
            HushPill(text: o.practice ? "Practice best!" : "New best!")
                .scaleEffect(appeared || controller.reduceMotion ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
        } else if o.isFirstHaul {
            HushPill(text: "First haul!")
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
    }

    private func details(_ c: Bool, width: CGFloat) -> some View {
        let r = summary.result
        let o = summary.outcome
        return VStack(spacing: c ? 10 : 12) {
            if summary.offersForgiving && info.hasFold {
                forgivingNudge(c)
            }
            HStack(alignment: .top, spacing: 10) {
                // R4 (tester 7): the chests OPENED, counted like the strip (the one the candle went out on too), so
                // the tile and the strip never disagree ("14" next to 15 chips).
                StatTile(value: AppRules.chestsOpened(r), label: "Opened", detail: "chests", compact: c)
                StatTile(value: r.hushed, label: "Hushed", detail: "while it slept", tint: HushTheme.asleep,
                         compact: c)
                StatTile(value: r.bites, label: r.bites == 1 ? "Bite" : "Bites",
                         detail: r.lostToBites > 0 ? "\(r.lostToBites.formatted()) lost" : nil,
                         tint: r.bites > 0 ? HushTheme.danger : HushTheme.mist, compact: c)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !r.chestLog.isEmpty {
                ChestStrip(log: r.chestLog, compact: c, width: width)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named("hush.results.column")).maxY   // = ResultsView.columnSpace
                    } action: { bottom in
                        stripBottom = bottom
                        refitPortrait()
                    }
            }
            if r.bestChain >= 2 {
                Text(AppRules.chainLine(r.bestChain))
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
        .padding(.bottom, 12)
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

/// R3 (UX P1-4): a scroll whose overflow fades out at the bottom, with a small chevron until the end is reached.
/// Content that fits doesn't scroll, fade or show the chevron.
struct FadingScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content
    /// R5: where the scroll starts (nil: the top). The lesson's final card starts at the bottom, so "Got it" shows.
    var anchor: UnitPoint?
    @State private var state = ScrollState()

    init(anchor: UnitPoint? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.anchor = anchor
        self.content = content
    }

    struct ScrollState: Equatable {
        var overflows = false
        var atEnd = true
    }

    /// Pure; tested.
    static func state(contentHeight: CGFloat, viewHeight: CGFloat, offset: CGFloat) -> ScrollState {
        let overflows = contentHeight > viewHeight + 1
        return ScrollState(overflows: overflows, atEnd: !overflows || offset + viewHeight >= contentHeight - 8)
    }

    /// R4 (QA-3 P2-8, frames 41/45): the chevron's own strip under the scroll, so it never sits on the totals.
    static var chevronStrip: CGFloat { 18 }   // computed: a generic type can't store a static
    /// R5: the height of the fade at the foot of an overflowing scroll (the mask below). R11 (ROUND-11 App 9, tester
    /// 11 frame 20: a half-visible card read as clipped, not "scroll for more"): 36 → 56, and steeper (`fadeStops`).
    static var fadeHeight: CGFloat { 56 }
    /// R11: the most of the view the fade may take.
    static var fadeMaxFraction: CGFloat { 0.35 }

    /// R11: the mask's stops over the fade (location within the view, opacity): fully shown above it, under half by
    /// its middle, gone at the foot, so a cut-off card dissolves instead of ending on a hard edge. Pure; tested.
    static func fadeStops(fade: CGFloat) -> [(location: CGFloat, opacity: Double)] {
        let f = min(max(fade.isFinite ? fade : 0, 0), 1)
        guard f > 0 else { return [(0, 1), (1, 1)] }
        return [(0, 1), (1 - f, 1), (1 - f * 0.45, 0.35), (1, 0)]
    }

    var body: some View {
        let fades = state.overflows && !state.atEnd
        VStack(spacing: 0) {
            scroll(fades: fades)
            if state.overflows {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(HushTheme.goldLight)
                    .frame(height: Self.chevronStrip)
                    .opacity(fades ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func scroll(fades: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            content()
        }
        .defaultScrollAnchor(anchor)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: ScrollState.self) { g in
            Self.state(contentHeight: g.contentSize.height, viewHeight: g.containerSize.height,
                       offset: g.contentOffset.y)
        } action: { _, new in
            state = new
        }
        .mask {
            GeometryReader { g in
                let fade = fades ? min(Self.fadeHeight / max(g.size.height, 1), Self.fadeMaxFraction) : 0
                LinearGradient(stops: Self.fadeStops(fade: fade).map {
                                   Gradient.Stop(color: .black.opacity($0.opacity), location: $0.location)
                               },
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// A stat tile. R3: the row's tiles are equal height (the HStack is fixed vertically and each tile fills it), and the
/// detail line is always reserved, so the numbers line up.
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(HushType.overline(compact))
                .foregroundStyle(HushTheme.mist)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(detail == nil)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HushTheme.surface))
        .accessibilityElement(children: .combine)
    }
}

/// R2 (UX P1-13): the run's story at a glance, one small chest per chest opened: its tier, the gold it banked, a "zzz"
/// if Hushed, teeth if it bit, a gold glow if it was a golden mimic. R3: at most two rows, then "+N more".
struct ChestStrip: View {
    let log: [ChestOutcome]
    let compact: Bool
    /// The column the strip sits in (its padding included).
    var width: CGFloat = 360

    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
    static let maxRows = 2

    static func side(compact: Bool) -> CGFloat { compact ? 40 : 46 }

    /// Chips per row in a strip `width` wide. Pure; tested.
    static func perRow(width: CGFloat, side: CGFloat) -> Int {
        let inner = width - 2 * padding
        return max(Int(((inner + spacing) / (side + 6 + spacing)).rounded(.down)), 3)
    }

    /// How many chips show, and the "+N more" count: all of them in up to two rows, else two rows with the last slot
    /// saying "+N more". Pure; tested.
    static func visible(count: Int, perRow: Int) -> (shown: Int, more: Int) {
        let cap = max(perRow, 1) * maxRows
        guard count > cap else { return (count, 0) }
        return (cap - 1, count - (cap - 1))
    }

    /// The one-line legend, only for what's on the strip. Pure; tested.
    static func legend(_ log: [ChestOutcome]) -> String? {
        var parts: [String] = []
        if log.contains(where: \.hushed) { parts.append("💤 = banked while it slept") }
        if log.contains(where: \.bitten) { parts.append("teeth = it bit") }
        if log.contains(where: \.golden) { parts.append("glow = golden mimic") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        let side = Self.side(compact: compact)
        let per = Self.perRow(width: width, side: side)
        let vis = Self.visible(count: log.count, perRow: per)
        let columns = Array(repeating: GridItem(.fixed(side + 6), spacing: Self.spacing), count: per)
        VStack(spacing: 6) {
            // R4 (UX P2-5): the legend is INSIDE the strip's card, above the chips, so a phone sees it unscrolled.
            if let legend = Self.legend(log) {
                Text(legend)
                    .font(.system(size: HushType.scaled(13, .footnote), weight: .medium, design: .rounded))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            chips(vis: vis, columns: columns, side: side)
        }
        .padding(Self.padding)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HushTheme.surface.opacity(0.8)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(log))
    }

    private func chips(vis: (shown: Int, more: Int), columns: [GridItem], side: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(0..<vis.shown, id: \.self) { i in
                ChestChip(outcome: log[i], side: side, compact: compact, isLast: i == log.count - 1)
            }
            if vis.more > 0 {
                Text("+\(vis.more) more")
                    .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HushTheme.goldLight)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(width: side + 6, height: side)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HushTheme.surfaceRaised))
            }
        }
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
    /// The run's last chest: an empty one there is where the candle went out ("out", never a mystery "0").
    var isLast = false

    /// The tier's wood and metal (the in-game chest colours).
    static func colors(_ tier: ChestTier) -> (body: Color, band: Color) {
        switch tier {
        case .wooden: return (Color(hush: ChestArt.palette.wood), Color(hush: ChestArt.palette.woodDark))
        case .iron: return (Color(hush: ChestArt.palette.wood), Color(hush: ChestArt.palette.iron))
        case .gilded: return (Color(hushHex: 0x7A4A2A), HushTheme.gold)
        case .royal: return (Color(hush: ChestArt.palette.velvet), HushTheme.goldLight)
        }
    }

    /// The chip's caption. Pure; tested.
    static func caption(_ o: ChestOutcome, isLast: Bool) -> String {
        if o.value > 0 { return "+\(o.value.formatted())" }
        if o.bitten { return "bit" }
        return isLast ? "out" : "0"
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
                    Text("💤")
                        .font(.system(size: side * 0.26))
                        .offset(x: side * 0.24, y: -side * 0.3)
                }
            }
            .frame(width: side, height: side * 0.8)
            Text(Self.caption(outcome, isLast: isLast))
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
