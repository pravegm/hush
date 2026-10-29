# Hush: App Review notes (v1.0)

*Rewritten Wed 28 Oct 2026 (after QA-6 P1-1) from the code of build 1.0 (4), and rewritten again the same day for Round 15 (e3612bb) and updated for R15c (2170f0e: the new three rules, the silent bank, "Banked +N gold!", the About links) from `Hush/UI/PoseCards.swift` (`HowToPlay`, `CoverCard`), `HomeView.swift`, `PlayHUD.swift` (`HushCopy`, `ClosingCard`), `Hush/Core/Lid.swift` and `Tuning.swift` (θ / 150, shut ≤ 15°), `Hush/Input/HingeLidSource.swift`, `Hush/App/AppRules*.swift` (Carry on, the cover escape, the pause hold, `showsHint`), `GameController.launch()` (Home first) and `Pages.swift`. The build-4 notes described a game that no longer exists (a standing pose with shut at 100 degrees, bank at 110, pause below 70, resume at 92, a forced First Chest, "That's wide enough"). The block between the markers is what you paste (or what the App Store Connect tool pushes). Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, ellipses or symbols), so bytes = characters; **3,927 bytes** (`node tools/appstore/build-metadata.js` prints it as `notesBytes`). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (the tool copies Squish's; typed by hand only into App Store Connect, never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s phone video on the Duo: the outer-screen intro, Play, the phone opened slowly (the chest opening with it), a coin dragged to the bag, the phone closed to bank. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Hush: a paid game. No login or accounts, no in-app purchases, no ads, no data collected, and no network requests of its own. Game Center is optional.

THE WHOLE GAME: THREE RULES (shown in the app before you play)
iPhone Duo: 1 The chest opens with the phone. Move it slowly. 2 Drag the loot into your bag. 3 Close the phone to bank it before your candle runs out.
Other iPhones: 1 In a chest, slide the lever up slowly to open it. 2 Drag the loot into your bag. 3 Slide the lever down to bank it before your candle runs out.
Moving fast makes noise. If the noise meter fills, the mimic wakes: "Freeze!" means keep still and it settles; if not, it bites (CHOMP): the bag is lost and the 100 s candle loses 10 s. First launch opens Home; Play is a real run. First Chest is only an optional replay (Settings > Replay First Chest).

1. ANY iPHONE OR THE SIMULATOR (start here)
The full game works on any iPhone and in the Simulator, in portrait. The top half has an on-screen brass LEVER; the bottom half is the floor with the loot.
- Press Play. Slide the lever up slowly: the chest opens with the lever and the lit loot appears.
- Drag a lit coin or gem into the bag (IN BAG).
- Slide the lever down: the bag is banked (BANKED). The next chest waits, closed: slide the lever up again.
- Tap the round pause coin to pause.
Every mode and achievement works with the lever.

2. iPHONE DUO (the hinge)
The phone IS the chest: 0 degrees shut, 150 wide, openness = angle / 150. At 15 degrees or less it counts as shut. No pose to hold, no lever, no pose tip.
a) Phone shut: the outer screen shows an intro ("Steal the mimic's gold while it sleeps", the three rules, Play, "Press Play, then open the phone slowly"). Press Play, then open the phone: the chest opens with the phone.
b) Launched with the phone open: press Play on the inner screen and the run starts with the chest already open.
c) Close the phone to bank. With loot in the bag the close IS the bank, at any speed; with an empty bag it just ends that chest. After a bank the outer screen shows "Banked +N gold!" and "Open the phone slowly for the next chest" (after an empty chest: "Nothing banked. A new chest waits."); the candle waits while shut, and End run is there. Opening again (play resumes from about 18 degrees) brings the next chest.
d) PAUSE on the inner screen: press and hold the pause coin (a tap shows "Hold to pause").
e) NEVER STUCK: Home is always on the pause card; Carry on appears after 3 s. If the hinge has not reported yet, the card says "Move the phone a little" (with Home). On the outer screen, "Already open?" does the same if the phone is open.
f) There is no "Hold still" card and no "That's wide enough".
Hush reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check; never the hinge's closed status. The angle never leaves the phone.

