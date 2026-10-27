# Hush: Don't Wake the Mimic. Game design v1

*Owner: founder (Claude). Numbers live in `Hush/Core/Tuning.swift`; this doc gives the intent and the starting values.*

## 1. The pitch (5 seconds)
**Your iPhone Duo is a treasure chest, and the chest is a sleeping mimic.**
- Stand the Duo like a little laptop. The raised half is the lid.
- Open it *slowly* and the light spills in, showing gold.
- Drag the loot into your bag gently, then ease the lid shut to keep it.
- Too fast, and the hinge creaks, the mimic wakes and it bites.

Store line: **"The game where you have to be gentle."**

## 2. Why it works
- **Duo-native:**
  - The lid *is* the phone's half.
  - The hinge's **speed** is the skill, which no Duo game uses.
  - With a touch slider it is still a game, but the hinge makes it a body sensation: the phone creaks under your
    fingers.
- **Clear:**
  - Lid = lid. Shh = slow. Bag = keep.
  - One fail cause: noise. One clock: the torch.
- **Addictive:**
  - Push-your-luck: the ruby is deeper, so do I open wider or bank now?
  - Runs last about 2 minutes, with a score chase, a Daily Dungeon and a Relic Codex to fill.
- **Satisfying:**
  - Creak audio and haptics follow your exact speed.
  - Gold glints in the light, coins clink into the bag, and a heavy *thunk* plus a coin cascade bank the haul.
  - The bite is comic and loud.
- **Kind to the hinge:**
  - About two slow strokes per chest.
  - Never flat, never closed, never fast. Being fast is literally the losing move.

## 3. Pose, angles, and the blurred half (Duo)
- **Tabletop.** The floor half lies on a table or in the palm. The lid half is raised.
- The canvas is portrait (about 669 × 951 pt), with the fold horizontal at mid-height.
  - The **lid** is drawn on the upper half of the canvas.
  - The **floor** is drawn on the lower half.
- **Hinge angle θ** (180 = flat):
  - **Lid openness** `o = clamp((θ − 100) / 65, 0, 1)`: 100° is shut, 165° is fully open.
  - **Shut zone:** θ ≤ 110°. A chest starts here, and banking happens here.
  - **Too wide:** θ > 172° shows the hint "That's wide enough". There is no penalty. This keeps players off flat.
  - **Closing:** θ < 85° held for 0.4 s pauses the game: "Lift the lid a little". Fully shut shows the cover card.
- **The blurred half (founder, 27 Oct):**
  - iOS blurs one fixed physical half of the inner screen (the left half in book pose) for about 1–2 s when a fold
    starts.
  - Brim found that in iOS portrait that half is the *bottom* of a tabletop, which would be our loot floor.
  - **Rule:** the floor is the sharp half. By default the canvas is drawn **turned round** (Brim build 8's proven
    method), so the player lifts the blurring half as the lid. The pose card shows which half to lift.
  - Settings has **"Turn the chest round"** (on by default) to undo this on a Duo that differs.
  - **Nothing time-critical lives only on the lid.** The noise meter, the torch, the bag and the mimic's main tell
    (its tongue, section 5) are on the floor. Every stage change is also a sound and a haptic.

## 4. The chest loop
1. **Ready.** A chest slides in, shut. If θ > 110° the prompt says "Ease the lid down", and the chest waits.
2. **Open.**
   - As `o` rises, the light reaches deeper into the chest. Each item has a **depth** `d ∈ [0, 1]`.
   - An item appears at `o ≥ d + 0.04` (a glint) and can be grabbed at `o ≥ d + 0.10`.
   - Relics sit at d ≈ 0.85–0.92, so they need about 160°.
3. **Grab.**
   - Touch a lit item and drag it to the **bag**, the strip along the floor's front edge nearest the player (about
     110 pt).
   - Dragging fast rattles: that's noise.
   - Letting go outside the bag drops the item back with a clunk: noise.
   - Items in the bag are **in hand**. They are not yet safe.
4. **Bank.**
   - Ease the lid back into the shut zone with at least one item in the bag, and hold it there for 0.35 s.
   - The haul is banked (value × chest multiplier) and the next chest comes.
   - Shutting with an empty bag does nothing.
   - Slamming shut is loud, so the mimic can bite on the way down.
5. **Bite.**
   - Noise reaches 1.0: CHOMP. The loot in hand is lost, and the torch loses 15 s.
   - The mimic hops away and the next chest comes.

**The run:**
- A **torch** burns for 100 s. Torch oil found in chests adds 8 s.
- The run ends when the torch goes out. Loot still in hand is lost.
- The score is the **gold banked**.
- Typical run: 2 minutes, 5–8 chests.

## 5. Noise and the mimic
**Noise N** is 0 to 1. Each source adds a rate per second (starting values, tuned in the sim):

| Source | Rule | Example |
|---|---|---|
| Lid speed ω (deg/s, filtered over about 0.25 s) | `0.006·(ω−8) + 0.00035·(ω−8)²` for ω > 8, else 0 | 20°/s → 0.12/s; 40°/s → 0.55/s; a slam at 120°/s for 0.4 s → +2.0 (bite) |
| Drag speed v (pt/s) | `0.6·(v−250)/1000` for v > 250 | 1000 pt/s → 0.45/s |
| Pick up / into bag / drop outside | +0.02 / +0.03 / +0.08 | |

