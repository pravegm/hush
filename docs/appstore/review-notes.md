# Hush: App Review notes (v1.0)

*Rewritten Wed 28 Oct 2026 (after QA-6 P1-1) from the code of build 1.0 (4) (rounds 6 to 10, c6e046c): `Hush/Core/Tuning.swift`, `Hush/Input/HingeLidSource.swift` (`canResume`, the speed range), `Hush/App/AppRules*.swift` (Carry on, the watchdog, the cover escape, the pause hold), `Hush/UI/PlayHUD.swift`, `PoseCards.swift` and `Pages.swift`, and `Hush/Persistence/EventLog.swift`. The R3 notes described a game that no longer exists (a blocking book card, "Play anyway", resume at 95 degrees, speed to 168). The block between the markers is what you paste (or what the App Store Connect tool pushes). Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, ellipses or symbols), so bytes = characters; **3,963 bytes** (`node tools/appstore/build-metadata.js` prints it as `notesBytes`). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (the tool copies Squish's; typed by hand only into App Store Connect, never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s phone video of one chest on the Duo in tabletop pose: the lid opened slowly, a coin dragged to the bag, the lid eased down to bank. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Hush: a paid game. No ads, IAP, accounts, data collection or network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
The full game works on any iPhone and in the Simulator, in portrait.
- The top half is the chest lid, the bottom half the floor with the loot.
- First launch opens First Chest, a short lesson (no score); Skip appears after step 2 or 20 s. Settings > Replay First Chest replays it.
- Drag the LEVER on the top half up slowly to open the lid.
- Drag a lit coin or gem into the bag (IN BAG). Bagged loot is not safe yet.
- Slide the lever back down and hold a moment: the bag is banked (BANKED) and the next chest arrives.
- The NOISE meter fills if you move or drag fast and drains when you keep still; "Freeze!" means hold still. If it fills, the mimic bites: the bag is lost and the candle loses 10 s.
- The run ends when the candle burns out (100 s, +6 s per oil flask bagged). Tap the pause coin to pause.
- Every achievement can be earned with the lever.

2. THE HINGE (iPhone Duo)
Hush reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. The angle never leaves the phone; a diagnostics log (last 80 events, with the angle) is kept on the device, never sent. On a Duo the hinge is the lid; no lever.
a) Stand the Duo like a small laptop: the raised half is the lid. The game draws the right way up in any orientation (portrait or landscape, even after opening it flat); nothing blocks play. Held like a book, a small closable tip suggests standing it up.
b) Shut is about 100 degrees, wide open about 165. Ease the lid down to 110 or less and hold a moment to bank.
c) The skill is moving the hinge SLOWLY: fast movement makes noise. Movement below 97 or above 162 degrees makes none.
d) iOS briefly blurs one half of the inner screen when a fold starts, so the chest is drawn turned round: the blurring half is the lid; loot and warnings stay on the sharp half. Settings > Turn the chest round switches this off.
e) PAUSE: mid-chest, PRESS AND HOLD the pause coin 0.35 s (a tap only shows "Hold to pause"). Lowering the lid below 70 degrees for 0.4 s also pauses ("Lift the lid a little to carry on"), as does the outer display (a sleeping-mimic card). Paused, the candle and noise are frozen.
f) RESUME: lift to 92 degrees or more (released below 88) AND hold still (under 6 degrees/s, 10 above 100 degrees, for 0.3 s) on the inner display; until then "Hold still". After a bank, just lift. Lid noise is ignored for 0.5 s after resuming.
g) NEVER STUCK: after 3 s the pause card adds Carry on (resumes at once) next to Home; with the hinge at 92 degrees or more it resumes by itself after 6 s. On the outer-display card, after 3 s with the hinge at 92 or more, "Already open?" offers Carry on and Home.
h) Above 172 degrees: "That's wide enough". No penalty; play goes on.

3. KIND TO THE DEVICE (2.4.2, 1.4.5)
Fast hinge movement is the losing move: about two slow strokes per chest, mid-range. Hush never asks the user to close the phone, lay it flat or move the hinge quickly; opening past 165 gains nothing. Nothing rewards hinge speed or move count. Play reads the angle, never the closed state.

