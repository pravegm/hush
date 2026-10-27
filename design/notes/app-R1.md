# App engineer, Round 1 hand-off (27 Oct)

Uncompiled. CI is the first compiler. Files:
- `Hush/App/`: HushApp, GameController, AppModels, AppRules (+ DailyClock, HintGate), LessonScript (+ LessonChest),
  DemoMode (+ DemoPresets, IconExport, DemoOrientation, BadgeExport), DemoRunner, AppTrace, GameCenterManager,
  OrientationLock (+ HushAppDelegate), BuildChannel.
- `Hush/UI/`: RootView, HomeView (+ TitleChest), PlayHUD (HintLine, PauseMenu, ClosingCard, LessonOverlay), PoseCards
  (DuoDiagram, StandUpCard, CoverCard), ResultsView, Pages (Codex, Daily, Settings), HushTheme, Layout, AppIconArt,
  AchievementArt.
- `Hush/Persistence/`: ProgressStore (ProgressData v1, ProgressRules), SettingsStore (SettingsData v1).
- `HushTests/AppTests.swift` (Swift Testing).
- `Hush/Assets.xcassets/AppIcon.appiconset/`: Contents.json (one 1024 universal slot) and a placeholder
  `AppIcon-1024.png` (teal + gold, RGB, no alpha).

## Flow
- **First launch:** the First Chest lesson (`HeistSession(mode: .lesson)`, `LessonChest.options`: a fixed chest of
  2 copper, 1 silver and 1 ruby, a Heavy sleeper, no torch, no bites, 0.6× noise). Then the first Run.
