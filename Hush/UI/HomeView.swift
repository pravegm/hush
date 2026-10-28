import SpriteKit
import SwiftUI

/// Home. The lid half: the wordmark and the mimic itself (R2: the Scene's `MimicPortraitScene`, the in-game chest),
/// whose lid follows the hinge (or a drag on phones), peeking, then glaring if you're loud. The floor half (the sharp,
/// reachable one on a Duo): the thief rank (always a visible bar and "Next: …"), the best haul, Play, the Daily
/// Dungeon, the Codex and the Badges (labels that never truncate), Settings and Game Center.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The menu column's width on `info`. Pure; tested.
    static func menuWidth(_ info: AppCanvas) -> CGFloat { min(info.floorHalf.width - 32, 520) }

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
            VStack(spacing: c ? 4 : 10) {
                HushWordmark(size: c ? 52 : (lid.height > 380 ? 78 : 64))
                HomePortrait(controller: controller, interactive: !controller.hasHinge)
                    .frame(width: min(lid.width * 0.78, 420), height: max(min(lid.height * 0.56, 300), 80))
                // R3 (decision 4): the layout's words (a fold: the lid; no fold: the drag on the chest).
                HomeCaption(lid: controller.homeLid, hinge: info.hasFold, compact: c)
            }
            .frame(width: lid.width, height: lid.height)
            .position(x: lid.midX, y: lid.midY)

            if info.hasFold {
                // R5 (UX P1-1, juror P1-1, frame 30): a short fold floor gets compact metrics, so the plain menu fits
                // at the default size (tested); only the accessibility sizes (or a last resort) scroll, with the fade.
                let menu = HomeMenu(controller: controller, store: store, compact: c, tight: info.tightFloor)
                Group {
                    if typeSize.isAccessibilitySize {
                        FadingScroll { menu }
                    } else {
                        ViewThatFits(in: .vertical) {
                            menu
                            FadingScroll { menu }
                        }
                    }
                }
                    .frame(width: HomeView.menuWidth(info))
                    .frame(height: floor.height, alignment: .center)
                    .position(x: floor.midX, y: floor.midY)
            } else {
                // R3 (UX P2-12): no dead band on a phone: the haul card sits at the top of the floor half, the menu
                // at the bottom (on a short screen the card folds back into the menu's rank row).
                ViewThatFits(in: .vertical) {
                    VStack(spacing: 12) {
                        HomeHaulCard(store: store, compact: c)
                        Spacer(minLength: 8)
                        HomeMenu(controller: controller, store: store, compact: c, showsRank: false)
                    }
                    VStack {
                        Spacer(minLength: 0)
                        HomeMenu(controller: controller, store: store, compact: c)
                    }
                    // R4 (founder): at the accessibility cap the menu scrolls rather than clip (R5: with the fade).
                    FadingScroll {
                        HomeMenu(controller: controller, store: store, compact: c)
                    }
                }
                .frame(width: HomeView.menuWidth(info))
                .frame(height: floor.height)
                .position(x: floor.midX, y: floor.midY)
            }

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
        // R12 (founder): "Lift the lid… slowly" only while the lid is closed (the shut zone); open, it's peeking.
        if AppRules.lidReadsOpen(lid.openness) { return "Shh… something's peeking." }
        // R4 (tester 8): the phone's words are the lever's ("slide"), the same verb the run and the lesson use.
        // R11 (tester 11, the third round running: "Slide its lid up" vs the game's "Slide the lever up"): the lever's
        // own words, exactly the lesson's and the run's line (`phoneCaption`; a drag up on the chest still lifts it).
        return hinge ? "Lift the lid… slowly." : Self.phoneCaption
    }

    /// R11: the phone Home caption, word for word the lesson's step-1 line and the run's `openSlowly` hint. Tested.
    static let phoneCaption = "Slide the lever up… slowly."
}

/// R3 (UX P2-12, brief "Home has no dead space"): the phone's floor half opens with the thief's standing: the best
/// haul as a big number, the rank and the bar to the next.
struct HomeHaulCard: View {
    @ObservedObject var store: ProgressStore
    let compact: Bool

