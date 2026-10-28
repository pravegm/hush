# CI engineer, R12: the lid IS the chest (`ci/duo.sh`)

Scope: `ci/duo.sh`, plus asks appended to `design/NEEDS.md` ("CI engineer (R12)"). Not committed. `bash -n` passes, and
the new log helpers were run on a made-up log.

## New checks (end of the hinge pass, after LANDSCAPE-PLAY; all timed with the R6 line clock)

| Check | Launch (hinge before launch) | Moves | PASS | INCONCLUSIVE |
|---|---|---|---|---|
| START-OPEN | `screen=run;mode=attract;seed=7` at 150 | clock from before the launch, 1° wiggle | `lidCracked` ≤ 3 s (+0.2 clock grain) after the run starts (first `screen playing` / `chestArrived` / `lid` line); no bad hint; last lid line 145–155° with openness within 0.05 of (θ−100)/65 | lid never read 140–160° |
| BITE-CLOSE-NEXT | `screen=run;mode=run;seed=7;noise=1;noiseUntil=bite` at 150 | bite → 1.8 s bite moment → ≥ 2 s open (wiggles) → robbed frame → 150→100 over 4 s → reopen 100→150 over 5 s | no `chestArrived` while open; next `chestArrived` ≤ 113° and ≤ 1 s (+0.3) after the first lid line ≤ 110°; nothing opens it at 100°; `lidCracked` (or the held noise's bite) after the reopen; `hint closeForNext` if hint lines exist | chest opened but no bite; no lid line ≤ 110° after a retry; reopen top < 140° |
| BANK-CLOSE-FULL | `screen=run;mode=attract;seed=7;bag=1` at 150 | 150→30 over 5 s, 1 s, →0 (cover frame), reopen to 165, wiggles until resume / 8 s | `banked` before the first `HUSH-T paused`; next `chestArrived` ≤ 113°; resume after the reopen (if it paused); new chest's `lidCracked` after the reopen began; no bad hint | no bag line and no bank (key missing); nothing ≤ 108° after a retry via a hold at 105°; reopen top < 92° |

A "bad hint" is any `HUSH-T hint easeLidDown`, or a `HUSH-T hint openSlowly` logged above 115°. That is rule 7: never
ask to open an open lid. Until the App prints hint lines, every check says "hint lines pending" in its detail and
doesn't judge hints.

New frames: duo-h12-start-open-150, duo-h13-robbed-open-150 (the robbed chest, shot during the open hold),
duo-h13b-next-opened-150, duo-h14-bank-cover-0 (cover display), duo-h14b-bank-next-opened-165,
duo-00-closed-100 (frames pass: the closed-chest cover), duo-h0-closed-100 (was duo-h0-ready-105).

New env knobs: `START_OPEN_LIMIT` (3) and `BITE_NEXT_LIMIT` (1). New helpers: `first_angle_line`, `last_lid`,
`hints`, `hints_on`, `bad_hints` and `dt_lines`.

## Choices

- **Bite without a slam.** The sim's slam peaks at about 80°/s and may only stir the mimic (R7: SLAM already accepts a
  noise rise ≥ 0.35). A slam also ends at 104°, inside the shut zone, so it would deal the next chest by itself and
  muddle "no chestArrived while open". Core's `nudgeNoise` allows a bite, so `noise=1` bites the first chest the moment
  it loots, and that is deterministic. I asked for `noiseUntil=bite` so the hold lets go after that bite. Until it
  lands, the hold bites the next chest too, before its crack logs. That bite still proves the chest opened, because a
  bite needs a looting chest, so CI accepts it and says so.
- **Close to 100°, not 105°.** 105° is openness 0.08, above `lidCrackedOpenness` (0.05). A chest dealt there loots and
  cracks at once, so "reopen → lidCracked" would test nothing. 100° is openness 0, still above the 70° closing pause.
- **Loot in the bag: the demo key `bag=1`** (asked in NEEDS). Loot only reaches the bag by a drag, and `simctl` can't
  touch. A pilot drives the lid as well as the touches, so the hinge's close would be ignored. `mode=attract;pilot=…`
  plus freezing doesn't help either, because the bank needs the hinge to close. The key keeps the whole check on the
  real hinge. Without it the check is INCONCLUSIVE, never FAIL.
- **BANK-CLOSE-FULL closes in one go**, the way the founder closes it. If the sim's cover hand-off (74–92°) pauses the
  session during the 1.4 s bank moment, and Core doesn't deal under the pause, the next chest lands on the reopen above
  113°. CI FAILs that, because rule 4 says the next chest arrives only under a closed lid. Flagged in NEEDS for Core/App.
- **Timing:** these checks measure the 3 s and 1 s rules with the line clock (`clock_start` runs before the launch
  for START-OPEN). Without a clock they fall back to lid-line counts at 10 Hz. Screenshots are taken outside the timed
  rules, except the robbed-chest `shoot_now`, which only lengthens the open hold and so only makes it stricter.

## Existing checks updated for the removed shut gate

- **SLOW-OPEN** now starts at 100° (the closed chest) and sweeps 100→160 over 8 s (7.5°/s, still under the creak
  floor). Before, at 105°, the chest was already cracked at launch. It FAILs if the chest cracks before the sweep while
  the lid reads ≤ 102°. Its PORTRAIT frame is now duo-h0-closed-100.
- **LANDSCAPE-PLAY** now starts at 100° (100→160 over 7 s, and the retry returns to 100). Its detail now also reports
  whether `lidCracked` came inside the window.
- **Frames pass:** starts at 100° (duo-00-closed-100, the cover), then 105° (duo-01, the cover lifting).
- **Unchanged and still valid:**
  - CLOSE-PAUSE, COVER-SLOW-CLOSE/REOPEN, FLAT-OPEN and WATCHDOG launch at 120–140°. Under the old gate that first chest
    never looted; now it does. Their rules are pause, resume and line based, so they hold either way.
  - COVER-SLOW-CLOSE closes an empty bag through the shut zone, so nothing banks.
  - SLAM, SLAM-CREAK and REOPEN-NO-BITE launch at 105°, in the shut zone. That behaves the same in both models.
  - The ui-lesson comment now notes the rule-7 copy ("Close the lid to start" at 150°).

## Pending on others (design/NEEDS.md, CI R12)

1. `HUSH-T hint <name>` on every HUD hint change.
2. The `bag=<n>` demo key and its `HUSH-T demo bag <n> value <v>` line.
3. `noiseUntil=bite`.
4. Confirmation that the next chest after a one-go full close is dealt under the closed lid.

The workflow comment in `.github/workflows/duo.yml` (its check list) is outside my scope. It could add the three new
names.