- **Later launches:** Home.
- **Home:**
  - Lid half: the "Hush" wordmark and a live title chest. Its lid follows the hinge, or a drag on phones. The eye
    peeks out past openness 0.12 and glares when the lid is loud. A caption teaches the idea ("Lift the lid…
    slowly." → "Shh… something's peeking." → "Easy! It's a mimic…").
  - Floor half: the rank row (title, bar, best), Play, Daily Dungeon (with its status), Codex n/24, Settings and Game
    Center.
- **Play:** the scene plus `PlayLayer`.
  - The hint line in `ChestLayout.hintBand`.
  - Pause in `ChestLayout.pauseArea`, opening the pause menu (Resume, Restart, Home) on the floor half.
  - The closing card ("Lift the lid a little to carry on").
- **Results:**
  - Lid half: the title, a counting gold number, "New best!" and one story sentence.
  - Floor half: Chests banked, Hushed, Bites, the relic strip, the rank bar (animated) and achievements.
  - Buttons: Again (a Daily becomes "Practise this dungeon") and Home.
- **Codex:** a 24-slot grid of `ChestArt.relicPath` art (flipped to y-down). Unfound slots show a silhouette and
  "???"; tap a found one for its blurb.
- **Daily:** the scored try ("Enter the dungeon"), or today's haul, the practice best and "A new dungeon in 5h 12m".
- **Settings:** Sound, Haptics, Respect silent switch, Turn the chest round (Duo / fold only), Reduce motion, Replay
  First Chest, About, Credits.
- **Pose cards:**
  - `standUp` (landscape on a Duo): a top-view diagram whose gold half is "Lift this half" (`AppRules.liftSide`).
  - `cover` (the cover display, long side < 760): the sleeping mimic and "Open to carry on" / "Open me… gently".
- **Copy:** every hint is ≤ 6 words (tested). Hit targets are ≥ 56 pt.

## Rules worth knowing
- **Turned round:**
  - `AppRules.turnsRound = wanted && pose == .play && portrait && hasFold`.
  - RootView rotates the whole portrait content (scene + SwiftUI) by 180°. Insets are swapped with it.
  - Deferred gesture edges are `[.top, .bottom]` while a chest is live and not paused.
  - `wanted` = demo `turn=` ?? the setting (default on).
  - `hasFold` = demo `fold=1`, a hinge seen (inner display), or a Duo-shaped portrait screen.
- **Pauses:**
  - closing: the hinge only, `isClosing` or my own θ < 85° for 0.4 s, or shut; it resumes once back at ≥ 88°;
  - the app inactive, which also opens the menu on a real live run;
  - the menu;
  - pose ≠ play.
  - No stepping while paused. Feedback gets `playing: false` telemetry.
- **Input:**
  - demo `pilot=` → pilot (its touches go into the session as real touches);
  - demo `lid=` → fixed;
  - a hinge sample → hinge (it upgrades a slider run mid-run);
  - otherwise the slider.
  - A fresh `SliderLidSource` is made per run.
- **Daily (founder):**
  - The day turns at **00:00 UTC** (`DailyClock.today()`, a Gregorian calendar in UTC) for the seed, the
    one-scored-try rule, Game Center staleness and the "new dungeon in" countdown.
  - The scored try is used up when it STARTS. Leaving early files the gold so far (`recordPartialDaily`, plus the
    Daily board).
  - Restarting a scored Daily restarts it as practice.
  - A clock set back gets no second try.
- **Game Center:**
  - `hush.best` takes runs and scored Dailies; `hush.daily` takes scored Dailies.
  - Achievements are `Achievements.all` ids (`hush.ach.<key>`, prefixed only if Core ever drops it).
  - The queue persists. Everything is silent when signed out and disabled in demo runs.
- **Hints:**
  - `HintGate`: 0.15 s to settle, 0.7 s minimum; "Freeze!" and "Slower…" show at once.
  - The teaching hints (openSlowly, dragToBag, shutToBank) retire after 5 runs.
  - A run-start banner shows for 2.6 s.

## Demo keys (`-hushDemo "k=v;…"`; all of ROUND-1 plus the extras below)
- **ROUND-1 keys:** `screen=home|run|results|codex|settings|lesson|pose|cover|icon|daily|badges`,
  `mode=run|daily|attract`, `seed=`, `pilot=`, `progress=fresh|mid|late`,
  `freezeOn=ready|reveal|stirring|waking|bite|bank|relic|torchLow|torchOut|results` (case-insensitive), `freezeAfter=`,
  `lid=`, `noise=`, `lessonStep=1…6`, `turn=0|1`, `fold=1` and `sound=0`.
- **Extras:**
  - `skipTo=<s>`: plays s seconds headless (pilot, default expert) before going live.
  - `orient=portrait|landscape`: Brim's DemoOrientation. It re-asks every 2 s and logs `HUSH-T orient <o>
    requested|ok|lost|failed after 30s`.
  - `screen=badges`: renders the 12 badges to `Documents/badges/hush.ach.<key>.png` and logs `HUSH-T badges done <n>`.
- **Behaviour:**
  - `screen=results` plays a real run headless (pilot, default casual) and records it into the in-memory progress.
  - Event freezes (bite, bank, relic, torchLow, torchOut) hold 0.3 s after the event.
  - `freezeAfter` alone prints `HUSH-T freeze after`.
  - Demo runs use in-memory stores only and never write UserDefaults (not even `hush.hasHinge`).
- **Release guard:**
  - DemoMode parsing is `#if DEBUG`, and `current` is nil in Release.
  - The stored field is `holdAfter`, so the Release binary carries no `freezeAfter` string (not even in Swift's field
    metadata).
  - `HUSH-T paused closing` is its own literal inside `#if DEBUG` (GameController.checkClosing), as the TestFlight
    guard needs.

## Log lines
- `HUSH-T demo '<raw>' starts`.
- `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1>`:
  - printed on every layout change (canvas, fold or turned), from `GameController.updateCanvas`;
  - `<w>x<h>` is the root view's size in points, before rotation.
- `HUSH-T input hinge|slider|pilot|fixed`, at every run start and on every change.
- `HUSH-T lid <o 2dp> speed <1dp> angle <1dp|-> noise <2dp> stage <name>`, at 10 Hz while stepping.
- `HUSH-T event <caseName> k=v…`, for every HeistEvent, including touch events.
- `HUSH-T paused closing|menu|background|pose`, then `HUSH-T resumed` once all pauses clear (play routes only).
- `HUSH-T freeze <tag>`.
- `HUSH-T frame 120`: printed by the App's `advance()` (Scene doesn't print it).
- `HUSH-T screen <route>`.
- `HUSH-T run gold= chests= bites= seconds=`.
- `HUSH-T skipped <s>`.

## Icon for CI
- **Triggers:** `-hushDemo "screen=icon"`, or `HUSH_ICON=1` in the environment (`SIMCTL_CHILD_HUSH_ICON=1`), which
  also turns on AppTrace and forces `screen=icon`.
- **Output:**
  - `IconExport.render()` (on the icon layer's appear) writes `Documents/AppIcon-1024.png`: 1024×1024, opaque, no
    alpha.
  - It also writes `AppIcon-180/60/40.png`.
  - It logs `HUSH-T icon ok 1024x1024`, then `HUSH-ICON <absolute path>`, then `HUSH-T icon sizes 180,60,40`.
- **Next step:** CI should copy the 1024 PNG over `Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. The
  committed file is a placeholder.

## Risks / for the next round
- **Turned touches:** the rotated SpriteView relies on UIKit mapping touches through SwiftUI's `rotationEffect`
  (NEEDS.md). Check a turned drag on the first Duo run.
- **Lesson items:** the lesson chest's item positions are hand-placed (floor y 85–150, behind the card band). They
  assume Core honours `fixedChest` positions as given.
- **Not done:**
  - the hinge-readout overlay;
  - share text;
  - VoiceOver lid control;
  - thermal/Low Power frame rates;
  - a "play with the slider" option on a Duo.
