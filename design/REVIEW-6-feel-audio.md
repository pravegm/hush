# REVIEW-6: feel, audio and haptics

*Reviewer: senior game audio and haptics designer. Scope: `Hush/Feedback/*`, `Hush/Input/HingeLidSource.swift` plus
`FeelFilters.swift` (the speed estimate), and the feel notes R1, R2, R3 and R7. No Swift was edited.*

**How I measured.** I couldn't listen, so I ported `FeelSynth`'s render loop to Node: the voices, the modal bank, every
continuous layer, and the DC blocker, limiter and tanh. I also ported the `FeelSoundBook` recipes and
`FeelSpeedEstimator(.hinge)`. The port is `tools/audio-probe.js`:

```
node tools/audio-probe.js [creak|speed|shots|mix|voices|haptic|variants|hot]
```

It reproduces R1's own level table to within 1 dB: the creak at 20/30/60°/s measures −28.4/−21.3/−17.0 dBFS, against
R1's −27/−21/−17.

The measurements are:
- loudness as BS.1770 K-weighted LUFS (mono);
- spectra from a Welch FFT;
- a buzz-versus-noise periodicity score: the normalised autocorrelation peak, where 1 is a pure buzz and below 0.3 is
  irregular friction;
- envelopes;
- a **phone-speaker proxy**: a 4th-order high-pass at 400 Hz. That is roughly where an iPhone's speaker gives up. The
  proxy matters more than anything else here.

**Verdict.**
- The architecture is excellent: lock-free, zipper-free, self-healing, truthful silence.
- I found one real bug. The voice pool is too small, so **the biggest banks silently lose their ka-ching, chain chime,
  relic choir and new-best**.
- Three design problems hurt satisfaction:
  1. The hero creak is a nasal *buzz* more than wood.
  2. The whole game is about 12–15 LU quieter than a typical iOS game, and most of the tension cues live below 200 Hz,
     where a phone speaker plays nothing.
  3. The Duo's default Strong haptic profile flattens every cue to the same 55 ms, sharpness-0.4 burst.

All three can be fixed with parameter changes.

---

## 1. The creak

**What the DSP is**
- A PolyBLEP saw at 140–420 Hz. Each period has its own slip strength (0.55–1.0, with an 8 % "catch" at 0.15–0.3) and
  ±7 % period jitter, plus a ±9 % random-walk wobble.
- It runs through a resonant low-pass at Q 5, with the cutoff at (2.4 to 4.4) × pitch.
- A fixed 1.1 kHz body band-pass sits under it at gain 0.05.
- Noise grains: 1.5–5.5 ms long, a Q 3.5 band at 600–2,500 Hz, 12 → 252 per second.
- A 1.7–2.6 kHz sine squeal from 25°/s.

**Measured, shipped** (the creak layer alone, after the master chain)

| °/s | level | RMS dBFS | LUFS | centroid | <400 Hz | 1–2.5 kHz | periodicity r | groan / body / grains (dB) |
|---|---|---|---|---|---|---|---|---|
| 15 | 0.06 | −46.0 | −46.9 | 334 Hz | 72 % | 2 % | **0.77** | −46 / −69 / −59 |
| 20 | 0.40 | −28.4 | −29.0 | 494 Hz | 46 % | 4 % | **0.69** | −28 / −51 / −38 |
| 25 | 0.60 | −23.9 | −24.2 | 679 Hz | 24 % | 11 % | **0.73** | −24 / −47 / −31 |
| 30 | 0.80 | −21.3 | −21.3 | 847 Hz | 23 % | 21 % | 0.61 | −22 / −44 / −26 |
| 40 | 0.90 | −19.5 | −18.7 | 1,279 Hz | 19 % | 54 % | 0.39 | −22 / −42 / −24 |
| 60 | 1.00 | −17.0 | −15.1 | 1,954 Hz | 3 % | 58 % | 0.35 | −21 / −40 / −19 |

