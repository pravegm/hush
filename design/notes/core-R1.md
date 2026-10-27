# Core engineer, Round 1: hand-off

## What I built
Everything in ARCHITECTURE "Core API", with the exact signatures, in `Hush/Core/`. All of it is plain Swift, Foundation +
CoreGraphics only, with no actor isolation and no access modifiers (internal: one module).

| File | What's in it |
|---|---|
| `Tuning.swift` | Every number from GAME-DESIGN §3–§6, documented, plus the lesson gate numbers (pose 95–125° for 0.5 s, stir 0.55, freeze 1.5 s) and `sliderShutZoneOpenness` 0.15 for the slider. |
| `SeededRandom.swift` | SplitMix64 (`next`, `unit`, `range`, `int(ClosedRange)`, `chance`). `int(7...7)` returns 7 without drawing. |
| `Noise.swift` | `lidRate`, `dragRate`, `stage(for:previous:)` (hysteresis 0.04), plus `threshold(_:)` and `multiplier(for:)`. |
| `Lid.swift` | `openness(angle:)`, `angle(openness:)`, plus `Lid.input(angle:speed:)` and `Lid.input(openness:speed:)`, which build a `LidInput` with the shut zone (θ ≤ 110) and too-wide (θ > 172) flags. |
| `Catalogs.swift` | `RelicCatalog` (24 relics: the 12 shapes twice, each with a name, blurb and tint; `ids`; an unknown id returns a placeholder) and `MimicNames` (10 per kind, `names(for:)`). |
| `ChestFactory.swift` | `chest(seed:index:found:)`, `tier(forIndex:)`, `multiplier/decay/itemCount/radius(for:)`, `rank(_ tier)`, `chestSeed`, `place(...)` and `lessonChest()`. |
| `HeistSession.swift` | `SessionOptions` (with `.for(mode)`) and `HeistSession`. |
| `DailySeed.swift` | `dayNumber(for:calendar:)` (default `.current`, per the contract) and `seed(day:)`. |
| `Ranks.swift` | `ThiefRanks` (12 ranks), `AchievementDef` and `Achievements` (12). |
| `ThiefPilot.swift` | `PilotSkill`, `PilotTouch`, `PilotOutput`, `PilotProfile` (the per-skill table) and `ThiefPilot`. |

There are also the tests (`HushTests/CoreTests.swift`, `BalanceTests.swift`) and `tools/balance-sim.js`, a line-by-line
Node port of the factory, session and pilot.

## Final tuning
**Every GAME-DESIGN starting value is kept unchanged.** The sim met all the ROUND-1 targets with them, so I changed
nothing.

| Group | Values |
|---|---|
| Lid | shut 100°, wide 165°, shut zone ≤ 110°, too wide > 172°, closing < 85° for 0.4 s |
| Lid noise | quiet 8 °/s, loud 30 °/s, rate 0.006(ω−8) + 0.00035(ω−8)² |
| Drag noise | silent ≤ 250 pt/s, 0.0006 per pt/s above that |
| One-off noise | pick 0.02, bag 0.03, drop 0.08 |
| Decay | grace 0.4 s; a rate ≤ 0.01/s counts as quiet; restlessness max(0.5, 1 − 0.02 t) |
| Stages | 0.35, 0.70, 1.0; hysteresis 0.04; caps at 0.99 when it can't bite |
| Mimics | ×1.0 snorer, ×1.35 light sleeper, ×0.7 heavy sleeper (one item fewer), ×1.0 dreamer (twitch every 4–9 s) |
| Deal weights | snorer 0.35, light 0.25, heavy 0.20, dreamer 0.20; chest #1 is never a light sleeper |
| Tiers | ×1 / ×1.5 / ×2 / ×3; decay 0.14 / 0.12 / 0.10 / 0.085; items 5–6 / 6–7 / 7–8 / 8–9 |
| Loot | copper 5–10 (depth 0–0.45, 2–3), silver 20–35 (0.2–0.6), gem 60–110 (0.45–0.8, 1–2), relic 250–450 (0.84–0.92, 35 % of iron+ chests), oil +8 s (0.25–0.55, 33 % of chests) |
| Radii | coin 22, silver 24, gem 26, relic 34, oil 24; gap ≥ 6 pt |
| Torch | 100 s, oil +8 s, bite −15 s, `torchLow` at 15 s |
| Banking | shut hold 0.35 s; moments: bank 1.4 s, bite 1.8 s, torch out 2.0 s |
| Light | ramp 0.10, reveal at 0.4, grabbable at 0.6 |
| Thresholds | looting starts > 0.02, `lidCracked` > 0.05, grab slop 14 pt |

