# Round 4: polish to "yes" (brief)

**R3 scores:** juror 8.5 ("fix P0 plus P1s and I'd say 9 and yes"); UX 8.8 ("launch-ready on clarity: yes"); QA-3: no
P0, 1 P1. Fresh testers 7 and 8: understood 8 / 8, premium 7 / 6.5, would pay 7 / 7.

Reports to read for your role:
- `design/panel/REVIEW-3-juror.md`, `REVIEW-3-ux.md`;
- `design/QA-3.md`;
- `design/fresh/tester7-duo.md`, `tester8-phone.md`.

R3's frames are in `artifacts/ci8s/`; the store set is in `artifacts/store1/`.

No new features. Every item below is a visible defect on a store-screenshot frame or a correctness gap.

## Scene engineer
1. **Plates** (juror P0, UX P1-1): `ChestArt.plateInsets` must cover the brass end-caps plus 8 pt. Expose
   `ChestArt.plateTextRect(in size: CGSize, style:) -> CGRect`, so the App lays text inside it.
2. **Chain medal** (UX P1-2): it reads "CHAIN" over "GOLD ×1.2", sized to its text, fully on screen with ≥ 16 pt
   inset, on Duo and phone. It always shows the multiplier the *last* bank used (it updates in the same frame as
   the bank toast), so the medal and the toast never disagree (testers 7 and 8: "+119 ×1.1 next to ×1.2").
3. **The pause stud** sits in a brass socket inside the floor half: not on a corner bracket, ≥ 16 pt from the edges,
   never under the hint plate, the meter or the HUD. Update `ChestLayout.pauseArea`, and shorten `hintBand` so the
   two never touch.
4. **The bank beat:** the interior dims to about 40 % and shows a small "Next chest…" (not black) on every tier and
   on phones (UX P2, tester 8).
5. **The gum:** a curved lip line at every stage (juror: "still a straight bar").
6. **Noise label by stage:** NOISE → STIRRING → WAKING!, so it doesn't rely on colour alone.
7. **Golden:** the seal shows the real total multiplier, the loot pops "×<same>", and no other number appears.
8. **Phone extension above the lid** (tester 8: "empty wood panel"): a carved plaque with the chest tier and number
   ("Iron-bound · Chest 4"), or the mimic's brow carving. It must not be empty.
9. **Seams:** flying loot, the lesson chain pop, and the cover hairlines plus the clipped "z" (juror P1-3).
   `MimicPortraitScene` cover style: add the eye glint.
10. The "Relic Hunter" badge glyph is a blob: redraw it.
11. **Icon:** keep every coin and sparkle inside the iOS corner-mask safe area (≈ 80 % centred circle or squircle).
    The bottom-right coin may be clipped.

## App engineer
1. **Plates:** lay out every plate's text in `ChestArt.plateTextRect`, on one line with `minimumScaleFactor(0.7)`
   (lesson cards may wrap to 2 lines). Check `05`, `10`, `36` and the lesson cards on the Duo and the phone.
2. **One prompt at a time:** a relic card, the bank beat or a toast hides the hint. The lesson's final card must
   never sit behind the closing card after the lesson bank (QA-3 P2).
3. **QA-3 P1-1:** when a live run's input changes to `.hinge` (leaving Play anyway), call `hinge.reset()`,
   `closingPause.hold()` and `setClosing(true)`, with a test.
   - The reverse switch (P2): entering Play anyway mid-run must not snap the lid shut or auto-bank. Hold the lid at
     its current openness, and the lever starts there.
4. **VoiceOver** (QA-3 P2):
   - A delayed announcement never cuts "Chomp!".
   - "It's stirring." is announced at most once per chest.
   - Lesson steps are announced.
5. **Copy:**
   - The phone Home hint uses lever words, not "Drag its lid up".
   - The lesson says "Drag a coin into your bag" (several coins show).
   - The golden banner says "A golden mimic! Extra gold!".
   - Results says "15 chests opened" (count the one the candle went out on, as the tiles do).
6. **Results:** the legend sits inside the chest-strip card, so it's visible without scrolling on phones.
7. **Dynamic Type:**
   - The chevron never covers totals (41/45).
   - Names never truncate (42/44/46): wrap them.
   - Relic names in the Codex wrap to 2 lines at large sizes.
8. **The pose screen (juror P1-4):** replace the flat trapezoid and the SF Symbol with a drawn Duo-shaped chest:
   two halves and the glowing lift half, using `ChestArt` art and glyphs.
9. **The "!" padlock** in fold frames (tester 7): find what it is. If it's a pose or lock indicator, label it or
   remove it.
10. **Diagnostics for the founder's device test:**
    - `docs/LAUNCH-RUNBOOK.md` step 9 asks for the hinge hand-off and relight angles. In TestFlight builds, show
      the Diagnostics panel after a 2 s press on Settings › About's version line. This exists; confirm it works in
      a TestFlight Release build: `BuildChannel` must detect TestFlight without exposing the panel to App Review.
      The hidden press is OK for both.
    - Write the exact steps in your notes. The founder (Claude) will update the runbook.

## CI engineer
Re-shoot the R3 frames that missed their moment (QA-3):
- `13b-creak`: freeze on `creak`, and pick a seed or pilot that slams without biting;
- `36-golden-mimic`: the golden chest on screen;
- `35-reveal-phone-turned`.

Add a phone CREAK frame. Then check every frame in `ci/scenarios.txt` against its caption, and fix any that miss.
For the store set, follow the same rule (look at `artifacts/store1/`): every frame must show its caption's
moment.

Every engineer: write `design/notes/<role>-R4.md`. Don't commit.
