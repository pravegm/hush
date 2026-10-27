# Review 1: UX, clarity and onboarding (senior game UX lead)

*Inputs: GAME-DESIGN.md (§3–§9), notes/app-R1.md, the copy in `Hush/UI/` and `Hush/App/` (LessonScript, AppRules),
the phone simulator set `artifacts/ci2/screens/01–40` and the Duo simulator set `artifacts/duo1/duo-screens/` (mentally
turned 180°). I did not edit any code.*

## Score: 6.5 / 10. Verdict: not launch-ready on clarity, but close

The concept is very clear: lid = lid, slow = safe, shut = keep. The hint system is the best I've seen in this
family of games. The gap is the **in-run HUD**. The three things a first-timer has to read every second (the noise
meter, what's in the bag versus what's banked, and the clock) are **all unlabelled icons**, and the lesson card sits on
top of the meter. The lesson teaches the *verbs* well but never the *stakes*: the bag isn't safe, a bite costs your
bag and 15 s, and when the candle goes out the run is over. That is the same failure the founder's first testers called
out on the sister games ("objective unclear", "half baked"). Fix the five P0s below (mostly copy and layout, about 1–2
days) and I'd score it 8+ and ship.

## First-chest comprehension test (what a first-timer can answer after chest 1)

| Question | Answer from the frames | Verdict |
|---|---|---|
| What do I do? (open slowly, drag, shut) | Lesson steps 1–5 say it in one line each; the hints repeat it | ✅ Clear |
| What's the noise meter? | A thin unlabelled segmented bar with a tiny sleeping-face icon, hidden under the lesson card in steps 1–3 and 5 (03/05/07) | ❌ Not taught |
| What's the torch? | A candle on the floor's left edge. The copy says "torch" (UK readers hear "flashlight"). The lesson has no torch, so it never burns down while you learn. One clause on the final card | ❌ Weak |
| Why did I get bitten? | CHOMP! plus loot flying into the mouth, but the "Freeze!" hint stays up under CHOMP (13). There is no "too loud", no "−164", no "−15 s" | ⚠️ Partly |
| What does banking mean? | "Ease it shut to keep it" teaches the action. "+179" pops small in a corner (14). Nothing ever says loot in the bag is *at risk* | ⚠️ Partly |
| What's the score? | Two numbers with coin-ish icons on the leather strip (bag left, banked right), neither labelled. On the Duo they swap sides | ❌ Not taught |
| Is the lesson short and skippable? | 6 steps, about 30–40 s, Skip from step 2, replayable from Settings | ✅ Good (Skip is missing on step 1) |
| Hints ≤ 6 words, well placed? | All 7 in-run hints are 5–6 words, colour-coded and tested. But the band sits in the loot area right above the meter, covering items and the drag path (10: it covers the silver bar) | ⚠️ Words ✅, place ❌ |

## Top 15 issues

### P0: must fix before launch

**1. Bag and banked counters are unlabelled, so the score is unreadable.**
- 09–16 and the Duo frames show `[bag icon] 164` and `1,819 [coin stack]` with no words.
- A first-timer reads 164 as their score, then watches it vanish on a bite and has no idea why.
- On the Duo the two counters swap sides, so you can't even learn them by position.
- **Fix:**
  - Put a small overline label above each plate: **"IN BAG"** (amber) and **"BANKED"** (gold).
  - Make the bag plate pulse amber whenever it's above 0 and the noise is ≥ Stirring.
  - Give the bag a sublabel while it's above 0: **"Not safe yet"** (3 words). Show it only in the first 3 runs.
  - VoiceOver: "In bag, 164 gold, not safe yet" and "Banked, 1,819 gold".

