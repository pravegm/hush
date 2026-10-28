# Feel R12 hand-off: REVIEW-6's top 10, plus the robbed chest

*Feel engineer, Round 12. Files: `Hush/Feedback/FeelSynth.swift`, `FeelSoundBook.swift`, `FeelAudioEngine.swift`,
`FeelHaptics.swift`, `FeedbackDirector.swift`, `HushTests/FeelTests.swift`, `tools/audio-probe.js`. Nothing committed.
Not compiled here (CI is the compiler). Every audio number below comes from the Node port, which now carries both
value sets.*

```
node tools/audio-probe.js compare        # the R11 → R12 table below
node tools/audio-probe.js tests          # the FeelTests render bounds, on the R12 values (all PASS)
node tools/audio-probe.js <section> --r11   # any section on the old values (creak, shots, mix, voices, haptic, hot, chomp)
```

`Hush/Input` is untouched. Nothing in Feedback or Input switches over `HeistHint`, so `closeForNext` needs nothing here.

## For the App engineer (one new call)

```swift
FeedbackDirector.shared.setRobbed(_ on: Bool)   // NEW. Call with session.awaitingClose (every frame is fine).
private(set) var robbed: Bool                    // NEW. Read-only mirror.
```
- **While on:** the game frames' bed mutes the snore and the tiptoe motif and plays the **grumble** instead. This holds
  in play and out of it (the bite moment).
- **The grumble:** a low, slow breath on a 5.5 s cycle (a 62 Hz saw through 320 Hz plus breath noise at 240 Hz,
  fluttering at 11 Hz).
  - It plays at `FeelSoundBook.robbedGrumble` = 0.6: −36.6 LUFS, 3 dB under the dungeon bed (−33.6) and under the
    snore it replaces (−33.0).
- **Off** restores the normal bed on the next frame.
- **Render-safety:** it is a new bed value (`FeelBed.grumble`), glided per sample on the audio thread, with no
  commands and no allocation.
- **Where it never plays:** Home, menus, `silence()` and the watchdog's idle bed.
- **Frames:** it needs the usual `handle(_:telemetry:)` frames to be applied. It takes effect on the next one.

Nothing else changes for the App.

## What changed (REVIEW-6 §7, in its order)

| # | Change | As the review said? |
|---|---|---|
| 1 | `voiceCount` 48 → 96; ring slot `decay × 7` → `× 5` (`FeelSynth.ringLife`). New diagnostics: `voiceSteals`, `liveVoices` (atomics, set on the audio thread). | Yes |
| 2 | Groan Q 5 → 3 (`FeelSynth.groanQ`), `bodyGain` 0.05 → 0.18, `grainGain` 2.0 → 3.5, `grainBase` 12 → 30 | Yes, **plus a top trim** (below) |
| 3 | `masterGain` 1.25 → 1.8 | Yes |
| 4 | Coin clink gains ×1.8 (0.16/0.11/0.065/0.08). Each partial's gain × 0.85…1.15 and index × 0.8…1.2 per hit. | Yes |
| 5 | Ka-ching chord D5 F♯5 A5 (`FeelSoundBook.kaChingChord`); glint 0.04 → 0.07 | Yes |
| 6 | Strong **layers**: each tap is kept (×1.15, its own sharpness) plus a 40 ms burst (×0.7, sharpness ≤ 0.5). `strongBurst` 0.055 → 0.04; new `strongBurstGain`. | Yes |
| 7 | Haptic creak `pow((s − q)/30, 0.6)` (`creakOnsetPower`); intensity jitter 0.15 → 0.30 | Yes |
| 8 | Heartbeat 150→80 / 140→78 Hz, 8 harmonics, band-pass 500/480 thock. Wake sting D4/D♯4, 5 harmonics, 0.06. New `heartbeatSoft` at Stirring. | Yes |
| 9 | Leaner CHOMP plus crunch; `restingCreakShare` 0.8 → 0.35; bite second snap 0.12 → 0.06 s (`FeelSoundBook.chompSecondClack`) | **Further** (below), **plus a fast duck** |
| 10 | `quietTick` tap(0.18, 0.8) → tap(0.3, 0.7). Bag thud: tone 138…165 Hz, noise cutoff 330…430 Hz per item. | Yes |

