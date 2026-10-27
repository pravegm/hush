# Hush: Game Center leaderboards and achievements (v1.0)

*Written Tue 27 Oct 2026 from `design/GAME-DESIGN.md` §7, `design/ARCHITECTURE.md` ("Achievements", `RunResult`) and `Hush/Shared/Contracts.swift`, mirroring Swoop's and Brim's plans. **IDs are permanent once created in App Store Connect**, so the code must use exactly these strings. Every achievement works the same with the hinge (Duo) and with the lid slider (other iPhones). Nothing rewards hinge speed or the number of hinge moves (App Review 2.4.2); several reward the opposite.*

**Status: synced with the code on Tue 27 Oct 2026 (~10:15 UTC).** `Hush/Core/Ranks.swift` (`Achievements.all`, the Core engineer's) landed while this kit was being written, with its own keys, titles and rules, so **the docs follow the code** (Swoop's lesson, its DECISIONS #43): the IDs, titles, pre-earned descriptions (`AchievementDef.detail`) and triggers below are copied from `Achievements.earned(after:…)`. The launch lead added only what the code doesn't hold: the **earned descriptions** and the **points**. If Core changes a key, title, detail or rule before the items are created in App Store Connect, change this table and re-run `node tools/appstore/build-metadata.js`.
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
| What the app submits | `RunResult.gold` (gold banked) of any Run or scored Daily run | the gold banked in the **first scored Daily Dungeon** of the (UTC) day |

**Why gold banked:** it is the score (`GAME-DESIGN.md` §4: "The score is the gold banked"), the Results headline and the number players compare. Loot lost to bites doesn't count.

**Why the Daily starts on 1 Nov, not launch day:** TestFlight testers (Game Center sandbox) can see the board before launch. It costs nothing.

**One engineering point (must be settled before 1.0):** a recurring leaderboard resets at the same UTC moment for everyone, so the Daily Dungeon's seed must change at **00:00 UTC** too (`DailySeed.dayNumber(for:)` counts days since 2026-01-01; it must use a UTC calendar, as Brim and Swoop do). A local-calendar seed would mix two days' dungeons on one board around midnight. See `DECISIONS.md` #19.

## Achievements (12, 525 points)

`Hidden`: none. `Achievable more than once`: No, for all twelve. Triggers are exactly `Achievements.earned(after:lifetimeGold:relicsFound:alreadyEarned:)` in `Hush/Core/Ranks.swift` (27 Oct): only Run and Daily runs count; attract and lesson runs never do. The pre-earned description is the code's `detail`; the earned description and the points are the launch lead's.

| # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger (from the code) |
|---|---|---|---|---|---|---|---|
| 1 | `hush.ach.firsthaul` | First Haul | Bank your first chest. | In the bag, and the lid shut. | 10 | No | `run.chestsBanked >= 1` |
| 2 | `hush.ach.notapeep` | Not a Peep | Bank a chest without the mimic ever stirring. | It never stopped snoring. | 25 | No | `run.hushed >= 1` |
| 3 | `hush.ach.firstrelic` | Relic Hunter | Bank your first relic. | The first page of your Codex. | 15 | No | `relicsFound >= 1` or a relic banked this run |
| 4 | `hush.ach.fivechests` | Light Fingers | Bank 5 chests in one run. | Five chests, one torch. | 25 | No | `run.chestsBanked >= 5` |
| 5 | `hush.ach.royal` | Royal Treatment | Reach a Royal chest. | The finest chest in the dungeon. | 50 | No | `run.highestTier == .royal` (chest 7 or later) |
| 6 | `hush.ach.heavybag` | Heavy Bag | Bank 2,000 gold in one run. | Two thousand gold, still on tiptoe. | 25 | No | `run.gold >= 2000` |
| 7 | `hush.ach.hoard` | Dragon's Hoard | Bank 5,000 gold in one run. | Five thousand gold, quietly hoarded. | 75 | No | `run.gold >= 5000` |
| 8 | `hush.ach.untouchable` | Untouchable | Bank 3 chests in a run without a single bite. | Not one tooth mark. | 50 | No | `run.bites == 0 && run.chestsBanked >= 3` |
| 9 | `hush.ach.hushhush` | Hush Hush | Bank 3 chests in one run without the mimic stirring. | Three chests, three snores. | 50 | No | `run.hushed >= 3` |
| 10 | `hush.ach.curator` | Curator | Find 12 relics for the Codex. | Half the Codex, beautifully kept. | 50 | No | `relicsFound >= 12` (lifetime) |
| 11 | `hush.ach.fullcodex` | Keeper of Curiosities | Find all 24 relics. | Every relic in the dungeon is yours. | 100 | No | `relicsFound >= RelicCatalog.all.count` (24, lifetime) |
| 12 | `hush.ach.fortune` | A Small Fortune | Bank 25,000 gold in total. | Twenty-five thousand gold, and counting. | 50 | No | `lifetimeGold >= 25000` |
| | | | | | **525** | | |

Points: 10 + 25 + 15 + 25 + 50 + 25 + 75 + 50 + 50 + 50 + 100 + 50 = **525**. **475 points stay in reserve** for later updates (new chests, relics or mimics), well under the 1,000 cap.

**en-US** is identical (no spelling differences). Enter it once per locale.

**Design examples covered:** "first relic" (#3), "bank a chest without the mimic ever stirring" (#2) and "5 chests in a run" (#4) are the three named in `GAME-DESIGN.md` §7.

**Not taken from the launch lead's first draft** (for the record; nothing to do): a "Mimic Whisperer" achievement for the top thief rank (the rank itself is the reward), and 1,000-gold and 5-Hushed steps. If Core ever adds them, they fit in the 475-point reserve.

## The ladder (does it feel right?)

Rough reach from the code's own numbers (`Ranks.swift`: "a casual run banks about 2,500, expert about 4,500"; the design: 4–8 chests a run; to be confirmed by `BalanceTests`):
- **First run:** First Haul, often Heavy Bag and Not a Peep.
- **First few sessions:** Relic Hunter (relics start at Iron-bound, about 35 % of chests), Light Fingers, Untouchable, Hush Hush.
- **A good week:** Royal Treatment, A Small Fortune (about ten casual runs), Curator.
- **The long tail:** Dragon's Hoard (expert runs), Keeper of Curiosities.

If the balance harness shows a step is far off (for example casual players never reaching a Royal chest), change the **description and trigger in the code and here** before the achievement is created. IDs can't change afterwards; descriptions can, but changing what an earned achievement meant is unfair.

## Copy rules
- Titles short (Game Center truncates long ones; "Keeper of Curiosities" is the longest at 21 characters: check it in the App Store Connect form).
- Nothing mentions hinge speed as a goal, slamming, snapping shut or closing the phone. Gentle, quiet and slow are the virtues.
- No injury words: the mimic "bites" and leaves "tooth marks" at most, and only in the comic sense.

## Images (needed before you can save each achievement)

Twelve 1024 × 1024 PNGs, one per achievement, opaque (no alpha channel). **The app already draws them** (`Hush/UI/AchievementArt.swift`, `AchievementBadge`, 27 Oct): the candlelit teal-black dungeon, a medallion whose rim marks the tier (verdigris for the first four, then silver, then gold) and one simple motif picked from the achievement's id and title (a relic crown, a chest, a sleeping eye, teeth, the daily sun, a coin stack, a key), with short numerals only.

**Where they come from:** the demo key `screen=badges` (`Hush/App/DemoMode.swift`) writes all twelve to the app's Documents/badges/<gc id>.png and logs `HUSH-T badges done <n>`. Still to do: a CI scenario that runs it and copies `badges/` into `ci.yml`'s `screenshots` artifact (`DECISIONS.md` §2 request #4). Then the App Store Connect tool's workflow collects them (`tools/appstore/badges.swift`), flattens them to opaque RGB, and pushes one per achievement.

## Implementation checklist (App and Core engineers)
- [x] IDs in code match this file (27 Oct: the twelve `def("key", …)` calls in `Ranks.swift`; `hush.best` and `hush.daily` in `GameCenterManager.Leaderboard`). Keep the `def("key"` form, or write IDs out in full: the tools can't read interpolated IDs.
- [ ] Authenticate once at launch; if the player declines, never show the sign-in sheet again uninvited (Swoop's `GameCenterManager`).
- [ ] Progress reported with `percentComplete` (optional, nice): #4 (best chests / 5), #6 and #7 (best gold / target), #9 (best hushed / 3), #10 and #11 (relics / target), #12 (lifetime gold / 25,000).
- [ ] Banners never appear mid-run: queue them until Results.
- [ ] Daily: submit only the first scored run of the (UTC) day.
- [ ] Lid-slider play can earn every achievement.

## Sources
- App Store Connect Help, *Achievements* (limits, hidden, images): https://developer.apple.com/help/app-store-connect/reference/game-center/achievements
- App Store Connect Help, *Leaderboards* (classic and recurring; start date, duration, restart): https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards
- Swoop's and Brim's Game Center plans (format mirrored): `C:\Users\59527\Wing\docs\appstore\achievements.md`, `C:\Users\59527\Fold\docs\appstore\achievements.md`
