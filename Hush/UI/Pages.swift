import SwiftUI

/// A full page (Codex, Settings, Daily): its title at the top, scrolling content, and its "Done" button at the bottom,
/// on the floor half (the reachable end on a Duo in tabletop pose).
struct PageScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    let info: AppCanvas
    let onDone: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        let c = info.isCompact
        ZStack {
            HushTheme.backdrop
                .contentShape(Rectangle())
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(title)
                        .font(HushType.title(c))
                        .foregroundStyle(HushTheme.parchment)
                    if let subtitle {
                        Text(subtitle)
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, max(info.insets.top, 12) + 8)
                .padding(.bottom, 12)
                ScrollView {
                    content()
                        .frame(width: info.columnWidth)
                        .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                HushButton(kind: .secondary, height: HushTheme.primaryHeight, compact: c, action: onDone) {
                    Text("Done")
                }
                .frame(width: info.columnWidth)
                .padding(.top, 8)
                .padding(.bottom, max(info.insets.bottom, 12) + 8)
            }
            .frame(width: info.size.width, height: info.size.height)
        }
        .frame(width: info.size.width, height: info.size.height)
    }
}

/// The Relic Codex: 24 slots. Found relics are drawn with their name (tap for the blurb); unfound ones are dark
/// silhouettes, "???".
struct CodexView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas
    @State private var selected: RelicID?

    var body: some View {
        let found = store.data.foundRelics
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: info.size.width > 560 ? 4 : 3)
        PageScaffold(title: "Relic Codex",
                     subtitle: "\(found.count) of \(RelicCatalog.all.count) found. Iron-bound chests and up hide them.",
                     info: info, onDone: { controller.show(.home) }) {
            VStack(spacing: 14) {
                if let id = selected, found.contains(id) {
                    let relic = RelicCatalog.relic(id)
                    HStack(spacing: 14) {
                        RelicArt(relic: relic, found: true)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(relic.name)
                                .font(HushType.headline(info.isCompact))
                                .foregroundStyle(HushTheme.goldLight)
                            Text(relic.blurb)
                                .font(HushType.body(info.isCompact))
                                .foregroundStyle(HushTheme.parchment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .hushCard(padding: 14, radius: 20)
                    .transition(.opacity)
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(RelicCatalog.all) { relic in
                        let has = found.contains(relic.id)
                        Button {
                            FeedbackDirector.shared.uiTap()
                            selected = has ? relic.id : nil
                        } label: {
                            VStack(spacing: 6) {
                                RelicArt(relic: relic, found: has)
                                    .frame(width: 52, height: 52)
                                Text(has ? relic.name : "???")
                                    .font(HushType.caption(info.isCompact))
                                    .foregroundStyle(has ? HushTheme.parchment : HushTheme.haze)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .frame(height: 34)
                            }
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selected == relic.id ? HushTheme.surfaceRaised : HushTheme.surface))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HushPressStyle())
                        .accessibilityLabel(has ? "\(relic.name). \(relic.blurb)" : "Not found yet")
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: selected)
        }
    }
}

