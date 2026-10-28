# Hush: Game Center leaderboards and achievements (v1.0)

*Rewritten Tue 27 Oct 2026 (Round 3, QA-2 P1-2) from the code as it is now: `Hush/Core/Ranks.swift` (`Achievements.all`, `Achievements.earned(after:…)`), `Hush/Core/Tuning.swift` and `Hush/App/GameCenterManager.swift`. **IDs are permanent once created in App Store Connect**, so the code and this file must use exactly the same strings. Every achievement works the same with the hinge (Duo) and with the lever (other iPhones). Nothing rewards hinge speed or the number of hinge moves (App Review 2.4.2); several reward the opposite.*

**Status: synced with the code on Tue 27 Oct 2026 (Round 3).** Round 2 changed three thresholds and replaced two achievements, keeping their keys (`royal` and `hushhush`), so the Game Center IDs and the badge slots are unchanged; only titles, descriptions and rules changed. The docs follow the code: the IDs, titles, pre-earned descriptions (`AchievementDef.detail`) and triggers below are copied from `Ranks.swift`. The launch lead adds only the **earned descriptions** and the **points**. If Core changes a key, title, detail or rule before the items are created in App Store Connect, change this table and re-run `node tools/appstore/build-metadata.js`.
- `tools/appstore/badges.swift` and the App Store Connect tool check that the app's IDs (read from the `def("key", …)` calls in `Ranks.swift`, prefixed `hush.ach.`), this file and `asc-metadata.json` are the same twelve, and stop if they aren't.
- The leaderboard IDs `hush.best` and `hush.daily` match `GameCenterManager.Leaderboard` in `Hush/App/GameCenterManager.swift`.

## Apple's limits (from Brim's and Squish's sourced notes)
- ≤ 100 points per achievement, ≤ 1,000 points per app, ≤ 100 achievements.
- IDs ≤ 100 characters: letters, digits, `.` and `_`. Permanent.
- Each achievement needs a **1024 × 1024** image (PNG or JPEG, RGB, no transparency, ≥ 72 dpi). Leaderboard images are optional.
- Achievements and leaderboards only go live attached to a version that includes them (runbook §5).

## Leaderboards (2)

