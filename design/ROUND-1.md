# Round 1: first playable (brief)

Read first: `design/GAME-DESIGN.md`, `design/ARCHITECTURE.md`, `Hush/Shared/Contracts.swift`, `CLAUDE.md`.
**Goal:** a complete, compiling, playable game on the first CI run: First Chest lesson → Run → Results → Home,
Daily, Codex, Settings, with feel (audio, haptics) and art that already sells the fantasy.

**Sister code to copy from (read-only, never modify):**
- Swoop: `C:\Users\59527\Wing\Swoop\...`
- Brim: `C:\Users\59527\Fold\Brim\...`

Both are battle-tested on a real Duo and in this CI. Copying and adapting is encouraged; rename `Swoop`/`Brim`/`SWOOP-`
to `Hush`/`HUSH-`.

## Demo mode (DEBUG only; launch argument `-hushDemo "k=v;k;…"`)
The App engineer parses it (`Hush/App/DemoMode.swift`); every module reads `DemoMode.current` (App) only through the
App. Keys:

| Key | Meaning |
|---|---|
| `screen=home\|run\|results\|codex\|settings\|lesson\|pose\|cover` | Start on this screen (`run` = straight into play) |
| `mode=run\|daily\|attract` | The run mode for `screen=run` (default `run`) |
| `seed=<n>` | The run seed |
| `pilot=novice\|casual\|expert\|perfect` | A `ThiefPilot` drives the lid and the touches. Without it, `screen=run` takes the real hinge (Duo CI) or the slider |
| `progress=fresh\|mid\|late` | Seed `ProgressStore` (fresh: nothing; mid: rank 4, 9 relics, best 2,400; late: rank 10, 22 relics, best 9,800) |
| `freezeOn=<tag>` | Stop stepping the session (the scene keeps drawing) at the first: `ready`, `reveal` (openness ≥ 0.75 and ≥ 3 items lit), `stirring`, `waking`, `bite`, `bank`, `relic`, `torchLow`, `torchOut`, `results`. Print `HUSH-T freeze <tag>` |
| `freezeAfter=<s>` | Freeze after s seconds of play |
| `lid=<0…1>` | Hold the lid at this openness (no pilot, no hinge): static frames |
| `noise=<0…1>` | Hold the noise at this level (stage frames) |
| `lessonStep=<n>` | Start the lesson at step n (1–6) |
| `turn=0\|1` | Force "Turn the chest round" off or on (CI shoots both) |
| `fold=1` | Lay out as if a fold exists (phone sims; frames of the Duo layout) |
| `sound=0` | Mute |

**Log lines** (stdout, DEBUG with `-hushDemo` only, one `print` + `fflush`):
- `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1>` on every layout change.
- `HUSH-T input hinge|slider|pilot` when the lid source changes.
- `HUSH-T lid <openness 2dp> speed <°/s 1dp> angle <θ 1dp|-> noise <2dp> stage <name>` at 10 Hz while in play.
- `HUSH-T event <name> [details]` for every HeistEvent (names = the enum case names).
- `HUSH-T paused closing` / `HUSH-T resumed`.
- `HUSH-T freeze <tag>`.
- `HUSH-T frame 120`.
- `HUSH-H <t> <angle>` (Feel engineer, inside HingeReader).

## Core engineer: `Hush/Core/`, `HushTests/CoreTests.swift`, `HushTests/BalanceTests.swift`
- Everything in ARCHITECTURE "Core API", with exactly those signatures.
- **Tuning:** every number in GAME-DESIGN §3–§6.
- **ChestFactory:** loot placed without overlap (≥ radius sum + 6 pt) inside `FloorSpace.interior`.
  - Deeper items sit further back (towards the hinge, smaller y) on average, but not strictly: the light reveals
    them by depth, not by position.
  - Radii: coin 22, silver 24, gem 26, relic 34, oil 24.
- **RelicCatalog:** 24 relics, each with a charming name and blurb, e.g. "The Moth-Eaten Crown — still fits, mostly".
  Use the 12 `RelicShape`s twice with different tints.
