# Review 6: retention and "one more go"

*Reviewer: retention / meta-loop pass. I read GAME-DESIGN, REVIEW-1-feel, core-R2, core-R7, `Hush/Core/` (Tuning,
HeistSession, ChestFactory, Ranks, Catalogs, DailySeed), `Hush/Persistence/ProgressStore.swift`, `Hush/App/`
(AppRules, AppModels, GameController, GameCenterManager) and `Hush/UI/` (ResultsView, Pages, HomeView). I looked at
CI frames 19, 21, 22, 26 and 40 in `artifacts/ci21s/`. The numbers come from `tools/balance-sim-r12.js`, a copy of
`balance-sim.js` with a new **career** mode: N Runs in a row, with the Codex, lifetime gold, best and badges carried
over. No Swift was edited.*

```
node tools/balance-sim-r12.js career=3 players=200                 # session 1, casual
node tools/balance-sim-r12.js career=3 players=200 plan=novice,novice,casual
node tools/balance-sim-r12.js career=60 players=60 plan=casual     # day 2 to day 30
node tools/balance-sim-r12.js career=6 players=200 plan=novice grace=0.8,0.85,0.9,0.95
node tools/balance-sim-r12.js windows=20 T.chainMax=8 bands=r12
```

Career seeds are `500000 + 7919·(player·1000 + run)`, so every run is a fresh Run seed. The default (non-career) output
of the copy is identical to `balance-sim.js`.

## Verdict in six lines
- **Day 1 is excellent.** A casual player gets a rank-up, a relic and a coin-flip at a new best on every one of the
  first three runs. No stretch of session 1 is dead.
- **Day 2 to day 5 is fine.** Relics come at about 1 per run until the Codex is full (casual run 25), and ranks come
  every 3 to 6 runs.
- **There is a content cliff at about run 25 to 28, which is about an hour of play, or day 5 to 7 at 4 to 5 runs a
  day.** After that a casual player gets 0 relics, about 0 badges, a rank-up every 14 to 19 runs, and a new best on 1 to
  3 % of runs.
- **The Daily Dungeon is the only day-30 hook, and today it is thin.** It has one seeded try, no streak, no modifier
  and no in-app way to see today's board: the Game Center tile opens the generic dashboard.
- **The mastery ceiling is flat.** Perfect play scores 1.6 % more than expert. The Hush Chain caps at ×1.5 on chest 5,
  but masters chain 12 to 13 chests. So in the second half of a master's run the chain can only be lost.
- **Fix with meta and copy, plus one tuning number:** a Daily streak with a link to today's board, a seeded Daily twist,
  chain cap 5 → 8, a "next goal" line on Results, and a tapered beginner's grace. Each is described in §6.

---

## 1. Session 1: the first three runs

**Casual pilot (200 players).** Each value is an average per player, except gold, which is the median.

| Run | Gold (median) | Rank-ups | New relics | New badges | New best | Bites | Hushed |
|---|---|---|---|---|---|---|---|
| 1 | 5,559 | 2.08 | 1.08 | **6.04** | – | 0 | 1.7 |
| 2 | 5,353 | 0.96 | 0.97 | 0.51 | 0.49 | 0 | 1.7 |
| 3 | 5,546 | 0.89 | 1.03 | 0.26 | 0.39 | 0 | 1.8 |

**When the first of each thing lands.** Each cell is the share of players who reach it within 3 runs, then the median
run among them.

| Milestone | Casual | Novice, novice, casual (a learner) |
|---|---|---|
| Rank 2 Cutpurse / Rank 3 Sneak | 100 % run 1 / 100 % run 1 | run 1 / run 2 |
| Rank 4 Lockpick / Rank 5 Cat Burglar | run 2 / 94 %, run 3 | 92 %, run 3 / – |
| First relic (the first Codex page) | 98 %, run 1 | 83 %, run 2 |
| First golden mimic seen / banked | 84 % / 79 %, run 1 to 2 | 82 % / 62 %, run 2 to 3 |
| First Hush Chain of 2 or more (the Results chain line) | 60 %, run 2 | **30 %, run 3** |
| First bite | 0 % (the pilot freezes perfectly) | 100 %, run 1 |

**What this shows:**
- There is no dead stretch, but run 1 hands out half the badges at once: First Haul, Not a Peep, Light Fingers, Heavy
  Bag, Untouchable and Relic Hunter, so the Badges page reads 6 of 12 after two minutes. The six that remain are:
  - Midas Touch (luck, run 2);
  - Dragon's Hoard (8,000, a skill check);
  - Hush Chain (5 in a row: 10 % of casual players by run 60);
  - Curator (run 12);
  - Keeper of Curiosities (run 25);
  - A Small Fortune (run 10).

  That is a decent ladder, but nothing tells the player which rung is next (change 4).
