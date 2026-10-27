# Hush: App Review notes (v1.0)

*Written Tue 27 Oct 2026 from the design (`design/GAME-DESIGN.md`, `design/ROUND-1.md`), adapted from Swoop's and Brim's reviewed notes. The block between the markers is what you paste (or what the App Store Connect tool pushes). Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes or symbols), so bytes = characters: **3,842 bytes** (counted with Node). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**:
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email (the tool copies Squish's; typed by hand only into App Store Connect, never in the repo).
- **Notes:** the block below.
- **Attachment (optional, recommended):** a 20–30 s phone video of one chest on the Duo in tabletop pose: the lid opened slowly, a coin dragged to the bag, the lid eased shut. The notes don't depend on it.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Hush: Don't Wake the Mimic: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
No Duo needed. Everything works on any iPhone and in the Simulator, upright (portrait).
- The screen is a treasure chest: the top half is the lid, the bottom half is the chest floor with the loot.
- First launch opens First Chest, a short lesson (no score, a heavy sleeper), one sentence per step. Skip appears after step 2; Settings > Replay First Chest plays it again.
- Open the lid with the LID SLIDER, the brass lever on the top half: drag it up slowly to open, down to shut.
- Drag a lit coin or gem down into the bag (the leather strip at the bottom edge).
- Slide the lid back down and hold it shut a moment: the bag is banked (scored) and the next chest arrives.
- The noise meter above the bag fills when you slide or drag fast and drains when you keep still. "FREEZE" means hold still. If it fills, the mimic bites: the bag is lost and the torch loses 15 seconds.
- The run ends when the torch burns out.

2. HOW THE HINGE IS USED (iPhone Duo)
Hush reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. The angle is used only while the game is on screen; it is never stored or sent.
a) Stand the Duo like a small laptop (tabletop). The raised half is the chest lid; a card shows which half to raise.
b) The lid is shut at about 100 degrees and fully open at about 165. Ease back to about 110 or less and hold to bank.
c) The skill is moving the hinge SLOWLY: the game measures hinge speed, and fast movement makes noise.
d) When a fold starts, iOS briefly blurs one half of the inner screen, so by default Hush draws the chest turned round: the blurring half is the raised lid, and the loot, meters and warnings stay on the sharp half. Settings > Turn the chest round switches this off.
e) Below about 85 degrees play pauses ("Lift the lid a little") until reopened. Closed, the outer display shows a sleeping-mimic card. Above about 172 degrees a hint says "That's wide enough" (no penalty). Held like a book, a card asks to stand it up like a little laptop.

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- Moving the hinge fast is the losing move and is never rewarded. About two slow strokes per chest, in the middle of the hinge's range.
- Hush never asks the user to close the phone, lay it flat or move the hinge quickly. Opening past 165 degrees gains nothing.
- No score, achievement or bonus rewards hinge speed or the number of moves.
- Play reads the angle, never the closed state. Nothing is placed on the screens.

4. MODES (nothing hidden, nothing to buy)
Run (chests until the torch burns out: Wooden, Iron-bound, Gilded, Royal); Daily Dungeon (the same chests for everyone that day, one scored try, then practice); First Chest. Relic Codex: 24 relics. Thief rank: 12 ranks by lifetime gold.

5. CONTENT (rated 9+)
A cartoon treasure-chest monster with one big eye. If the player is noisy it "bites": its teeth snap shut across the fold with a comic CHOMP and a red flash. Nobody is shown hurt; the player loses the loot in the bag and some torch time.

6. PRIVACY
No third-party SDKs, analytics, ads, accounts or tracking. Progress stays on the device. App Privacy: Data Not Collected.

