import SwiftUI
import UIKit

/// A full page (Codex, Badges, Settings, Daily): its title, scrolling content and "Done". R2: on a Duo the title sits
/// on the lid half and the content and Done on the floor half (the sharp, reachable one: Settings' toggles too);
/// elsewhere one column. The subtitle has gutters and wraps; the scroll fades out above Done instead of being cut by it.
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
            if info.hasFold {
                let lid = info.lidHalf
                let floor = info.floorHalf
                header(c)
                    .frame(width: lid.width)
                    .position(x: lid.midX, y: lid.midY)
                column(c)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(width: floor.width, height: floor.height)
                    .position(x: floor.midX, y: floor.midY)
            } else {
                VStack(spacing: 0) {
                    header(c)
                        .padding(.top, max(info.insets.top, 12) + 8)
                        .padding(.bottom, 12)
                    column(c)
                        .padding(.bottom, max(info.insets.bottom, 12) + 8)
                }
                .frame(width: info.size.width, height: info.size.height)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    private func header(_ c: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(HushType.title(c))
                .foregroundStyle(HushTheme.parchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(HushType.body(c))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
    }

    private func column(_ c: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .frame(width: info.columnWidth)
                    .padding(.top, 4)
                    .padding(.bottom, 72)   // R3: the last row scrolls clear of the fade and Done
            }
            .scrollIndicators(.hidden)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9),
                                         .init(color: .black.opacity(0), location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            HushButton(kind: .secondary, height: HushTheme.primaryHeight, compact: c, action: onDone) {
                Text("Done")
            }
            .frame(width: info.columnWidth)
            .padding(.top, 8)
        }
    }
}