Small extras:
- `FeelSoundBook.heartGap(fast:)` shares the beat's gap between the sound and both haptic heartbeats.
- The haptic fallback (no Core Haptics) counts notes within 5 ms as one impact, so Strong's tap-plus-burst pairs don't
  double-fire.

### Where I went past the review, and why (measured)
Each top-10 item was measured alone. Together, #2 (a woodier creak, 0–3 dB louder at the top) and #3 (+3.2 dB) put
the slam creak into the limiter:

| Creak, waking bed | R11 | #2 + #3 as written | R12 (with the trim) |
|---|---|---|---|
| Limiter active, 45°/s | 0 % | 46 % | 7 % |
| Limiter active, 60°/s | 0 % | 81 % | 17 % |
| Samples over 0.6, 45 / 60°/s | 0 / 0.04 % | 1.0 / 1.4 % | 0.27 / 0.64 % |
| Review #9's CHOMP vs a 45°/s creak, speaker, loudest 50 ms | +0.8 dB (R11 CHOMP) | −2.2 dB (it loses) | **+1.5 dB** |

The fixes:
- **Creak top trim.** `loudLevel` 0.8 → 0.68 and a new `topLevel` 1.0 → 0.7 (`creakLevel` tops out at `topLevel`).
  - Nothing changes up to 20°/s.
  - With it, the creak is a uniform +3 to +4 dB over R11 from 16 to 60°/s, with the new wood timbre throughout.
  - The level is nearly flat from 30 to 50°/s. The creak still grows by 4.4 dB RMS from 30 to 60 through the grains,
    the brightness and the squeal.
- **CHOMP beyond #9.**

  | Part | R11 | Review #9 | R12 |
  |---|---|---|---|
  | Thump | 0.36 | 0.2 | 0.14, end 70 Hz, 8 harmonics |
  | Low noise | 0.34 | 0.2 | 0.12 |
  | Crack | 0.26 (20 ms) | 0.34 | 0.4 (50 ms) |
  | 340 Hz wood | 0.26 (50 ms) | 0.36 | 0.4, 5 partials (80 ms) |
  | Crunch (750 → 450 Hz) | none | 0.32 (50 ms) | 0.4 (80 ms) |
  | Teeth | 0.2 / 0.17 | unchanged | 0.3 / 0.26, 18 ms |

  - Every gain stays ≤ 0.4 (the `everyRecipeIsSane` bound).
  - The CHOMP's loudest 50 ms on the speaker goes from −15.8 to −10.9 LUFS.
- **A fast duck.** On the bite frame the bed glides at `FeelSoundBook.duckGlide` 0.03 s for `duckHold` 0.12 s, not
  the 0.35 s fade.
  - Without it, the 0.35 share only arrived after the CHOMP's body.
  - A 45°/s creak 0.5–1 s after the bite now sits at −22.9, against −19.3 in R11.
- **Still open:** on a 60°/s slam the CHOMP still loses on the speaker by 1.8 dB. R11 lost there too, by 0.7.
  - The creak's grains reach the limiter first. Closing it would need the "Next" items: limiter `ceiling` 0.9 → 1.1,
    or a sidechain duck before the limiter.
  - The haptic slam (1.0) is unaffected.

## Node port: R11 → R12 (each at its own master)