3. KIND TO THE DEVICE (2.4.2, 1.4.5)
Fast opening is the losing move. Play is the phone's ordinary open and close (the app does ask the player to close the phone to bank); never flat, never fast, and nothing rewards hinge speed or move count.

4. MODES AND SETTINGS
Run; Daily Dungeon (same chests for everyone each UTC day, one scored try); First Chest (optional replay). 12 achievements, 2 leaderboards. Settings: Sound, Vibration (Off, Normal, Strong), Lid sensitivity (Forgiving, Normal, Strict; the scored Daily plays Normal), Play sound on silent, Reduce motion. Settings > About has Privacy and Support links.

5. CONTENT (9+)
A cartoon chest mimic "bites" a noisy player: a comic CHOMP and a red flash. Nobody is hurt.

6. OTHER
No SDKs, analytics, notifications or rating prompt; Data Not Collected. Debug and demo modes are compiled out of Release. Diagnostic log: Settings > About > hold the Version line 2 s > Copy log. It stays on the device; nothing is sent. All sound is synthesized; every sound cue has an on-screen cue.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

Re-checked against the Round 15 code (e3612bb) and R15c (2170f0e) on Wed 28 Oct. Tick the **RC** column on the release candidate; change the block wherever the build differs.

| Claim in the block | Where it is in the code (28 Oct, R15) | RC |
|---|---|---|
| The three rules, word for word (Duo and lever) | `PoseCards.swift` `HowToPlay.lines(slider:)` | [ ] |
| No forced tutorial: first launch opens Home; Play is a real run; Settings **"Replay First Chest"** | `GameController.launch()` → `goHome()` (R14); `Pages.swift` `SettingsView` | [ ] |
| NOISE meter; **"Freeze!"**; a bite loses the bag and **10 s**; a fast drag is noise too | `HushCopy.hint(.freeze)`, `.slower`; `Tuning.biteTorchPenalty` 10; `HeistSession` drag noise (R14) | [ ] |
| Candle 100 s; the run ends at candle out | `Tuning.torchSeconds` 100 | [ ] |
| Portrait on every iPhone without a fold and the Simulator; the lever on the top half (phones only); a Duo always uses the hinge | `OrientationLock.mask`; the scene's lever (`usesSlider`) | [ ] |
| Lever: up opens, down (held a moment) banks; the next chest waits closed | `SliderLidSource` (shut zone + detent, R13); `Tuning.shutHoldSeconds` 0.35; `HushCopy.closeForNextLever` | [ ] |
| Phones: the pause coin is a tap | `AppRules.pauseNeedsHold(duo:phase:)` false off a Duo | [ ] |
| The phone is the chest: openness = θ / 150, shut ≤ 15° | `Lid.hingeOpenness`; `Tuning.hingeWideAngle` 150, `hingeShutZoneAngle` 15 | [ ] |
| Phone shut: the outer screen's intro ("Steal the mimic's gold while it sleeps", the rules, Play, "Press Play, then open the phone slowly"); Play there starts the run closed | `CoverCard` intro, `onPlay` (R15) | [ ] |
| Play on the inner screen with the phone open starts with the chest open | R15 `sawShut` starts true (commit 04fde7c) | [ ] |
| Closing with loot banks at any speed (silent); closing an empty chest ends it; the outer screen then shows **"Banked +N gold!"** and **"Open the phone slowly for the next chest"** (empty: "Open the phone slowly"); the candle waits while shut; **End run** | R15c (2170f0e, test `r15cAFastCloseWithLootIsSilent`); `CoverCard.justBankedLine`, `nextChestTitle`, `title(midRun:)`, `detail(midRun: true)`, `endRunLabel` | [ ] |
| Shut 0°, wide 150°, openness = angle / 150, shut zone ≤ 15°; play resumes from about 18° | `Tuning.hingeShutAngle` 0, `hingeWideAngle` 150, `hingeShutZoneAngle` 15; `HingeLidSource.resumeAngle` 18 | [ ] |
| A silent hinge: "Move the phone a little", with Home | `ClosingCard.title(awaitingHinge: true)`; `AppRulesR8` / `AppRulesR11` | [ ] |
| Settings › About: **Privacy** and **Support** links (5.1.1) | `Pages.swift` `Link("Privacy", …)`, `Link("Support", …)` | [ ] |
| Duo mid-chest: the pause coin is a **press-and-hold** (the stakes card: "Hold the coin to pause"); a tap shows "Hold to pause" | `AppRules.pauseHoldSeconds` 0.35, `pauseNeedsHold`; `PlayHUD.swift` `PauseCoin` | [ ] |
| **Carry on** after 3 s (with a hinge report) next to **Home**; outer screen **"Already open?"** after 3 s with the phone open | `AppRules.carryOnDelay` 3; `ClosingCard`; `AppRules.coverEscapeDelay` 3, `coverEscapeAngle`; `CoverCard` | [ ] |
| Loot and warnings on the sharp half; Settings **"Turn the chest round"** | `SettingsStore.turnRound` default true; `Pages.swift` `turnTitle` | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; never the hinge's closed status; angle never sent; kept only in the on-device diagnostics log | `Input/HingeReader.swift`; `HingeLidSource` header ("Never use the hinge's `status`"); `Persistence/EventLog.swift` (`hush.diag.events`, capacity 80) | [ ] |
| No pose asked for (no pose tip); never flat; no "Hold still" card; "That's wide enough" never shows | `AppRules.showsPoseTip` (R14: never by itself); `AppRules.showsHint` drops `.tooWide` | [ ] |
| Daily on the UTC day, one scored try; 2 leaderboards, 12 achievements | `AppRules` Daily clock; `achievements.md` → `App/GameCenterManager.swift` | [ ] |
| **Lid sensitivity** Forgiving / Normal / Strict, the scored Daily always Normal; **Vibration** Off / Normal / Strong | `AppRules.sensitivityName`, `sensitivityLine`, `scoredDailyLine`; `AppRules.vibrationTitle` | [ ] |
| **"Reduce motion"**, **"Play sound on silent"**; every sound cue has an on-screen cue | `Pages.swift` `SettingsView`; `SceneMoments` | [ ] |
| No notifications, no rating prompt; no SDKs | grep `UNUserNotificationCenter` / `requestReview` in `Hush/`; `privacy.md` §3 | [ ] |
| Debug and demo modes compiled out of Release; Diagnostics only behind Settings › About › hold **Version** 2 s, with **Copy log** | `App/DemoMode.swift` (`#if DEBUG`); `Pages.swift` `versionText` long-press, `EventLogPanel.copyLabel` | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Hush rewards moving the hinge slowly and penalises moving it fast: speed is how a player loses, so the game actively trains gentle use. Play is the phone's ordinary open and close: the chest opens as the phone opens, and the player closes the phone to bank (with loot in the bag the close is the bank itself, whatever its speed, so nothing is lost or punished by closing). It never asks users to lay the phone flat or move it quickly, and opening wider than the loot needs gains nothing. No score, achievement or bonus rewards hinge speed or the number of moves. Nothing is ever placed on the device. Any iPhone without a hinge plays the full game with an on-screen lever."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable on any iPhone and in the Simulator with the lever. A Duo plays with the hinge only (the founder's Round 3 decision: a fold layout never shows the lever). On a Duo the quickest path is §2 a: phone shut, press Play on the outer screen, open the phone slowly. If the reviewer says pause or play seemed stuck, point to §2 d and e: the Duo's pause coin is press-and-hold, the pause card always has Home and offers Carry on after 3 s, and the outer screen offers "Already open?". Offer the video attachment, and if App Review insists on a touch fallback on the Duo, tell Claude (a "Play with the lever" setting is a small 1.0.1 change).

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and §1 and the 12 achievements: an endless Run with four chest tiers, four mimic kinds plus golden mimics, the Hush Chain, a Daily Dungeon, a 24-relic Codex, 12 thief ranks and an optional lesson; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## If the age rating is questioned

The answers are in `metadata.md` §8: Infrequent cartoon or fantasy violence and Infrequent horror/fear (the comic bite), giving 9+. If Apple asks for a higher rating, accept it and tell Claude (the store copy names no age).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Swoop's and Brim's notes (structure mirrored): `C:\Users\59527\Wing\docs\appstore\review-notes.md`, `C:\Users\59527\Fold\docs\appstore\review-notes.md`