| | `hush.best` | `hush.daily` |
|---|---|---|
| Type | **Classic** (all-time) | **Recurring** |
| Reference name | `Best Haul` | `Daily Dungeon` |
| Display name (en-GB and en-US) | `Best Haul` | `Daily Dungeon` |
| Score format | Integer | Integer |
| Format suffix (singular / plural) | ` gold` / ` gold` | ` gold` / ` gold` |
| Sort order | High to Low | High to Low |
| Score submission | Best score | Best score (the app submits only the day's one scored try) |
| Score range (optional) | 0 – 10,000,000 | 0 – 1,000,000 |
| Recurring settings | — | Start **Sun 1 Nov 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day** |
| What the app submits | `RunResult.gold` (gold banked, Hush Chain and golden-mimic bonuses included) of any Run or scored Daily run | the gold banked in the **first scored Daily Dungeon** of the (UTC) day |

**Why gold banked:** it is the score, the Results headline and the number players compare. Loot lost to bites doesn't count.

**Why the Daily starts on 1 Nov, not launch day:** TestFlight testers (Game Center sandbox) can see the board before launch. It costs nothing.

**Day boundary:** the Daily Dungeon turns at **00:00 UTC** for everyone (`AppRules` "The Daily Dungeon's clock"), the same moment the recurring board resets.

## Achievements (12, 525 points)

`Hidden`: none. `Achievable more than once`: No, for all twelve. Triggers are exactly `Achievements.earned(after:lifetimeGold:relicsFound:alreadyEarned:)`: only Run and Daily runs count; attract and lesson runs never do. A **Hushed** bank is a chest banked without the mimic ever stirring.

| # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger (from the code) |
|---|---|---|---|---|---|---|---|
| 1 | `hush.ach.firsthaul` | First Haul | Bank your first chest. | In the bag, and quietly banked. | 10 | No | `run.chestsBanked >= 1` |
| 2 | `hush.ach.notapeep` | Not a Peep | Bank a chest without the mimic ever stirring. | It never stopped snoring. | 25 | No | `run.hushed >= 1` |
| 3 | `hush.ach.firstrelic` | Relic Hunter | Bank your first relic. | The first page of your Codex. | 15 | No | `relicsFound >= 1` or a relic banked this run |
| 4 | `hush.ach.fivechests` | Light Fingers | Bank 5 chests in one run. | Five hauls, one candle. | 25 | No | `run.chestsBanked >= 5` |
| 5 | `hush.ach.royal` | Midas Touch | Bank a golden mimic. | Double gold, and away you crept. | 25 | No | `run.goldenBanked >= 1` |
| 6 | `hush.ach.heavybag` | Heavy Bag | Bank 3,000 gold in one run. | Three thousand gold, still on tiptoe. | 25 | No | `run.gold >= 3000` |
| 7 | `hush.ach.hoard` | Dragon's Hoard | Bank 8,000 gold in one run. | Eight thousand gold, quietly hoarded. | 75 | No | `run.gold >= 8000` |
| 8 | `hush.ach.untouchable` | Untouchable | Bank 3 chests in a run without a single bite. | Not one tooth mark. | 50 | No | `run.bites == 0 && run.chestsBanked >= 3` |
| 9 | `hush.ach.hushhush` | Hush Chain | Bank 5 chests in a row without the mimic stirring. | Five sleepy banks in a row. | 75 | No | `run.bestChain >= Tuning.chainMax` (5) |
| 10 | `hush.ach.curator` | Curator | Find 12 relics for the Codex. | Half the Codex, beautifully kept. | 50 | No | `relicsFound >= 12` (lifetime) |
| 11 | `hush.ach.fullcodex` | Keeper of Curiosities | Find all 24 relics. | Every relic in the dungeon is yours. | 100 | No | `relicsFound >= RelicCatalog.all.count` (24, lifetime) |
| 12 | `hush.ach.fortune` | A Small Fortune | Bank 50,000 gold in total. | Fifty thousand gold, and counting. | 50 | No | `lifetimeGold >= 50000` |
| | | | | | **525** | | |

Points: 10 + 25 + 15 + 25 + 25 + 25 + 75 + 50 + 75 + 50 + 100 + 50 = **525**. **475 points stay in reserve** for later updates (new chests, relics or mimics), well under the 1,000 cap.

**Round 3 point changes (the total is unchanged):** Midas Touch 25 (Royal Treatment was 50): golden mimics come in about 6 % of chests from chest 3, so most players bank one within a few runs. Hush Chain 75 (Hush Hush was 50): five Hushed banks in a row is an expert feat (the balance sim's casual player's best chain is 2; the expert's is 8).

**en-US** is identical (no spelling differences). Enter it once per locale.

## The ladder (does it feel right?)

From the R2 balance sim (`design/notes/core-R2.md`, 40 seeds, medians; CI's BalanceTests hold the same bands): a novice run banks about 1,700 gold over 5 chests with 3 bites; a casual run about 3,950 gold over 8 chests (2 Hushed, best chain 2, about 2 min 10 s); an expert run about 11,000 over 13 chests (best chain 8, about 2 min 25 s).
- **First run:** First Haul, Light Fingers, often Not a Peep, Untouchable and Heavy Bag.
- **First few sessions:** Relic Hunter (relics are in about 1 in 4 chests from the third, Iron-bound, chest), Midas Touch.
- **A good week:** Hush Chain, A Small Fortune (about thirteen casual runs), Curator, Dragon's Hoard (expert runs).
- **The long tail:** Keeper of Curiosities.

If the balance harness or the founder's device test shows a step is far off, change the **description and trigger in the code and here** before the achievement is created. IDs can't change afterwards; descriptions can, but changing what an earned achievement meant is unfair.

## Copy rules
- Titles short (Game Center truncates long ones; "Keeper of Curiosities" is the longest at 21 characters: check it in the App Store Connect form).
- It's a **candle** (the art is one), and the verb is **bank**.
- Nothing mentions hinge speed as a goal, slamming, snapping shut or closing the phone. Gentle, quiet and slow are the virtues.
- No injury words: the mimic "bites" and leaves "tooth marks" at most, and only in the comic sense.

## Images (needed before you can save each achievement)

Twelve 1024 × 1024 PNGs, one per achievement, opaque (no alpha channel). **The app draws them** (`Hush/UI/AchievementArt.swift`, `AchievementBadge`): the candlelit teal-black dungeon, a medallion whose rim marks the tier and one simple motif picked from the achievement's id and title, with short numerals only.

**Where they come from:** the demo key `screen=badges` writes all twelve to the app's Documents/badges/<gc id>.png and logs `HUSH-T badges done <n>`; CI's `40-badges` scenario (`ci/scenarios.txt`) copies them into the `screenshots` artifact's `badges/`. The App Store Connect tool's workflow collects them (`tools/appstore/badges.swift`), flattens them to opaque RGB, and pushes one per achievement. **Check the Midas Touch and Hush Chain badges** show a gold/coin and a chain-or-sleep motif, not the old Royal Treatment and Hush Hush ones (the motif is picked from the title).

## Implementation checklist (App and Core engineers)
- [x] IDs in code match this file (the twelve `def("key", …)` calls in `Ranks.swift`; `hush.best` and `hush.daily` in `GameCenterManager.Leaderboard`). Keep the `def("key"` form, or write IDs out in full: the tools can't read interpolated IDs.
- [ ] Authenticate once at launch; if the player declines, never show the sign-in sheet again uninvited.
- [ ] Progress reported with `percentComplete` (optional, nice): #4 (best chests / 5), #6 (best gold / 3,000), #7 (best gold / 8,000), #9 (best chain / 5), #10 and #11 (relics / target), #12 (lifetime gold / 50,000).
- [ ] Banners never appear mid-run: queue them until Results.
- [ ] Daily: submit only the first scored run of the (UTC) day.
- [ ] Lever play can earn every achievement.

## Sources
- App Store Connect Help, *Achievements* (limits, hidden, images): https://developer.apple.com/help/app-store-connect/reference/game-center/achievements
- App Store Connect Help, *Leaderboards* (classic and recurring; start date, duration, restart): https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards
- Swoop's and Brim's Game Center plans (format mirrored): `C:\Users\59527\Wing\docs\appstore\achievements.md`, `C:\Users\59527\Fold\docs\appstore\achievements.md`
