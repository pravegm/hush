# Round 13: the phone IS the chest (founder, build 7 test, 28 Oct)

> "the iphone lid is at 90 degrees open and it says that the chest is closed. how is it closed if the lid is still
> open? … iphone lid should be the chest lid. open means open and closed means closed."
> "lid closed means chest closed. on the main screen there should be something to tell the user that for the next
> chest to open, open lid slowly, even 1 degree open lid means chest is opening"

## Root cause
From round 1 the Duo standing like a laptop (~90°) was the chest's *shut* pose: openness was (θ − 100) / 65, so
everything up to 100° read as a closed chest, the shut zone was ≤ 110° and the closing pause < 70°. Round 12 removed
the "open the lid" gates but kept that dead zone, so a phone visibly open at 90° still showed a closed chest.

## Decisions
1. **The chest follows the phone.** Openness = θ / 150 (0° shut … 150° wide). Any opening opens the chest.
2. **Closed means closed.** The shut zone (bank) is θ ≤ 15°. The closing pause is θ < 12° for 0.4 s, and it unlatches
   above 20°. Resume is ≥ 18° held still, with hysteresis down to 15°. The cover display taking over still banks
   (R12b).
3. **The game's own lid scale is unchanged.** Core keeps its 65° lid travel. `HingeLidSource` maps the phone onto it
   (`Lid.hingeOpenness`) and scales the hinge's °/s by 65/150 (`Tuning.hingeSpeedScale`). The same openness per second
   makes the same noise, so the lever, the pilot, the balance and Core's tests don't move.
4. **The lesson loses its shut-first gate** (`shutGate` is never on). Its chest opens with the lid like every other.
   Step 1 is any laptop pose, 45–150° (loose 30–165°).
5. **What the player reads while the chest is closed:**
   - **Cover card:** "Open the lid slowly", then "The chest opens with the lid, from the very first degree."
   - **Closing card:** "Open the lid slowly for the next chest" / "… to carry on".
   - **Home on the Duo:** "Open the lid slowly. The chest opens with it."
   - **The words' "open" line:** 0.15 → 0.03 (≈ 4.5°).
6. **Unchanged:** "Already open?" on the cover card still needs ≥ 92° (it rescues a stuck cover display, not a
   normal close). "That's wide enough" stays above 172°.

## The lever (phone QA, same round)
- **Shut zone:** 0.15 → 0.06, and a silent shut detent on release, so the lever down means the chest is drawn shut.
- **Multitouch:** only the first lid-half finger owns the lever. A second finger used to snap it.
- **Copy:**
  - "Lever down for the next chest";
  - Results "Nothing banked. Slide the lever down to bank.";
  - Forgiving: "For shaky hands. Easier to stay quiet."
- **Open from QA, not done yet:**
  - a lever drawn on Home;
  - lever noise per screen size (`degreesPerFraction` by stroke length);
  - a down chevron;
  - a VoiceOver adjustable lever;
  - more phone sizes in CI.

## CI
`ci/duo.sh` trajectories and thresholds move to the new angles:
- closes go to ≈ 5°;
- "upright, no pause" becomes "low but open (25°), no pause";
- the expected openness is θ / 150.
