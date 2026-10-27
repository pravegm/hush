# Feel R1 hand-off: input, audio, haptics

*Feel engineer, Round 1. Files: `Hush/Input/*`, `Hush/Feedback/*`, `HushTests/FeelTests.swift`. Nothing committed. Not
compiled yet (CI is the compiler).*

## What I built

- **Input**
  - `HingeReader` (Swoop's, unchanged in behaviour, prints `HUSH-H <t> <angle>` at ≤ 10/s).
  - `HingeLidSource` and `SliderLidSource`.
  - `FeelFilters.swift`: One-Euro, Swoop's `HingePredictor`, the new `FeelSpeedEstimator`, `FeelClosingGate` and
    `FeelDemoLog`.
- **Feedback**
  - `FeelSynth`: Swoop's lock-free real-time synth (SPSC atomic command ring, voice pool, modal bank, limiter), with
    Hush's continuous layers and an FM voice added.
  - `FeelAudioEngine` (Swoop's, self-healing, naps when idle).
  - `FeelSoundBook`: every recipe and the bed, as pure functions.
  - `FeelHaptics` and `FeelHapticBook`: two looping players (the creak texture and the rattle) plus one-shot cues.
  - `FeedbackDirector`.
- Everything is synthesised; there are no audio files.

## Public API (the ARCHITECTURE contract, plus the additions marked ➕)

```swift
@MainActor final class HingeLidSource: LidSource {
    init(); func ingest(angleDegrees:at:); var hasHinge; var angle: Double?; var isClosing; func lid(at:) -> LidInput
    ➕ func closing(at: TimeInterval) -> Bool      // isClosing judged at a given time
    ➕ var clock: () -> TimeInterval              // what isClosing judges the dwell against (CACurrentMediaTime; tests override)
    ➕ func reset()                               // forget motion (keeps hasHinge + the last reading); call on becoming active
    ➕ private(set) var speed, lastRawAngle, lastSampleTime, lastLid   // diagnostics for the HUSH-T lid line
    ➕ nonisolated static func lidInput(angle:speed:) -> LidInput      // the pure θ → LidInput mapping
}
@MainActor final class SliderLidSource: LidSource {
    init(); func touch(began:ended:fraction:time:); func lid(at:) -> LidInput
    ➕ var degreesPerFraction: Double   // default 65 = Tuning.wideAngle − Tuning.shutAngle (see "Open question")
    ➕ private(set) var openness, isTouching, speed; func reset(openness: Double = 0); static let shutZoneOpenness = 0.15
}
struct HingeReader: ViewModifier   // HingeReader(onUpdate: { angle, time in … }, onUnavailable: { … })
enum FeelDemoLog { static let isEnabled: Bool; static func line(_:) }   // ➕ emit(_:) alias. DEBUG && "-hushDemo" only.

@MainActor final class FeedbackDirector: FeedbackSink {
    static let shared; func start(); var soundOn, hapticsOn, respectSilentSwitch, idle: Bool
    func handle(_:telemetry:); func uiTap(); func uiConfirm(); func celebrate(); func silence()
    func homeLid(speed:openness:)
    ➕ var deviceHasFold: Bool                 // set true once a hinge is seen: haptics default to Strong (weak Duo taptic)
    ➕ var hapticProfile: FeelHapticProfile    // .normal / .strong (optional; hapticsOn keeps working alone)
    ➕ var idling: Bool { get }
}
```

**Behaviour the App should know**
- **The slider drag is relative.**
  - A finger landing anywhere on the strip doesn't move the lid; the lid moves by however far the finger moves.
  - It re-anchors at the ends, so a pull past shut followed by a move up opens at once.
  - A jump to the finger would be a slam, which means noise.
  - The scene should draw the knob at `snapshot.openness`.
- **`isClosing`** latches after 0.4 s under 85° and clears above **88°** (3° of hysteresis, so the pause card can't
  flicker).
  - It works with no frames: while the game is paused it judges the reports, and the dwell matures on the clock.
- **No hinge:** `lid(at:)` returns `LidInput()`, which is shut and still.
- **Watchdog:** if `handle`/`homeLid` stop arriving without a `silence()`, the director fades the continuous layers
  after 0.25 s by itself. Nothing can be left creaking.
- **`idle = true`** (menus): the engines nap once quiet. Menu sounds and the Home creak still play and wake them.
- **`playing: false`** (result moments):
  - The creak still follows the hinge, at 80 %, because it's the phone's own hinge.
  - The dungeon ambience holds for 3 s.
  - Snore, motif, growl and rattle fade.
- **Heartbeat:** the director keeps the beat itself from `telemetry.stage`: 60 bpm at Stirring (sound only), 110 at
  Waking (sound and haptic in step).
- **Torch tick:** the director plays a tick on each whole second of the last 15 s of `torchRemaining`.
- **`dreamTwitch` is deliberately silent.** It is lid art only, so sound and haptics stay truthful.

## The speed estimate (the skill)

**Two pipelines run on the same raw reports**
- **The angle** (openness, zones, closing): `HingePredictor` → One-Euro at frame rate. It is continuous between
  reports.
- **The speed** (`FeelSpeedEstimator`):
  - One-Euro on each report (2 Hz, β 0.12).
  - Over a **0.25 s window** it takes the mean of the net speed and the path speed. A steady move reads exactly, a
    fast wiggle still counts (half its path), and uneven report spacing cancels out.
  - **Gap-aware:** it uses real elapsed times, and never takes a derivative across a silence longer than 0.25 s. The
    report after a gap restarts the filter as a base and contributes no speed.
  - **Decay:** with no report for more than 0.12 s, it decays with τ 0.15 s.
  - At display rate a 0.04 s follow smooths the 30 Hz steps.
  - It never reads the predictor, so extrapolation can't invent motion.

**Verified numerically** in a Node port of the exact algorithm, with a fake Duo at 30/25 Hz that reports only after
≥ 0.25° of movement:

| Case | Result |
|---|---|
| 10°/s | reads 10.00 at both 30 and 25 Hz |
| 10°/s with ±0.5° report jitter | 8.1–12.3 |
| Still 0.5 s after 10°/s | 0.67–0.82 |
| Still 1.5 s | 0.001 |
| Report after a 2 s gap, and a 9° jump after a gap | 0 |
| Slam at 120°/s | 74 at 0.1 s, 98 at 0.15 s, 117 at 0.3 s, peak 122 |
| Tremor ±0.5° at 6 Hz | ≤ 1.6 (quiet) |
| Onset from still at 30°/s | crosses 8 after 67 ms, 20 after 150 ms |

## Sound design

**Mix**
- Master 1.25, then a DC blocker, a peak-follower limiter (ceiling 0.9) and a tanh soft clip, with the output clamped
  to ±0.98.
- Levels were measured in a Node port of the render loop:

| Layer | RMS level |
|---|---|
| Dungeon bed | −37.5 dB |
| Snore | −34 dB |
| Growl (full) | ≈ −28 dB |
| Rattle | ≈ −34 dB |
| Creak at 12 / 15 / 20°/s | −39 / −33 / −27 dB |
| Creak at 30°/s | −21 dB |
| Creak flat out (60°/s and up) | −17 dB, peak 0.83 |

- So the soft creak sits just above the snore, and the loud creak dominates everything continuous.

**Session:** `.playback` + `.mixWithOthers`, so it's heard with the silent switch on. `.ambient` when
`respectSilentSwitch` is set.

**The creak (the hero)**
- It follows the bed per sample: no zipper, and the bed glides 0.05 s.
- **Groan:** a stick-slip pulse train (a PolyBLEP saw).
  - Every period has its own slip strength and ±7 % jitter, with an 8 % chance of a weak "catch".
  - It runs through a resonant low-pass (Q 5) at 2.4–4.4× its pitch, plus a 1.1 kHz wooden body formant.
  - Its pitch is 140 → 420 Hz with speed, and wavers ±9 % on a random walk.
- **Grains:** 1.5–5.5 ms noise bursts, each through its own Q 3.5 band (600–2,500 Hz, brighter with speed), at
  12–252 per second.
- **Squeal:** a 1.7–2.6 kHz sine that fades in from 25°/s (full at 45), its amplitude fluttering with the slips.
- **Level curve** (continuous and monotonic; the test checks a step < 0.02 per 0.05°/s):

| Speed (°/s) | Creak level |
|---|---|
| ≤ 8 | 0 (exactly silent) |
| 20 | 0.4 |
| 30 | 0.8 |
| 50 | 1.0 |

**The mimic**
- **Snore:** a 3.6–4.9 s cycle (4.25 s ±15 %).
  - The nasal inhale is breath noise at 420 Hz plus a 95 Hz saw fluttering at 27 Hz; then a breathy 900 Hz exhale and
    a pause.
  - A shut lid muffles it to 55 %, and it gets lighter as the noise rises.
  - It stops at Stirring.
- **Stage-up stings:**
  - Stirring: a snort.
  - Waking: a rising growl under a sour minor-second sting, then the growl bed (a 23 Hz vocal-fry rattle over a
    78 Hz saw), louder towards a bite.
  - Stage down: a relieved sigh.
- **Heartbeat:** a lub-dub with its body at 120 → 62 Hz plus harmonics, so a phone speaker carries it.
- **CHOMP:** a 150 → 48 Hz thump, a wooden crack, two teeth clacks (+35 ms, +60 ms), then a burp-y growl at +160 ms.
  It is the biggest sound.

**Loot**
- **Copper:** 3 inharmonic FM partials (2.3, 3.65 and 5.2 kHz) plus a second smaller knock.
- **Silver:** a glass ting at 2.1 kHz plus FM at 4.2 kHz.
- **Gems:** a bell by colour (ruby C6, emerald D6, sapphire E6, amethyst G6) plus a glint an octave up.
- **Relic:** a D-major choir swell (4 voices with vibrato and an "aah" breath). It plays after the ka-ching.
- **Moves:**
  - Pick: a soft lift plus the item's voice at 35 %.
  - Bag: a leather thump plus the voice.
  - Drop: a clunk that sounds like a mistake.
  - Reveal: a glint, queued 70 ms apart when several light at once.
- **Bank:**
  - A heavy thunk.
  - Then a cascade of 6–14 clinks (one more per doubling over 50 gold) between 0.12 and 0.93 s, slowing like settling
    coins.
  - Then the ka-ching at 1.0 s: a metal "ka" and a low D-major bell chord.
  - A hushed bank adds two proud chimes.
  - The haptic rattle uses the same cascade times.

**Music and ambience**
- **Tiptoe motif:** a 32-step D-minor pizzicato ostinato at 92 bpm (eighths), D4 root, using modal "pluck" voices.
  - Density thins by beat weight: all notes while safely asleep, quarters as the noise nears 0.35, strong beats only
    at Stirring, and nothing at Waking.
- **Dungeon:**
  - A soft D/A drone with slow breathing, plus cave air.
  - Drips (0.5/s) with a faint echo.
  - The torch's flame hiss and crackle, louder and denser in the last 15 s, plus a tick each second.
- **Rattle:** dragging faster than 250 pt/s rattles the loot (two Q 12 metal bands).

**Haptics** (Strong is the default on a Duo: taps become 55 ms bursts and continuous levels are ×1.4)
- **Creak texture:** a looping player.
  - Intensity is (speed − 8) / 30, clamped.
  - Sharpness is 0.3 → 0.6 with speed.
  - Every 30 Hz send carries ±15 % intensity and ±0.07 sharpness jitter: the stick-slip grain.
- **Moments:**
  - Coin tick, bag thump (a brighter double for gems and relics), and a drop clunk.
  - Bank thunk plus cascade taps plus the ka-ching tap.
  - The heartbeat at Waking.
  - **The bite:** a 1.0 slam, a 0.32 s shudder and a second snap. It is the strongest cue (tested).
  - The stage-up nudges.
  - Chest arrival, torch low and out, new best, and the UI taps.

## What to listen for on device (please report)

1. **The creak is the game.**
   - Open the lid slowly (about 5°/s): it should be silent.
   - Speed up through 10–20°/s: a soft woody groan should grow under your fingers.
   - At 30°/s and up it should be loud and rough, and a squeal should cut in past ~25°/s.
   - It should start within about a tenth of a second of the hand and stop about 0.25 s after the hand stops.
   - Does it feel like *the phone's hinge*?
   - If it is too tonal, lower `FeelSynth.groanGain` / raise `grainGain`. If it is too hissy, the reverse.
2. **Haptic creak:** is it felt at 15°/s on Strong? If it is too weak, raise `FeelHapticBook.creakSpan` sensitivity
   (lower 30).
3. **Stillness:** let go of the lid mid-open. The creak and the speed must die out with no ghost creak.
4. Pause on closing (< 85° for 0.4 s), then reopen past 88°: it should resume promptly.
5. Snore vs creak balance; the growl at Waking should be scary, not muddy, on the speaker.
6. The bank cascade and ka-ching should be satisfying; the CHOMP should be comic and loud without distortion.

## Open question for the founder / Core

- `Tuning.sliderDegreesPerPoint = 0.25` (GAME-DESIGN §9: 1 pt/s ≈ 0.25°/s) disagrees with ARCHITECTURE ("|d
  fraction/dt| × 65°"). Over the 456-pt lid half, ×65 is 0.143°/pt.
- I followed ARCHITECTURE: one full slider stroke equals one full lid stroke, so both take the same time at the quiet
  speed.
- For the GAME-DESIGN mapping, set `slider.degreesPerFraction = 456 * Tuning.sliderDegreesPerPoint` (114).

## Tests (`HushTests/FeelTests.swift`, 37 tests)

- **Speed:**
  - 10°/s at 30 and 25 Hz reads 9–11.
  - Still for 0.5 s reads < 1.
  - A gap then a sample doesn't spike, and the ramp afterwards doesn't overshoot.
  - A slam is loud within 0.15 s.
  - Jitter and tremor.
  - Never NaN or negative.
- **Lid mapping** and zones, the closing dwell (with and without frames), gate hysteresis, and `reset`.
- **Slider:** speed = fraction/s × 65, decay, and relative drag.
- **Creak curve:** silent ≤ 8, monotonic and continuous, the squeal from 25.
- **Rendering:**
  - The creak renders exactly silent below 8 and grows with speed.
  - A sweep doesn't blow up.
  - Each bed layer is audible but gentle.
  - 10 s of mixed events: no NaN, peak < 1, < 2 % of samples over 0.6.
  - A hot pile-up never clips.
- **Recipes:** all sane; the cascade and its haptic; the motif; the haptic shapes; the director with feedback off;
  edge cases; the haptics toggle; and `FeelDemoLog` gated.
