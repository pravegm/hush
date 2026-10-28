# Round 12: the lid IS the chest (brief, founder's real-Duo test of build 6)

## The founder, verbatim (28 Oct)
> "you really need to work on the lid open and close mechanism. lid shut i launch the game it asks me to open the lid,
> once open i click play while lid is open, then it again asks me to open the lid - this makes no sense, the lid is
> already open. moving from one chest to another, the lid is still open but it asks me to again open - again makes no
> sense. it should feel real please. the chest closed means lid closed, chest open means lid open"

## Diagnosis
- `HeistSession` puts every new chest in `.ready`, where it waits until the lid has been seen in the "shut zone"
  (≤ 110°) before it can be opened. If the lid is already open at run start or after a bite, the player is told to
  lower it ("Lower the lid a little first") and then to open it again. That breaks the physical metaphor.
- Our "shut" is 100–110°, which to a human holding a laptop-shaped Duo looks *open*.

## The model (founder decision; overrides earlier rounds)
1. **The lid angle is the chest's openness, always.** There's no hidden gate and no extra "lower it first" before a
   chest can be played.
2. **Run start:** if the lid is already open when the run starts (Play pressed with the lid up), the **first chest is
   simply open**. Looting begins at once and the loot shows at the current openness. If the lid is closed, the first
   chest arrives closed and you open it.
3. **Bank = close the lid.** With loot in the bag, the lid going into the shut zone (≤ 110°) and held 0.35 s banks,
   as now. Copy: **"Close the lid to bank"** (Duo), "Slide the lever down to bank" (phone). Closing it all the way is
   fine: the bank fires on the way down; then the cover display shows the sleeping mimic, and reopening starts the
   next chest.
4. **The next chest arrives only under a closed lid.**
   - After a bank, the lid is closed by definition, so the next chest is dealt at once, closed.
   - After a **bite**, the lid is usually open, so the robbed chest **stays open and empty**: no loot, the mimic
     glaring, the "CHOMP" aftermath. The only prompt is **"Close the lid for the next chest"** (`HeistHint
     .closeForNext`). The next chest is dealt (`chestArrived`) the moment the lid enters the shut zone, and it
     arrives closed. Open it to play.
   - The candle keeps burning while you close. It's quick, and the urgency is honest.
5. **What the floor draws matches the lid.**
   - At openness ≈ 0 (the shut zone), the floor half shows the **closed chest**: the outside of the lid (wooden
     planks, iron bands, the lock) seen from above, covering the interior.
   - As the lid opens (openness 0 → ~0.15), that cover lifts and slides back towards the hinge, revealing the dark
     interior; then the light does the rest, as now.
   - Never draw an open chest while the lid is shut, or a closed chest while it's open, except the bitten chest
     after a bite, which is drawn open and empty.
6. **Home:** the live title chest already follows the lid. Pressing Play with the lid open goes straight into an open
   first chest (rule 2), with no prompt to open.
7. **Lesson:** keep the teaching order (close it, then open it slowly), but in chest words: "Close the lid…" and
   "Now open it… slowly." Never ask to open an already-open lid: if the lid is open at step 1, the step says "Close
   the lid to start".

## Core engineer
- Implement rules 1–4 in `HeistSession`:
  - First chest of a run (not the lesson): `.looting` at once if `!lid.inShutZone` on the first step.
  - After a bite: keep the robbed chest (spec, no loot), phase `.ready`, with a new `awaitingClose` state. The hint is
    `.closeForNext` until `lid.inShutZone`, then deal the next chest (`chestArrived`) with `sawShut = true`.
  - After a bank: unchanged (the next chest is dealt in the shut zone).
  - `.easeLidDown` is no longer produced in runs. Keep the enum case for compatibility, or map it.
  - Expose `HeistSession.awaitingClose: Bool` and `HeistSnapshot`-visible state through the existing snapshot: when
    awaiting, `snapshot.loot` is empty and `snapshot.hint == .closeForNext`.
  - Pilots: after a bite the pilot closes the lid (it already does to bank).
  - Mirror in `tools/balance-sim.js`. Balance should be nearly unchanged; report the medians. The Daily stays
    deterministic: the deal order is unchanged.
- Tests for each rule.

## Scene engineer
- Rule 5: the **closed-chest cover** on the floor:
  - drawn at openness ≤ 0.02;
  - it lifts and slides towards the hinge as the openness goes 0 → 0.15 (eased);
  - every tier and golden (the lid's planks, bands, studs, lock and jewels match the tier);
  - the turned and quarter-turn layouts (it lives in `world`).
- After a bite (`snapshot.loot` empty and `hint == .closeForNext`), draw the robbed chest open and empty: the tongue
  is curled and the eye angry on the lid. Don't draw the cover while the lid is open.
- When the next chest arrives under a closed lid, it slides in already covered.
- Tests.

## App engineer
- Copy:
  - `HeistHint.closeForNext` → "Close the lid for the next chest" (Duo) / "Slide the lever down for the next chest"
    (phone).
  - Bank copy: "Close the lid to bank" (Duo).
  - Remove every run-time "open the lid" prompt that can show while the lid is open: banners ("Candle lit. Open it
    gently." only when the lid is closed; otherwise "Candle lit. Gently does it.").
  - Lesson wording per rule 7.
  - Home caption: "Lift the lid… slowly" only while the lid is closed. While open: "Shh… something's peeking."
- Play with the lid open → straight into the open first chest. Check every path that starts a run: Play, Again,
  Daily, Restart.
- The R7 fresh-chest / closing-pause interplay: closing fully after a bank goes to the cover display and pauses.
  Reopening must resume straight into the new (closed → opening) chest, with no "Hold still" friction on a fresh
  chest (R7 rule).
- Tests and demo/CI frames:
  - `screen=run` with `lid=0.8` at start → looting at once;
  - the closed cover at `lid=0`;
  - the robbed chest after a bite with "Close the lid for the next chest".

## CI engineer (`ci/duo.sh`)
- **START-OPEN:** hinge at 150, launch `screen=run;mode=attract`. PASS if `event lidCracked` or looting starts
  within 3 s with no `hint easeLidDown`, and the lid lines show the openness of 150°.
- **BITE-CLOSE-NEXT:** a slam that bites (`mode=run`), then hold at 150 for 2 s. PASS if no `chestArrived` while
  open; then close to 105 and expect `chestArrived` within 1 s; then reopen and expect `lidCracked`.
- **BANK-CLOSE-FULL:** with loot in the bag (pilot or `lid=` plus a demo bag), close to 30° (the cover display).
  Expect `banked` before the pause; reopen and expect the next chest closed, then opening.

Every engineer: write `design/notes/<role>-R12.md`. Don't commit.
