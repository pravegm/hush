# Hush: App Review notes (v1.0)

*Rewritten Tue 27 Oct 2026 (Round 3, QA-2 P1-2) from the code as it is now: `Hush/Core/Tuning.swift`, `Hush/Input/HingeLidSource.swift` (`canResume`), `Hush/App/AppRules.swift`, `Hush/UI/PlayHUD.swift` and `Pages.swift`, plus the founder's Round 3 decisions (`design/ROUND-3.md`). The block between the markers is what you paste (or what the App Store Connect tool pushes). Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, ellipses or symbols), so bytes = characters; **3,915 bytes** (`node tools/appstore/build-metadata.js` prints it as `notesBytes`). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (the tool copies Squish's; typed by hand only into App Store Connect, never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s phone video of one chest on the Duo in tabletop pose: the lid opened slowly, a coin dragged to the bag, the lid eased shut. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Hush: a paid game. No ads, IAP, accounts, data collection or network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
The full game works on any iPhone and in the Simulator, in portrait.
- The top half is the chest lid, the bottom half the floor with the loot.
- First launch opens First Chest, a short lesson (no score). Skip appears after step 2; Settings > Replay First Chest replays it.
- Open the lid with the LEVER on the top half: drag it up slowly to open, down to shut.
- Drag a lit coin or gem into the bag (IN BAG, at the bottom). Bagged loot is not safe yet.
- Slide the lever back down and hold a moment: the bag is banked (BANKED) and the next chest arrives.
- The NOISE meter fills if you move or drag fast and drains when you keep still. "Freeze!" means hold still. If it fills, the mimic bites: the bag is lost and the candle loses 10 seconds.
- The run ends when the candle burns out (100 s, +6 s per oil flask bagged).
- Every achievement can be earned with the lever.

2. THE HINGE (iPhone Duo)
Hush reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. The angle never leaves the phone (only the last screen-switch angle is kept, for an on-device diagnostics panel). On a Duo the hinge is the lid; if iOS keeps it in landscape, "Play anyway" offers the lever.
a) Stand the Duo like a small laptop. The raised half is the lid; held like a book, a card shows which half to lift.
b) Shut is about 100 degrees, wide open about 165. Ease back to 110 or less and hold a moment to bank.
c) The skill is moving the hinge SLOWLY: fast movement makes noise. Movement below 97 or above 168 degrees makes none.
d) iOS briefly blurs one half of the inner screen when a fold starts, so Hush draws the chest turned round: the blurring half is the lid; loot and warnings stay on the sharp half. Settings > Turn the chest round switches this off.
e) PAUSE: below 70 degrees (for 0.4 s) play pauses: "Lift the lid a little to carry on". If iOS moves the app to the outer display first, that is a pause too (a sleeping-mimic card). While paused the candle stops and the noise is frozen.
f) RESUME: at 95 degrees or more (after the outer display: where the inner one lit, if lower) AND held still (under 6 degrees/s for 0.3 s), on the inner display; until then "Hold still". Lid noise is ignored for 0.5 s after resuming, so reopening never bites.
g) Above 172 degrees: "That's wide enough" (no penalty).

3. KIND TO THE DEVICE (2.4.2, 1.4.5)
- Fast hinge movement is the losing move. About two slow strokes per chest, mid-range.
- Hush never asks the user to close the phone, lay it flat or move the hinge quickly. Opening past 165 gains nothing.
- No score, achievement or bonus rewards hinge speed or move count; the bonuses reward quiet play.
- Play reads the angle, never the closed state. Nothing is placed on the screens.

4. MODES
Run (until the candle burns out; Wooden, Iron-bound, Gilded, Royal chests; a rare golden mimic pays double); Daily Dungeon (the same chests for everyone that UTC day, one scored try, then practice); First Chest. Hush Chain: banks in a row where the mimic never stirred pay x1.1 up to x1.5. Relic Codex: 24 relics. 12 thief ranks.

5. CONTENT (9+)
A cartoon chest monster with one big eye. If the player is noisy it "bites": teeth snap shut across the fold with a comic CHOMP and a red flash. Nobody is hurt; the player loses the bag and 10 s of candle.

6. PRIVACY
No SDKs, analytics, ads, accounts or tracking. Progress stays on the device. Data Not Collected.

7. GAME CENTER
Optional. 2 leaderboards, 12 achievements (525 points), none hidden.

8. OTHER
- No notifications, no rating prompt. Debug and demo modes are compiled out of Release.
- Sound plays on silent; Settings > Play sound on silent turns that off. All sound is synthesized; every sound cue has an on-screen cue.
- Settings > Reduce motion (or iOS Reduce Motion) removes the shake and red flash.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

Checked against the code on 27 Oct (Round 3). Tick the **RC** column on the release candidate; change the block wherever the build differs.