- The **chain is invisible to learners**: 70 % of them never see a chain of 2 in session 1.
  - The "Hush Chain! Sleepy banks pay more" tip is the hook that sells mastery, and most players meet it late.
- **The novice is the real day-1 churn risk.** They take 3.5 bites a run and lose 1,684 gold to bites, which is *more
  than they bank* (1,589). Frame 19 shows it: "The mimic bit you 5 times…".
  - The R11 Forgiving nudge is the right safety net. But it waits for a bad Results screen.
- **The stale comment in `Ranks.swift`** says a first session makes "about 1.6k, 2.5k, 3.9k gold", which is
  R2-era. R7's real hands make about 5.3k per casual run, so run 1 gives 2 ranks. That is fine for the feel, but fix the
  comment.

## 2. Mid-term: is it enough for a week?

**Casual career, 60 players × 60 runs**, with the median run on which each milestone lands:

| Milestone | Run | Milestone | Run |
|---|---|---|---|
| Rank 6 Shadow | 5 | Codex 6 / 12 / 18 / **24** | 6 / 12 / 18 / **25** |
| Rank 7 Vault Diver | 8 | A Small Fortune (50k) | 10 |
| Rank 8 Gem Fancier | 13 | Dragon's Hoard | 14 (72 % by run 60) |
| Rank 9 Night Raider | 19 | Hush Chain badge | 30 (**10 %** by run 60) |
| Rank 10 Master Thief | 28 | Rank 11 / **Rank 12 Mimic Whisperer** | 40 / **59** |

**Per-run reward density** (casual):

| Runs | Rank-ups per run | New relics per run | New badges per run | New best per run |
|---|---|---|---|---|
| 7–10 | 0.25 | 0.94 | 0.34 | 0.13 |
| 11–20 | 0.20 | 0.98 | 0.12 | 0.07 |
| 21–30 | 0.10 | 0.43 | 0.09 | 0.04 |
| 31–45 | 0.07 | **0** | 0.01 | 0.03 |
| 46–60 | 0.06 | **0** | 0 | 0.01 |

**The other careers:**
- **Expert:** the Codex is full on run 11 and the top rank comes on run 28.
- **Learner** (novice, then casual, then expert from run 9): the Codex is full on run 16 and the top rank comes on run 33.

**Answer:**
- **24 relics, 12 ranks and 12 badges cover a week only for a casual player who plays about 4 runs (10 minutes) a
  day.** A skilled player is done with the Codex on day 2 or 3.
- About one hour of meta content is the right size for £1.99. The problem is that after it, **only the rank bar moves,
  and it slows to one rank-up every 14 to 19 runs.**
- What brings someone back on day 7 and day 30 has to be the **Daily** and **mastery**. Adding relics would need new
  art, and it would only postpone the cliff.
- Rank pacing beyond session 1 is a good shape (gaps of 3, 5, 6, 9, 12 and 19 runs). Leave the thresholds alone.

## 3. The Daily Dungeon: a reason to play every day?

What the code has today (`DailyView`, `ProgressRules`, `GameCenterManager`):

| Has | Missing |
|---|---|
| One scored try, then practice. A UTC reset that matches GC's recurring board. A "new dungeon in 5h 12m" line. The best Daily ever. A per-day record in `ProgressData.daily` and a `dailyAttempted` set. | **No streak.** **No modifier**: every day plays like a Run on another seed, and REVIEW-1's "Daily twist" was never built. **No in-app board**: the Home trophy opens the generic GC dashboard, and the Daily page has no link to *today's* ranks. No "yesterday you scored X" line. |

**Why it matters:**
- "Same seed as everyone" is only felt when you can see everyone.
- "A new dungeon tomorrow" is only felt if tomorrow's dungeon is *different*.
- The data for a streak already exists (`dailyAttempted`), so a streak costs no save change.
- Changes 1 and 2 fix all of this.

## 4. Mastery ceiling

| Skill | Gold (40 seeds) | Best chain | Chain gold | Hushed / banked |
|---|---|---|---|---|
| casual | 5,353 | 1 | 38 | 1 / 10 |
| expert | 11,414 | 12 | 3,507 | 12 / 13 |
| perfect | 11,597 (**+1.6 %**) | 13 | 3,731 | 13 / 13 |

**Skill expression beyond "be slow":**
- It does exist, but it is subtle:
  - ride just under the quiet lines (14°/s opening, 28°/s closing);
  - leave copper once the bag jingles, and bank at the jingle floor;
  - judge the relic reach against the candle, and take oil late in the run.