    var body: some View {
        let data = store.data
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HushOverline(text: data.bestRun > 0 ? "Best haul" : "Your first chest awaits", compact: compact,
                                 color: HushTheme.gold)
                    HStack(spacing: 8) {
                        CoinGlyph(size: compact ? 24 : 30)
                        Text(data.bestRun > 0 ? data.bestRun.formatted() : "No haul yet")
                            .font(data.bestRun > 0 ? HushType.number(compact ? 30 : 38) : HushType.headline(compact))
                            .foregroundStyle(data.bestRun > 0 ? HushTheme.goldLight : HushTheme.mist)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ThiefRanks.title(store.rank))
                        .font(HushType.headline(compact))
                        .foregroundStyle(HushTheme.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Rank \(store.rank + 1)")
                        .font(HushType.caption(compact))
                        .foregroundStyle(HushTheme.mist)
                }
            }
            HushProgressBar(value: ProgressRules.rankProgress(lifetime: data.lifetimeGold, rank: store.rank), height: 8)
            if let next = RankRow.nextLine(rank: store.rank) {
                Text(next)
                    .font(HushType.caption(compact))
                    .foregroundStyle(HushTheme.mist)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .hushCard(padding: 14, radius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(store.rank + 1), \(ThiefRanks.title(store.rank)). "
                            + (data.bestRun > 0 ? "Best haul \(data.bestRun) gold." : "No haul yet."))
    }
}

/// The caption under the mimic: its own view, observing only the lid (QA-1 P2-14).
struct HomeCaption: View {
    @ObservedObject var lid: HomeLidState
    let hinge: Bool
    let compact: Bool

    var body: some View {
        let text = HomeView.caption(lid.lid, hinge: hinge)
        Text(text)
            .font(HushType.body(compact))
            .foregroundStyle(color(lid.lid))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.2), value: text)
    }

    private func color(_ lid: HomeLid) -> Color {
        if lid.speed > Tuning.loudSpeed { return HushTheme.amber }
        return AppRules.lidReadsOpen(lid.openness) ? HushTheme.goldLight : HushTheme.mist
    }
}

/// The live mimic on Home. On an iPhone without a hinge, dragging up on it lifts its lid (the home slider).
struct HomePortrait: View {
    @ObservedObject var controller: GameController
    let interactive: Bool
    @State private var dragStart: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MimicPortraitView(scene: controller.portraits.home, paused: controller.route != .home,
                                  fps: min(controller.preferredFPS, 60))
                    .frame(width: geo.size.width, height: geo.size.height)
                if interactive {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(drag(height: geo.size.height))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A treasure chest. Something inside is asleep.")
    }

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? controller.homeLid.lid.openness
                if dragStart == nil {
                    dragStart = start
                    controller.homeChestDrag(began: true, ended: false, fraction: start)
                }
                let f = start + Double(-value.translation.height / max(height * 0.8, 1))
                controller.homeChestDrag(began: false, ended: false, fraction: f)
            }
            .onEnded { value in
                let start = dragStart ?? controller.homeLid.lid.openness
                let f = start + Double(-value.translation.height / max(height * 0.8, 1))
                controller.homeChestDrag(began: false, ended: true, fraction: f)
                dragStart = nil
            }
    }
}

