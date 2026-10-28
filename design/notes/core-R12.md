# Core engineer, Round 12: the lid IS the chest

Source: `design/ROUND-12.md` (rules 1–4, Core section) plus the founder's refinement relayed mid-round (a bank always
deals the next chest "seen shut"). Only `Hush/Core/`, `HushTests/CoreTests.swift`, `HushTests/BalanceTests.swift` and
`tools/balance-sim.js` changed. Not compiled here (no Swift toolchain): CI is the check. Not committed.

## What changed (`HeistSession`)

- **The lesson keeps the old gate; nothing else does.** `shutGate = (mode == .lesson)`. The lesson behaves exactly as
  in R11: shut-first gate, `.easeLidDown`, the lid heard in `.ready`, R7's fresh rule. Every other mode (run, Daily,
  attract) follows the rules below.
- **Rules 1–2: no hidden gate.** Every non-lesson chest starts "seen shut" (`sawShut = true` in `init` and
  `nextChest`). So a run started with the lid up is `.looting` on its first step: `lidCracked` fires and the loot is lit
  at the current openness. With the lid shut, the chest arrives `.ready` (dark, `.openSlowly`) and opens with the lid.
- **A `.ready` chest is closed.**
  - It turns `.looting` once the openness passes 0.02, but not while the lid is still coming down. This only matters
    for a chest just dealt in the shut zone during a fast close.
  - The lid makes no noise there and `.slower` doesn't show. Otherwise a slam after a bite would carry on into the new
    chest and wake (or, once looting, bite) its mimic.
- **Rule 4: after a bite, the robbed chest waits.** If the 1.8 s bite moment ends with the lid out of the shut zone,
  the robbed chest stays:
  - state: `awaitingClose = true` (new, `private(set)`), phase `.ready`, `snapshot.loot == []`,
    `hint == .closeForNext` (top priority, the only prompt);
  - the same `chest` spec; the mimic goes back to Asleep (`stageChanged(biting→asleep)`) with noise 0;
  - the candle burns on, and it can run out (`torchOut` clears `awaitingClose`).
  - The step the lid enters the shut zone (≤ 110°), `nextChest` deals (`chestArrived`), already "seen shut".
  - If the moment ends with the lid already shut, the next chest is dealt at once, as before.
- **After a bank (founder refinement):** the next chest is always dealt when the 1.4 s moment ends, "seen shut",
  whatever the lid is doing. Reopened to 150° during the moment, it loots at once and never shows `.closeForNext`.
- **`.easeLidDown` is only produced by the lesson** (the enum case stays).
- **`isFreshChest`:** outside the lesson, any `.ready` chest that isn't awaiting the close and has an empty bag. A
  `.ready` chest there is closed, dark and silent, so its openness history doesn't matter. The chest dealt on the way
  down after a bite is therefore fresh, and the closing pause resumes it without "Hold still". The lesson keeps R7's
  peak ≤ 0.05 rule.
- **New `noteLidShut()`:** if a chest is awaiting the close, the next one is dealt now (its `chestArrived` comes with
  the next step).
- **Chain:** the chain multiplier shown while awaiting is the next chest's.
- **The Daily stays deterministic:** chests are still dealt by index, in the same order (tested against
  `ChestFactory`, index by index, on three Dailies).

## `ThiefPilot`
When `snapshot.hint == .closeForNext`, the pilot:
- ends any drag and unfreezes;
- closes the lid to its shut rest (0.06) at the robbed chest's closing speed. That takes no new draws except the
  stick-slip.

The next chest then rolls its speeds as usual; the settle step takes the lid the rest of the way down, then it opens.

## Balance (`node tools/balance-sim.js`, mirrored; `T.r12=0` restores R11 and reproduces the R7 table exactly)
| Skill | n | Gold before → after | Banked | Bites | Run (s) |
|---|---|---|---|---|---|
| novice | 8 | 1,347 → **1,347** | 4.5 → 5.5 | 3.5 → 4 | 99.6 → 102.3 |
| casual | 8 | 4,966 → 4,966 | 9 → 9 | 0 → 0 | 132.8 → 132.8 |
| expert | 8 | 11,328 → 11,328 | 12 → 12 | 0 → 0 | 137.0 → 137.0 |
| perfect | 8 | 11,076 → 11,076 | 12 → 12 | 0 → 0 | 137.0 → 137.0 |
| novice | 40 | 1,589 → **1,566** | 5.5 → 6 | 4 → 4 | 101.2 → 101.8 |
| casual / expert / perfect | 40 | 5,353 / 11,414 / 11,597, unchanged | | | |