| Measure | R11 | R12 |
|---|---|---|
| Creak 16 / 20°/s RMS dBFS | −39.2 / −28.4 | −36.3 / −24.5 |
| Creak 30 / 40 / 60°/s RMS dBFS | −21.3 / −19.5 / −17.0 | −18.2 / −16.2 / −13.8 |
| Creak 20 / 30 / 40°/s periodicity r (1 = buzz) | 0.69 / 0.61 / 0.39 | 0.55 / 0.29 / 0.22 |
| Creak 20 / 30°/s centroid | 494 / 847 Hz | 789 / 1,181 Hz |
| Coin clink, momentary LUFS | −27.9 | −20.1 |
| Bag thud + copper, momentary / speaker LUFS | −27.6 / −29.1 | −20.7 / −21.3 |
| Ka-ching alone, speaker LUFS | −24.0 | −16.4 |
| Heartbeat slow / fast, speaker LUFS | −43.5 / −41.2 | −33.0 / −30.7 |
| Wake sting, speaker LUFS | −33.5 | −25.5 |
| CHOMP, momentary / loudest 50 ms on the speaker | −16.8 / −15.8 | −14.0 / −10.9 |
| CHOMP on a 30 / 45 / 60°/s slam vs the creak before (speaker, 50 ms) | +4.9 / +0.8 / −0.7 | +5.2 / +1.5 / −1.8 |
| Scene: asleep, lid still (careful play) | −31.9 LUFS | −28.7 LUFS |
| Scene: asleep, 20°/s | −27.0 | −23.4 |
| Scene: Stirring, still, with heartbeat (speaker) | −39.2 | −33.9 |
| Scene: Waking, still, with heartbeat (speaker) | −37.1 | −30.4 |
| Scene: Waking, 40°/s | −17.8 | −14.4 |
| 1,700 g bank + chain 5 + relic + best: moment max / voices stolen | −19.0 LUFS / 26 | −11.4 LUFS / **0** |
| Voice budget, 1,700 g: ka-ching / chain / choir / best kept | 0/5, 0/4, 0/6, 1/4 | 5/5, 4/4, 6/6, 4/4 (most live 80 of 96) |
| Mixed-events test: samples over 0.6 (bound 2 %) / peak | 0.07 % / 0.716 | 0.37 % / 0.716 |
| Same test at master 2.0 (not shipped) | — | 0.60 % |

**The peak never exceeds tanh(0.9) = 0.716 (−2.9 dBFS)**, so it stays under 1.0. The ±0.98 clamp never acts. (R1's
"creak peak 0.83" was stale, B6.)

**Haptics (Strong)**

| Measure | R11 | R12 |
|---|---|---|
| Creak texture at 16 / 20 / 25°/s | 0.09 / 0.28 / 0.51 | 0.28 / 0.53 / 0.77 |
| Creak texture jitter | ±15 % | ±30 % |
| Quiet tick | 55 ms burst at 0.21 | tap 0.35 (sharpness 0.7) + 40 ms at 0.21 |
| Bank cascade bursts overlapping the next (n = 14) | 4 / 13 | 3 / 13 (each now starts on its own crisp tap) |
| Bite second snap vs the last tooth-clack | 60 ms late | 0 ms |
| Stirring heartbeat | none | 0.40 + 0.28 at 0.18 s |

## Tests (`HushTests/FeelTests.swift`)

**Updated**
- `theCreakTextureFollowsTheSpeed` (line ~858): +15°/s is now `pow(0.5, 0.6)` = 0.66.
- `hapticMomentsHaveTheirShapes` (line ~915): Strong keeps each tap (same time and sharpness) plus a 40 ms burst. It
  also lists `heartbeatSoft`.
