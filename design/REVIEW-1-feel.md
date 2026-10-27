# Review 1: game feel and push-your-luck

*Reviewer: game-feel / push-your-luck design pass. Read: GAME-DESIGN, core-R1, Tuning, HeistSession, ChestFactory,
ThiefPilot, Ranks, Catalogs, feel-R1 (speed estimator). Numbers are from `tools/balance-sim.js` (R1) and my copy
`tools/balance-sim-r2.js` (proposal). No Swift was edited.*

## Verdict in five lines
- The core verb is excellent and genuinely Duo-native. The R1 numbers make it **an execution test, not yet a
  push-your-luck game**. For anyone who moves under the creak, reaching deeper costs only time and carries no risk, so
  "always reach, always freeze" is the dominant strategy.
- **Dead seconds:** the R1 casual player spends **22 s per run (16 %) frozen, waiting for decay**. The expert spends
  **39 s (28 %) easing the lid shut**.
- **The 8°/s quiet line sits inside the hinge's measurement jitter.** A careful player at 9–10°/s hears phantom creaks.
  That is a feel bug more than a difficulty problem.
- **R1 has no mastery multiplier and no rare moments.** The casual pilot banks **0 relics and 0 Hushed chests per run**,
  so the Codex and "Not a Peep" are effectively closed to the median player.
- **Fix:** widen the quiet band, make closing quicker, speed up decay, and soften the torch sting. Add five small things:
  a Hush Chain, a golden mimic, a relic glimmer, a bag jingle and a Daily twist. The R2 sim passes every R1 target and
  the three new ones (table in §5).

---

## 1. Moment-to-moment: tense or slow?

### Where the time goes (R1, 40 seeds, median seconds per run)
This uses the new time-use breakdown in `balance-sim-r2.js`. A frame is put in exactly one bucket. "Moments" are the
bank, bite and torch-out animations. "Idle" is mostly the pilot's human-reaction pause after each drag.

| Skill | Run | Moments | Opening | Closing | Dragging | **Frozen** | Idle | s per banked chest |
|---|---|---|---|---|---|---|---|---|
| novice | 90 | 13.1 | 13.6 | 17.6 | 7.9 | 8.5 | 27.1 | 22.5 |
| casual | 136 | 12.0 | 28.3 | 26.8 | 15.8 | **22.0** | 28.6 | 19.4 |
| expert | 139 | 14.8 | 28.4 | **38.8** | 43.9 | 5.7 | 5.4 | 15.4 |
| perfect | 142 | 17.6 | 35.9 | 28.9 | 53.9 | 4.1 | 2.7 | 12.9 |