- Those skills show up as *speed*, and speed means more chests.
- Today the Daily board between masters is decided by a few seconds and by the rare stir.

**Is the Hush Chain the right lever? Yes, but it saturates too early.**
- The cap ×1.5 arrives on chest 5, at about 55 s into a 145 s run.
- After that a master's chain has no upside, only a reset.
- A break at chest 10 costs about 1 chest of value (the climb from ×1.1 back to ×1.5), whatever the chain was.
- **Raising the cap to 8 (×1.8) keeps the stake rising until chest 8** (about 90 s in), so a late stir really hurts.
  That loss is the "I had ×1.7 going…" feeling that sells the next run.
- It changes nothing for casual players or novices: their chains are 0 to 1.

## 5. Friction: what makes a player stop?

| Candidate | Finding | Severity |
|---|---|---|
| **Bites feel unfair?** | No. The meter, tongue and stage live on the sharp floor half. The name plate shows the personality ("Dreamer · Wooden", frame 26). A slam is clearly the cause. **But the novice loses more gold to bites than they bank**, and the first bite comes on run 1 for 100 % of them (chest 1 for 18 %). | **Medium** (day-1 churn for the bottom third) |
| Run length | Novice 101 s, casual 139 s, expert 147 s. That is right for "one more". | None |
| Results to Again | The candle-out moment is 2.0 s, then a 0.5 s beat, then the count-up, which takes at most 1.8 s. **Again is live at once** and is the primary button (frame 21). Again → chest 1 needs the lid eased shut, which is about 2 s and natural. | None |
| Results tone on a bad run | "Bitten 5 times: 2,368 gold went down the hatch" is honest, but it ends the run on the loss. The Forgiving nudge sits above it. | Low (change 4 adds a forward-looking line) |
| Codex done, no more relic excitement | A relic is just 250–450 gold after run 25. | Medium, from day 5 to 7 |
| Daily has no pull | See §3. | **High** for day 7 and day 30 |
| `GAME-DESIGN.md` §4 still says oil +8 s and bite −15 s | Tuning is 6 / 10. This is a docs-only error. | Docs |

## 6. Five small changes, in priority order

### Change 1: a Daily streak, plus "See today's board" (meta and copy; no art)
- **Change:**
  - **`Hush/Persistence/ProgressStore.swift`:** add a pure
    `ProgressRules.dailyStreak(_ data: ProgressData, today: Int) -> Int`. It counts consecutive days in
    `dailyAttempted` ending at `today`, or at `today − 1` if today isn't played yet, so the streak isn't "lost" before
    the player has had a chance. This needs no new save field.
  - **`Hush/UI/Pages.swift` `DailyView`:** add a line under the hero, using the SF Symbol `flame.fill` in
    `HushTheme.gold`:
    - "4 nights in a row" when the streak is 2 or more;
    - "Keep your 4-night streak: one try tonight" when today is unplayed.
  - **`Hush/UI/HomeView.swift` `dailyStatus`:** append " · 🔥4" (rendered as the symbol, not the emoji).
  - **`ResultsView` title for a scored Daily:** "Daily Dungeon · 28 Oct · night 4".
  - **`GameCenterManager.swift`:** add `showDailyBoard()`. It calls
    `GKAccessPoint.shared.trigger(leaderboardID: Leaderboard.daily, playerScope: .global, timeScope: .today)` (on
    iOS 17 or older use `GKGameCenterViewController(leaderboardID:playerScope:timeScope:)`), with the same sign-in and
    `onDismiss` path as `showDashboard`.
  - **Buttons:** add a "See today's board" button on the Daily page after the scored try, and one on Results for a
    scored Daily.
- **Expected effect:** the cheapest proven day-7 and day-30 lever, a streak loss-aversion loop on a habit that is
  already there (one try a day). Seeing the board makes "the same chests for every thief today" real.
- **Risk:**
  - Balance and determinism: **none**. It reads the save; no deal or rule changes.
  - The UTC boundary means a 4–5 pm reset on the US west coast. Count the streak by the same `DailyClock` day as the
    one-try rule, so the two can never disagree.
- **Art:** none (an SF Symbol).