- `carefulPlayTicksEveryFourDegrees` (lines ~1827–1828): the tick is 0.25…0.35, and Strong has both a tap and a burst.
- `everyRecipeIsSane` and `theCreakAccentIsSharpAndPlaysThroughTheDirector`: the gain-parameter comparisons ("CHOMP gain >
  3× coin gain", "crack gain > 2× coin gain") could not hold with the louder coin. They are now **rendered**, via a new
  `feelShot` helper (0.4 s RMS and peak).
  - The CHOMP is more than 2× the loudest coin (port: 2.46×).
  - The crack's RMS is less than half the CHOMP's.
  - The crack's peak is above the loudest coin's (port: 0.66 vs 0.53).

**New**
- `theBiggestBankKeepsItsKaChingChainAndChoir`: the voice-pool overflow case.
  - Setup: a running bed, a gem and a copper just bagged, then a 1,700 g and a 9,999 g Hushed bank with a 5-chain, a
    relic choir and a new best (72 and 80 commands, more than 48).
  - Checks: 0 `voiceSteals`, `liveVoices` ≥ the moment's size, then 3 s render clean.
- `aStruckRingFreesItsSlotAfterFiveTimeConstants`
- `theWoodierCreakKeepsASlamOutOfTheLimiter`: hot < 0.6 % at 45°/s and < 1 % at 60°/s. The untrimmed curve fails both.
- `rewardsAreBrighterAndNeverIdentical`
- `theTensionCuesReachThePhoneSpeakerAndTheHand`
- `theChompOwnsTheBite`
- `strongHapticsKeepTheVocabularyAndTheCreakIsFeltEarly`
- `aRobbedChestGrumblesInsteadOfSnoring` (the founder's extra, including the director on/off)

Every mutating call (`dice`, `update`, `handle`) is bound with `let` or run as a statement before any `#expect`.

## Compile risks I couldn't rule out
- `FeelBed` gained a stored `grumble` (defaulted). Nothing in the repo uses its memberwise init.
- `FeelSoundBook.heistBed` gained `robbed: Bool = false`, so existing callers still compile.
- `FeelHapticBook.heartbeat` / `heartbeatSoft` / `bite` are static lets that read `FeelSoundBook` statics. Both are
  non-isolated enums, so this is fine.
- `Issue.record("…")` in two tests (Swift Testing).

## On the Duo, listen and feel for
1. **The creak at 16, 20, 30 and 45°/s.**
   - 16°/s: just audible, and a faint grain in the hand.
   - 20°/s: a woody groan with crackle, not a hum or a kazoo.
   - 30°/s and up: rough fibre crackle, with the squeal past 25.
   - Does it feel like *the phone's own hinge*? If it is too hissy, lower `FeelSynth.grainGain` (3.5). If it is too
     tonal, raise `bodyGain` (0.18).
2. **Speaker at 50 % in a normal room.**
   - Careful play (snore, tiptoe, drips) should be clearly audible: no "is the sound on?".
   - At Stirring you should **hear** the slow heartbeat over the bed and **feel** a soft lub-dub each second.
   - At Waking the beat is firmer and faster, and the wake sting's sour two notes are clearly there.
3. **The biggest bank you can make** (relic, chain ≥ 3, new best): thunk, the coin pour, a bright **ka-ching**
   ("ching", not "bong"), the Hushed chimes, the chain sparkle, the choir, the best. All of them, every time.
4. **Coins.**
   - Each clink cuts through a soft creak, and no two sound alike.
   - Thirty baggings in a row shouldn't feel like the same sample.
5. **Slam to a bite at a natural slam.**
   - The jaw must be louder than the creak on the speaker, and the creak must drop away right under the CHOMP.
   - The second haptic snap lands **on** the tooth-clack.
   - Try a full-force fling too: is the CHOMP still the event there? This is the one known gap, 60°/s+.
6. **Strong haptics.**
   - The coin tick should feel crisper than the bank thunk, and the creak crack keener than both.
   - A big bank's cascade should be distinct taps, not a buzz.
   - The quiet ticks should feel like ticks, not fuzz.
   - Starting to creak (14–18°/s) should feel *more*, not less, than the quiet ticks just before it.
7. **The robbed chest** (once the App wires `setRobbed`): after a bite, until the lid closes, the snore and tiptoe
   are gone and a low, slow grumble breathes under the dungeon. It should be audible on headphones and subtle on the
   speaker. Closing the lid brings the normal bed back.