/// The floor half's menu.
struct HomeMenu: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let compact: Bool
    var showsRank = true
    /// R5 (UX P1-1): a short fold floor's compact metrics (`AppCanvas.tightFloor`): closer rows and a 60 pt Play.
    var tight = false
    /// R5 (QA-4 P1-A, frame 44): at the accessibility sizes the Daily status goes under its title and the paired
    /// buttons stack one per row, so no label is truncated or broken mid-word.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The row spacing and Play's height. Pure; tested.
    static func spacing(compact: Bool, tight: Bool) -> CGFloat { tight ? 8 : (compact ? 10 : 14) }
    static func playHeight(compact: Bool, tight: Bool) -> CGFloat { compact || tight ? 60 : 70 }

    /// "Codex 9/24" / "Badges 7/12": the same numbers the Codex and Badges pages show (one preset, one source). Pure;
    /// tested.
    static func codexLine(_ data: ProgressData) -> String { "Codex \(data.foundRelics.count)/\(RelicCatalog.all.count)" }
    static func badgesLine(_ data: ProgressData) -> String {
        "Badges \(data.achievements.count)/\(Achievements.all.count)"
    }

    var body: some View {
        let data = store.data
        let rank = store.rank
        let ax = typeSize.isAccessibilitySize
        // R5 (QA-4 P1-A): the pairs side by side, or one per row at the accessibility sizes.
        let pair = ax ? AnyLayout(VStackLayout(spacing: Self.spacing(compact: compact, tight: tight)))
            : AnyLayout(HStackLayout(spacing: 10))
        let status = Text(Self.dailyStatus(scoredReady: controller.dailyScoredAvailable,
                                           todayGold: data.dailyRecord(day: controller.today)?.gold))
            .font(HushType.caption(compact))
            .foregroundStyle(controller.dailyScoredAvailable ? HushTheme.goldLight : HushTheme.mist)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
        VStack(spacing: Self.spacing(compact: compact, tight: tight)) {
            if showsRank {
                RankRow(rank: rank, lifetime: data.lifetimeGold, best: data.bestRun, compact: compact)
            }
            HushButton(kind: .primary, height: Self.playHeight(compact: compact, tight: tight), compact: compact,
                       confirm: true, action: { controller.play() }) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                    Text("Play")
                }
            }
            .accessibilityHint("A run: chests until your candle burns out")
            HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                       action: { controller.show(.daily) }) {
                HStack(spacing: 10) {
                    Image(systemName: "sun.max.fill").foregroundStyle(HushTheme.gold)
                    if ax {
                        // R5 (QA-4 P1-A, frame 44): the status under the title, never squeezed beside it.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Dungeon")
                            status.multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 8)
                        Spacer(minLength: 0)
                    } else {
                        Text("Daily Dungeon")
                            .layoutPriority(1)
                        Spacer(minLength: 6)
                        // R4 (UX P2-7, frame 44): never "Today's try…": it wraps onto a second line (the row grows).
                        status.multilineTextAlignment(.trailing)
                    }
                }
            }
            pair {
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                           action: { controller.show(.codex) }) {
                    CountLabel(icon: "book.closed.fill", word: "Codex", count: data.foundRelics.count,
                               total: RelicCatalog.all.count)
                }
                .accessibilityLabel("Codex, \(data.foundRelics.count) of \(RelicCatalog.all.count) relics found")
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: compact,
                           action: { controller.show(.badges) }) {
                    CountLabel(icon: "rosette", word: "Badges", count: data.achievements.count,
                               total: Achievements.all.count)
                }
                .accessibilityLabel("Badges, \(data.achievements.count) of \(Achievements.all.count) earned")
            }
            // R3 (UX P2-12, testers 4 and 6): every button says what it is (no unlabelled icons).
            pair {
                IconTile(systemName: "gearshape.fill", label: "Settings") { controller.show(.settings) }
                IconTile(systemName: "trophy.fill", label: "Game Center") { controller.showGameCenter() }
            }
        }
    }

    /// The Daily button's status. Pure; tested.
    static func dailyStatus(scoredReady: Bool, todayGold: Int?) -> String {
        if scoredReady { return "Today's try ready" }
        if let gold = todayGold { return "\(gold.formatted()) today" }
        return "Practice"
    }
}

/// "Codex 9/24" (R3: the word always shows; the row now holds only Codex and Badges, so it fits; it shrinks before it
/// ever drops the word).
struct CountLabel: View {
    let icon: String
    let word: String
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text("\(word) \(count)/\(total)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// A labelled button the height of its row (Settings, Game Center): the icon AND its name (R3: testers asked what the
/// "flask" was).
struct IconTile: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HushTheme.gold)
                Text(label)
                    .font(HushType.body(false))
                    .foregroundStyle(HushTheme.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: HushTheme.minTap)
            .background(RoundedRectangle(cornerRadius: HushTheme.buttonRadius, style: .continuous)
                .fill(HushTheme.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: HushTheme.buttonRadius, style: .continuous)
                    .stroke(HushTheme.stroke, lineWidth: 1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(HushPressStyle())
        .accessibilityLabel(label)
    }
}

/// "Cat Burglar · Rank 5", the bar to the next rank (always visible, "Next: Sneak"), and the best haul ("No haul yet").
struct RankRow: View {
    let rank: Int
    let lifetime: Int
    let best: Int
    let compact: Bool

    /// Pure; tested.
    static func bestLine(_ best: Int) -> String { best > 0 ? "Best \(best.formatted())" : "No haul yet" }
    static func nextLine(rank: Int) -> String? {
        rank + 1 < ThiefRanks.count ? "Next: \(ThiefRanks.title(rank + 1))" : nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ThiefRanks.title(rank))
                    .font(HushType.headline(compact))
                    .foregroundStyle(HushTheme.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Rank \(rank + 1)")
                    .font(HushType.caption(compact))
                    .foregroundStyle(HushTheme.mist)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    if best > 0 { CoinGlyph(size: 16) }
                    Text(Self.bestLine(best))
                        .font(HushType.caption(compact).monospacedDigit())
                        .foregroundStyle(best > 0 ? HushTheme.goldLight : HushTheme.mist)
                        .lineLimit(1)
                }
            }
            HushProgressBar(value: ProgressRules.rankProgress(lifetime: lifetime, rank: rank), height: 8)
            if let next = Self.nextLine(rank: rank) {
                Text(next)
                    .font(HushType.caption(compact))
                    .foregroundStyle(HushTheme.mist)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank + 1), \(ThiefRanks.title(rank)). "
                            + (best > 0 ? "Best haul \(best) gold." : "No haul yet."))
        .accessibilityValue("\(Int((ProgressRules.rankProgress(lifetime: lifetime, rank: rank) * 100).rounded())) percent to the next rank")
    }
}
