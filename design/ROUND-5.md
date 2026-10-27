# Round 5: the release candidate (brief)

**R4 verdicts:**
- Juror **9.0**. Its only blocker, fold-layout clipping, doesn't happen on the real Duo canvas (`artifacts/duo5`,
  `duo-ui-home-150` is clean), so by the juror's own condition the verdict is yes.
- UX **8.9**, launch-ready on clarity: yes.
- Duo simulator: **11 / 11 PASS**.
- QA-4: no P0. "Fix first": one P1, then ship as 1.0.
- Fresh testers 9 and 10: would pay 7 / 8.

This round fixes what's left. No new features, nothing risky.

Reports:
- `design/panel/REVIEW-4-juror.md`, `REVIEW-4-ux.md`;
- `design/QA-4.md`;
- `design/fresh/tester9-duo.md`, `tester10-phone.md`.

Frames: `artifacts/ci9s/` (phone), `artifacts/duo5/` (Duo simulator).

## App engineer
1. **QA-4 P1-A.** At accessibility text sizes, Home:
   - puts the Daily status under its title (no mid-word wrap);
   - stacks Codex / Badges and Settings / Game Center one per row.

   Re-check frame 44.
2. **The fold layout emulated on a phone** (UX P1-1, juror P1-1: frames 30 and 39). The R4 `ViewThatFits` fallback
   hard-clips (`HomeView.swift:42`, `PlayHUD.swift:396`). Give the fold layout compact metrics so the non-scroll
   version fits the floor half on every canvas. Use a fading scroll only at accessibility sizes. Add a test that
   the lesson's final card and Home fit `HUDLayout.floor` at the default size on the Duo canvas and on a 393 pt phone
   with `fold=1`.
3. **UX P1-2:** trace why `fold=1;turn=0` (frames 32, 13c) still uses or draws the lever. Fix the root cause,
   add a test, and say in your notes whether a real Duo with "Turn the chest round" off could hit it.
4. **QA-4 P2s:**
   - The hint must not reappear over the relic card after the menu's Resume.
   - VoiceOver must not repeat "Slower…" in the lesson.
   - Clamp gold totals when decoding saves (no overflow on hand-edited saves).
5. **The hint plates** (juror P2, tester 9):
   - Centre them on the chest's centre line, not x ≈ 400 (ask the Scene for the centre via `ChestLayout`).
   - Keep them ≥ 20 pt clear of the fold edge (the crease can distort the band right next to the hinge).
   - The Daily plate must not overlap the nameplate (frame 26).
   - Hide the pause coin during the bite moment (frame 13).
6. **Results:** the second row of the chest strip must not sit under the fade (frames 20, 38). Show 2 full rows,
   then "+N more".
7. **The first Hush Chain tip:** show it at the moment of the first chain bank (not at chest 2's lid crack), and
   hold it for at least 3 s, with no hint replacing it.
8. **Badge icons:** Heavy Bag and Light Fingers have the wrong art (frame 40). Match each badge to its meaning.

## Scene engineer
1. **The chain tab:** reads "CHAIN ×1.2" (no "GOLD", so it never reads as a second gold multiplier next to the seal),
   ≥ 11 pt text.
2. **Flying loot** never passes over the IN BAG / BANKED labels (frames 07, 14): route it under them, or fade it as
   it reaches the plates.
3. Expose the chest's centre x as `ChestLayout.chestCenterX` for the App's hint plate.
4. **Juror R4 P2 leftovers**, where cheap: the gum curve, the Zzz on the bands.

## Founder (Claude)
- `docs/appstore/review-notes.md` and `asc-metadata.json` (QA-4 P2-A):
  - the hand-off and relight angles are stored on the device (diagnostics only, never sent);
  - after a trip to the cover display, resume can need a lower angle;
  - the Duo has a "Play anyway" lever fallback when portrait is refused.
- **Golden copy:** "a golden mimic doubles a chest's gold" (not "double gold").
- Then: CI, Duo, store, **TestFlight build 2**, and a final frame check.