| Claim in the block | Where it is in the code (27 Oct, R3) | RC |
|---|---|---|
| Portrait on every iPhone and the Simulator; the top half is the lid, the bottom half the floor | `UI/RootView.swift`, `Shared/Contracts.swift` (canvas) | [ ] |
| First launch opens First Chest, no score; Skip after step 2; Settings **"Replay First Chest"** | `LessonScript.canSkip`; `Pages.swift` `SettingsView` | [ ] |
| The **lever** is on the top half; up opens, down shuts; a fold layout never draws it | the scene's lever (`usesSlider`); `ROUND-3.md` decision 4 (App + Scene this round) | [ ] where it sits |
| The bag is the IN BAG pouch at the bottom; banking = shut and hold (0.35 s), adds to BANKED | `Tuning.shutHoldSeconds`; HUD plates (ROUND-2 Scene #7; "not safe yet" sub-label, `ROUND-3.md` decision 3) | [ ] |
| NOISE meter; **"Freeze!"**; a bite loses the bag and **10 s** | `HushCopy.hint(.freeze)`; `Tuning` bite penalty | [ ] |
| Candle 100 s, **+6 s per oil bagged**; the run ends at candle out | `Tuning` candle 100 / oil 6; `HeistSession` adds oil when bagged | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle never persisted or sent | `Input/HingeReader.swift`; `Persistence/` grep | [ ] |
| Shut ≈ 100°, open ≈ 165°, bank ≤ 110°, speed counted only 97–168° | `Tuning.shutAngle`, `wideAngle`, `shutZoneAngle`; Feel's speed clamp (REVIEW-2-duo "Fixed" P1-5) | [ ] |
| **Pause below 70° for 0.4 s**, "Lift the lid a little to carry on"; the cover display is always a pause | `Tuning.closingAngle` 70, `closingDwell` 0.4; `PlayHUD` closing card; `ROUND-3.md` decision 1 | [ ] |
| Candle stopped and **noise frozen** while paused | `ROUND-3.md` decision 2 (App this round; Core's test "noise unchanged across a pause") | [ ] |
| **Resume at ≥ 95°, < 6°/s for 0.3 s**, inner display only; "Hold still…"; 0.5 s grace | `HingeLidSource.canResume`, `AppRules.resumeAngle` 95, `resumeGraceSeconds` 0.5; `PlayHUD` "Hold still…" | [ ] |
| "That's wide enough" > 172° | `Tuning.tooWideAngle`; `HushCopy.hint(.tooWide)` | [ ] |
| Turned round by default; Settings **"Turn the chest round"** | `SettingsStore.turnRound` default true; `Pages.swift` | [ ] |
| Never uses the hinge's closed status in play | `HingeLidSource` / `HingeReader` header comments → grep `.closed` | [ ] |
| Run tiers; golden mimic ×2; Hush Chain ×1.1 … ×1.5; Daily on the UTC day, one scored try then practice; Codex 24; 12 ranks | `Tuning`, `AppRules` Daily clock, `RelicCatalog`, `ThiefRanks` | [ ] |
| 2 leaderboards, 12 achievements, 525 points, none hidden | `achievements.md` → `App/GameCenterManager.swift` | [ ] |
| **"Play sound on silent"** (on by default); every sound cue has an on-screen cue | `Pages.swift` `silentTitle`; `SettingsStore.respectSilentSwitch` default false | [ ] |
| **"Reduce motion"** or the iOS setting turns off the shake and the red flash | `Pages.swift`; `RootView` `systemReduceMotion`; `SceneMoments` ("no shake, no red flash") | [ ] |
| No notifications, no rating prompt | grep `UNUserNotificationCenter` / `requestReview` in `Hush/` (none on 27 Oct) | [ ] |
| Debug and demo modes compiled out of Release; no test-build panel for App Review | `App/DemoMode.swift` (`#if DEBUG`); `ROUND-3.md` App Review item (QA-2 P2-15) | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Hush rewards moving the hinge slowly and penalises moving it fast: speed is how a player loses, so the game actively trains gentle use. Play uses about two slow strokes of the hinge per chest, between about 100 and 165 degrees, in the middle of its range, with the phone standing in its normal tabletop pose. It never asks users to close the phone, lay it flat or move it quickly, and opening wider gains nothing. No score, achievement or bonus rewards hinge speed or the number of moves. Nothing is ever placed on the device. Any iPhone without a hinge plays the full game with an on-screen lever."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable on any iPhone and in the Simulator with the lever. A Duo plays with the hinge only (the founder's Round 3 decision: a fold layout never shows the lever), so offer the video attachment, and if App Review insists on a touch fallback on the Duo, tell Claude (a "Play with the lever" setting is a small 1.0.1 change).

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and the 12 achievements: an endless Run with four chest tiers, four mimic kinds plus golden mimics, the Hush Chain, a Daily Dungeon, a 24-relic Codex, 12 thief ranks and a lesson; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## If the age rating is questioned

The answers are in `metadata.md` §8: Infrequent cartoon or fantasy violence and Infrequent horror/fear (the comic bite), giving 9+. If Apple asks for a higher rating, accept it and tell Claude (the store copy names no age).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Swoop's and Brim's notes (structure mirrored): `C:\Users\59527\Wing\docs\appstore\review-notes.md`, `C:\Users\59527\Fold\docs\appstore\review-notes.md`