**2. The noise meter is unlabelled, has no end-state, and the lesson hides it.**
- It's the only fail cause, yet it's a 20-segment bar with a tiny face icon.
- The lesson card's bottom edge overlaps it in 03, 04, 05 and 07. Nothing marks where a bite happens.
- **Fix:**
  - Add a **jaw/teeth icon at the right end** of the meter (it fills toward the teeth), and swap the left icon to an
    ear or the sleeping face at 2× size.
  - Add a 1-word overline **"NOISE"** in the first 3 runs.
  - Move `HUDLayout.lessonBand` up so it clears the meter by at least 12 pt.
  - In lesson step 2, append the meter to the line: **"Open the lid… slowly. Watch the noise."**
  - In step 4, flash a ring around the meter.

**3. The lesson teaches the verbs but never the stakes (risk, loss, clock).**
- Bites are off in the lesson (fine). But nothing ever says that bag loot is lost on a bite, that a bite costs time, or
  that the candle ending is the end of the run.
- The final card (08) is "Lovely work, little thief. / Your torch burns down. Loot all you can, gently."
- **Fix:** turn step 6 into a 3-row icon card (an icon plus ≤ 5 words per row). It's still one glance:
  - 🕯 **"Candle out = run over"**
  - 🦷 **"Too loud? It bites your bag"**
  - 🔒 **"Shut the lid to bank"**
  - Keep the title "Lovely work, little thief." and the button "Start my first run".