- **Only the novice moves.** It is the only skill that gets bitten. It now closes after a bite into a silent closed
  chest, where the R11 settle into a waiting chest was heard.
- **Checks:** every check passes at 8 and 40 seeds. No band moved.
- **Attract is unchanged:** 8–11 banks at 120 s, 0 bites.
- **`windows=40`:**
  - The novice spread is 1,087..1,737..3,415 gold (R11: 793..1,622..3,415).
  - 8 of 40 windows fail some check (R11: 5). The extra three are "novice gold ≤ 2,600" in rich windows.
  - CI's window 0 passes.

## Tests (`// MARK: R12` in CoreTests)

New tests:
- `r12FirstChestOpensAtOnceWithTheLidUp`: run, Daily and attract all loot at once at 0.8 (cracked, lit, grabbable,
  no `easeLidDown` or `closeForNext`). With the lid shut, the chest is `.ready` and dark with `.openSlowly`, then
  opens. The lesson still waits with `.easeLidDown`.
- `r12AfterABiteTheRobbedChestWaitsForTheClose`:
  - 5 s with the lid up: no deal. The chest is awaiting, empty, `.closeForNext`, asleep, noise 0, and the candle burns
    ( > 3 s).
  - Touches do nothing, even a wide or fast lid only shows `.closeForNext`, and the partial log is correct.
  - At 107.8° the next chest is dealt (the exact `chestArrived`), `.ready` while closing.
  - The slam tail is silent and the chest is fresh; it opens at 0.1.
- `r12TheNextChestArrivesOnlyUnderAClosedLid`:
  - dealt at a rest of 0.12, the chest loots;
  - a lid shut during the bite moment deals at once;
  - `noteLidShut()` deals the next chest, and does nothing otherwise;
  - the candle can go out while the chest is awaiting.
- `r12ABankAlwaysDealsTheNextChestSeenShut` (the founder's test): bank, reopen to 150° within the moment, and the next
  chest loots at once, never awaiting and never `.closeForNext`.
- `r12PilotsPlayTheLidAsTheChest`: Dailies 300–302, novice and casual, played to the end. It checks:
  - the deal order equals `ChestFactory`'s;
  - every later chest arrives with the lid in the shut zone;
  - `easeLidDown` never shows;
  - `closeForNext` shows if and only if the chest is awaiting, and the loot is empty then.

  The novices do await (45 / 7 / 70 frames in the JS port).

Updated tests:
- `chestArrivesAndLootingStartsFromTheShutZone` is now `theLessonChestWaitsForTheShutZone`;
- `aSlamBitesAndCostsTheHaulAndTorch`: the robbed chest waits, then closing deals the next one;
- `hintPriority`: comment only;
- `aFreshChestIsReadyAndUntouched`: a reopen during the bank moment now loots at once. The old "arrives open, waits,
  not fresh" case moved to the lesson.

Every scenario above was run through the JS port first, and all hold.

BalanceTests: header only (R12 numbers).

## Watch items for the other roles
- **App:** call `session.noteLidShut()` when the closing pause starts. If a fast fold goes straight into the pause
  without a `step` at ≤ 110°, the robbed chest would otherwise still be waiting after the reopen, which is the
  founder's complaint again.
- **App / Feel:** while `awaitingClose`, the stage is `.asleep` and the noise is 0. The Feel bed would snore at the
  robbed chest, so consider muting the bed or using the glare. The Scene draws the glare from `loot.isEmpty &&
  hint == .closeForNext`, as briefed.
- **App:** `GameController.mostLit` and the other snapshot readers must accept an empty `loot` in `.ready`.
- **CI:** none of BITE-CLOSE-NEXT, START-OPEN or BANK-CLOSE-FULL needs a Core switch. A reopen inside the bank moment
  now loots at once.
- **`tools/balance-sim-r12.js`** (REVIEW-6's untracked copy) was not touched and still has the R11 rules.
