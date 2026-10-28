# Hush: Accessibility Nutrition Labels (v1.0)

*Decided Tue 27 Oct 2026, updated in Round 3 from the code (`Hush/UI/Pages.swift`, `Hush/Scene/SceneMoments.swift`, `Hush/UI/RootView.swift`), with the method Squish, Brim and Swoop use: **claim a label only when the build earns it across every common task**, and verify on the release build first. Labels are voluntary, per device, and can only be published once a version is live, so this happens on **launch day, Tue 1 Dec** (runbook §6).*

Common tasks for Hush:
1. the first launch: get through **First Chest** (or skip it after step 2 or 20 s), including the dismissible "Stand it up" tip on a Duo held like a book;
2. start a Run or the Daily Dungeon from Home;
3. play a chest: open the lid (hinge on a Duo, the lever elsewhere), see which loot is lit, drag it to the bag, read the noise meter and the candle, react to Stirring/Waking/"Freeze!", ease the lid down to bank (the app's words: "Ease the lid down to bank"); on a Duo, pause with a 0.35 s press-and-hold on the pause coin (VoiceOver: activating it pauses at once);
4. read Results (gold banked, new best, chests, Hushed count, bites, relics, rank progress);
5. open the Codex and read a relic's name and blurb;
6. change Settings (Sound, Vibration (Off / Normal / Strong), Lid sensitivity (Forgiving / Normal / Careful), Play sound on silent, Turn the chest round (Duo only), Reduce motion, Replay First Chest).

## What the build gives us (27 Oct, Round 3)

- **Every tell is on the sharp floor half and in sound and haptics** (`GAME-DESIGN.md` §3, §5): the noise meter (segments plus stage ticks, shaking near the top), the tongue's movement, the "Freeze!" hint, a snore that stops, a heartbeat that speeds up (sound at Stirring, sound and haptic at Waking), a growl. No cue is colour-only or sound-only by design.
- **Reduce motion**, in Settings and following the iOS setting (`RootView` `systemReduceMotion`): no shake and no red flash on a bite (`SceneMoments`).
- **A Sound switch, a Vibration choice (Off / Normal / Strong) and a Lid sensitivity choice (Forgiving / Normal / Careful; the scored Daily always plays Normal)**, and "Play sound on silent" (on by default).
- **Two ways to move the lid:** the hinge (Duo) and the on-screen lever (other iPhones; a Duo never shows it, `ROUND-3.md` decision 4). Neither ever needs a fast or precise flick; both reward slow, steady movement.
- **VoiceOver groundwork (Round 3, App):** elements for BANKED, the candle and NOISE, and spoken stage, bite and bank announcements. Still not enough for the VoiceOver label (task 3 needs sight of the lit loot).
- **Dark by design:** the app forces the dark style (`UIUserInterfaceStyle: Dark` in `project.yml`), and every screen is candlelit gold on teal-black.
- **Large targets:** HUD and menu targets ≥ 56 pt (ROUND-1 Theme).

## The answer, at a glance

| Label | 1.0 answer | Status | Why |
|---|---|---|---|
| VoiceOver | **No** | Decided | Menus can be labelled, but play (task 3) means seeing which loot is lit and dragging it to the bag. Apple's bar is all common tasks |
| Voice Control | **No** | Decided | Dragging loot and easing the lid have no spoken alternative |
| Larger Text | **No** | Decided | Menus may scale, but the HUD, the meter labels, the mimic's name tag and Results aren't designed to reach 200 % |
| Dark Interface | **Yes**, if check D passes | **Verify** | Forced dark style; every screen is teal-black. This is the one Hush earns more easily than Brim or Swoop |
| Differentiate Without Color Alone | **Yes**, if check A passes | **Verify** | The meter reads by fill level and stage ticks, the stages also by words, motion and sound; relics locked vs found by silhouette vs art |
| Sufficient Contrast | **Yes**, if check B passes | **Verify** | Gold on teal-black is about 10:1; the risk is dim text inside the dark chest and over the light wash |
| Reduced Motion | **Yes**, if check C passes | **Verify** | A Reduce motion setting exists by design; it must also follow the iOS setting and remove shake and flash |
| Captions | **No** (not applicable) | Decided | No dialogue, video or spoken content. (Every sound cue has an on-screen equivalent: check A) |
| Audio Descriptions | **No** (not applicable) | Decided | No time-based video content |

**Publish for iPhone: Dark Interface, Sufficient Contrast, Differentiate Without Color Alone, Reduced Motion**, each only if its check below passes on the release build. Leave every other box unticked. If a check fails, leave that box unticked: an honest "not indicated" beats a false claim.

## Checks (on the release build, on a Duo and on a non-Duo iPhone)

### A. Differentiate Without Color Alone (and sound-off play)
- [ ] The **noise meter** reads by **fill level** and the **tick marks** at the stage lines, not only by its green/amber/red colour. Waking also shows the hint **"Freeze!"**; the tongue visibly twitches (Stirring) and curls (Waking).
- [ ] **Lit vs unlit loot** differs by brightness and the glint, and a grabbable item shows a shape cue (outline or glint), not only a hue. Gem colours (ruby, emerald, sapphire, amethyst) only change value, and the value is shown when bagged.
- [ ] The **bag** shows its in-hand value as a number; the **shut-hold ring** fills (shape), not only changes colour.
- [ ] The **candle** reads by its height, and the last 15 seconds add a guttering flame, a countdown and a tick sound, not only a colour change.
- [ ] **Codex:** found relics are drawn, unfound ones are silhouettes with "???", not greyed colour alone.
- [ ] **Settings** toggles show their position, not only a tint.
- [ ] With **sound off**, a full run is still fair: every stage change is visible on the floor half (`GAME-DESIGN.md` §3 "Nothing time-critical lives only on the lid").
- [ ] Run tasks 1–6 with **Settings > Accessibility > Display & Text Size > Color Filters > Grayscale** on.

### B. Sufficient Contrast
Apple's bar: about 4.5:1 for text, 3:1 for large text, controls and state indicators.
- [ ] HUD text (the hint line, the gold counter, the bag value, the mimic's name tag, "Freeze!") keeps ≥ 4.5:1 (3:1 for the large ones) against the **dark chest interior** and against the **light wash** when the lid is wide open. Gold `#F2B84B` on teal-black `#12161C` is about 10:1; dim golds and the velvet tongue behind text are the risk.
- [ ] Menu, Codex and Results text ≥ 4.5:1 on its panel, including the quiet secondary lines and relic blurbs.
- [ ] The noise meter, the pause coin, the lever's knob and the bag reach 3:1 against what's behind them.
- [ ] Check with Increase Contrast and Bold Text on.

Measure with a contrast checker on the release-build frames (the CI frame sets) and paste the ratios here (Brim's table format).

### C. Reduced Motion
- [ ] Hush follows **Settings > Accessibility > Motion > Reduce Motion** as well as its own "Reduce motion" setting (either one turns it on).
- [ ] With it on: no camera shake (bite, bank, the shaking meter becomes a steady pulse of its fill), **no full-screen red flash on a bite** (a red edge or the word CHOMP instead), no dust burst sweep, no golden-ray burst on a relic (a fade instead).
- [ ] Menu transitions become fades or short moves, not springs and slides.
- [ ] The lid, the light, the tongue's breathing and the teeth still move: that motion *is* the game's information, which Apple's criteria allow.

### D. Dark Interface
- [ ] Home, Run, Results, Codex, Settings, Daily, the pose tip, the pause and closing cards and the cover-display card are all dark panels (teal-black). No white sheets: the system share sheet or Game Center sheets are Apple's and don't count against it.

## Photosensitivity (not a label, but a must)

The bite's red flash must never strobe: one flash per bite, under about 3 flashes per second in any case, and not full-screen bright red. With Reduce Motion on, no flash at all (check C).

## What we can say in copy today

The description says "Every warning is shown on screen too, so you can play with the sound off" and "Settings has Sound, Vibration, Lid sensitivity and Reduce motion". None of this claims a VoiceOver or Larger Text label. If check A's sound-off line fails, cut the first sentence; if check C fails, cut "and Reduce motion" only if the setting itself is missing.

## 1.0.1 list to earn more labels honestly

| Fix | Size | Earns |
|---|---|---|
| Spoken cues: "Coin, lit", "Gem, lit, deep", the stage changes (Round 3 announces them), plus a VoiceOver drag action "Put in bag" for the focused item | M | VoiceOver (maybe) |
| Named custom actions "Open a little", "Close a little", "Bag it" on the play area, driving the lid at a fixed slow speed | S | Voice Control (with the above) |
| HUD, Results, Codex and menus scale to AX3 with reflow | M | Larger Text |

Re-check the labels with every update; add one only after the fix is on device and tested.

## Sources
- App Store Connect Help, *Overview of Accessibility Nutrition Labels*: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- App Store Connect Help, *Manage Accessibility Nutrition Labels* (publish only for devices with a live version): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
- Swoop's and Brim's label decisions (method mirrored): `C:\Users\59527\Wing\docs\appstore\accessibility.md`, `C:\Users\59527\Fold\docs\appstore\accessibility.md`