New numbers, all mine and all in Tuning:
- Drag speed: smoothing 0.06 s; still after 0.06 s without a move, then decays with τ 0.1 s.
- Placement: jitter ±60 pt, 60 tries, then a 12 pt grid scan.
- Bag slots: x = 110 + 50·k, y = bagMinY + 55 (one row of 10, which is more than the maximum of 9 items).

## Balance (tools/balance-sim.js; seeds 1000 + 7919·i, 60 Hz; the same harness as BalanceTests.swift)

| Skill | n | Gold (median) | p10–p90 | Run (s) | Chests banked | Bites | Hushed | Relics |
|---|---|---|---|---|---|---|---|---|
| novice | 8 | 561 | 178–1098 | 76 | 2.5 (1–5) | 4 (max 4) | 0 | 0 |
| casual | 8 | 2,585 | 2439–2750 | 132 | 7 (7–8) | 0 | 0 | 0 |
| expert | 8 | 4,882 | 4234–5887 | 138 | 9 (8–11) | 0 | 7 | 2 |
| perfect | 8 | 6,122 | 4952–7410 | 137 | 10.5 (9–12) | 0 (max 0) | 8 | 2 |
| casual | 40 | 2,525 | 1830–3299 | 136 | 7 (6–9) | 0 | 0 | 0 |
| perfect | 40 | 6,113 | 4575–7386 | 142 | 11 (7–13) | 0 (max 0) | 9 | 2 |

Every target passes:
- **Gold order:** novice < casual < expert ≤ perfect, with perfect about 25 % ahead of expert.
- **Casual:** banks 7 chests (target 4–8) in a 132 s run (target 90–160).
- **Novice:** bitten 4 times per run (target ≥ 1).
- **Perfect:** bitten 0 times in 40 seeds.
- **Attract:** it runs forever with every skill. Expert banks about 36 chests in 600 s; noise caps at 0.99 and nothing
  bites.