7. GAME CENTER
Optional. 2 leaderboards (Best Haul, Daily Dungeon), 12 achievements (525 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on; Settings > Respect silent switch turns that off. All sound is synthesized in the app; every sound cue also has an on-screen cue.
- Settings > Reduce motion turns off the screen shake and the red flash.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

Written from the design on 27 Oct (no code yet). Tick the **RC** column on the release candidate; change the block wherever the build differs.

| Claim in the block | Source (design) → where to check | RC |
|---|---|---|
| Portrait on every iPhone and the Simulator; the top half is the lid, the bottom half the floor | `GAME-DESIGN.md` §3, §9 → `UI/RootView.swift` | [ ] |
| First launch opens First Chest; heavy sleeper, no score; Skip after step 2; Settings **"Replay First Chest"** | §8, ROUND-1 App → lesson code, `UI/SettingsView.swift` | [ ] exact label |
| The **lid slider** is a brass lever on the top half; up opens, down shuts | §9, ROUND-1 Scene → `Scene/`, `Input/SliderLidSource.swift` | [ ] |
| The bag is the leather strip along the bottom edge; banking = shut and hold (0.35 s) | §4 → `Core/Tuning.swift` | [ ] |
| Noise meter above the bag; "FREEZE"; a bite loses the bag and 15 s | §4.5, §5, ROUND-1 Scene → `Core/Tuning.swift`, `Scene/` | [ ] |
| "The run ends when the torch burns out" | §4 "The run" | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle never persisted or sent | `CLAUDE.md`, ARCHITECTURE → `Input/HingeReader.swift`, `Persistence/` grep | [ ] |
| Shut ≈ 100°, open ≈ 165°, bank ≤ 110°, pause < 85° "Lift the lid a little", "That's wide enough" > 172°, cover card, book-pose card | §3, ROUND-1 App → `Core/Tuning.swift`, `UI/` pose cards | [ ] exact wording |
| Turned round by default; Settings **"Turn the chest round"** | §3 → `UI/RootView.swift`, `UI/SettingsView.swift` | [ ] exact label |
| **Settings "Lid slider" on a Duo** (not in the block) | Not built on 27 Oct (`DECISIONS.md` §2 request #1). **If the RC has it, add to section 2: "f) Settings > Lid slider gives the touch slider on a Duo too."** (61 bytes; the block stays under 4,000) | [ ] |
| Never uses `status == .closed` in play | `CLAUDE.md` hinge facts → grep | [ ] |
| Run tiers Wooden, Iron-bound, Gilded, Royal; Daily one scored try then practice; Codex 24; 12 ranks | §6, §7 → `Core/` | [ ] |
| 2 leaderboards, 12 achievements, 525 points, none hidden | `achievements.md` → `App/GameCenterManager.swift` | [ ] |
| **"Respect silent switch"**, default off; every sound cue has an on-screen cue | §10, ROUND-1 Settings | [ ] exact label |
| **"Reduce motion"** turns off the shake and the red flash | ROUND-1 Settings, `DECISIONS.md` §2 request #6 | [ ] |
| No notifications, no rating prompt | grep `UNUserNotificationCenter` / `requestReview` in `Hush/` (if a rating prompt is added, add: "A one-time rating prompt may appear on the Results screen, never during a run.") | [ ] |
| Debug and demo modes disabled in Release | `App/DemoMode.swift` (`#if DEBUG`) | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Hush rewards moving the hinge slowly and penalises moving it fast: speed is how a player loses, so the game actively trains gentle use. Play uses about two slow strokes of the hinge per chest, between about 100 and 165 degrees, in the middle of its range, with the phone standing in its normal tabletop pose. It never asks users to close the phone, lay it flat or move it quickly, and opening wider gains nothing. No score, achievement or bonus rewards hinge speed or the number of moves. Nothing is ever placed on the device. Any iPhone without a hinge plays the full game with an on-screen lid slider."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable on any iPhone and in the Simulator with the lid slider (and on a Duo through Settings > Lid slider, if that ships). Offer the video attachment.

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and the 12 achievements: an endless Run with four chest tiers and four mimic kinds, a Daily Dungeon, a 24-relic Codex, 12 thief ranks and a lesson; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## If the age rating is questioned

The answers are in `metadata.md` §8: Infrequent cartoon or fantasy violence and Infrequent horror/fear (the comic bite), giving 9+. If Apple asks for a higher rating, accept it and tell Claude (the store copy names no age).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Swoop's and Brim's notes (structure mirrored): `C:\Users\59527\Wing\docs\appstore\review-notes.md`, `C:\Users\59527\Fold\docs\appstore\review-notes.md`