/// The Daily Dungeon: the same dungeon for everyone today; one scored try, then practice.
struct DailyView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let today = controller.today
        let record = store.data.dailyRecord(day: today)
        let scored = controller.dailyScoredAvailable
        let c = info.isCompact
        PageScaffold(title: "Daily Dungeon #\(today)",
                     subtitle: "Same chests for every thief today.", info: info,
                     onDone: { controller.show(.home) }) {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: scored ? "sun.max.fill" : "moon.zzz.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HushTheme.gold)
                    if scored {
                        Text("Your scored try is ready")
                            .font(HushType.headline(c))
                            .foregroundStyle(HushTheme.parchment)
                        Text("One try counts. Make it a quiet one.")
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                    } else {
                        Text("Today's haul")
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                        HStack(spacing: 8) {
                            CoinGlyph(size: 30)
                            Text((record?.gold ?? 0).formatted())
                                .font(HushType.number(44))
                                .foregroundStyle(HushTheme.goldLight)
                        }
                        if let p = record?.practiceBest, p > 0 {
                            Text("Practice best \(p.formatted())")
                                .font(HushType.caption(c))
                                .foregroundStyle(HushTheme.haze)
                        }
                        Text("A new dungeon in \(Self.untilTomorrow())")
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                    }
                }
                .frame(maxWidth: .infinity)
                .hushCard()
                if scored {
                    HushButton(kind: .primary, compact: c, confirm: true, action: { controller.playDaily() }) {
                        Label("Enter the dungeon", systemImage: "key.fill")
                    }
                } else {
                    HushButton(kind: .primary, compact: c, action: { controller.practiseDaily() }) {
                        Label("Practise it", systemImage: "arrow.counterclockwise")
                    }
                    Text("Practice never counts. Sneak about freely.")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.haze)
                }
                if store.data.bestDaily > 0 {
                    Text("Your best Daily: \(store.data.bestDaily.formatted())")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.haze)
                }
            }
        }
    }

    /// "5h 12m" until the next Daily (00:00 UTC, DailyClock).
    static func untilTomorrow(now: Date = Date()) -> String {
        guard let next = DailyClock.nextReset(after: now) else { return "a while" }
        let s = max(Int(next.timeIntervalSince(now)), 0)
        let h = s / 3600
        let m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

/// Settings: Sound, Haptics, Respect silent switch, Turn the chest round (Duo only), Reduce motion, Replay First
/// Chest, About, Credits.
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var settings: SettingsStore
    let info: AppCanvas
    @State private var showsAbout = false
    @State private var showsCredits = false

    var body: some View {
        let c = info.isCompact
        PageScaffold(title: "Settings", info: info, onDone: { controller.show(.home) }) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    SettingToggle(title: "Sound", detail: nil, isOn: $settings.soundOn, compact: c)
                    divider
                    SettingToggle(title: "Haptics", detail: "Feel every creak.", isOn: $settings.hapticsOn,
                                  compact: c)
                    divider
                    SettingToggle(title: "Respect silent switch", detail: "Off: you'll hear the creak on silent.",
                                  isOn: $settings.respectSilentSwitch, compact: c)
                    if controller.hingeSeen || info.hasFold {
                        divider
                        SettingToggle(title: "Turn the chest round",
                                      detail: "Lifts the half that blurs as you fold, so the loot stays sharp.",
                                      isOn: $settings.turnRound, compact: c)
                    }
                    divider
                    SettingToggle(title: "Reduce motion", detail: "Calmer shakes and sparkles.",
                                  isOn: $settings.reduceMotion, compact: c)
                }
                .hushCard(padding: 6, radius: 22)
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: c,
                           action: { controller.replayLesson() }) {
                    Label("Replay First Chest", systemImage: "graduationcap.fill")
                }
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: c,
                           action: { showsAbout.toggle() }) {
                    Label("About", systemImage: "info.circle.fill")
                }
                if showsAbout {
                    Text("Hush: Don't Wake the Mimic \(BuildChannel.versionLine). The game where you have to be gentle. "
                         + "No ads, no tracking, nothing collected. Ever.")
                        .font(HushType.body(c))
                        .foregroundStyle(HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                    if BuildChannel.isTestBuild {
                        Text("Test build · lid: \(controller.hasHinge ? "hinge" : "slider")")
                            .font(HushType.caption(c))
                            .foregroundStyle(HushTheme.haze)
                    }
                }
                HushButton(kind: .secondary, height: HushTheme.secondaryHeight, compact: c,
                           action: { showsCredits.toggle() }) {
                    Label("Credits", systemImage: "heart.fill")
                }
                if showsCredits {
                    Text("Made by a tiny studio and one very patient mimic. Every sound is synthesised live, "
                         + "so the creak is really yours.")
                        .font(HushType.body(c))
                        .foregroundStyle(HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
            }
            .animation(.easeOut(duration: 0.2), value: showsAbout)
            .animation(.easeOut(duration: 0.2), value: showsCredits)
        }
    }

    private var divider: some View {
        Rectangle().fill(HushTheme.stroke).frame(height: 1).padding(.horizontal, 12)
    }
}

struct SettingToggle: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool
    let compact: Bool

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { v in
            FeedbackDirector.shared.uiTap()
            isOn = v
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HushType.body(compact))
                    .foregroundStyle(HushTheme.parchment)
                if let detail {
                    Text(detail)
                        .font(HushType.caption(compact))
                        .foregroundStyle(HushTheme.haze)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(HushTheme.gold)
        .padding(.horizontal, 14)
        .frame(minHeight: HushTheme.minTap)
    }
}