### Change 2: the Daily twist, one seeded "night" per day (Core rules plus copy; no art)
- **Change:**
  - **The enum:** add `enum DailyTwist: Int, CaseIterable` in `Hush/Core/DailySeed.swift`, with
    `static func forDay(_ day: Int)`. It uses `SeededRandom(seed: DailySeed.seed(day: day) ^ 0x7A157).next() % 6`; if
    that equals yesterday's twist, it steps +1, so the rule stays deterministic.
  - **The plumbing:**
    - `SessionOptions.for(.daily(day, _))` carries the twist. It applies to both the scored try and practice, and
      never to a Run, the lesson or attract.
    - `ChestFactory.chest(seed:index:found:rules:)` gets a `DealRules` parameter that defaults to Tuning.
    - `HeistSession` reads `torchSeconds` and `decayScale` from the options.
  - **The copy:** one line on the Daily page, the run banner and the Home Daily status, e.g. "Tonight: Gold Rush".
  - **The six nights.** Simulated with T overrides, 40 seeds, medians, novice / casual / expert gold. A plain Daily
    is 1,589 / 5,353 / 11,414.

    | Night | Rule (Tuning knob) | Novice | Casual | Expert | Feel |
    |---|---|---|---|---|---|
    | A Quiet Night | none | 1,589 | 5,353 | 11,414 | the baseline |
    | Gold Rush | `goldenChance` 0.06 → 0.25 | 1,465 | 5,734 | 12,885 | jackpots everywhere, more risk |
    | Deep Pockets | `relicChance` 0.25 → 0.50 | 1,757 | 5,925 (2 relics) | 12,997 (4 relics) | Codex hunters come back |
    | Short Wick | `torchSeconds` 100 → 80 | 1,084 | 3,981 | 8,117 | a tight, tense night |
    | Restless Night | every tier decay × 0.8 | 1,404 | 4,719 | 11,196 | it rewards control (−12 % casual, −2 % expert) |
    | Sleepy Dungeon | Heavy weight 0.20 → 0.50, Light 0.25 → 0.10 | **2,842** | 5,934 (Hushed 3.5) | 10,719 | a gentle night; novices thrive |

- **Expected effect:**
  - Six different dungeons a week give a reason to *look* every day, not just to play.
  - Deep Pockets nights pull Codex players back. Sleepy nights rescue novices.
  - Restless and Short Wick nights give masters a board that separates them.
- **Risk to determinism:**
  - Every knob only changes a *comparison* on numbers that are already drawn, or a session constant.
    - The golden roll is on its own stream.
    - The mimic weights only move the `u` thresholds.
    - The torch and the decay are session constants.
  - Deep Pockets changes which chests hold a relic, so it changes the item list. It is still a pure function of
    (day, index), so it is **identical for everyone**.
  - The scored try is still forced to Normal sensitivity.
  - **Guard test:** `.quiet` and every Run deal are bit-identical to today's `ChestFactory` for 200 seeds, so
    BalanceTests are untouched.
- **Risk to balance:** "Your best Daily" becomes partly a twist lottery. Label it "Best Daily (any night)". The GC
  board is recurring daily, so scores are never compared across nights there.
- **Art:** none; a text plate.
- This is the largest of the five. If it doesn't fit, ship Quiet, Gold Rush, Short Wick and Sleepy first. Those four
  don't touch the item list.

### Change 3: Hush Chain cap 5 → 8, i.e. ×1.5 → ×1.8 (one tuning number)
- **Change:**
  - **`Hush/Core/Tuning.swift`:** `chainMax` 5 → **8**, with `chainStep` 0.10 kept.
  - **`tools/balance-sim.js` and the BalanceTests bands:**
    - expert gold 8,000–14,000 → **8,000–16,000**;
    - perfect 8,500–15,000 → **8,500–17,000**;
    - any `r2TuningNumbers` assertion on 5 or ×1.5 moves to 8 / ×1.8.
  - **What stays:** the Hush Chain *badge* stays at 5 in a row (`bestChain >= 5`): replace the
    `Tuning.chainMax` reference in `Achievements.earned` with a literal 5 or a new `Tuning.chainBadge = 5`. Its copy is
    unchanged.
- **Before → after:**

  | Run | Novice | Casual | Expert | Perfect |
  |---|---|---|---|---|
  | 40 seeds | 1,589 → 1,589 | 5,353 → 5,353 | 11,414 → **12,719 (+11 %)** | 11,597 → **13,243 (+14 %)** |
  | CI window, 8 seeds | | | 11,328 → 12,909 | 11,076 → 12,632, all checks PASS |

  - Robustness, `windows=20`:
    - the current bands: 3 of 20 windows fail → 5 of 20, because expert goes above 14k;
    - the widened bands (`bands=r12`): **3 of 20, exactly the baseline's own failures** (novice ≥ 1,000 and perfect ≥
      0.95 × expert).
  - Perfect/expert goes from 1.016 to 1.041. The casual-to-expert gap goes from 2.1× to 2.4×.