**BalanceTests assertions** (all on medians):
- `novice < casual < expert`, and `perfect ≥ 0.95 × expert` (5 % slack on the brief's "expert ≤ perfect");
- casual banks 4–8 chests and runs 90–160 s; novice bites ≥ 1; expert bites ≤ 1;
- perfect's maximum bites == 0; no run hits the 10 min cap.

`HUSH_BAL_SEEDS` overrides the default of 8 seeds. Lines print as `HUSH-BAL skill=…`.

**Why the pilots differ.** The skill gap is not mainly lid speed: an expert's 5–9 °/s is slower than a casual's 8–16.
What makes the expert better:
- **Two hands:** experts drag lit items while the lid is still opening.
- **Silent drags:** experts drag at or below 250 pt/s.
- **Relics:** experts reach for them; casual and novice never do.
- **Freezing early:** experts freeze at Stirring, casual players at Waking.
- **Banking before torch-out:** experts bank early when the torch would go out first.

Casual drags at 450–800 pt/s. So the mimic stirs in most casual chests and the casual pilot freezes at Waking, which
is the intended drama. That also gives casual 0 Hushed on median.

Novice:
- slams in 30 % of chests (70–120 °/s);
- obeys a freeze only half the time;
- drags at 700–1200 pt/s and drops 15 % of them.

## How the session behaves (where the docs left room)
- **The first event:** `chestArrived` for chest #0 comes out of the **first `step`**, because `init` can't return events.
  Events from `nudgeNoise` also come out on the next step (its stage changes at once in the snapshot).
- **Ready:** light is 0 and nothing can be grabbed until looting starts. Noise integrates in `.ready` too (easing
  a slammed lid down is heard), but **only `.looting` can bite**; elsewhere noise caps at 0.99.
- **Grab rule:** I followed ARCHITECTURE's rule, grabbable at light ≥ 0.6, which is openness ≥ depth + 0.06.
  - GAME-DESIGN §4 says d + 0.10, which would make a 0.92-deep relic impossible to grab (it would need openness 1.02).
  - **Founder:** please make GAME-DESIGN §4 agree.
- **Mimic multipliers:** the multiplier × `noiseScale` applies to **every** source: lid, drag and the one-off amounts.
- **Drag noise:** each held finger adds its own `dragRate`. The `dragSpeed` property reports the fastest.
  - Speed comes from successive `touchMoved` positions and times, smoothed. Moves less than 0.1 ms apart only move the
    item.
  - A finger with no move for 0.06 s (session time) decays towards 0.
- **Touch times:** only differences matter, so any monotonic clock works. `UITouch.timestamp` is fine; the pilot
  harness passes accumulated dt.
- **Dropping and bagging:**
  - Any let-go with `y ≥ FloorSpace.bagMinY` bags the item; elsewhere the item drops to the nearest spot inside
    `interior`, inset by its radius.
  - Oil adds +8 s at once when bagged, and also to `torchTotal`.
  - A bite or torch-out loses the bag and any held items. A held item when the bank fires stays behind in the chest.
- **Bank moment:** `shutHold` reads 1 during it and resets to 0 at the next chest.
- **Stage reset:** the next chest resets noise to 0. If the stage wasn't Asleep it emits
  `stageChanged(→ .asleep)` (after a bite, `biting → asleep`) **before** `chestArrived`.
- **newBest** fires only if `bestRun > 0`.
- **Event order:**
  - Bite: `stageChanged(→ biting)`, then `bitten`.
  - Bank: `banked`, then `relicFound` for each relic, then `newBest`.
- **Hints:** these are worked out in `snapshot` (so they also follow touches).
  - `openSlowly` shows in `.ready` with the lid shut, and in `.looting` before anything has been revealed.
  - There is no hint in the bank, bite or torch-out moments.
- **Results:**
  - `chestsOpened` counts chests that reached `.looting`.
  - `itemsBagged` counts every item bagged, including ones lost later.
  - `highestTier` includes the chest the torch went out on.
- **Attract and lesson:** they never finish. The lesson repeats its fixed chest, re-indexed, after each bank.
- **The lesson chest** (`ChestFactory.lessonChest()`, and `SessionOptions.for(.lesson).fixedChest`):
  - Heavy Hugo (a heavy sleeper), wooden.
  - Copper 6 at depth 0.05, copper 8 at 0.12, silver 25 at 0.28, ruby 80 at 0.45.
- **Achievements** (ids `hush.ach.<key>`): attract and lesson runs earn nothing. The keys are firsthaul, notapeep,
  firstrelic, fivechests, royal, heavybag, hoard, untouchable, hushhush, curator, fullcodex and fortune.
- **Thief ranks:**
  - Thresholds: 0, 500, 1.5k, 3.5k, 7k, 12k, 20k, 32k, 50k, 75k, 110k, 160k.
  - Titles: Pickpocket → Mimic Whisperer.

## For the other engineers
- **App (driving a pilot)** each frame:
  1. Call `out = pilot.step(dt:snapshot: session.snapshot)`.
  2. Feed `out.touches` to `session.touchBegan`, `touchMoved` and `touchEnded`, in order.
  3. Call `session.step(dt:lid: out.lid)`.

  This is the order `BalanceTests.runOne` uses. Pilot touch ids start at 900001. On a phase change the pilot ends any
  drag, and the session ignores that.
- **Feel (slider):** `Lid.input(openness:speed:)` gives a ready-made `LidInput`. Its shut zone is θ ≤ 110°, which is
  openness ≤ 0.154. If you want the contract's slider shut zone of exactly 0.15, use `Tuning.sliderShutZoneOpenness`.
- **Scene:**
  - Loot positions are in floor space. Bag slots sit in one row at y = 401.
  - The lid-art twitch is `.dreamTwitch`.
  - `LootState.light` is 1 for held and bagged items. Lost items keep their last position.
- **The sim:** `node tools/balance-sim.js [seeds=N] [skills=a,b] [verbose=1] [T.<tuning>=value]`. Keep it in sync with
  any Core rule change.

**Not verified:** none of this has been compiled yet (no Mac here). The first CI run is the check.
