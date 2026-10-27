# Core engineer, Round 2: hand-off

## What changed
Everything in ROUND-2 "Core engineer" plus the Core part of QA-1. Files: `Hush/Core/` (Tuning, Noise, Catalogs,
ChestFactory, HeistSession, ThiefPilot, Ranks), `HushTests/CoreTests.swift`, `HushTests/BalanceTests.swift`,
`tools/balance-sim.js`. `tools/balance-sim-r2.js` (the reviewer's copy, with its `r1=1` baseline) is kept as the
reference.

| Area | Change |
|---|---|
| Tuning | REVIEW-1-feel §5 changes 1–10, as numbered (table below). Relic depth 0.80–0.88 (Duo P1-9). `closingAngle` 85 → 70 and lesson pose 90–112° (Duo P0-2/P1-6; Feel and App read these). |
| A. Hush Chain | A Hushed bank adds 1 and pays ×(1 + 0.1·min(chain, 5)). `chainUp(count:multiplier:)` comes right after `banked`. The chain breaks **the moment the mimic leaves Asleep** (a stir, or a bite from Asleep), because that chest can no longer be Hushed. The gold is the same as the sim's break-at-bank rule. `chainBroken(count:)` fires only for a chain of ≥ 2; a chain of 1 resets silently. |
| B. Golden mimic | 6 % per chest from index 2, from its own stream (`chestSeed ^ 0x601DE7`), so every other draw and the Daily are unchanged. `ChestSpec.golden`. **`ChestSpec.multiplier` includes the ×2** (tier × 2). Noise ×1.25 on every source. Gold names (`MimicNames.goldenNames`: "Midas Mo", …). `ChestFactory.isGolden(seed:index:)`. |
| C. Relic glimmer | `HeistSession.relicGlimmers(depth:openness:)`: a relic in the chest glimmers while openness ≥ glint line − 0.25 and < glint line (glint line = depth + 0.04, where `itemRevealed` fires). It drives `.relicDeeper`; the Scene should use the same helper for its twinkle. |
| D. Bag jingle | Decay stops at `Noise.jingleFloor` = min(0.30, 0.035 × items × the chest's noise multiplier). It never raises the noise. `snapshot.noiseFloor` is that value in .ready/.looting, and 0 in the moments. |
| `rest(dt:)` | `@discardableResult`, returns `[HeistEvent]`. Only in .ready/.looting (otherwise it returns `[]` and nothing moves). Noise decays after the usual 0.3 s grace, at the tier rate × the current restlessness, down to the jingle floor. The only events are `stageChanged`. There is no candle, no bite, no light, no time and no moments. `lidSpeed` reads 0 from the first call (QA P1-1). Held drags go still. |
| `resumeGrace(seconds:)` | Lid noise counts as 0 for that many seconds of **play** time (it ticks only in .ready/.looting). Drags and one-off sounds still count. `.slower` doesn't show during it. NaN or negative values are ignored; a shorter call never cuts a longer pending grace. |
| `biteCost(lostValue:seconds:)` | Right after every `bitten`. `seconds` is the candle actually taken: 10, or less if there was less left. |
| `chestLog` | One `ChestOutcome` per chest **opened** (that reached .looting). Banked: value incl. chain, hushed. Bitten: 0, `bitten`. Candle out while looting: 0. So `chestLog.count == chestsOpened`, and the sum of the values == gold (BalanceTests asserts both for every run). |
| `partialResult()` | QA P1-3. The `RunResult` so far; exactly `result` once finished. A chest being looted counts as opened, with a value-0 log entry. |
| `RunResult` | `bestChain` and `goldenBanked` are filled. `bestChestValue` includes the chain multiplier. |
| Snapshot | `chain`. `chainMultiplier` is **what the next bank pays**: ×1 once this chest has stirred, else 1 + 0.1·min(chain + 1, 5). So it reads 1.1 at chain 0, and in the bank moment it already shows the next chest's rate. For "Hush Chain ×1.3" on the badge, show `1 + 0.1·min(chain, 5)` or the `chainUp` multiplier while `chain ≥ 1`. |
| Hints | Priority: freeze > slower > **candleLow** > tooWide > easeLidDown > shutToBank > dragToBag > **relicDeeper** > openSlowly. `candleLow`: the candle burns, looting, loot in the bag, ≤ 15 s left. `relicDeeper` sits where the brief put it, so it shows only with an empty bag and nothing grabbable (the Scene's glimmer is the main cue). |
| Relics | 24 relics with 24 different shapes (relic01–12 unchanged; 13–24 renamed for candlestick … idol), and 24 different tints. |
| Ranks | `[0, 1k, 3k, 7k, 14k, 25k, 42k, 66k, 100k, 150k, 220k, 320k]`. |
| Achievements | Heavy Bag 3,000, Dragon's Hoard 8,000, A Small Fortune 50,000. `Achievements.midasTouch` ("Midas Touch", bank a golden mimic) replaces Royal Treatment. `Achievements.hushChain` ("Hush Chain", `bestChain ≥ 5`) replaces Hush Hush. **The keys stay `royal` / `hushhush`**, so the Game Center ids, the `Achievements.all` order and the badge slots are unchanged; only the titles and details change. |
| ThiefPilot | Ported from the R2 sim. Every skill unfreezes at max(unfreeze, floor + 0.04), so attract/CI never hang (sim: 33–52 banks per 600 s attract, 0 bites). Expert and perfect adapt: open × 12/8, close 13.5–18 (perfect 17.1), drags × 350/250, skip copper while anything better is wanted, bank at a floor of 0.20 / 0.22. Novice (50 %) and casual (60 %) are lured by a relic per chest, from one shared stream per skill. `PilotProfile.base` is the R1 table; `profile` adapts it. |
| QA-1 P2-14 | The session's touches are an array: no `Array(touches.keys)` per sub-step. |

## Final tuning (R2)
| Group | Values |
|---|---|
| Lid | shut 100°, wide 165°, shut zone ≤ 110°, too wide > 172°, **closing < 70° for 0.4 s** |
| Lid noise | **quiet 12 °/s; closing quiet 18 °/s**; rate **0.008·x + 0.0004·x²** (x = ω − quiet): 20 °/s → 0.09/s, 40 → 0.55/s, a 45 °/s open bites, a 120 °/s slam for 0.4 s → 2.2 |
| Drag noise | **silent ≤ 350 pt/s**, 0.0006 per pt/s above (1,000 pt/s → 0.39/s) |
| One-off | pick 0.02, bag 0.03, drop 0.08 |
| Decay | **grace 0.3 s**; tiers **0.16 / 0.14 / 0.12 / 0.10**; restlessness max(0.5, 1 − 0.02 t) |
| Stages | 0.35 / 0.70 / 1.0, hysteresis 0.04, no-bite cap 0.99 |
| Mimics | ×1.0 / ×1.35 / ×0.7 (one item fewer) / ×1.0; **golden ×1.25 noise, ×2 loot, 6 % from chest #3** |
| Loot | copper 5–10 (0–0.45), silver 20–35 (0.2–0.6), gem 60–110 (0.45–0.8), **relic 250–450 at 0.80–0.88, 25 %** of iron+ chests, oil (0.25–0.55, 33 %) |
| Candle | 100 s, **oil +6 s, bite −10 s**, low at 15 s |
| Chain | **×1.1 per Hushed bank in a row, max ×1.5** |
| Jingle | **0.035 × items × multiplier, max 0.30** |
| Glimmer | **within 0.25** under the glint line |
| Bank | shut hold 0.35 s; moments 1.4 / 1.8 / 2.0 s |

## Balance (`node tools/balance-sim.js`, seeds 1000 + 7919·i, 60 Hz, the BalanceTests harness)
`tools/balance-sim.js` reproduces `balance-sim-r2.js` with the relic depth overridden to 0.80–0.88 exactly (every
median is identical), so the port of the new rules is faithful. R1's CI matched the R1 sim within 1 gold per median.

| Skill | n | Gold | p10–p90 | Chests banked | Bites | Hushed | Run (s) | Relics | Best chain |
|---|---|---|---|---|---|---|---|---|---|
| novice | 8 | 1,244 | 536–2,241 | 4 | 4 | 0 | 95 | 0 | 0 |
| casual | 8 | 3,803 | 3,230–5,008 | 8 | 0 | 2 | 131 | 1 | 1 |
| expert | 8 | 10,089 | 7,902–11,678 | 12 | 0 | 11 | 137 | 2 | 6 |
| perfect | 8 | 10,989 | 9,505–13,458 | 12 | 0 (max 0) | 12 | 137 | 2 | 12 |
| novice | 40 | 1,685 | 690–3,186 | 5.5 | 3 | 1 | 108 | 0 | 1 |
| casual | 40 | 3,958 | 2,925–5,067 | 8 | 0 | 2 | 131 | 1 | 2 |
| expert | 40 | 11,007 | 8,235–13,147 | 13 | 0 | 12 | 144 | 2 | 8 |
| perfect | 40 | 11,573 | 9,853–14,873 | 13 | 0 (max 0) | 13 | 144 | 2 | 13 |

This matches the R2 table (≈1,635 / 3,945 / 10,847 / 11,553). The shallower relics add about 1 %.

**BalanceTests** (medians; the same bands as `BANDS` in the sim):

| Skill | Gold | Chests banked | Bites | Hushed | Other |
|---|---|---|---|---|---|
| novice | 1,000–2,600 | 3–8 | 1–6 | | |
| casual | 3,000–5,200 | 5–10 | ≤ 0.5 | 1–5 | run 90–160 s |
| expert | 8,000–14,000 | 10–16 | ≤ 1 | 8–16 | best-chain median ≥ 3 |
| perfect | 8,500–15,000 | 10–16 | max 0 | 9–16 | |

Plus: novice < casual < expert, perfect ≥ 0.95 × expert, no run capped, and every chest log adds up.

**Robustness.** I ran `node tools/balance-sim.js windows=40` over 40 disjoint 8-seed windows (320 seeds).
- Every band holds in 36 of 40 windows. The 4 failures are all "novice ≥ 1,000": the novice 8-seed median ranges
  901–2,835, so the brief's ≥ 1,000 at 8 seeds is the tightest check.
- CI's window gives 1,244. Its 4th and 5th runs are 1,175 and 1,312.
- With `HUSH_BAL_SEEDS=40` every band passes in all 6 windows tried.
- Attract (`attract=1`) never stalls: 7–10 banks in 120 s and 33–52 in 600 s, with 0 bites.

Time use (40 seeds, median s): casual is frozen 3.1 s and expert 1.5 s (R1: 22 and 5.7). Expert closing takes 36.5 s
for 13 chests. The chain is worth 2,640 gold per expert run.

## For the other engineers
- **Scene:**
  - Glimmer: `HeistSession.relicGlimmers(depth:openness:)`. Golden: `chest.golden`, with `chest.multiplier` already ×2.
  - Bite callout: `biteCost`.
  - Chain badge: see the snapshot row above for what `chainMultiplier` means.
  - Strip: `chestLog`.
- **Feel:**
  - `Tuning.closingAngle` is now 70.
  - The creak's quiet line is `Tuning.quietSpeed` (12). While closing it is `Noise.quietSpeed(closing: true)` (18).
    `Noise.lidRate(speed:closing:)` is the truth.
  - Your FeelTests closing-gate case at 84° needs updating (84 is above 70 now).
- **App:**
  - Call `rest(dt:)` each paused frame; you may ignore its result.
  - Call `resumeGrace(seconds: 0.5)` on resume, and `partialResult()` on abandon.
  - The chain also runs in the lesson and attract (a Hushed lesson bank pays ×1.1). Say if the lesson should be
    exempt.
- **Launch lead:** `docs/appstore/achievements.md` and `asc-metadata.json` still say "Royal Treatment", "Hush Hush",
  2,000 / 5,000 / 25,000, and "relics in about 35 % of chests". The ids are unchanged.

**Not verified:** none of this has been compiled (there is no Swift toolchain here). The CI run is the check. Every
scenario-based CoreTest (seeds 131–201) was replayed through the JS port, and the outcomes the tests assume hold there.