**Judgement**
- **Wood or buzz?** In the zone where careful players live (14–30°/s), it is a **periodic buzz**.
  - The periodicity is 0.6–0.77, the energy sits at 150–700 Hz, and the grains are 10–13 dB under the groan.
  - The body formant is 23 dB under the groan, so it does nothing.
  - The resonance tracks the pitch (cutoff ∝ pitch) at Q 5, so the timbre is a vowel that slides with pitch. That reads
    as a kazoo or a synth "groan", not a plank.
  - Real wood friction is the opposite: impulses at the slip rate exciting **fixed** body resonances, with fibre
    crackle on top.
  - Only above about 40°/s do the grains take over, and then it does sound like rough friction.
- **The fix is pure mix** (Top-10 #2). Measured, it sounds like a woody groan with fibre crackle and keeps its pitch:

| °/s | RMS dBFS | centroid | periodicity r |
|---|---|---|---|
| 20 | −27.6 | 791 Hz | 0.54 |
| 30 | −19.9 | 1,183 Hz | 0.29 |
| 40 | −17.1 | 1,495 Hz | 0.23 |

- **Tracking and zipper**
  - The bed glides every parameter per sample (one-pole, 0.05 s), and the groan filter re-tunes every 32 samples. That
    attenuates the 30 Hz report steps by about 19 dB, so there is no zipper.
  - The level curve is continuous and monotonic.
- **Silence**
  - The creak is exactly 0 at or below 14°/s (`Tuning.quietSpeed`), and while closing at or below 28°/s.
  - The squeal is 0 below 25°/s. The frozen-speed guard and the watchdog are correct.
  - Note that 14–16°/s renders at −46 dBFS, so the *audible* line on a speaker is really about 16.5°/s. That is still
    truthful: noise there is under `quietRateThreshold`.
- **Latency** (through the real estimator, with a fake Duo at 30 Hz and ≥ 0.25° steps)

| Hand | Creak audible after | 95 % of level after | Silent after the stop |
|---|---|---|---|
| 20°/s | 217 ms | 392 ms | 158 ms |
| 30°/s | 133 ms | 350 ms | 233 ms |
| 45°/s | 108 ms | 308 ms | 300 ms |

  - This is the main thing standing between "a sound effect" and "the phone's own hinge creaking". Above about 100 ms
    the hand leads the sound.
  - It is input-side (the 0.25 s window, the 0.10 s breakaway floor, One-Euro, the 0.04 s follow), so it isn't in the
    low-risk list. See §6 "Next".

## 2. The rewards

These are momentary maximums (400 ms). "spk" is after the speaker proxy.

| Sound | peak dBFS | LUFS | spk LUFS | centroid | voices |
|---|---|---|---|---|---|
| coin clink | −13.7 | **−27.9** | −27.9 | 2.7 kHz | 4 |
| bag thud + copper | −12.4 | −27.7 | −29.2 | 2.1 kHz | 6 |
| bag thud + gem | −13.3 | −22.7 | −23.1 | 1.1 kHz | 4 |
| silver ting | −14.1 | −23.1 | −23.1 | 2.4 kHz | 2 |
| bank 30 g | −4.6 | −20.2 | −24.4 | 0.6 kHz | 32 |
| ka-ching chord alone | −9.9 | −20.6 | **−24.2** | **497 Hz** | 5 |
| relic choir | −11.3 | −21.2 | −22.4 | 0.7 kHz | 6 |
| chain up ×3 | −11.8 | −21.6 | −21.6 | 1.2 kHz | 4 |
| golden arrival | −11.1 | −20.7 | −20.7 | 2.0 kHz | 14 |
| new best | −8.6 | −17.1 | −17.1 | 2.0 kHz | 4 |

- **Bright and layered:** the gems, chain, golden arrival and new best are good.
  - They are bright, layered (glass and bell partials, glints, ±1.5 % detune seeds) and survive the speaker intact.
- **The coin clink** is the most frequent reward, and at −27.9 LUFS it is as quiet as a *soft creak* (−29 at 20°/s)
  and 6–7 LU under a loud one. The tick that says "you got it" doesn't cut through.
  - **Variation is thin.** Each hit varies only the carrier (±3 %, about ±50 cents) and the timing of the second knock.
    The gain and the FM index are fixed.
  - The bag thud's pitch and cutoff are fixed, so every bagging is identical. That fatigues after 30 coins.
- **The ka-ching** is a *low* D4–F♯4–A4 bell chord. The bell table's "hum" partial (×0.5) puts energy at 147–220 Hz.
  - Its centroid is 497 Hz and it loses 3.6 dB on the speaker. It reads as a dull *bong*, not a ka-ching. The only
    bright parts are a 12 ms noise tick and a 0.04 glint.
  - Up an octave, it measures −19.5 spk LUFS instead of −24.4: **+4.9 dB on the speaker**.
- **The bank cascade is nicely designed:** 6–14 clinks slowing like settling coins, sharing its timing with the haptic.
  - The jitter is a fixed sine, so every bank of the same size is rhythmically identical. That is minor.
- **Reward over the bed**
  - A 400 g hushed bank with chain, relic and best measures −16.9 LUFS momentary with all voices playing, against a
    −31.5 bed. That is +14.6 LU, which is good contrast.
  - With the shipped 48 voices it is −18.1, because 18 voices are stolen (§7, bug B1).

## 3. Tension: snore, heartbeat, growl, CHOMP

| Cue | LUFS | spk LUFS | speaker loss | energy < 200 Hz |
|---|---|---|---|---|
| heartbeat, slow (the Stirring tell) | −28.7 | **−43.5** | **−14.9 dB** | 88 % |
| heartbeat, fast | −26.2 | −41.2 | −15.0 dB | 88 % |
| snort (stage-up to Stirring) | −30.2 | −40.0 | −9.8 dB | 70 % |
| wake sting | −20.3 | −33.5 | −13.2 dB | 81 % |
| growl bed (full) | −31 dBFS RMS | n/a | n/a | 78 Hz saw, 260 Hz LP noise |
| CHOMP | −16.8 | −23.3 | −6.5 dB | 73 % |

- **Is the escalation audible?** On headphones, yes. **On the phone speaker, mostly not.**
  - The asleep bed through the speaker proxy is about −35.6 LUFS.
  - The slow heartbeat at −43.5 spk LUFS sits *under the bed*, and at Stirring it has no haptic. So the Stirring stage
    has essentially no sustained tell on the speaker.
  - The snort and the wake sting lose 10–13 dB.
  - Raising the heartbeat to 150 → 80 Hz with 8 harmonics and a 500 Hz band-pass "thock" recovers +7.5 dB (−36.0).
  - Raising the wake sting's minor second an octave (D4/D♯4) recovers +5 dB.
- **Is the CHOMP punchy?** Its *shape* is right.
  - The transients are 2 ms and 0.5 ms; it takes 145 ms to fall 20 dB, and the burp tail runs 0.7 s. It is the loudest
    one-shot, and it hits the limiter.
  - But 73 % of its energy is a 150 → 48 Hz thump the speaker can't play. That thump also pumps the limiter, which
    ducks the mids.
  - Through the speaker, its loudest 50 ms is **−15.8 LUFS, against −15.3 for the 45°/s creak plus growl it usually
    lands on**. On a phone, the "biggest sound in the game" is no louder than the slam that caused it.
  - A leaner CHOMP measures −14.5 (Top-10 #9): less sub, more crack, wood and a mid crunch.
  - Dropping the resting creak share from 0.8 to 0.35 when the bite stops play makes the jaw *own* the moment.

## 4. Haptics

**The Strong default on a Duo**
- **Strong is the right default.** The founder said "vibration felt weak".
- **But Strong is implemented as a *replacement*:** every transient becomes `buzz(intensity × 1.15, sharpness 0.4,
  0.055 s)` (`FeelHapticBook.adapt`). That erases the vocabulary:
  - The coin tick (sharpness 0.9), the bank thunk (0.2), the creak crack (1.0) and the bite slam (0.7) all become the
    same rounded 55 ms bzz.
  - Continuous events also ramp in on the actuator, so the slam loses its leading edge.
- **Layering keeps both:** the original transient (crisp onset, its own sharpness) plus a 40 ms burst under it
  (energy). This is Top-10 #6.

**The creak texture** (`creakLevel` = (speed − 14)/30; Strong × 1.4; sharpness 0.30 → 0.60 ± 0.07; ±15 % intensity
jitter at 30 Hz)

| °/s | Normal | Strong | sharpness |
|---|---|---|---|
| 16 | 0.07 | 0.09 | 0.32 |
| 20 | 0.20 | 0.28 | 0.34 |
| 25 | 0.37 | 0.51 | 0.38 |
| 30 | 0.53 | 0.75 | 0.42 |
| 40 | 0.87 | 1.00 | 0.49 |

- **Haptic dead zone (bug B6):** the quiet ticks stop the moment the creak starts (`quiet: !creaking`). But the texture
  is ≤ 0.2 until about 18°/s on Strong, and continuous haptics under about 0.25 are near threshold.
  - So at the exact moment the player starts making noise, they feel *less* than they did a moment before.
  - A 0.6 curve fixes it: 16°/s → 0.28 Strong, 20 → 0.53.
- **±15 % jitter is too subtle to read as grain.** At 0.3 intensity it is ±0.045. Use ±30 %.
- **Draining and annoying?** It is fine.
  - Both looping players idle at intensity 0, and no parameter is sent while silent (the `changed`/`silencing` guards).
  - The engine has `isAutoShutdownEnabled = false` only in play (runs of about 2.5 min), and the haptics idle in menus.
  - The continuous creak only plays while you're doing the wrong thing, so its "annoyance" is the design.
  - The 30 s loop could produce a tiny bump at the loop seam if it lands mid-creak. That is negligible.

**The other cues on Strong**
- **Quiet ticks:** `tap(0.18, 0.8)`, which on Strong becomes a 55 ms bzz at 0.21.
  - That is felt as a faint fuzz, not a tick, and 0.18 is at threshold on a weak actuator.
  - Use 0.3 at sharpness 0.7: still well under every reward (0.45+) and the bite. The rate is only 1.3–7 per second, so
    it can't buzz.
- **Bank:** the thunk is `tap(1.0, 0.2)` plus `buzz(0.75, 0.1, 0.12 s)`. The cascade taps are 0.4 → 0.26 at sharpness
  0.85, and the ka-ching tap is 0.7.
  - The shapes are good. But at n = 14 the first cascade gaps are **19–27 ms**, and on Strong 4 of 13 bursts overlap
    the next, which smears into a buzz.
  - Layering (#6) shortens the burst to 40 ms, which mostly fixes that.
- **The bite:** `tap(1.0, 0.7)` plus `buzz(1.0, 0.15, 0.32 s)` plus `tap(0.85, 0.4)` at 0.12 s, with the curve
  1 → 0.9 → 0.5 → 0.
  - It is correctly the strongest cue, and 0.32 s is the right length.
  - **The second snap is at 0.12 s, but the sound's second tooth-clack is at 0.06 s.** A 60 ms haptic-audio offset is
    perceptible. Move it to 0.06.
- **The heartbeat** (`tap(0.75, 0.15)` plus `tap(0.5, 0.15)` at 0.14 s, Waking only) is in sync with the sound and has
  good low sharpness.
  - Adding a soft version at Stirring makes the escalation *felt*: nothing → a soft slow beat → a firm fast beat → the
    slam.

## 5. The mix

**Integrated loudness by scene** (10 s, BS.1770, mono, shipped)

| Scene | LUFS | speaker LUFS | peak dBFS |
|---|---|---|---|
| asleep, lid still (careful play) | **−31.9** | −35.6 | −13.6 |
| asleep, opening at 20°/s | −27.0 | −29.6 | −10.7 |
| asleep, opening at 30°/s | −21.3 | −22.5 | −5.8 |
| stirring, still, with the heartbeat | −31.0 | −39.2 | −10.1 |
| waking, still (growl plus fast heartbeat) | −26.2 | −37.1 | −7.6 |
| waking at 40°/s | −17.8 | −19.0 | −3.7 |
| bank moment (momentary max) | −16.9 | n/a | −3.6 |
| bite moment (momentary max) | −16.5 | n/a | −2.9 |

- **Loudness**
  - Careful play, which is most of the game, sits at about −32 LUFS: 12–16 LU under typical iOS games (about −16 to
    −18) and under the system UI sounds.
  - "A candlelit hush" is the right intent, but at half volume on a speaker in a living room this will read as "is the
    sound on?". That is the founder's Squish complaint coming back by another route.
  - The rewards top out around −17 LUFS momentary.
  - `masterGain` 1.25 → 1.8 adds +3.2 dB everywhere (careful play about −29, moments about −14). The R1 test bound "hot
    < 2 % over 0.6" stays satisfied: I measured 0.07 % shipped, 0.15 % at 1.6 and 0.46 % at 2.0, in a port of that
    test's scenario.
  - Don't go to 2.0 without the CHOMP and duck changes. At 2.0 a 40°/s creak (−14.1) overtakes the bite (−13.9).
- **Headroom**
  - The limiter drives tanh to at most 0.9, so **the true ceiling is tanh(0.9) = 0.716 = −2.9 dBFS**. The ±0.98 clamp
    never acts.
  - R1's "creak flat out peak 0.83" can't happen in this chain; it is a stale note.
  - Normal play peaks at −10 to −14 dBFS, so there are 7–11 dB of unused headroom outside the CHOMP.
  - The limiter has no lookahead and an instant attack with an 80 ms release, so on a 48 Hz thump it ripples gain about
    22 % per cycle (mild intermodulation). The CHOMP change removes most of that sub.
- **The silent-switch policy is correct.**
  - `.playback` + `.mixWithOthers` by default; `.ambient` behind "Respect silent switch".
  - There is no `UIBackgroundModes` audio, so nothing plays in the background.
  - VoiceOver speech mixes in (R3).
- **Interruptions are handled well.**
  - `.began` sends `stopAll` (nothing bursts out afterwards), `.ended` and `didBecomeActive` resume, and `heal()` is
    skipped while interrupted.
  - Media-services resets rebuild the engine; route and configuration changes restart it.
  - Ignoring `shouldResume` is fine for a game.
- **Battery**
  - The audio naps after 6 s idle, and the haptics idle in menus. That is good.
  - `setPreferredIOBufferDuration(0.005)` wakes the audio thread every 5 ms. 0.01 halves those wake-ups at no audible
    cost, since the creak's latency is about 130 ms from input anyway.

## 6. Bugs

- **B1 (P1): voice-pool overflow drops the ending of every big bank.**
  - `bank()` sends 8 + 4 × cascade commands: 32 at 30 g and 64 at 14 clinks. The same frame adds the chain (4), the
    choir (6) and the best (4).
  - Every command is started at once, and delayed voices hold a slot from that frame.
  - Once 48 slots are full, `start()` steals the highest `age`. All just-queued voices have age 0, so it overwrites the
    same lowest-index fresh slot again and again. **The commands queued last are lost.**
  - Measured, with a little bed and two bagged items before the bank:

| Bank | Commands | Stolen | What survives (kept / queued) |
|---|---|---|---|
| 400 g hushed, chain, relic | 60 | 21 | hushed chimes 0/2, chain 0/4, choir 1/6 |
| 1,700 g with best | 72 | 33 | **ka-ching 0/5**, hushed 0/2, chain 0/4, choir 0/6, best 1/4 |
| 96 voices, any case | n/a | 0 | everything |

  - Ring voices also hold their slot for decay × 7 (a gem bell: 6 s, by which point it is at −67 dB), and a steal cuts
    a voice with no fade, which clicks.
  - Fix: Top-10 #1.
- **B2 (P2): Strong erases the haptic vocabulary.** Every tap becomes the same sharpness-0.4 burst (§4). Fix: #6.
- **B3 (P2): the Stirring tells are below the speaker's band.** The slow heartbeat loses 15 dB and sits under the bed;
  the snort loses 10 dB (§3). Fix: #8.
- **B4 (P2): there is a haptic dead zone at 14–18°/s**, between the quiet ticks stopping and the creak texture becoming
  perceptible (§4). Fix: #7.
- **B5 (P3): the bite haptic's second snap (0.12 s) is 60 ms off the sound's last tooth-clack (0.06 s).** Fix: #9.
- **B6 (P3, docs): R1's peak table is stale.** The ceiling is −2.9 dBFS.

## 7. Top 10 improvements (ranked by satisfaction impact; all low-risk parameter changes)

| # | Change (file: before → after) | Why (measured) |
|---|---|---|
| 1 | **`FeelSynth.voiceCount` 48 → 96.** And in `start(_:)` `.ring`, `spec.decay * sampleRate * 7` → `* 5`. | Fixes B1. With 96, the 1,700 g bank keeps all 72 commands. The ring slot is freed at −43 dB, which is inaudible under the bed. The bank memory is 96 × 6 × 5 floats (11 KB). CPU at worst is about 96 small voices at 48 kHz, which is trivial. |
| 2 | **The creak voice:** `FeelSynth.retuneContinuous` groan `q: 5` → `3`; `bodyGain` 0.05 → 0.18; `grainGain` 2.0 → 3.5; `FeelSoundBook.grainBase` 12 → 30. | Turns the buzz into wood. At 20°/s periodicity goes 0.69 → 0.54 and the centroid 494 → 791 Hz; at 40°/s, 0.39 → 0.23 and 1.28 → 1.50 kHz. The body formant goes from −23 to −10 dB re groan; the grains from −10 to −2 dB. The level rises 0–3 dB at the top (60°/s: −17.0 → −14.0 dBFS). The hero sound gets fibre and a fixed resonance. |
| 3 | **`FeelAudioEngine.masterGain` 1.25 → 1.8.** | +3.2 dB: careful play about −29 LUFS, moments about −14 momentary. Hot samples stay ≤ 0.5 % (the test bound is 2 %). It answers "is the sound on?" on a speaker. Ship it with #9. |
| 4 | **The coin clink, louder and alive:** `coinClink` gains 0.09/0.06/0.035/0.045 → 0.16/0.11/0.065/0.08. Each partial's gain × `dice.float(0.85, 1.15)` and `index` × `dice.float(0.8, 1.2)`. | −27.9 → −22.7 LUFS momentary: the most frequent reward now clears a soft creak by 5 LU instead of tying it. The random gain and index stop it fatiguing. The cascade, the celebrate shower and the spill inherit it. |
| 5 | **The ka-ching up an octave:** `bank()` chord `[293.66, 369.99, 440]` → `[587.33, 739.99, 880]`; the ka-ching glass gain 0.04 → 0.07. | −24.4 → −19.5 spk LUFS (+4.9 dB on the speaker). It is brighter (the hum partial moves out of the 147–220 Hz dead zone), so it reads as "ching", not "bong". |
| 6 | **Strong layers instead of replacing:** in `FeelHapticBook.adapt`, a `.transient` becomes `[.tap(min(i·1.15, 1), s), .buzz(min(i·0.7, 1), min(s, 0.5), duration: 0.04)]`; `strongBurst` 0.055 → 0.04. | Keeps each cue's own sharpness (tick 0.9, crack 1.0, thunk 0.2) and its leading edge, and adds energy underneath. It cuts the cascade smear (19–27 ms gaps). Update FeelTests 915 and 1828 (they assert "all continuous"). |
| 7 | **The haptic creak onset:** `FeelHapticBook.creakLevel` `clamp01((s − q)/30)` → `pow(clamp01((s − q)/30), 0.6)`; `creakIntensityJitter` 0.15 → 0.30. | Strong at 16/20/25°/s goes 0.09/0.28/0.51 → 0.28/0.53/0.77, which closes the dead zone (B4). ±30 % jitter reads as stick-slip grain. Update FeelTests 858 (+15°/s now gives 0.66). |
| 8 | **Danger you can hear on a speaker and feel:** in `heartbeat`, the tones 120→62 / 110→60 Hz → 150→80 / 140→78 Hz, `harmonics` 4 → 8, the noises `.lowPass 260/240` → `.bandPass 500/480`. In `wakeSting`, the two 146.83/155.56 tones → 293.66/311.13 with harmonics 3 → 5 and gain 0.05 → 0.06. Add `FeelHapticBook.heartbeatSoft = [.tap(0.4, 0.15), .tap(0.28, 0.15, at: 0.18)]` and play it in `keepTheBeat` when `!fast`. | Heartbeat spk LUFS −43.5 → −36.0 (slow) and −41.2 → −33.6 (fast); wake sting −33.5 → −28.5. Stirring gets a sustained tell in the hand (B3), so the escalation reads nothing → soft beat → hard beat → slam. |
| 9 | **A CHOMP that wins on the speaker, and a duck:** in `chomp`, the thump `gain 0.36 → 0.2, end 48 → 70, harmonics 6 → 8`; the LP noise 0.34 → 0.2; the HP crack 0.26 → 0.34; the wood ring 340 Hz 0.26 → 0.36 (5 partials). Add a `.noise(.bandPass, cutoff: 750, to: 450, sweep: 0.08, q: 1.2, attack: 0.001, decay: 0.05, gain: 0.32)` "crunch". `FeelSoundBook.restingCreakShare` 0.8 → 0.35. In `FeelHapticBook.bite`, the second snap `at: 0.12` → `0.06`. | The speaker's loudest 50 ms goes −15.8 → −14.5 LUFS, above the −15.3 creak it lands on. Less sub pumping the limiter. The creak gets out of the jaw's way (the bank's slow close is barely affected). The haptic syncs with the clack (B5). |
| 10 | **The careful-play feel and the bag variation:** `quietTick` `tap(0.18, 0.8)` → `tap(0.3, 0.7)`. In `itemBagged`, the thump tone start 150 → `dice.float(138, 165)` and the noise cutoff 380 → `dice.float(330, 430)`. | A felt tick per 4° instead of fuzz at threshold, still under every reward cue. The bag thud stops being identical on every item. Update FeelTests 1827 (≤ 0.25 → ≤ 0.35). |

**Next (worth doing, not in the low-risk ten)**
- **Creak latency, 108–217 ms.** Feed the *feedback only* (sound and haptic creak, never the noise) from a second
  estimator with a 0.15 s window and `followTau` 0.02. Or use `max(speed, sampleSpeed)`, which saves about 40 ms. This
  needs device ears and must keep the tremor/stick-slip guards.
- **`setPreferredIOBufferDuration`** 0.005 → 0.01 (battery).
- **The cascade jitter:** pass dice into `cascadeTimes` (±10 ms) so equal-size banks don't repeat rhythmically. The
  haptic shares the array, so the sync is kept.
- **The limiter `ceiling`** 0.9 → 1.1 (tanh 0.80 = −1.9 dBFS): +1 dB of true peak headroom.
- **The squeal:** a pure 1.7–2.6 kHz sine can read as a beep. After #2 it is masked by the grains; if not, swap it for a
  Q 25 band-passed noise at the same frequency.

## 8. What to listen and feel for on the Duo after the changes

1. **Open at 16, 20, 30 and 45°/s.**
   - 16°/s should be just audible plus a felt grain.
   - 20°/s should be a woody groan, not a hum.
   - 45°/s should be a rough crackle with a squeal.
2. **Speaker at 50 % volume in a normal room:** is careful play audible? Are the heartbeat at Stirring and the wake
   sting clearly there?
3. **The biggest bank you can make** (relic, chain ≥ 3, new best): thunk, pour, **ka-ching**, chimes, chain, choir, all
   present.
4. **Slam to a bite:** the jaw must be louder than the creak on the speaker, and the second haptic snap must land on
   the clack.
5. **Strong haptics:** the coin tick should feel crisper than the bank thunk, and the quiet ticks should feel like
   ticks, not fuzz.
