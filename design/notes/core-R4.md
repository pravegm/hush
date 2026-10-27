# Core engineer, Round 4: the loot keep-out under the pause coin

On phones the App's pause coin (a SwiftUI overlay) covers the interior's back-right corner (about floor x 551–592,
y 10–102). It takes the touch, so loot dealt there couldn't be grabbed.

## What changed
- `Tuning.lootKeepOut = CGRect(x: 540, y: 0, width: 130, height: 112)` (floor space, y 0 at the hinge).
- `ChestFactory.place` rejects any spot whose circle (radius + `Tuning.lootGap`) touches that box: the box's nearest
  point to the centre must be at least radius + gap away. The same check runs in the random tries and in the grid scan.
  The last-resort fallback (the interior's centre, 335, 179) is far clear of the box.
- **Every mode and device**, the Duo included, so a seed deals the same chest everywhere (the Daily is the same for
  everyone). The mimic, tier, item count, golden and relic choice are drawn before placement, so they don't change.
  Placement shares the chest's stream, though, so a chest that had a rejected try can deal different values, depths
  and positions after that point.
- `tools/balance-sim.js` mirrors it exactly (`keepOut: 1, keepOutX/Y/W/H`; `keepOut=0` switches it off for comparison).
- New CoreTest `lootStaysOutOfThePauseCoinCorner`: seeds 1–120 × chests 0–10 (≈ 8,600 items) have none in the
  keep-out, and the lesson chest is clear. The JS port agrees: 0 of 287,619 items over seeds 1–3,000 × chests 0–12.

## The lesson chest: unchanged
Its rightmost item is the copper at (420, 268), radius 22: its edge plus the gap reaches x 448, nearly 100 pt left of
the box (x ≥ 540). No position moved.

## Seed-specific CoreTests: none broken (checked through the JS port)
Of the chests the tests deal, only seed 112's chest 0 changes. The other changes are deeper in runs than the tests go
(seed 7 chest 2, 61/62/101 chest 2, 181 chest 1, 131 chest 8, …, all unused).
- `hintPriority` (seed 112): the shallowest item still bags and the 0.5 s shut still banks.
- `sessionsAreDeterministic` (4242, casual): it still finishes, with 8 banks (≥ 1 needed).
- `pilotPlaysAttractForever` (seed 7, expert): 10 banks in 120 s (≥ 4 needed), 0 bites.
- The placement statistics (seeds 1–60): the mean y of deep items is 139.5 against 258.7 for shallow ones (it was
  137.9 / 258.4), so deep items still sit further back. The relic share is still 0.240.

## Balance (`node tools/balance-sim.js`): every band PASSes; BalanceTests bands unchanged
| Skill | n | Gold (R3) | p10–p90 | Banked | Bites | Hushed | Run (s) |
|---|---|---|---|---|---|---|---|
| novice | 8 | **2,065** (1,244) | 1,132–2,368 | 4.5 | 3 | 0 | 101 |
| casual | 8 | **3,821** (3,803) | 3,232–5,005 | 8 | 0 | 2 | 131 |
| expert | 8 | **10,323** (10,089) | 8,232–11,769 | 12 | 0 | 10.5 | 137 |
| perfect | 8 | **11,076** (10,989) | 9,892–13,562 | 12 | 0 (max 0) | 12 | 137 |
| novice | 40 | **1,876** (1,685) | 1,089–3,180 | 5.5 | 3 | 1 | 106 |
| casual | 40 | **3,958** (3,958) | 2,881–5,078 | 8 | 0 | 2 | 131 |
| expert | 40 | **11,045** (11,007) | 8,545–13,148 | 13 | 0 | 12 | 147 |
| perfect | 40 | **11,597** (11,573) | 9,788–14,876 | 13 | 0 (max 0) | 13 | 144 |

The novice jump at 8 seeds is reshuffled draws, not easier play: the 40-seed novice median moves about 11 %, and the
others under 2.5 %. Robustness (`windows=40`): 3 of 40 windows fail a check (R2: 4): 2 are "novice ≥ 1,000" and 1 is
"perfect ≥ 0.95 × expert". CI's window passes every band. Attract: 7–10 banks in 120 s and 33–52 in 600 s, 0 bites.

Not compiled here (no Swift toolchain): the CI run is the check. Not committed.