/// The Relic Codex: 24 slots on velvet (R2: the in-game relic art, `ChestArt`). Found relics show their name (tap for
/// the blurb); unfound ones a softened silhouette and "???".
struct CodexView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas
    @State private var selected: RelicID?
    @Environment(\.dynamicTypeSize) private var dynamicType

    /// R4 (ROUND-4 App 7): a relic name's lines: 2, and 3 from xxLarge up (then the name is shrunk at most to 0.7 to
    /// fit, so the longest names wrap whole instead of truncating). Pure; tested.
    static func nameLines(_ size: DynamicTypeSize) -> Int { size >= .xxLarge ? 3 : 2 }

    /// Pure; tested.
    static func subtitle(found: Int, total: Int) -> String {
        if found == 0 { return "0 of \(total) found. Relics hide in iron-bound chests and finer." }
        return "\(found) of \(total) found. Tap a relic to read it."
    }

    var body: some View {
        let found = store.data.foundRelics
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: info.columnWidth > 440 ? 4 : 3)
        PageScaffold(title: "Relic Codex",
                     subtitle: Self.subtitle(found: found.count, total: RelicCatalog.all.count),
                     info: info, onDone: { controller.show(.home) }) {
            VStack(spacing: 14) {
                if let id = selected, found.contains(id) {
                    let relic = RelicCatalog.relic(id)
                    HStack(spacing: 14) {
                        RelicArt(relic: relic, found: true)
                            .frame(width: 64, height: 64)
                            .padding(6)
                            .background(VelvetTile(selected: true))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(relic.name)
                                .font(HushType.headline(info.isCompact))
                                .foregroundStyle(HushTheme.goldLight)
                                .fixedSize(horizontal: false, vertical: true)
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
                                ZStack {
                                    RelicArt(relic: relic, found: has)
                                        .frame(width: 54, height: 54)
                                    if !has {
                                        Text("?")
                                            .font(.system(size: 22, weight: .black, design: .rounded))
                                            .foregroundStyle(HushTheme.goldDeep.opacity(0.8))
                                    }
                                }
                                // R4 (UX P2-7, frames 42/46): names wrap, never truncate. A fixed box of
                                // `nameLines` lines keeps the grid aligned; at large sizes the box grows a line.
                                let lines = Self.nameLines(dynamicType)
                                Text(has ? relic.name : "???")
                                    .font(HushType.caption(info.isCompact))
                                    .foregroundStyle(has ? HushTheme.parchment : HushTheme.haze)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(lines)
                                    .minimumScaleFactor(0.7)
                                    .allowsTightening(true)
                                    .frame(height: HushType.scaled(14, .footnote) * (CGFloat(lines) * 1.3 + 0.1),
                                           alignment: .top)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, minHeight: 118)
                            .background(VelvetTile(selected: selected == relic.id))
                            .opacity(has ? 1 : 0.8)
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

/// R2 (ROUND-2 App 8): the 12 badges as a page of their own: earned ones in their metal, the rest dark, each with its
/// name and what earns it.
struct BadgesView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let earned = store.data.achievements
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: info.columnWidth > 440 ? 3 : 2)
        PageScaffold(title: "Badges",
                     subtitle: "\(earned.count) of \(Achievements.all.count) earned. Game Center keeps them too.",
                     info: info, onDone: { controller.show(.home) }) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Achievements.all.enumerated()), id: \.element.id) { item in
                    let has = earned.contains(item.element.id)
                    VStack(spacing: 6) {
                        AchievementBadge(def: item.element, index: item.offset, side: 76, earned: has)
                            .clipShape(Circle())
                        Text(item.element.title)
                            .font(HushType.body(info.isCompact))
                            .foregroundStyle(has ? HushTheme.goldLight : HushTheme.parchment.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.element.detail)
                            .font(HushType.caption(info.isCompact))
                            .foregroundStyle(HushTheme.mist)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
                    // R3 (juror P2): the Codex's velvet tiles here too; a locked badge is a dimmed tile.
                    .background(VelvetTile(selected: has).opacity(has ? 1 : 0.55))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.element.title). \(item.element.detail) "
                                        + (has ? "Earned." : "Not earned yet."))
                }
            }
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
        PageScaffold(title: "Daily Dungeon",
                     subtitle: "\(AppRules.dailyDate(day: today)) · the same chests for every thief today.",
                     info: info, onDone: { controller.show(.home) }) {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: scored ? "sun.max.fill" : "moon.zzz.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HushTheme.gold)
                    if scored {
                        Text("Your scored try is ready")
                            .font(HushType.headline(c))
                            .foregroundStyle(HushTheme.parchment)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("One try counts. Make it a quiet one.")
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
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
                        if record?.finished == false {
                            Text("Left early: the gold you banked counts.")
                                .font(HushType.caption(c))
                                .foregroundStyle(HushTheme.haze)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let p = record?.practiceBest, p > 0 {
                            Text("Practice best \(p.formatted())")
                                .font(HushType.caption(c))
                                .foregroundStyle(HushTheme.mist)
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
                    Text("Practice never reaches the leaderboard. Sneak about freely.")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.data.bestDaily > 0 {
                    Text("Your best Daily: \(store.data.bestDaily.formatted())")
                        .font(HushType.caption(c))
                        .foregroundStyle(HushTheme.mist)
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

/// Settings: Sound, Haptics, Play sound on silent, Turn the chest round (Duo only), Reduce motion, Replay First Chest,
/// About, Credits.
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var settings: SettingsStore
    let info: AppCanvas
    @State private var showsAbout = false
    @State private var showsCredits = false
    @State private var showsDiagnostics = BuildChannel.showsDiagnostics()

    /// Pure; tested (UX P2-15 / brief copy). R3 (tester 6: "what does 'stays sharp' mean?"): plain words.
    static let turnTitle = "Turn the chest round"
    static let turnDetail = "Puts the loot on the half that stays flat, the lid on the half you lift"
    /// R8 (QA-5 P2-2): while a change waits for Settings to close. Pure; tested.
    static func turnDetailLine(pending: Bool) -> String {
        pending ? turnDetail + ". " + AppRules.turnAppliesLater : turnDetail
    }
    static let silentTitle = "Play sound on silent"
    /// The About card's version line (the hidden Diagnostics press is on it).
    static var versionText: String { "Version \(BuildChannel.versionLine)" }
    /// R7: the Vibration and Lid sensitivity rows' options, in order.
    static let vibrationOptions: [(HapticStrength, String)] = HapticStrength.allCases.map { ($0, $0.title) }
    static let sensitivityOptions: [(LidSensitivity, String)] =
        LidSensitivity.allCases.map { ($0, AppRules.sensitivityName($0)) }

    var body: some View {
        let c = info.isCompact
        PageScaffold(title: "Settings", info: info, onDone: { controller.show(.home) }) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    SettingToggle(title: "Sound", detail: nil, isOn: $settings.soundOn, compact: c)
                    divider
                    // R7 (ROUND-7 App 4): Vibration, Off / Normal / Strong (was a Haptics on/off toggle). Unchosen,
                    // it shows what the device plays (Strong on a Duo) and is not stored.
                    let duo = controller.hingeSeen || info.hasFold
                    SettingChoice(title: AppRules.vibrationTitle,
                                  detail: AppRules.vibrationDetail(chosen: settings.vibration != nil, duo: duo),
                                  options: Self.vibrationOptions,
                                  selected: SettingsStore.shownVibration(chosen: settings.vibration,
                                                                         hapticsOn: settings.hapticsOn,
                                                                         hasFold: duo),
                                  compact: c) { settings.chooseVibration($0) }
                    divider
                    // R7 (ROUND-7 App 4, DEVICE-RISKS-1 D3): Lid sensitivity; the row says the scored Daily is Normal.
                    SettingChoice(title: AppRules.sensitivityTitle,
                                  detail: AppRules.sensitivityDetail(settings.lidSensitivity),
                                  options: Self.sensitivityOptions,
                                  selected: settings.lidSensitivity,
                                  compact: c) { settings.lidSensitivity = $0 }
                    divider
                    SettingToggle(title: Self.silentTitle, detail: "The creak plays with the ringer off.",
                                  isOn: Binding(get: { !settings.respectSilentSwitch },
                                                set: { settings.respectSilentSwitch = !$0 }),
                                  compact: c)
                    if controller.hingeSeen || info.hasFold {
                        divider
                        // R8 (QA-5 P2-2): the page never flips under the finger; the change applies as Settings
                        // closes, and the row says so meanwhile.
                        SettingToggle(title: Self.turnTitle,
                                      detail: Self.turnDetailLine(pending: controller.turnRoundPending),
                                      isOn: $settings.turnRound, compact: c)
                    }
                    divider
                    SettingToggle(title: "Reduce motion", detail: "Calmer shakes and sparkles.",
                                  isOn: $settings.reduceMotion, compact: c)
                }
                .hushCard(padding: 6, radius: 22)
                VStack(spacing: 0) {
                    SettingRow(icon: "key.fill", title: "Replay First Chest", compact: c) { controller.replayLesson() }
                    divider
                    SettingRow(icon: "info.circle.fill", title: "About", compact: c, open: showsAbout) {
                        showsAbout.toggle()
                    }
                    if showsAbout {
                        VStack(spacing: 6) {
                            Text("Hush: Don't Wake the Mimic. The game where you have to be gentle. No ads, no "
                                 + "tracking, nothing collected. Ever.")
                                .font(HushType.body(c))
                                .foregroundStyle(HushTheme.mist)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            // R3 (QA-2 P2-15) / R4 (ROUND-4 App 10): a hidden 2 s press on the VERSION LINE toggles
                            // Diagnostics in any build (a click confirms it). A sandbox receipt (TestFlight, and App
                            // Review installs too) never shows test UI by itself.
                            Text(Self.versionText)
                                .font(HushType.caption(c).monospacedDigit())
                                .foregroundStyle(HushTheme.haze)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 2, maximumDistance: 40) {
                                    showsDiagnostics = BuildChannel.toggleDiagnostics()
                                    FeedbackDirector.shared.uiConfirm()
                                }
                            if showsDiagnostics {
                                DiagnosticsPanel(controller: controller, compact: c)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }
                    divider
                    SettingRow(icon: "heart.fill", title: "Credits", compact: c, open: showsCredits) {
                        showsCredits.toggle()
                    }
                    if showsCredits {
                        Text("Made by a tiny studio and one very patient mimic. Every sound is synthesised live, "
                             + "so the creak is really yours.")
                            .font(HushType.body(c))
                            .foregroundStyle(HushTheme.mist)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }
                }
                .hushCard(padding: 6, radius: 22)
            }
            .animation(.easeOut(duration: 0.2), value: showsAbout)
            .animation(.easeOut(duration: 0.2), value: showsCredits)
        }
    }

    private var divider: some View {
        Rectangle().fill(HushTheme.stroke).frame(height: 1).padding(.horizontal, 12)
    }
}

/// R4 (ROUND-4 App 10): the founder's device-test panel. It redraws 4 times a second, so the hinge angle is live; the
/// last hand-off (inner → cover) and relight (cover → inner) angles are kept across launches.
struct DiagnosticsPanel: View {
    @ObservedObject var controller: GameController
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            diagnostics
            // R7 (ROUND-7 App 5): Copy log carries the raw hinge trace too.
            EventLogPanel(log: controller.events, compact: compact,
                          copyText: { controller.diagnosticsCopyText })
        }
    }

    private var diagnostics: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            VStack(alignment: .leading, spacing: 3) {
                Text("DIAGNOSTICS")
                    .font(HushType.overline(compact))
                    .kerning(1.2)
                    .foregroundStyle(HushTheme.gold)
                ForEach(controller.diagnosticsLines, id: \.self) { line in
                    Text(line)
                        .font(HushType.caption(compact).monospacedDigit())
                        .foregroundStyle(HushTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HushTheme.night.opacity(0.6)))
            .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

/// R6 (ROUND-6 App 8): the last 80 events (pose changes and why, pauses, resumes, the watchdog, canvas and
/// orientation changes, hinge nil, scene phase), newest first, monospaced and scrollable, with a Copy button so the
/// founder can paste it to Claude. Stored on this device only.
struct EventLogPanel: View {
    @ObservedObject var log: EventLog
    let compact: Bool
    /// R7 (ROUND-7 App 5): what Copy puts on the pasteboard (the event log, then the raw hinge trace,
    /// `GameController.diagnosticsCopyText`). Nil: the event log alone.
    var copyText: (@MainActor () -> String)? = nil
    @State private var copied = false

    static let copyLabel = "Copy log"
    static let height: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EVENT LOG · \(log.ring.entries.count)")
                    .font(HushType.overline(compact))
                    .kerning(1.2)
                    .foregroundStyle(HushTheme.gold)
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = copyText?() ?? log.text
                    FeedbackDirector.shared.uiConfirm()
                    copied = true
                } label: {
                    Text(copied ? "Copied" : Self.copyLabel)
                        .font(HushType.caption(compact).weight(.bold))
                        .foregroundStyle(HushTheme.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: HushTheme.minTap)
                        .background(Capsule().fill(HushTheme.gold))
                        .contentShape(Capsule())
                }
                .buttonStyle(HushPressStyle())
                .accessibilityIdentifier("diag.copy")
                .accessibilityHint("Copies the event log and the hinge trace, to paste into a message")
            }
            ScrollView(showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(HushTheme.mist)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if log.ring.entries.isEmpty {
                        Text("Nothing yet.")
                            .font(HushType.caption(compact))
                            .foregroundStyle(HushTheme.haze)
                    }
                }
                .padding(8)
            }
            .frame(height: Self.height)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HushTheme.night.opacity(0.6)))
            .textSelection(.enabled)
        }
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
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(HushType.caption(compact))
                        .foregroundStyle(HushTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(HushTheme.gold)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: HushTheme.minTap)
    }
}