**The dead seconds, ranked:**
1. **Waiting for decay (casual: 22 s per run).**
   - Decay starts 0.4 s after the last sound. Speed reaches ~0 about 0.1–0.2 s after the lid stops (feel-R1: "still
     0.5 s after 10°/s reads 0.67–0.82").
   - At 0.14/s, getting from Waking (0.70) back to the casual unfreeze (0.50) takes **~1.9 s**. Getting back to Asleep
     takes **~3.2 s**.
   - Restlessness halves decay after 25 s in a chest, so those become 3.3 s and 6 s.
   - A held breath is great for 1.5–2.5 s and a chore at 4–6 s.
2. **Closing (expert: 39 s per run, 28 %).**
   - Closing makes no decisions: you shut 50–55° at 8–12°/s, which takes 4–6 s every chest.
   - It is the cash-out beat, and it should be the *quickest* careful move, not the slowest.
3. **The full-open crawl.**
   - A relic needs openness 0.94–0.98 (161–164°).
   - At an R1 expert's 5–9°/s, opening fully takes 7–13 s.
4. **After a bite** you must ease the lid back into the shut zone before the next chest lights. That is ~3 s of
   "settle" on top of the 1.8 s bite moment.
   - It is acceptable as a breather. I'd keep it.
5. **Chest arrival is fine.**
   - The next chest arrives already shut.
   - The first copper lights at o ≈ 0.10–0.20, which is under 1 s of opening.
   - The 1.4 s bank and 1.8 s bite moments are juice, not dead time.

### How fast will a real person move a hinge? (estimates)
| Situation | Typical speed |
|---|---|
| Opening a laptop lid naturally (90–120° in 0.4–0.8 s) | **150–250°/s** |
| Unfolding a foldable one-handed | 150–300°/s |
| Told "open it slowly", no feedback yet | **20–40°/s** (people make a "slow" move last 2–3 s) |
| Told "as slowly as you can", listening to a creak | **6–12°/s** mean, but stick-slip and finger tremor swing the instantaneous speed ±30–50 % |
| The hinge estimator at a true 10°/s with ±0.5° report jitter (feel-R1) | reads **8.1–12.3°/s** |

Noise from one full 65° open at a constant speed. This is a Snorer, with no decay while moving. A bite is 1.0.

| °/s | Time to open | R1 N | R2 N (open) | R2 N (closing) |
|---|---|---|---|---|
| 10 | 6.5 s | 0.09 | 0 | 0 |
| 12 | 5.4 s | 0.16 | 0 | 0 |
| 15 | 4.3 s | 0.26 | 0.12 | 0 |
| 20 | 3.3 s | 0.40 | 0.29 | 0.06 |
| 25 | 2.6 s | 0.53 Stirring | 0.45 Stirring | 0.20 |
| 30 | 2.2 s | 0.65 Stirring | 0.59 Stirring | 0.33 |
| 40 | 1.6 s | 0.89 Waking | 0.87 Waking | 0.60 |
| 45 | 1.4 s | **1.01 bite** | **1.01 bite** | 0.73 |
| 120°/s slam for 0.4 s | | 2.0 bite | 2.2 bite | 2.0 bite |

**Answers:**
- **Is the default human "just too loud"? Yes, in both R1 and R2.**
  - A first-timer's natural "slow" of 25–30°/s turns the meter amber (0.45–0.65) without a bite.
  - The creak is clearly audible there (−27 to −21 dB).
  - Only ≥ 45°/s or a slam bites.
  - So the skill is learnable inside chest 1, which is never a Light sleeper. The sim novice is bitten in chest 1 in
    40 % of runs, mostly from slams and 1,000 pt/s drags. That comic first CHOMP is fine.
- **Is 8°/s too punishing? It isn't harsh, but it is mis-placed.**
  - The noise below 12°/s is tiny (0.09–0.16 per open).
  - But the creak sound and haptic switch on at 8. A careful player at 9–10°/s, whose reading jitters between 8 and
    12, hears "you are failing" while doing exactly what we asked.
  - **Move the line to 12°/s** and steepen the curve slightly (linear 0.008, quadratic 0.0004). The bite point stays
    at 45°/s, the amber zone stays at 25–30°/s, and a full silent open drops from 8.1 s to 5.4 s.
- **Decay grace: 0.4 s → 0.3 s.**
  - Human freeze reaction (~0.3 s) plus the estimator's tail (~0.15 s) already add half a second.
  - 0.3 s still stops a "jerk, pause, jerk" exploit, because any source above 0.01/s resets the grace.

## 2. Push-your-luck

**The value-by-depth curve is the right shape** (about ×3.5 per 0.2 of depth):

| Item | Value | Depth | Openness to grab it |
|---|---|---|---|
| copper | 7.5 | 0.22 | 0.28 |
| silver | 27.5 | 0.40 | 0.46 |
| gem | 85 | 0.62 | 0.68 |
| relic | 350 | 0.88 | 0.94 |

- An Iron-or-better chest's expected base value is about 190 + 0.35 × 350 ≈ 310, so the relic is ~40 % of it.
- On Royal, one relic is about 1,050 gold.

**R1 problem: the cost of depth is time only.**
- Going from gem depth to relic depth is ~32° of extra travel, about 3.5 s, or 2.5 % of a run.
- It earns 6–8 % of a run's gold, with zero risk if you move under the creak.
- So reaching is always right, freezing is always right (it costs 2–4 s against a bite costing in-hand loot + 15 s),
  and **bank-vs-reach is only a real call when the torch is nearly out**.
- In R1 the expert pilot never stirs more than 1.5 times per run and the perfect pilot is Hushed in 9 of 11 chests.

**The multipliers escalate, then plateau.**
- ×1 / 1.5 / 2 / 3 by chest index gives a good first minute.
- From chest 7 everything is ×3: an expert spends the second half of the run on a flat line.
- Bites don't slow escalation, because the index still advances. That is kind to novices, and I'd keep it.

**The sting: keep losing in-hand loot; cut the torch penalty from 15 s to 10 s.**
- In-hand loss *is* the stake, and the bet is what makes banking feel good. The R1 novice loses a median 763 gold per
  run to bites, about equal to what they bank.
- The −15 s compounds: 3 bites cost 45 % of the base torch, which means fewer chests and so less tier escalation. It
  punishes the same mistake three times.

**Streak/combo: yes.** It is the cheapest way to make perfect play *pay* and to spread the leaderboard:
- **The Hush Chain.** Consecutive Hushed chests pay ×1.1, ×1.2 … up to ×1.5. A stir or a bite breaks it.
- It also turns "one more item?" into a real decision for masters. Their risk is not the bite, it is breaking the
  chain.
- Pair it with the **bag jingle**. The noise can't decay below 0.035 × items in the bag (× the mimic multiplier),
  capped at 0.30. Every extra grab lowers the headroom under Stirring.
- Then "leave the copper, bank now" becomes the expert play. In the R2 sim the adapted expert pilot skips coppers and
  banks at a 0.20 floor.

## 3. Run length, pacing, first session, meta

- **Run length.** R1: casual 136 s, expert 139 s, novice 90 s.
  - R2: casual 131 s and expert 144 s (oil cut from +8 s to +6 s, because experts now bank more chests). Novice is
    107 s because bites cost 10 s.
  - Either way it is about 2 minutes, and that is right.
- **First 3 runs (novice drifting towards casual).**
  - R1: about 0.7k, 1.5k and 2.5k gold, so 1–3 Hushed chests in total and **0 relics** (the casual pilot never reaches
    0.84+, and a relic is invisible until o ≥ d + 0.04).
  - R2: about 1.6k, 2.5k and 3.9k, about 1 golden mimic seen, 1–2 relics and the first chain of ×1.1–×1.2.
- **Ranks.**
  - R1 thresholds with R1 gold: run 1 gives Cutpurse (500) and runs 2–3 give Sneak (1.5k), maybe Lockpick (3.5k).
    **Yes, the first 3 ranks come in session 1.**
  - With R2 gold the old thresholds would hand out 5 ranks in session 1, so roughly double them:
    `[0, 1_000, 3_000, 7_000, 14_000, 25_000, 42_000, 66_000, 100_000, 150_000, 220_000, 320_000]`.
  - That gives one rank per run in session 1. The top rank is about 50–60 runs (~2 h), roughly 10 days at
    10–12 minutes a day.
- **Achievements.**
  - Under R1, "Relic Hunter" and "Not a Peep" sit behind skills the median pilot never shows (0 relics, 0 Hushed).
  - "Royal Treatment" is trivial: chest 7 arrives in almost every casual run.
  - With R2 gold: Heavy Bag 2,000 → **3,000**, Dragon's Hoard 5,000 → **8,000**, A Small Fortune 25k → **50k**.
  - Swap `royal` for **"Midas Touch: bank a golden mimic"**, and `hushhush` for **"Hush Chain: 5 Hushed chests in a
    row"**.
- **Daily.** One scored try plus practice is right.
  - What's missing is a reason today's dungeon *feels* different. Add a **Daily twist** (feature 5).
- **Codex (24 relics).**
  - R1: the expert banks 2 per run, so 12 runs (~28 min). The casual pilot banks 0, so effectively never.
  - R2 (glimmer plus a relic chance of 0.25): casual 1 per run, so 24 runs (~53 min); expert 2 per run, so 12 runs.
  - A real median player lands at about 1–1.5 h, which is about a week at 10 min/day. That's right for £1.99.

## 4. Variety over a week
- A week is about 70 runs × 9 chests ≈ 600 chests.
- Today, personalities differ only in one invisible multiplier (×0.7–×1.35) and a name tag. The Dreamer's fakes are
  lid-only.
- Tiers differ only in their multiplier and item count.
- **By day 2 every chest is "the chest".** Four kinds and four tiers are enough *structure*, but they need **rare
  moments** and **daily difference**.

| Cheap addition | Payoff | Verdict |
|---|---|---|
| **Golden mimic** (6 % of chests from #3: loot ×2, noise ×1.25) | A jackpot about once every 2 runs: a gold flash and a heart-rate spike | **Do** |
| **Relic glimmer** (a faint twinkle plus "Something glints at the back…") | Makes the deep reach a *visible* temptation, and opens the Codex to casual players | **Do** (scene only) |
| **Daily twist** (one seeded modifier per day) | 7 different dungeons a week, and a reason to return | **Do** if there's time |
| A chest that's just a chest (no mimic) | A breather, but it removes the tension, and players can't tell it apart from the others | Defer |
| Trap item (a cursed bell, +0.3 noise) | Punishes reading on a small floor; low clarity | Defer |
| Key (the next chest is +1 tier) | Nice risk-now-for-later, but needs UI on the next chest | v1.1 |

## 5. The proposal

### Tuning changes, in priority order (Tuning.swift names)
| # | Change | Why |
|---|---|---|
| 1 | `quietSpeed` 8 → **12**; `lidRateLinear` 0.006 → **0.008**; `lidRateQuadratic` 0.00035 → **0.0004** | The quiet line moves out of the jitter band. The bite point stays at 45°/s, amber stays at 25–30°/s, and a silent open is 33 % faster. |
| 2 | **New** `closeQuietSpeed` = **18** (the lid is silent below 18°/s *while closing*; HeistSession gets the direction from the openness delta) | The cash-out gets quicker. Expert closing time drops from 4.3 to 2.8 s per chest. |
| 3 | `decayGrace` 0.4 → **0.3**; `woodenDecay`/`ironDecay`/`gildedDecay`/`royalDecay` 0.14/0.12/0.10/0.085 → **0.16/0.14/0.12/0.10** | Casual frozen time per run goes from 22 s to 3 s, and the freezes become short held breaths. |
| 4 | `dragQuietSpeed` 250 → **350** | 250 pt/s is a crawl (1 s per item). The hinge should be the star. In the ablation it moves casual Hushed from 1 to 2 and casual gold from 3,244 to 3,945. |
| 5 | `biteTorchPenalty` 15 → **10** | Stops the triple punishment. Novice median goes from 761 to 1,635 gold. |
| 6 | `oilSeconds` 8 → **6** | Keeps the faster expert runs at about 2:25. |
| 7 | `relicChance` 0.35 → **0.25** (with the glimmer) | The Codex lasts about a week for a median player. |
| 8 | `ThiefRanks.thresholds` → `[0, 1k, 3k, 7k, 14k, 25k, 42k, 66k, 100k, 150k, 220k, 320k]` | One rank per run in session 1. |
| 9 | Achievements: Heavy Bag **3,000**, Hoard **8,000**, Fortune **50,000**; `royal` → Midas Touch; `hushhush` → Hush Chain ×1.5 | Fits the R2 gold scale and points at the new features. |
| 10 | BalanceTests: casual banks 4–8 → **5–10** | The R2 casual median is 8 (7–10). |

### Five small features
1. **The Hush Chain.** Tuning: `chainStep` 0.10, `chainMax` 5.
   - A Hushed bank adds 1 to the chain and pays ×(1 + 0.1·min(chain, 5)). A non-Hushed bank or a bite resets it to 0.
   - UI: a "Hush ×1.3" pill by the bag; the bank shows "HUSHED ×1.3".
   - *Effect:* 24 % of an expert's gold (2.6k of 10.8k) and 2 % of a casual's. The leaderboard separates (casual p90
     is 5.0k, expert p10 is 8.2k).
2. **The golden mimic.** Tuning: `goldenChance` 0.06 from chest index 2, `goldenValueMult` 2 (on top of the tier
   multiplier), `goldenNoiseMult` 1.25.
   - Its roll comes from its own RNG stream (`chestSeed ^ 0x601DE7`), so every other draw, and the Daily, are
     unchanged.
   - Art: a gold tint and gold names ("Midas Mo").
   - *Effect:* seen 0.35 times per run (casual) to 0.6 (expert); casual players bank 12 of 14, novices 6 of 14. It's
     the screenshot moment.
3. **The relic glimmer.** This is scene and hint only, with no rule change.
   - If a chest holds a relic, it twinkles faintly from arrival, and the hint says "Something glints at the back…".
   - *Effect (sim: novice and casual go for it in 50 % and 60 % of relic chests):* casual relics per run go from 0 to
     1, and casual gold rises by 440.
4. **The bag jingle.** Tuning: `jinglePerItem` 0.035, `jingleMax` 0.30. Noise can't decay below the floor.
   - Show the floor as a notch on the meter, and make the bag rattle louder per item.
   - *Effect:* "leave the copper, bank now" becomes the master's call.
   - **ThiefPilot must then unfreeze at max(unfreeze, floor + 0.04).** Without that, the sim's expert and perfect pilots
     froze for 74 s per run, which would hang attract mode and CI.
5. **The Daily twist.** One seeded modifier per day, carried on `SessionOptions`, which already has `noiseScale`. For
   example:
   - Restless Night (decay ×0.75)
   - Gold Rush (golden chance 25 %)
   - Deep Pockets (relic chance 50 %)
   - Lights Out (an 80 s torch, all loot ×1.25)
   - Light Sleepers' Ball (every mimic a Light sleeper, loot ×1.5)

   *Effect:* 5–7 distinct dungeons a week. It is not simulated.

### Before / after (median, `node tools/balance-sim-r2.js seeds=40` vs `… r1=1`)
`r1=1` runs the R1 numbers through the same code and reproduces `balance-sim.js` exactly.

| Skill | Gold R1 → R2 | Chests banked | Bites | Hushed | Run (s) | Relics |
|---|---|---|---|---|---|---|
| novice | 761 → **1,635** (p10 147 → 759) | 4 → **5** (p10 1 → 3) | 3 → 3 | 0 → 1 | 90 → 107 | 0 → 0 |
| casual | 2,525 → **3,945** | 7 → 8 | 0 → 0 | 0 → **2** | 136 → 131 | 0 → **1** |
| expert | 4,677 → **10,847** | 9 → 13 | 0 → 0 | 7 → 12 | 139 → 144 | 2 → 2 |
| perfect | 6,113 → **11,553** | 11 → 13 | 0 → 0 (max 0) | 9 → 13 | 142 → 144 | 2 → 2 |

With CI's default of 8 seeds, R2 gives:

| Skill | Gold | Chests banked | Bites | Hushed | Run (s) |
|---|---|---|---|---|---|
| novice | 1,244 | 4 | 4 | 0 | 95 |
| casual | 3,803 | 8 | 0 | 2 | 131 |
| expert | 10,073 | 12 | 0 | 11 | 137 |
| perfect | 10,915 | 12 | 0 | 12 | 137 |

**Every check passes:**
- the R1 checks: gold order, casual banks 4–8 and runs 90–160 s, novice is bitten, perfect is never bitten;
- **novice ≥ 1,000 gold and ≥ 3 chests;**
- **casual Hushed ≥ 1.**

R2 time use (median seconds per run):

| Skill | Moments | Opening | Closing | Dragging | Frozen | Idle |
|---|---|---|---|---|---|---|
| casual | 13.4 | 32.9 | 30.7 | 18.0 | **3.1** | 32.5 |
| expert | 20.5 | 37.9 | **36.6** | 40.8 | 1.4 | 8.6 |

- The expert's closing time per chest goes from 4.3 to 2.8 s.
- Seconds per banked chest: casual 19.4 → 16.4, expert 15.4 → 11.1.

**What each change does, removed one at a time from R2 (gold median, casual / expert):**

| R2 minus … | Casual | Expert |
|---|---|---|
| (full R2) | 3,945 | 10,847 |
| the chain | 3,858 | 7,738 |
| the golden mimic | 3,760 | 10,364 |
| the glimmer | 3,506 (0 relics) | (unchanged) |
| the bag jingle | 3,945 | 8,529 (the copper-skipping strategy is part of it) |
| `closeQuietSpeed` | 3,945 | 8,742 |
| the R1 lid curve | 3,221 | 4,636 |
| the R1 drag line | 3,244 (Hushed 1) | 9,371 |
| the R1 decay | 3,437 (Hushed 1) | 9,929 |
| the R1 bite penalty | 3,945 (novice 1,396) | (unchanged) |

### Caveats (read before shipping)
- **Pilot model.**
  - In R2 the expert and perfect pilots *adapt to the thresholds*:
    - opening speed × quiet/8;
    - closing at 0.75–1.0 × `closeQuietSpeed` (perfect at 0.95 ×);
    - drags × the drag line/250;
    - they skip copper when the jingle is on and bank at a floor of 0.20 (perfect 0.22).
  - The novice and casual pilots are unchanged, which is conservative.
  - `ThiefPilot.swift` needs the same adaptation, or CI's expert and perfect numbers will be lower than this sim's and
    may stall on the jingle floor.
  - Sensitivity: casual scaled to the thresholds makes 4,642 gold with 1 Hushed. A casual who fails a freeze 15 % of the
    time makes 3,887 gold with 0 bites.
- **The casual pilot is never bitten, in R1 or R2.** It freezes at Waking every time.
  - Real median players will be noisier.
  - Use TestFlight telemetry to aim for **0.5–1 bites per run and 4–8 s frozen per run** for the median player. If
    real casual players come out safer than that, raise decay back towards 0.14 before touching the lid curve.
- **The expert/casual gap widens from 1.9× to 2.7×.** That is intended, because mastery now pays, mostly through the
  chain. If it's too much, `chainMax` 5 → 3 (a ×1.3 cap) takes it to 2.5× (expert 9,727). Most of the rest of the gap comes from
  the faster threshold-adapted expert.
- **Hushed with the jingle.** The cap of 0.30 sits under Stirring (0.35), so a full bag never stirs the mimic by itself.
  On a golden Light sleeper (×1.69) the floor hits the cap at 5 items. That is deliberate: those chests are for
  brave players.