- **Expected effect:**
  - The stake keeps rising through the back half of a master's run.
  - A late stir now costs 2 to 3 chests' worth, not 1. That is the leaderboard-chaser's "one more go".
- **Risk:**
  - Daily determinism: none; it is a rule, not a deal.
  - Expert and perfect rank pacing gets about 10 % faster (top rank around run 25 instead of 28).
  - The HUD pill and the Results chain line read the multiplier from Core (`AppRules.chainGold`), so no layout change
    is needed. The pill must fit "×1.8".
- **Art:** none.

### Change 4: a "next goal" line on Results (copy only)
- **Change:**
  - **`Hush/App/AppRules.swift`:** add a pure `AppRules.nextGoal(progress:result:) -> String?`. It returns the
    *closest* unmet goal, in this order:
    1. relics: "3 more relics for Curator" when the next Codex badge is ≤ 3 away;
    2. rank: "1,240 gold to Shadow" when that is under about one run's gold;
    3. chain: "Longest chain 3 · five in a row earns Hush Chain", when `bestChain` is 2–4 and the badge is unearned;
    4. Hoard: "1,900 short of Dragon's Hoard", when the run made at least 6,000 and the badge is unearned;
    5. otherwise the rank line with its number.
  - **`Hush/UI/ResultsView.swift`:** show it in the rank row in place of "Next: Shadow", as
    "Next: Shadow · 1,240 gold", or under the story as one caption line.
  - **`Hush/App/GameController.swift` `makeSummary`:** fills it.
- **Expected effect:**
  - A goal gradient for runs 4 to 30, where rewards thin out (badges drop to 0.1 a run).
  - A bad run ends on "what's next" rather than "what you lost".
  - It names the Hush Chain badge, which only 10 % of casual players ever chase on their own.
- **Risk:** none to balance or determinism. One more line on Results: test at AX sizes (frames 41 and 45 style).
- **Art:** none.

### Change 5: a tapered beginner's grace (App only; Run mode only)
- **Change:**
  - **`GameController` `start(_:)`:** for `.run` when `store.data.runs < 4`, multiply the session's `noiseScale` by
    **0.80 / 0.85 / 0.90 / 0.95** for runs 1 to 4. `SessionOptions(noiseScale:sensitivity:)` already multiplies.
  - **The guards:**
    - never for a Daily, scored or practice;
    - never when the player chose Careful;
    - never in the lesson (it keeps 0.6).
  - **The copy:** none. It is invisible, as core-R7 "Not done" suggested.
  - **The taper is the point.** A flat 3 × 0.8 makes a cliff: novice gold falls 3,416 → 1,600 (−53 %) between runs 3
    and 4 in the static-skill sim. The taper spreads it over four runs (3,178 / 3,045 / 2,587 / 2,010 / 1,767), and a
    real player's learning fills it.
- **Before → after:** novice pilot, 200 players.

  | Run | Gold | Bites | Hushed |
  |---|---|---|---|
  | 1 | 1,785 → **3,178** | 3.5 → 2.5 | 0.5 → 1.35 |
  | 2 | 1,586 → 3,045 | | |

  - The casual pilot's run-1 Hushed goes from 1.7 to 4.0, so the first chain and its tip land on run 1 for most
    players.
- **Expected effect:**
  - The bottom third keeps a first bite (2.5 a run is still comic CHOMPs), but banks double.
  - More of them reach run 4, where learning takes over.
  - Fewer players need the Forgiving nudge.
- **Risk:**
  - None to the Daily or the leaderboards. Best Haul could get an early inflated best, but at 3k it is below any
    casual run.
  - The founder's real-Duo tension check should be done with runs ≥ 4 (or a fresh install, noting the grace).
  - This is the most debatable of the five. Drop it first if the device test says run 1 already feels right.
- **Art:** none.

### Not proposed (and why)
- **More relics or ranks:** they need art, and they only move the cliff.
- **Re-thresholding badges to spread the run-1 dump:** the Game Center ids would be unchanged, but the ASC achievement
  text would need re-entry, and real players are noisier than the casual pilot, so the dump is likely smaller. Change 4
  addresses the "what next" gap instead.
- **Relic chance down:** it would make the Codex last longer, but it costs the best moment in a run.

## 7. Watch on TestFlight
- **Day-1 bites per run for new installs:** target 1.5–2.5, with the grace.
- **Share of players who see a chain of 2 or more by run 3:** target ≥ 60 %.
- **Scored-Daily days per player in week 1:** a streak of 3 or more is the signal that change 1 works.
- **Runs-per-day decay around runs 25–30:** the Codex cliff.