/// R7 (ROUND-7 App 4): a Settings row with a few named choices (Vibration, Lid sensitivity): the title and a detail
/// line, then one pill per option (the chosen one gold). Each pill is a full-height tap target and says to VoiceOver
/// which it is and whether it is chosen.
struct SettingChoice<Value: Hashable>: View {
    let title: String
    let detail: String?
    let options: [(Value, String)]
    let selected: Value
    let compact: Bool
    let onPick: (Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HushType.body(compact))
                    .foregroundStyle(HushTheme.parchment)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(HushType.caption(compact))
                        .foregroundStyle(HushTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 6) {
                ForEach(options.indices, id: \.self) { i in
                    pill(options[i].0, name: options[i].1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(_ value: Value, name: String) -> some View {
        let on = value == selected
        return Button {
            FeedbackDirector.shared.uiTap()
            onPick(value)
        } label: {
            Text(name)
                .font(HushType.caption(compact).weight(.bold))
                .foregroundStyle(on ? HushTheme.ink : HushTheme.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: HushTheme.minTap)
                .background(Capsule().fill(on ? HushTheme.gold : HushTheme.night.opacity(0.6)))
                .overlay(Capsule().stroke(on ? Color.clear : HushTheme.stroke, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(HushPressStyle())
        .accessibilityLabel("\(title): \(name)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A list row in a Settings card (R2, juror: lighter than full-width buttons).
struct SettingRow: View {
    let icon: String
    let title: String
    let compact: Bool
    var open: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HushTheme.gold)
                    .frame(width: 26)
                Text(title)
                    .font(HushType.body(compact))
                    .foregroundStyle(HushTheme.parchment)
                Spacer(minLength: 8)
                Image(systemName: open == nil ? "chevron.right" : (open == true ? "chevron.up" : "chevron.down"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HushTheme.mist)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: HushTheme.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(HushPressStyle())
    }
}
