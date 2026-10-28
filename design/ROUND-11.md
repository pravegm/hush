# Round 11: last polish on build 4 (brief)

**Build 4 verdicts:**
- Apple juror **9.2, YES**. Its condition (Duo frames show the R10 fixes) is met: `artifacts/duo12` shows the coin in
  its seat and Settings reachable.
- UX **8.8**, launch-ready on clarity, with 3 small P1s.
- QA-6: ship after 2 doc fixes, which the launch lead is doing.
- Fresh tester 11: **8 / 8 / 8 / 8**.
- Duo sim on R10: **13 / 13**.

Reports:
- `design/panel/REVIEW-5-juror.md`, `REVIEW-5-ux.md`;
- `design/QA-6.md`;
- `design/fresh/tester11-phone.md`.

Frames: `artifacts/ci19s/` (phone), `artifacts/duo12/` (Duo, drawn turned).

Nothing risky. Keep every R6–R10 behaviour.

## Scene engineer
1. **Callouts never touch** (juror P2-1, tester 11): "CREAK!" vs the "Freeze!" plate (13c), "Hushed!" vs the hint
   plate (14), and the chain banner vs "Hushed!". Give them a 12 pt minimum gap: offset stacked callouts, or tell the
   App to hide the hint while a callout shows (expose `ChestScene.calloutActive: Bool`).
2. **The CHAIN pill** must never run into the right-hand plate (tester 11, frame 14).
3. **Royal chest:** its corner jewels must not hide under the pause coin, the hint plate or the candle (juror, frame
   16). Move the jewels.
4. **The "0:10" chip** must not sit on the candle (frame 16).
5. **"not safe yet"** under IN BAG: ≥ 13 pt, legible.
6. **Art leftovers** (juror):
   - "Banked!" text is gold or cream, never green.
   - The Heavy Bag badge glyph must read as a bag, not a pawn or person.
   - Badges are less "porthole": a brass bezel with a relief.
7. **The relic card** (frame 15) must not overlap a loot item behind it: dim or hide loot under it.

## App engineer (+ CI scenario lines for your new frames)
1. **UX P1-1: make "Forgiving" findable.**
   - Each option gets its own line:
     - Forgiving: "For a stiff hinge or shaky hands. Easier to stay quiet."
     - Normal: "If it wakes while you're being gentle, try Forgiving."
     - Strict: "For thieves who never creak."
   - The scored Daily line stays.
   - **Rename "Careful" to "Strict"** (tester 11). Keep the stored raw value compatible.
   - A one-time Results nudge after a run with ≥ 3 bites in the first 2 runs: "Keeps waking? Try a forgiving lid."
     with a **Make it forgiving** button.
   - VoiceOver hints on each option.
2. **UX P1-2:** a first-time Skip goes to the lesson's stakes card ("Here's the gist, little thief."), not straight
   Home. The stakes card also says "Close the lid to pause."
3. **UX P1-3:** demo keys and CI frames (`ci/scenarios.txt`, and duo.sh UI frames if cheap) for:
   - the pose tip;
   - "Hold to pause";
   - "Already open?" on the cover card;
   - the closing card with Carry on at accessibility XXXL (it must fit or scroll);
   - Results with the Forgiving nudge.
4. **Copy:**
   - Phone Home must use **lever** words; it still says "Slide its lid up", and tester 11 saw this for the third
     round in a row. Find the source and add a test.
   - "Ease the lid down first" becomes "Lower the lid a little first".
   - Lesson step 5 has a double "to".
   - The Results cause line becomes "The mimic bit you 5 times, and your candle burned out." (not "bit you 5 times.
     Candle out.").
5. **"Hushed!" vs Results "0 Hushed"** (tester 11): check whether the bank callout shows "Hushed!" on banks that
   weren't hushed. If so, it's a bug: fix it (the App's or the Scene's text, from the `banked(hushed:)` flag) and add
   a test. If the frames were just different runs, say so.
6. **VoiceOver:**
   - Announce the closing card and Carry on's appearance.
   - The pause coin's hint is right under VoiceOver (a double-tap pauses at once).
   - The bank announcement includes the chain.
7. **Settings on the Duo:** "Play sound on silent" sits under the fold fade on the lid half. Move it to the floor
   group so the lid group fits without scrolling.
8. **QA-6 P2s:**
   - Release builds no per-touch strings (`ChestScene` raw-touch diagnostics are DEBUG only; the Scene engineer may
     own the file: coordinate through `#if DEBUG` around those lines only).
   - The closing card's text flicker at 3 s.
   - Refresh the hinge on the cover card too.
   - VoiceOver order across the Duo Settings halves.
   - A system sheet must never stay sideways under the menu hold: release the hold while a sheet is up.
9. **Results:** the cut-off half-visible card must read as scrollable (stronger fade plus the chevron), or fit.

Every engineer: write `design/notes/<role>-R11.md`. Don't commit.