- **MimicNames:** about 10 per kind.
- **ThiefPilot:**
  - Opens at a skill-dependent speed:
    - novice: 10–35°/s, sometimes over the loud limit;
    - casual: 8–16°/s;
    - expert: 5–9°/s;
    - perfect: 6°/s.
  - Freezes when the stage ≥ stirring (expert/perfect) or waking (casual); novice sometimes doesn't.
  - Drags lit items to the bag at a skill-dependent speed.
  - Reaches for relics if expert+.
  - Eases shut at 6–15°/s to bank. Novice occasionally slams.
- **BalanceTests:** run 8 seeds × 4 skills through a full run with the pilot at 60 Hz. Assert:
  - novice gold < casual < expert ≤ perfect (median);
  - casual banks 4–8 chests; novice gets bitten ≥ 1 time per run on median;
  - perfect is never bitten;
  - a run lasts 90–160 s for casual.
  - Print a table as `HUSH-BAL` lines.
- **Unit tests:** noise rates match the §5 examples, stage hysteresis, openness mapping, determinism, bank/bite/torch
  rules, hint priority, the touch pick/drop/bag rules, oil, DailySeed, ranks, achievements.

## Feel engineer: `Hush/Input/`, `Hush/Feedback/`, `HushTests/FeelTests.swift`
- `HingeReader` (copy Swoop's, `HUSH-H`).
- `HingeLidSource`, `SliderLidSource`, the filters (One-Euro, copy Swoop's `FeelFilters.swift`).
- **FeedbackDirector**, audio engine (copy and adapt Swoop's `FeelAudioEngine` and `FeelSynth` architecture:
  lock-free render, command queue, beds) and haptics (copy `FeelHaptics`). The sounds come from GAME-DESIGN §10:
  - **Creak** is the hero. Wood friction:
    - noise grains (bandpassed 600–2,500 Hz) whose density follows lid speed;
    - a resonant "groan" (a saw through a resonant low-pass) at 140–420 Hz whose pitch wavers;
    - a squeal partial above 25°/s.
    - Silent below 8°/s, soft at 8–20, loud past 30.
    - It must feel like the phone's hinge is creaking.
  - **Snore** (breath noise with a 3.5–5 s cycle, plus a low nasal tone on the inhale) while Asleep. It stops at
    Stirring.
  - **Heartbeat:** a soft double thump. Slow (60 bpm) at Stirring, fast (110) at Waking.
  - **Growl** at Waking.
  - **CHOMP:** a low thump, a wooden crack, teeth clack, then a burp-y growl.
  - Coin clink (2–3 inharmonic FM partials, bright), silver ting, gem chime (a bell, by colour pitch), relic choir
    swell (a warm chord).
  - **Bag thud:** a soft leather thump plus clink.
  - **Bank:** a heavy lid thunk, then a cascade of 6–14 clinks over 0.8 s (count by value), then a low "ka-ching"
    chord.
  - **Tiptoe motif:** a quiet pizzicato phrase (a minor-key "sneaking" ostinato, about 92 bpm) while looting
    Asleep. It thins out at Stirring and stops at Waking.
  - **Dungeon bed:** drips and a low drone. Torch crackle louder in the last 15 s, plus a tick.
- **Haptics:** a continuous creak texture (intensity ∝ (speed − 8)/30, sharpness 0.3–0.6 with jitter), a coin tick,
  a bag thump, the bank thunk plus rattle, a heartbeat at Waking, a bite slam (strongest transient) and UI taps.
- `homeLid(speed:openness:)`: the Home chest creaks too.
- **Tests:** filter speed from synthetic sample streams (e.g. 10°/s at 30 Hz reads 9–11; still for 0.5 s reads < 1;
  a 2 s gap then a sample doesn't spike), the slider's speed, the closing dwell, the noise-free render (no NaN; peak
  < 1.0 over 10 s of mixed events).

## Scene engineer: `Hush/Scene/`, `HushTests/SceneTests.swift`
`ChestScene` and `ChestArt` per ARCHITECTURE. The look (GAME-DESIGN §10). It must read on a still frame.
- **Floor half (sharp):** the open chest seen from above, in perspective-ish.
  - Thick wooden walls with iron bands along the left, right and back (the back is at the fold).
  - A velvet lining, which is the mimic's **tongue**: a big pink-red velvet shape across the chest bed. It breathes
    when Asleep, twitches at Stirring, and curls/lifts at Waking. This is the main tell on the sharp half.
  - Loot sits on it.
  - **Darkness** covers the interior, and the light reveals by depth:
    - each item shows by its `light`;
    - a warm light wash spreads from the back (the opening) as openness grows;
    - glints sparkle on lit gold.
  - **The bag** is a leather satchel strip along the front edge, showing the bagged loot (small icons) and the
    in-hand value.
  - **Noise meter:** a horizontal "snore-o-meter" just above the bag. Its segments go green, amber, red, it shows a
    tick at the stage lines, and it shakes when near 1.
  - **Torch:** a candle/torch gauge at the floor's left edge (burns down, flickers when low).
  - **Gold counter** at the floor's right edge.
  - **Shut-hold:** a ring that fills on the bag while banking.
- **Lid half (may blur):** the underside of the lid = the mimic's upper jaw.
  - Wooden planks and iron studs.
  - A row of big rounded teeth along the fold edge, tucked away when Asleep and showing as it wakes.
  - **One big eye** in the middle: shut and Zzz when Asleep, flickering at Stirring, half open with the iris
    tracking the player's finger at Waking, wide when biting.
  - The mimic's name tag on a little brass plate.
  - No HUD here except ambience.
- **Fold band:** the hinge, drawn as the chest's brass hinge strip.
- **Moments:**
  - **Bite:** the teeth slam down across the fold, the floor shakes, in-hand loot flies into the mouth, and a red
    flash.
  - **Bank:** a lid-shadow sweep, the loot glints and flies into the counter, and the counter rolls up.
  - **Chest arrival:** the new chest slides in from the front with dust.
  - **Relic found:** a golden ray plus its name on the floor.
  - **Torch out:** darkness closes in.
- **Touch:** begin, move and end on the floor half go to `driver.floorTouch…` (floor space). On the lid half,
  `sliderTouch` when `usesSlider` is true. Draw the slider (a brass lever track with a knob) only when `usesSlider`.
  Multi-touch on.
- **Tests:** geometry mapping round-trips, palette contrast sanity, and that the art paths are non-empty for every
  kind and shape.
- Performance: 120 fps target on the Duo; no per-frame path rebuilding for static art; cache textures.

## App engineer: `Hush/App/`, `Hush/UI/`, `Hush/Persistence/`, `HushTests/AppTests.swift`
- **`HushApp`, `RootView`:**
  - A portrait play canvas; landscape on a Duo shows the pose card.
  - **Turned round** (Brim's method, `C:\Users\59527\Fold\Brim\UI\RootView.swift`), default on for a Duo. Settings
    has "Turn the chest round".
- **Screens:**
  - **Home:** the title "Hush", a live chest that follows the hinge (or the slider), and Play, Daily Dungeon, Codex,
    Settings. It shows the thief rank, the best haul and the daily status.
    - On a Duo, Home's big buttons sit on the floor half.
    - Opening the lid on Home makes the little mimic peek out: a playful hint at the game.
  - **The HUD over the scene (SwiftUI):** the hint text (one line, ≤ 6 words, on the floor half above the meter),
    a pause button and the pause menu (Resume, Restart, Home).
  - **Pose cards:**
    - "Stand it up like a little laptop" (landscape): a diagram, with the lid marked "Lift this half".
    - "Lift the lid a little to carry on" (closing pause).
    - A cover-display card when shut: the sleeping mimic plus "Open to carry on".
  - **Results:** the gold banked (a big counting number), new best, chests banked, Hushed count, bites, relics found
    (art), the rank bar progress, and one sentence of story. Buttons: Again, Home.
  - **Codex:** a 24-slot grid. Found relics are drawn (`ChestArt.relicPath`) with name and blurb; unfound ones are
    silhouettes "???".
  - **Settings:** Sound, Haptics, Respect silent switch, Turn the chest round (Duo only), Reduce motion, Replay First
    Chest, About, Credits.
  - **Daily Dungeon:** one scored try a day (then practice), with today's best.
- **First Chest lesson** (GAME-DESIGN §8): a `HeistSession(mode: .lesson)` with a fixed chest (2 copper, 1 silver,
  1 gem; heavy sleeper). The App drives the 6 steps: copy, gates and the scripted stir via `nudgeNoise(to: 0.55)`.
  - It runs on first launch. Skip is allowed after step 2.
  - On phones without a hinge, the step texts switch to the slider.
- **GameController:**
  - The hub (ARCHITECTURE), with pause on closing, app inactive or the menu.
  - Lid sources:
    - `HingeLidSource` fed by `HingeReader` on the root view;
    - `SliderLidSource` when no hinge;
    - `ThiefPilot` output when the demo asks.
  - Pilot touches are fed to the session as real touches.
- **Persistence:**
  - `ProgressStore`: best per mode, lifetime gold, relics found, achievements earned, daily (the day, played, best),
    stats, lesson done.
  - `SettingsStore`.
  - Versioned JSON in UserDefaults.
- **Game Center:** copy Swoop's `GameCenterManager`.
  - Leaderboards `hush.best` (Best Haul) and `hush.daily` (Daily Dungeon).
  - Achievements `hush.ach.<key>` from `Achievements.all`.
  - Silent when signed out.
- **Theme** (`HushTheme.swift`): candlelit gold on teal-black, a rounded heavy display font (system `.rounded` black
  weight) for numbers, and big hit targets (≥ 56 pt). Use `ChestArt.palette`.
- **DemoMode** (the keys above) and every `HUSH-T` line listed.
- The **app icon** as code (`UI/AppIconArt.swift`, like Swoop's). CI renders the PNG: the founder's CI step reads
  `HUSH_ICON=1`. Its subject is the chest, lid slightly open, one sleepy eye peeking, gold glow inside.
- **Tests:** progress/settings round-trip and migration, the daily one-scored-try rule, demo parsing, turned-round
  rules, lesson step gating.

## CI engineer: `.github/workflows/`, `ci/`
Adapt Swoop's `ci.yml`, `duo.yml`, `testflight.yml`, `tf-status.yml`, `ci/screenshots.sh`, `ci/duo.sh` and the
scenario files for Hush (portrait canvas; phone sim "iPhone 18 Pro" in portrait). Specifics:
- **`ci.yml`:**
  - Build, test, screenshots from `ci/scenarios.txt`.
  - Render the app icon: run the app with `-hushDemo "screen=icon"` and pull `HUSH-ICON` PNG from the app's
    Documents (follow Swoop's approach if it did it differently).
- **`ci/duo.sh` hinge pass:** the Duo sim's inner display in tabletop is *portrait*. If the sim boots in book pose,
  rotate the device to portrait via `xcrun simctl` … **never** `screenConfig`. Check Swoop's and Brim's
  `ci/duo.sh`/`DUO-CI.md` for how they rotated (Brim is tabletop). Checks:
  1. **SLOW-OPEN:** hinge at 105, launch `screen=run;mode=attract;seed=7`, sweep 105 → 160 over 7 s. PASS if
     `event lidCracked` appears and the max logged noise is < 0.35.
  2. **SLAM:** launch `screen=run;mode=run;seed=7`, sweep 105 → 150 over 6 s, hold 2 s, then sweep 150 → 104 in
     0.3 s. PASS if `event bitten` or `stage waking` is logged within 2 s.
  3. **STILL:** after a sweep, hold 1.5 s. PASS if a logged speed is < 1.0.
  4. **CLOSE-PAUSE:** sweep to 60 → `paused closing`; sweep back to 120 → `resumed`.
  5. Frames: closed 105, half 135, wide 160, the cover display shut, and the pose card in book pose (if the sim
     allows).
- Store-frame passes come later (round 3). Keep `duo.yml` manual.
- `testflight.yml`: bundle `com.pravegm.hush`; everything else as Swoop's (the cloud-managed signing path).
