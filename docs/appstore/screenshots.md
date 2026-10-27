# Hush: App Store screenshot plan (v1.0)

*Rewritten Tue 27 Oct 2026 (Round 3) by the launch lead. Owner: CI captures and captions (`ROUND-3.md` CI engineer: the store pipeline adapted from Swoop's `store.yml`, `ci/store-capture.sh`, `ci/store-frame.swift`, `ci/store-set.sh`), the launch lead writes captions, the founder approves. **Every frame comes from a real demo state**: the app's own rendering, launched with `-hushDemo "…"` (keys in the header of `Hush/App/DemoMode.swift`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. Each frame below names the existing `ci/scenarios.txt` frame it matches, so the moment is one CI already reaches. Once the store scenario file exists, **it is the source of truth**: change a caption there and here together.*

## Sets, sizes and slots

Hush plays in **portrait** (tabletop: the 669 × 951 pt inner canvas with the fold across the middle), exactly like Brim, so every set is portrait.

| Upload order | App Store Connect slot | Pixels (portrait) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **1320 × 2868** | P1–P6 | `store-69` | Optional, but upload it (Apple scales it down for the 6.5" row) |
| 2 | **iPhone 6.3" / 6.1" class** (Dynamic Island, medium display) | **1206 × 2622** (or 1179 × 2556) | P1–P6 | `store-61` | **Required** (Apple's only required iPhone size). Never 1170 × 2532: that's "Face ID (medium)" and doesn't fill the slot |
| 3 | **iPhone Duo, inner display** (the hero set) | **2007 × 2853** (the tabletop canvas at 3×) | D1–D6 | `store-duo` | Upload **if** App Store Connect shows an iPhone Duo slot. Submitting Duo screenshots earns the "optimized for iPhone Duo" badge, and from **April 2027** every submission built with the iOS 27.1 SDK needs them |
| – | iPhone Duo, outer (cover) display | 1398 × 2034 | none | – | Not made: Hush isn't played on the cover (it shows only the sleeping-mimic card, and the run is paused there). One capture of that card only if the slot insists |

**Does App Store Connect have an iPhone Duo slot?** Apple's specification page lists one, but in October 2026 developers reported no Duo entry in the version page's device selector or the API (Apple Developer Forums 845505). So: **look for an "iPhone Duo" entry on upload day.** If it's there, upload `store-duo` (D1–D6). If it isn't, ship 1.0 with the 6.9" and 6.3" sets only (frame 1 still carries the Duo pitch: see below) and add the Duo set with 1.0.1, before April 2027.

Rules: PNG, **no alpha channel**, 1–10 per size (we use 6). In search results a portrait set shows its **first three frames**, so frames 1–3 must each sell the game alone: open slowly, freeze, bank.

## Frame 1: the Duo standing like a little laptop, lid raised, gold glowing

The pitch is physical: **the raised half is the lid.** A flat frame of the inner display shows the screen but not the pose, so frame 1 should be a **tabletop composite** (`ci/store-frame.swift --tabletop`, adapted from Swoop's `--book` composite): D1's real Duo capture split at the fold, the floor half mapped flat onto a stylised Duo lying on a table, the lid half mapped onto its raised half at about 130°, seen from in front and slightly above. Graphite bezel, a hinge barrel, a soft table shadow. **No hands.**
- **Truthful:** every screen pixel is the app's, only warped. Nothing is drawn on the screen. The device is the real tabletop pose Hush is played in, never a non-folding iPhone drawn folded, never flat or closed.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture), because without a Duo slot the 6.9" set is all anyone sees. The iPhone caption's sub-line says any iPhone plays.
- **Fallback:** if the composite isn't ready by code freeze, D1 and P1 are the flat captures with the same caption. The caption still makes sense on a flat frame; a real photo of the Duo on a table can replace it in 1.0.1.

## Caption style (what `ci/store-frame.swift` should draw)

- **Layout:** caption band across the top (3–24 % of the height), the screenshot itself under it, unaltered, scaled to fit, rounded corners, a hairline gold edge and a soft shadow. The caption never covers the chest, the loot, the meter or the fold band.
- **Background:** the dungeon teal-black `#12161C` with a warm candle glow (gold `#F2B84B` at low strength, added with plus-lighter blending, never gold at partial alpha over the dark) rising from behind the screenshot.
- **Type:** SF Pro Rounded Heavy (plain system Heavy if missing), parchment `#F3E9D2`. **One** highlighted word, `*word*` in the scenario file, drawn in ink `#12161C` letters on a gold `#F2B84B` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold at ~46 %, warm grey `#BFB39A`.
- **Six words maximum for the headline, and six for the sub-line** (`store-set.sh` lints both; `×1.5` counts as one word). No logo, no price, no "#1", no Apple logos or "Made for iPhone Duo" badge (Guideline 2.3.7; Apple adds its own badge).
- **The app's words, exactly:** "Freeze!" (exactly so: capital F, lower case, the exclamation mark), the candle, bank, the lever (phones).

## A. iPhone Duo, inner display (2007 × 2853): 6 frames

Captured on the Duo simulator's tabletop canvas, **upright** (`turn=0`). On a real Duo the canvas is drawn turned round by default, but the player turns the phone round too, so the upright capture is the picture they see: don't re-shoot it upside down (Brim's lesson). A fold layout never draws the lever, so no Duo frame shows one.

| # | File | In-game moment (the `ci/scenarios.txt` frame it matches) | Caption: headline / sub-line (words) | Demo args |
|---|---|---|---|---|
| **D1** | `D1-hero-open` | An Iron-bound or Wooden chest with the lid well open: light from the fold, coins and a gem glinting, the mimic asleep, the meter low (`31`/`32-reveal-fold`) | **Open the lid. *Slowly.*** (4) / Your Duo is the treasure chest. (6) | `screen=run;mode=run;seed=7;pilot=expert;turn=0;freezeOn=reveal` (frame 1 composite source) |
| **D2** | `D2-freeze` | Waking: the meter red, "Freeze!" on the hint plate, the tongue curled, the eye opening (`33-waking-fold`) | **It's waking. *Freeze!*** (3) / Hold still and it settles. (5) | `screen=run;mode=run;seed=7;pilot=novice;turn=0;freezeOn=waking` (fallback: `screen=run;mode=attract;seed=7;turn=0;lid=0.7;noise=0.85`, frame 18) |
| **D3** | `D3-bank` | Banked: the lid eased low, loot flying into the BANKED plate (`14-bank`) | **Ease it shut to *bank*.** (5) / Bank before the candle burns out. (6) | `screen=run;mode=run;seed=7;pilot=casual;turn=0;freezeOn=bank` |
| **D4** | `D4-chain` | A Hushed bank with the Hush Chain medal by BANKED ("GOLD ×1.2" or more) (`37-chain-badge`) | **Sleepy banks pay *more*.** (4) / Hush Chain: up to ×1.5 gold. (6) | `screen=run;mode=run;seed=7;pilot=perfect;turn=0;freezeAfter=24;freezeOn=bank` |
| **D5** | `D5-chomp` | The bite: teeth slammed across the fold, coins flying into the mouth, "−10s" off the candle (`13-bite`) | **Too loud? *CHOMP.*** (3) / Lose your bag and 10 seconds. (6) | `screen=run;mode=run;seed=7;pilot=novice;turn=0;freezeOn=bite` |
| **D6** | `D6-codex` | The Relic Codex, mid progress: 9 relics drawn on velvet, the rest silhouettes (`22-codex-mid`) | **Twenty-four relics. One *Codex*.** (4) / Daily Dungeon, ranks, Game Center. (5) | `screen=codex;progress=mid` |

Reserves (same rules), in order of preference:
- `DR1-golden` (`36-golden-mimic`): **A golden mimic. *Extra* gold.** (5) / But it sleeps lighter. (4). Args: `screen=run;mode=run;seed=7;pilot=casual;golden=1;turn=0;freezeOn=reveal`. Use only if the frame shows the gilded chest and "GOLDEN" on the plate.
- `DR2-relic` (`15-relic`): **Open wide for *relics*.** (4) / The best loot sits deepest. (5). Args: `screen=run;mode=run;seed=7;pilot=expert;turn=0;skipTo=25;freezeOn=relic`. Use only if the relic card (art and name) is in the frame.
- `DR3-results` (`20-results-mid`): **One more *chest*?** (3) / No ads. No in-app purchases. (5). Args: `screen=results;seed=7;progress=mid;pilot=casual`.
- `DR4-lesson` (`39`/`34-lesson-fold`): **A short lesson shows *how*.** (5) / Open, grab, freeze, bank. (4). Args: `screen=lesson;lessonStep=2;lid=0.3` on the Duo sim.

**File names** (the App Store Connect tool expects exactly these, `tools/appstore/build-metadata.js`): `D1-hero-open`, `D2-freeze`, `D3-bank`, `D4-chain`, `D5-chomp`, `D6-codex` in `store-duo/duo-screens/store/`, and `P1-hero-open` … `P6-codex` (same suffixes) in `store-69/store/` and `store-61/store/`. Rename a frame here and in `build-metadata.js` together.

Every Duo frame must log the folded inner canvas (`HUSH-T canvas 669x951 fold=1 turned=0`), so a cover-display or landscape capture is flagged, never uploaded.

## B. iPhone 6.9" (1320 × 2868) and 6.3" class (1206 × 2622 / 1179 × 2556): 6 frames each

The same moments as A, captured on the iPhone 18 Pro Max and the iPhone 18 Pro (or the newest simulator with a 1179 × 2556 screen), **with the lever showing** on the lid half (no fold, so the lever is drawn: that's what an iPhone player sees). No Duo-only line appears inside an iPhone capture (the app never shows one there).

| # | File | Caption: headline / sub-line (where it differs from A) | Demo args |
|---|---|---|---|
| **P1** | `P1-hero-open` | **Open the lid. *Slowly.*** / Any iPhone. Best on iPhone Duo. (6) | the frame-1 composite of D1 (fallback: `screen=run;mode=run;seed=7;pilot=expert;freezeOn=reveal`, frame `10-run-reveal`) |
| **P3** | `P3-bank` | **Slide it down to *bank*.** (5) / Bank before the candle burns out. (6) (the phone's words follow the lever, `ROUND-3.md` decision 4) | as D3 without `turn=0` (frame `14`) |
| **P2, P4–P6** | `P2-freeze`, `P4-chain`, `P5-chomp`, `P6-codex` | as D2, D4–D6 | as D2, D4–D6 without `turn=0` (frames `12`, `37`, `13`, `22`) |

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture from the app (frame 1: only warped onto the device); captions sit outside it. No composited coins, glows, teeth, eyes or medals.
- [ ] **Frame 1's device is a real iPhone Duo pose** (tabletop, lid raised about 120–150°), never a non-folding iPhone drawn folded, never closed or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build:** a bite costs the bag and 10 s of candle (`Tuning`); the app shows "Freeze!" at Waking; banking is easing the lid shut (the lever down on phones); the Hush Chain tops out at ×1.5 (`Tuning.chainMax` 5 × `chainStep` 0.1); 24 relics in the Codex. If any of these change, change the caption.
- [ ] **D4 shows a chain medal** (×1.2 or more) and **D3's floor is not blacked out** (QA: the Round 2 bank moment darkened the whole floor on wooden and iron chests, frames 14 and 37; the Scene fixes it in Round 3). If either is wrong on the store run, use the next reserve.
- [ ] **Seeded states are reachable states:** pilots play real runs; `noise=` and `lid=` hold real levels a player passes through; "mid progress" is 9 relics and a 5,200 best (`DemoMode` presets). Never seed all 24 relics or an impossible haul.
- [ ] **The Duo frames are upright** (`turn=0`), as the player sees them after turning the Duo round.
- [ ] **Nothing important in the crease band** (the fold across the middle) except the light spilling in and the teeth in D5, which are the point.
- [ ] **No prices, dates, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7).
- [ ] **The bite frame is comic, not scary:** teeth and flying coins, no red full-screen flash in the frozen frame (choose the moment after the flash).
- [ ] **Exact size, PNG, no alpha** (the MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Upload order and checks (founder, runbook §5)

The App Store Connect tool uploads the sets from the store run named in `.github/workflows/asc.yml` (`DEFAULT_STORE_RUN`) once it exists. By hand: 1. 6.9" slot: `store-69` P1–P6. 2. 6.3"/6.1" slot: `store-61`, the same. 3. If an **iPhone Duo** entry appears: `store-duo` D1–D6, then check them in App Store Connect's preview.

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames). Upload only from the `store-*` artifact of the run Claude names, after reading its MANIFEST.

## Sources
- Apple, App Store Connect Help, *Screenshot specifications* (iPhone Duo inner 2007 × 2853 / 2853 × 2007, outer 1398 × 2034; 6.9" 1320 × 2868; Dynamic Island medium 1206 × 2622 / 1179 × 2556, the one required iPhone size; 1–10 per size; no alpha): https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple Developer Forums 845505, *How do I upload iPhone Duo screenshots in App Store Connect?* (no Duo entry, Oct 2026): https://developer.apple.com/forums/thread/845505
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Swoop's store pipeline and book composite: `C:\Users\59527\Wing\.github\workflows\store.yml`, `C:\Users\59527\Wing\ci\store-*`