**4. Phone: the lid control is invisible or misdirected.**
- The brass lever (`SceneLid.sliderRoot`, x = 606, on the lid's right edge) shows in only one phone frame (08). It's
  missing from every run frame (09–18) and from lesson steps 1–5. The CI captures may be using `lid=`/pilot input;
  **verify on a clean phone install.**
- Meanwhile step 1's marker says **"Slide up here"** with a hand dead centre on the lid, not on the lever.
- In a run with the slider there is no persistent affordance at all once the teaching hints retire.
- **Fix:**
  - Always draw the lever when `usesSlider`.
  - Point the step-1 marker *at the lever*: an arrow along the track, with the copy **"Slide this up… slowly"**.
  - Add a faint up-chevron on the track while the lid is shut and the bag is empty.
  - Keep "Drag the lid up… slowly." on Home (01) consistent: **"Slide the lever up… slowly."**

**5. Duo pose: the hand-off from book pose to tabletop isn't explained, and neither is the turned-round canvas.**
- The book-pose card (duo-ui-pose-book) shows a top view: the left half glows "Lift this half", the other is "Floor",
  with a tiny side-view stick. It never says *turn the Duo sideways*, or which half goes nearest you.
- The whole canvas is turned 180° on purpose, so the iOS status bar ends up on the far side. A player who stands it up
  the "natural" way gets an upside-down game and no prompt to fix it.
- **Fix:**
  - Make the pose card two beats, animated: (a) the Duo rotates a quarter-turn on screen, (b) the glowing half lifts.
  - Copy: title **"Turn it sideways. Lift the glowing half."** Body: **"Keep the other half flat, nearest you. That's
    the floor."**
  - When an upside-down tabletop is detected (sensor gravity versus the expected orientation), show a floor-half card:
    **"Spin it round. Lid at the back."**

### P1: fix before launch if at all possible

**6. The bite doesn't say what it cost, or why.**
- **Fix:** at CHOMP, show these on the floor:
  - **"Too loud!"** (red, 2 words), shown together with **"−164"** as the bag's loot flies into the mouth;
  - **"−15s"** dropping off the candle.
- Clear the hint line during the bite. Today "Freeze!" stays up under CHOMP (13), which reads as "you should have frozen
  *now*".

**7. "Torch" copy versus candle art, and no low-time warning.**
- The art is a candle in a brass tube. Every string says "torch" ("Torch lit. Open it gently.", "Your torch does too.").
  In the UK "torch" means a flashlight.
- 16 (torch-low) shows only a stubby candle and a `lowFlash`. There is no text and no number.
- **Fix:**
  - Rename to **"candle"** in all copy: "Candle lit. Open it gently." / "The mimic waits. Your candle does too." /
    "The candle guttered out with 1,683 gold in your bag."
  - Add a torch-low hint, the **"Candle's low. Bank it!"** line (4 words), as a warning colour.
  - Show the seconds left under the candle for the last 10 s.
  - Show **"+8s"** floating up when oil is bagged.

**8. Mimic personalities and chest tiers are invisible, and "×1" is jargon.**
- "Wary Wendell" and "Wheezy Walt" are charming, but nothing says Wendell is a Light sleeper (×1.35 noise), which is a
  real strategy cue.
- "Wooden chest ×1" leaves the player asking ×1 of what.
- **Fix:**
  - Put the trait as a one-line sub-tag on the arrival card: **"Light sleeper"**, **"Heavy sleeper · less loot"**,
    **"Dreamer · twitches are fake"**, **"Snorer"**.
  - Tier: **"Iron-bound chest · gold ×1.5"**. Hide the multiplier for ×1.
  - Announce the tier step-ups once: **"Gilded! Gold ×2"**.

**9. The arrival name tag lands on top of the loot.**
- The floor tag "Dozy Doris / Wooden chest ×1" overlaps the silver and coins for 1.6 s (06, 07, 11). The name is already
  on the lid plaque.
- **Fix:** show the arrival tag *before* the light reaches the loot (while shut), or put it in a band between the meter
  and the bag strip. Use a translucent backing.

**10. The hint band covers loot and sits in the drag path.**
- The capsule sits right above the meter in the area loot is dragged through (10: it covers the silver bar). The
  dragging finger then covers the hint.
- **Fix:** move `HUDLayout.hintBand` to the back edge of the floor, by the fold, between the lid and the loot. That's
  where the eye already is (the mimic's eye is just across the fold). Keep the meter at the front.

**11. Phone layout is letterboxed, which looks unfinished.**
- On a 6.9" phone (03–18) the 669×951 canvas uses only about 65 % of the height. Black bands are left top and bottom,
  and the pause button is clipped by the right screen edge (03, 09).
- **Fix:**
  - Scale-to-fill the width and extend the dungeon backdrop (wall texture or vignette) into the bands.
  - Move the floor HUD plates into the bottom band so the chest can grow.
  - Inset the pause button by at least 16 pt from the safe area.

**12. Banking reads as small.**
- "+179" pops in the floor's top-right in small type (14). On a relic bank, "Hushed!", "Relic found!" and "+948" stack in
  one row (15).
- **Fix:**
  - Centre a big **"BANKED +179"** pop over the bag-to-counter arc.
  - Stagger the beats: Banked → Hushed → Relic, about 0.35 s apart.
  - Give "Hushed!" its meaning once (first time only): **"Hushed! It never stirred."**

**13. Results: "Hushed" is unexplained, achievements are unnamed, and the middle is dead space.**
- 19–21: the "Hushed 0" tile has no explanation, and "3 achievements earned" is neither named nor tappable.
- About 30 % of the screen between the story and the tiles is empty.
- There's no "why it ended" line on a new best (the new-best story outranks the cause). There's no near-miss pull
  toward Again.
- **Fix:**
  - Tile sublabels: **"Chests banked"**, **"Hushed (it slept)"**, **"Bites"**.
  - List up to 2 achievement names with badge art, and make the row tappable. Use "+1 more" beyond that.
  - Fill the gap with a **chest-by-chest strip**: one small chest icon per chest, coloured green (Hushed), gold
    (banked) or red (bitten). It tells the run's story at a glance.
  - Add a near-miss line under Best when the haul is within 25 %: **"312 gold short of your best."**

**14. Home: truncation and empty states.**
- **"Codex 0/…"** and **"Codex 9/…"** are truncated on the phone (01, 02). That is exactly the "half baked" tell.
- The fresh rank bar is an invisible empty track. The trophy button has no visible label.
- The huge gap between the chest caption and the rank row looks unfinished.
- **Fix:**
  - Let the Codex/Settings/trophy row size to content: **"Codex 9/24"** with a shorter "Settings" icon button, or just
    the icon plus "9/24".
  - Show a 4 % sliver of fill and **"Next: Sneak"** on the fresh rank bar.
  - On the fresh profile show **"Best —"** or **"No haul yet"**.
  - Pull the title chest down, or show the last run's haul in the gap.

### P2: polish

**15. Codex, Settings, accessibility.**
- **Codex (22):**
  - The subtitle runs edge to edge and is clipped at the left ("9 of 24 found…"). Give it 16 pt gutters and 2 lines.
  - Unfound silhouettes reuse the shapes of relics already found (an unfound crown looks exactly like the Moth-Eaten
    Crown), which reads as "I already have that". Give each unfound slot its own silhouette, or use a plain "?" chest.
  - Several relics are bare primitives (the Ring and the Amulet are blobs).
  - Add a first-time hint on the found tiles: **"Tap a relic to read it"**.
- **Settings (24):**
  - "Respect silent switch: Off: you'll hear the creak on silent" is a double negative. Better: **"Play sound on
    silent"** (default on).
  - R1 lists "play with the slider on a Duo" as not done. Add **"Use on-screen lever"** for broken or stiff hinges.
- **Daily:**
  - The copy is good ("One try counts. Make it a quiet one.").
  - The run HUD has no Daily marker (26). Add a small **"DAILY · scored"** overline by the pause button.
- **Accessibility:**
  - The type uses fixed `.system(size:)` with `minimumScaleFactor`, so there is no Dynamic Type. At least let menus,
    results and codex scale.
  - Mist-grey captions on teal-black (Settings sublabels, "Best 1,683") look near the 4.5:1 limit. Lift them a step.
  - Meter stages rely on green/amber/red. Add a shape cue per stage (Zzz, "?", "!") for colour-blind players.
  - There is no VoiceOver lid control (R1). At minimum, VoiceOver should announce stage changes: "It's stirring",
    "It's waking. Freeze."
  - Lesson step 1 has no Skip. Add it, because returning players replaying from Settings will want it.
  - "Like a laptop. A little lower…" is ambiguous ("lower" the lid, or the phone?). Better: **"Close it a little
    more…"**

## The 5 strongest things
1. **The concept explains itself.** One verb (gentle), a real lid, one fail cause. The Home title chest acts out the
   rule before you press Play ("Lift the lid… slowly." → "Shh… something's peeking." → "Easy! It's a mimic…"). That's
   onboarding most games never get.
2. **The hint system is right.**
   - Every hint is ≤ 6 words, and that's enforced by a test.
   - They're colour-coded by urgency (parchment teach, amber "Slower…", red pulsing "Freeze!").
   - HintGate stops flicker, and the teaching hints retire after 5 runs.
3. **The mimic's eye is a great stage tell.** Shut, a sliver, half open, wide slit pupil (05, 11, 12, 13): you read it
   at a glance, it's funny, and the teeth plus the velvet tongue sell "this chest is alive". CHOMP lands.
4. **Pause and closing states have no dead ends.**
   - "Lift the lid a little to carry on / The mimic waits. Your torch does too." has a diagram and a Home exit.
   - The cover card says "Open me… gently".
   - The pause menu sits on the sharp half, and a scored Daily says "Leaving keeps the gold you've banked."
   - The Duo layout (floor sharp, lid blurred) is honoured throughout.
5. **Results lead with the haul and push Again.** A giant gold number, a "NEW BEST!" pill and one witty story sentence
   ("Bitten 3 times: 1,019 gold went down the hatch.", "You lifted the Compass of True North-ish from right under its
   nose."), with Again as the gold primary next to Home. Add the near-miss line and the chest strip and this screen is
   excellent.
