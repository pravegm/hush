# Round 7: real hands (brief)

**Source:** `design/DEVICE-RISKS-1.md`, which predicts the founder's other real-Duo issues from TestFlight 1.0 (1).
- **Root cause:** every CI and balance run moves the hinge smoothly and slowly. A real hand is faster and jerky, and
  a real hinge sticks, then slips.
- Read the doc in full for your role.

**Rule for this round:** forgiving on unknown hardware. When unsure, be kinder. The skill is still "slow", but a
normal careful human must never be punished.

## Core engineer (Core, CoreTests, BalanceTests, tools)
1. **Tuning:**
   - `quietSpeed` 12 → **14**; `closeQuietSpeed` 18 → **28**.
   - Noise counts only after the lid has been above quiet for **0.08 s** (a stick-slip blip is free). This is a
     Core rule in `HeistSession`, fed by `lid.speed`. Add `Tuning.loudOnsetSeconds = 0.08`.
2. **The "fresh chest" rule:**
   - A chest that is `.ready` and untouched (nothing opened yet) after a bank is not a resume hazard.
   - Expose `HeistSession.isFreshChest: Bool`: `.ready`, openness never > 0.05 in this chest, nothing in the bag.
   - The App will skip the stillness wait for it.
3. **Lid sensitivity:**
   - Add `enum LidSensitivity: String, Codable, CaseIterable { case forgiving, normal, careful }` in Core.
   - Add `SessionOptions(sensitivity:)`, mapping to `noiseScale` 0.75 / 1.0 / 1.2. The scored Daily always uses
     `.normal`; enforce it in `SessionOptions.for(mode:)` with an override argument.
   - The App adds the Settings row.
4. **Pilots:** the novice and casual pilots get realistic "hands":
   - casual closes at **20–40°/s** and opens at 10–25°/s, with stick-slip (0.5–2° jumps at the start of each
     stroke);
   - novice is faster still.

   Re-run the sim (8 and 40 seeds). Targets:
   - casual is never bitten on median and banks ≥ 6;
   - novice median ≥ 1,000 gold and ≥ 3 chests banked;
   - expert and perfect are unchanged (±10 %).

   Update BalanceTests bands only if needed, with the reason in your notes. Mirror everything in
   `tools/balance-sim.js`.
5. **Tests** for each rule.

## Feel engineer (Input, Feedback, FeelTests)
1. **A clean speed estimator** (DEVICE-RISKS item 2):
   - after a restart (no report for > 0.12 s), the first derivative uses `dt ≥ 0.10 s`;
   - steps < 0.4° are ignored (a deadband on the reported angle);
   - a single-report jump over 8° above 150° is a snap: no speed is credited (it is treated as the hinge settling).
   - **Trace tests:**
     - a stick-slip slow open (2° jumps then 0.5° steps at 10°/s average) never reads above 14°/s after 0.15 s;
     - a real 40°/s move still reads 36–44°/s within 0.2 s;
     - a slam still reads > 80°/s.
2. **Resume:**
   - hysteresis at 92° (enter) / 88° (leave) instead of a hard 95°;
   - above 100°, the still threshold is 10°/s instead of 6;
   - keep `canResume`'s API.
3. **Haptics for careful play:**
   - a faint tick for every 4° of quiet travel (so a slow, silent open still feels like a hinge), at most 20 Hz;
   - `FeedbackDirector.hapticStrength: HapticStrength` (`.off`, `.normal`, `.strong`), defaulting to `.strong` on a
     Duo and `.normal` elsewhere. The App adds the Settings row.
4. **Raw hinge trace:** keep the last 10 s of raw hinge reports (t, angle) in a ring buffer.
   `HingeLidSource.traceText() -> String` gives the App's Diagnostics Copy log a compact text block.

Every engineer: write `design/notes/<role>-R7.md`. Don't commit. Use the names above exactly; the App engineer wires
them next.

## App engineer (after R6 lands)
1. **Copy:**
   - "Ease the lid down to bank" (never "shut"); the lesson says "to upright".
   - On a fresh chest (`isFreshChest`) after a bank, reopening skips "Hold still…".
2. **The pause coin:**
   - On a Duo, mid-chest, it needs a 0.35 s press-and-hold, with a fill ring as feedback. A tap shows "Hold to
     pause". Elsewhere it's a tap.
   - Or move it to the bag-strip corner, whichever the layout allows; keep `lootKeepOut` consistent.
3. **The lesson:**
   - Step 1 passes after 4 s anywhere in 80–125°, or after 0.5 s in 90–112°.
   - Skip from step 1 after 20 s, or from the start on a replay.
   - Freeze is judged by displacement (< 8 pt in 0.3 s), not drag speed.
4. **Settings:**
   - "Lid sensitivity" (Forgiving / Normal / Careful): the Daily's scored try uses Normal, and the row says so.
   - "Vibration" (Off / Normal / Strong).
5. **Diagnostics Copy log:** add the raw hinge trace (`HingeLidSource.traceText()`).
6. **Game Center** sign-in waits until after the lesson.
7. **"Other way round" banner:** extend it to a Duo held at 170–180° in menus (DEVICE-RISKS item 9).