4. MODES AND SETTINGS
Run; Daily Dungeon (same chests for everyone each UTC day, one scored try); First Chest. 12 achievements, 2 leaderboards, Game Center optional. Settings: Lid sensitivity (Forgiving, Normal, Careful; the scored Daily always plays Normal), Vibration (Off, Normal, Strong), Reduce motion, Play sound on silent.

5. CONTENT (9+)
A cartoon chest mimic "bites" a noisy player: a comic CHOMP and a red flash. Nobody is hurt.

6. OTHER
No SDKs, analytics, notifications or rating prompt; Data Not Collected. Debug and demo modes are compiled out of Release. Settings > About > hold Version 2 s opens the on-device diagnostics log (Copy log); nothing is sent. All sound is synthesized; every sound cue has an on-screen cue.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

Re-checked against build 1.0 (4) code (c6e046c, rounds 6 to 10) on Wed 28 Oct, after QA-6 P1-1. Tick the **RC** column on the release candidate; change the block wherever the build differs.

| Claim in the block | Where it is in the code (28 Oct, build 4) | RC |
|---|---|---|
| Portrait on every iPhone without a fold and the Simulator; the top half is the lid, the bottom half the floor | `OrientationLock.mask` (`.portrait` unless a Duo); `UI/RootView.swift` (k = 0 without a fold) | [ ] |
| First launch opens First Chest, no score; Skip from step 3 (after step 2) or after 20 s, from the start on a replay; Settings **"Replay First Chest"** | `LessonScript.canSkip`, `skipAfter` 20; `Pages.swift` `SettingsView` | [ ] |
| The **lever** on the top half (phones only); a Duo always uses the hinge | the scene's lever (`usesSlider`); `design/notes/app-R6.md` item 4 | [ ] |
| The bag is the IN BAG pouch; banking = lid (or lever) down and held (0.35 s), adds to BANKED | `Tuning.shutZoneAngle` 110, `shutHoldSeconds` 0.35; `HushCopy.bankLid` "Ease the lid down to bank" | [ ] |
| NOISE meter; **"Freeze!"**; a bite loses the bag and **10 s** | `HushCopy.hint(.freeze)`; `Tuning.biteTorchPenalty` 10 | [ ] |
| Candle 100 s, **+6 s per oil bagged**; the run ends at candle out | `Tuning.torchSeconds` 100, `oilSeconds` 6 | [ ] |
| Phones: the pause coin is a tap | `AppRules.pauseNeedsHold(duo:phase:)` false off a Duo | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle never sent; kept only in the on-device diagnostics log (last 80 events with angle, plus the hand-off and relight angles) | `Input/HingeReader.swift`; `Persistence/EventLog.swift` (`hush.diag.events`, capacity 80); `GameController` `hush.diag.handoff` / `hush.diag.relight` | [ ] |
| Any orientation on a Duo, drawn the right way up; no blocking card; no "Play anyway"; book pose = a dismissible "Stand it up like a little laptop" tip | `AppRules.quarterTurns`; `OrientationLock.mask` (`.allButUpsideDown` on a Duo); `PoseCards.swift` `PoseTip`; `AppRules.showsPoseTip` | [ ] |
| Shut ≈ 100°, open ≈ 165°, bank ≤ 110°, speed counted only 97–162° | `Tuning.shutAngle` 100, `wideAngle` 165, `shutZoneAngle` 110; `HingeLidSource.speedAngleRange` (`min(wideAngle + 3, 162)`) | [ ] |
| Turned round by default; Settings **"Turn the chest round"** | `SettingsStore.turnRound` default true; `Pages.swift` `turnTitle` | [ ] |
| Duo mid-chest: the pause coin is a **0.35 s press-and-hold**; a tap shows "Hold to pause" | `AppRules.pauseHoldSeconds` 0.35, `pauseNeedsHold`; `PlayHUD.swift` `PauseCoin` | [ ] |
| **Pause below 70° for 0.4 s**, "Lift the lid a little to carry on"; the outer display is always a pause | `Tuning.closingAngle` 70, `closingDwell` 0.4; `PlayHUD` closing card; `CoverCard` | [ ] |
| Candle stopped and **noise frozen** while paused | `ROUND-3.md` decision 2 | [ ] |
| **Resume at ≥ 92° (released < 88°), < 6°/s (10°/s at ≥ 100°) for 0.3 s**, inner display only; "Hold still…"; after a bank no stillness wait; 0.5 s grace | `HingeLidSource.resumeAngle` 92, hysteresis 4°, `resumeWideAngle` 100 / `resumeWideSpeed` 10, `resumeHold` 0.3; `AppRules.closingResumes(…freshChest:)`; `AppRules.resumeGraceSeconds` 0.5 | [ ] |
| **Carry on** after 3 s next to **Home**; the watchdog resumes after 6 s at ≥ 92° on the inner display | `AppRules.carryOnDelay` 3, `watchdogSeconds` 6, `watchdogResumes(…resumeAngle:)`; `PlayHUD` closing card | [ ] |
| Outer-display card: **"Already open?" Carry on / Home** after 3 s at ≥ 92° | `AppRules.coverEscapeDelay` 3, `coverEscapeAngle` 92; `PoseCards.swift` `CoverCard` | [ ] |
| "That's wide enough" > 172°, play goes on | `Tuning.tooWideAngle` 172; `HushCopy.hint(.tooWide)` | [ ] |
| Never uses the hinge's closed status in play | `HingeLidSource` / `HingeReader` header comments → grep `.closed` | [ ] |
| Daily on the UTC day, one scored try; 2 leaderboards, 12 achievements | `AppRules` Daily clock; `achievements.md` → `App/GameCenterManager.swift` | [ ] |
| **Lid sensitivity** Forgiving / Normal / Careful, the scored Daily always Normal; **Vibration** Off / Normal / Strong | `AppRules.sensitivityTitle`, `sensitivityDetail`; `SessionOptions.for(mode:sensitivity:)`; `AppRules.vibrationTitle` | [ ] |
| **"Reduce motion"**, **"Play sound on silent"**; every sound cue has an on-screen cue | `Pages.swift` `SettingsView`; `SceneMoments` | [ ] |
| No notifications, no rating prompt; no SDKs | grep `UNUserNotificationCenter` / `requestReview` in `Hush/`; `privacy.md` §3 | [ ] |
| Debug and demo modes compiled out of Release; Diagnostics only behind Settings › About › hold **Version** 2 s, with **Copy log** | `App/DemoMode.swift` (`#if DEBUG`); `Pages.swift` `versionText` long-press, `EventLogPanel.copyLabel` | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Hush rewards moving the hinge slowly and penalises moving it fast: speed is how a player loses, so the game actively trains gentle use. Play uses about two slow strokes of the hinge per chest, between about 100 and 165 degrees, in the middle of its range, with the phone standing in its normal tabletop pose. It never asks users to close the phone, lay it flat or move it quickly, and opening wider gains nothing. No score, achievement or bonus rewards hinge speed or the number of moves. Nothing is ever placed on the device. Any iPhone without a hinge plays the full game with an on-screen lever."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable on any iPhone and in the Simulator with the lever. A Duo plays with the hinge only (the founder's Round 3 decision: a fold layout never shows the lever; since R6 it plays in any orientation, so there is no "Play anyway" path either). If the reviewer says pause or play seemed stuck, point to §2 e to g: the Duo's pause coin is press-and-hold, and the pause card always has Carry on and Home. Offer the video attachment, and if App Review insists on a touch fallback on the Duo, tell Claude (a "Play with the lever" setting is a small 1.0.1 change).

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and §1 and the 12 achievements: an endless Run with four chest tiers, four mimic kinds plus golden mimics, the Hush Chain, a Daily Dungeon, a 24-relic Codex, 12 thief ranks and a lesson; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## If the age rating is questioned

The answers are in `metadata.md` §8: Infrequent cartoon or fantasy violence and Infrequent horror/fear (the comic bite), giving 9+. If Apple asks for a higher rating, accept it and tell Claude (the store copy names no age).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Swoop's and Brim's notes (structure mirrored): `C:\Users\59527\Wing\docs\appstore\review-notes.md`, `C:\Users\59527\Fold\docs\appstore\review-notes.md`
