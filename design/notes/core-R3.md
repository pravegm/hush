# Core engineer, Round 3: hand-off

A small round. Files: `Hush/Core/HeistSession.swift`, `Hush/Core/Tuning.swift`, `HushTests/CoreTests.swift`.
`BalanceTests.swift` and `tools/` are unchanged.

## What changed
| Area | Change |
|---|---|
| Decision 2: noise frozen in a pause | **A pause is simply no stepping.** The session has no wall clock, so if the App calls neither `step` nor `rest` while paused, the noise, the stage, the candle, the clock, the shut-hold and the decay grace (`quietFor`) are all exactly where they were. The first frame back carries on as if there had been no pause. |
| `rest(dt:)` | Stays in the API, unchanged in behaviour. Its doc comment now says **"not for pauses"** (decision 2, REVIEW-2-duo P2-5) and that it is kept for tools and tests (and a possible future "the mimic dozes off" rule). The header comment says the same. |
| QA-2 P2-9: resume grace | `resumeGrace(seconds:)` still forgives lid noise for 0.5 s of play, but **once the lid has spent more than `Tuning.resumeGraceLoudLimit` (0.15 s) of the grace above `Tuning.loudSpeed` (30 °/s), the grace ends** and the lid counts again (and "Slower…" shows). So a pause can't buy a silent fling (e.g. 95° → 165° in 0.5 s now bites, as it would without a pause). A short filter blip is still forgiven (0.1 s at 120 °/s costs nothing). The loud count resets when a new grace starts after the old one has run out. Slow motion (≤ 30 °/s) is forgiven for the full 0.5 s, as before. |

**Why P2-9 is safe for the reopen:** the App only resumes through `HingeLidSource.canResume` (≥ 95°, < 6 °/s for 0.3 s)
and calls `hinge.reset()` first, which seeds the filters with the last sample at speed 0. So the lid is still when the
grace starts, and only a deliberate fast move after the resume can end it. CI's REOPEN-NO-BITE flings *before* the
stillness gate, so it is unaffected.

## New and updated tests (CoreTests)
- `noiseIsFrozenAcrossAPause`: noise 0.6 (Stirring), then a "30 s pause" with no calls: the snapshot is identical
  (noise, stage, candle, time). After `resumeGrace(0.5)` and 1 s of play with a still lid, the session equals a twin that
  never paused (`snapshot ==`), still Stirring, noise > 0.45. For contrast, `rest(dt: 30)` on a third copy would have
  calmed it to Asleep: that is the free calm-down the App no longer gets.
- `resumeGraceEndsOnASustainedLoudLid`: a blip (0.1 s at 120 °/s) is forgiven and the grace runs on; a fling at 40 °/s is
  free for 0.1 s, then heard, with "Slower…"; once ended, slow motion is heard again; a fresh grace starts its loud
  count from zero. Also pins `Tuning.resumeGraceLoudLimit == 0.15`.
- `resumeGraceIgnoresTheLidForAMoment`: its "inside the grace" steps now use 25 °/s (noisy in play, under loudSpeed)
  instead of 40 °/s, since a sustained 40 °/s now ends the grace (the test's intent is unchanged).
- The existing `restOnlyLetsTheMimicSettle` still covers `rest(dt:)` itself.

No mutating calls inside `#expect`. Not compiled here (no Swift toolchain): the CI run is the check.

## Re-check against QA-2 (no rule change needed)
- **Hush Chain:** +1 per Hushed bank and ×(1 + 0.1·min(n, 5)) (`bank`); it breaks the moment the mimic leaves Asleep
  (`markStirred`) or on a bite (`bite`), with `chainBroken` only at ≥ 2. `rest()` can't stir the mimic (it only
  lowers noise); with decision 2 it isn't called in pauses anyway. The banked counter equals the sum of the chest log.
- **Golden:** its own stream (`chestSeed ^ 0x601DE7`), from index 2, 6 %; noise ×1.25 on every source
  (`noiseMultiplier`); `ChestSpec.multiplier` is tier × 2.
- **Jingle:** floor = min(0.30, 0.035 × items × noise multiplier), under Stirring's down-line (0.31); decay stops at it
  and it never raises the noise (`decayNoise`).
- **Freezing the noise in a pause changes none of these.** A pause no longer lowers the noise, so a stirred chest stays
  stirred (it was already un-Hushable), and the jingle floor is irrelevant while nothing decays.

QA-2 items that touch Core data but are fixed elsewhere:
- P2-6 (glimmer geometry): the Scene should call `HeistSession.relicGlimmers(depth:openness:)`; Core's helper is the truth.
- P2-8 (golden plate): the plate should print `chest.multiplier` (iron golden ×3, gilded ×4, royal ×6), not "×2".
- P2-12 (snapshot built 2–4× a frame, each running `currentHint()`): the fix is App-side (one snapshot per frame in
  `advance`). `snapshot` is a computed property with no side effects, so that is safe.

## Balance (`node tools/balance-sim.js`): unchanged
The sim has no pauses (pilots never pause; the sim mirrors the session minus `rest`/`resumeGrace`), so nothing in it
moved. Every band PASSes.

| Skill | n | Gold | p10–p90 | Banked | Bites | Hushed | Run (s) |
|---|---|---|---|---|---|---|---|
| novice | 8 | 1,244 | 536–2,241 | 4 | 4 | 0 | 95 |
| casual | 8 | 3,803 | 3,230–5,008 | 8 | 0 | 2 | 131 |
| expert | 8 | 10,089 | 7,902–11,678 | 12 | 0 | 11 | 137 |
| perfect | 8 | 10,989 | 9,505–13,458 | 12 | 0 (max 0) | 12 | 137 |
| novice | 40 | 1,685 | 690–3,186 | 5.5 | 3 | 1 | 108 |
| casual | 40 | 3,958 | 2,925–5,067 | 8 | 0 | 2 | 131 |
| expert | 40 | 11,007 | 8,235–13,147 | 13 | 0 | 12 | 144 |
| perfect | 40 | 11,573 | 9,853–14,873 | 13 | 0 (max 0) | 13 | 144 |

Identical to the core-R2 table, median for median. No tuning change; the one new constant
(`resumeGraceLoudLimit`) only acts after a resume.

## For the other engineers
- **App:** don't call `rest(dt:)` from the pause path (decision 2): just skip `step` while paused. Keep
  `resumeGrace(seconds: 0.5)` on resume. Make sure the first step after a pause gets a frame-sized `dt`, not the paused
  wall time (the session sub-steps any `dt` faithfully, so a 30 s `dt` would burn 30 s of candle). AppTests'
  `pauseRestSettlesWithoutTheCandle` and `restChunksCoverTheGap` describe the old R2 pause; they still pass against
  Core (rest is unchanged) but no longer describe the App. Retire or rewrite them with the pause change.
- **Launch lead:** if any copy says the mimic "settles while the lid is closed", that's no longer true: noise is frozen
  while paused.
- **CI:** REOPEN-NO-BITE now starts the reopen with the noise still at 0.6 (no rest). The fling happens before the
  stillness gate, so it should still pass; watch the noise level logged after `resumed`.