- **Decay.** After 0.4 s with no source, N falls at the chest's decay rate (0.14/s at the start).
- **Restlessness.** The longer you stay in one chest, the lighter the mimic sleeps: decay × `max(0.5, 1 − 0.02·t)`.
- **Stages** (with hysteresis of 0.04):

| N | Stage | Floor (sharp half) | Lid | Sound / haptic |
|---|---|---|---|---|
| < 0.35 | Asleep | The tongue (a velvet "cushion" in the chest) rises and falls with the snores | Eye shut, Zzz | Snore |
| 0.35–0.70 | Stirring | The tongue twitches; the meter turns amber | Eye flickers | The snore stops; a slow heartbeat |
| 0.70–1.0 | Waking | The tongue curls; the meter turns red; "FREEZE" pulses | Eye half open, teeth show | Growl; a fast heartbeat haptic |
| ≥ 1.0 | Bite | Teeth slam across the fold | Jaw snaps | CHOMP: big thud and haptic |

- **Mimic personalities** (one per chest; a name tag on the floor such as "Snoring Sam"):
  - **Snorer:** ×1.0 noise.
  - **Light sleeper:** ×1.35 noise.
  - **Heavy sleeper:** ×0.7 noise, but less loot.
  - **Dreamer:** ×1.0 noise, plus harmless fake twitches in the lid art only. The floor meter stays truthful.

## 6. Chests and loot
| Chest # in run | Tier | Multiplier | Decay /s | Items |
|---|---|---|---|---|
| 1–2 | Wooden | ×1 | 0.14 | 5–6 |
| 3–4 | Iron-bound | ×1.5 | 0.12 | 6–7 |
| 5–6 | Gilded | ×2 | 0.10 | 7–8 |
| 7+ | Royal | ×3 | 0.085 | 8–9 |

| Item | Value | Depth | Notes |
|---|---|---|---|
| Copper coins | 5–10 | 0.00–0.45 | 2–3 per chest |
| Silver | 20–35 | 0.20–0.60 | |
| Gem (4 colours) | 60–110 | 0.45–0.80 | 1–2 per chest |
| Relic | 250–450 | 0.84–0.92 | Iron-bound and up, about 35 % of chests; each is a named Codex entry |
| Torch oil | +8 s | 0.25–0.55 | About 1 per 3 chests |

Everything is seeded from `(run seed, chest index)`, so the Daily Dungeon is identical for everyone.

## 7. Meta
- **Modes:**
  - **Run**: endless chests until the torch is out.
  - **Daily Dungeon**: the same seed for everyone; one scored try a day, plus practice.
  - **First Chest**: the lesson.
- **Relic Codex:** 24 named relics, such as the Moth-Eaten Crown or the Ever-Warm Teacup. Each is found once and
  stays. A chest at Iron-bound tier or above rolls from the relics not yet found first.
- **Thief rank:** 12 ranks by lifetime gold banked, from "Pickpocket" to "Mimic Whisperer". The rank shows on Home.
- **Game Center:**
  - Leaderboards: "Best Haul" and "Daily Dungeon".
  - 12 achievements, e.g. first relic, bank a chest without the mimic ever stirring, 5 chests in a run.
- **Results:**
  - Gold banked, chests opened, the "Hushed" count (chests banked while the mimic stayed Asleep), relics found and the
    best run.
  - One sentence naming the best moment, or the cause of the end.

## 8. First Chest (lesson, first launch, replayable)
The lesson teaches by doing, one sentence per step, no walls of text:
1. **Pose:** "Stand your Duo like a little laptop. Lift *this* half." The diagram marks the lid half. The step passes
   when 95° ≤ θ ≤ 125° for 0.5 s.
2. **Open:** "Open the lid… slowly." A Heavy sleeper; no bites in the lesson. If ω exceeds 30°/s: creak, the mimic
   grumbles, "Slower…", and its noise falls back.
3. **Grab:** "Drag the coin into your bag."
4. **Freeze:** a scripted stir: "It's stirring. Freeze!" Hold still for 1.5 s, and it snores again.
5. **Bank:** "Ease the lid shut to keep it."
6. Card: "Your torch burns down. Loot all you can — gently." Then Run.

## 9. iPhone without a hinge (fallback)
- The canvas, chest and floor are the same, laid flat.
- The **lid slider** is a wide vertical strip on the lid half: drag up to open, down to shut. Slider speed maps to
  ω with the same noise formula, at 1 pt/s ≈ 0.25°/s.
- The lesson's pose step becomes "Slide the lid up… slowly."

## 10. Feel
- **Audio** (synthesised, `.playback` so it is heard with the silent switch on; Settings has "Respect silent
  switch"):
  - Creak: friction grains plus a resonant groan whose pitch and density follow ω. Silent below 8°/s.
  - Snore breath, a heartbeat by stage, the dungeon bed (drips, torch crackle).
  - A tiptoe pizzicato motif while Asleep, which thins out as N rises.
  - Coin clink (FM), gem chime, bag thud, bank thunk plus cascade, and CHOMP.
- **Haptics:**
  - A continuous creak texture (intensity ∝ ω in the creak zone).
  - A tick per coin, a heartbeat at Waking, a heavy thunk on banking, and a big bite.
- **Look:**
  - A candlelit dungeon: warm golds against deep teal-black.
  - A chunky cartoon chest of wood and iron.
  - A cute-scary mimic: one big eye, round teeth and a velvet tongue.
  - Gold bloom when lit. The light falls into the chest from the lid opening.
