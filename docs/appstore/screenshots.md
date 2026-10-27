# Hush: App Store screenshot plan (v1.0)

*Written Tue 27 Oct 2026 by the launch lead, adapted from Brim's portrait tabletop plan (`C:\Users\59527\Fold\docs\appstore\screenshots.md`) and Swoop's frame-1 composite. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-hushDemo "…"` (keys in `design/ROUND-1.md` and the header of `Hush/App/DemoMode.swift`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The store pipeline (`store.yml`, `ci/store-scenarios.txt`, `ci/store-set.sh`, `ci/store-frame.swift`) is still to be ported from Brim (`DECISIONS.md` §2 request #3); once it exists, **the scenario file is the source of truth**: change a caption there, not only here.*

## Sets, sizes and slots

Hush plays in **portrait** (tabletop: the 669 × 951 pt inner canvas with the fold across the middle), exactly like Brim, so every set is portrait.

| Upload order | App Store Connect slot | Pixels (portrait) | Frames | Artifact (planned) | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **1320 × 2868** | P1–P6 | `store-69` | Optional, but upload it (Apple scales it down for the 6.5" row) |
| 2 | **iPhone 6.3" / 6.1" class** (Dynamic Island, medium display) | **1206 × 2622** (or 1179 × 2556) | P1–P6 | `store-61` | **Required** (Apple's only required iPhone size). Never 1170 × 2532: that's "Face ID (medium)" and doesn't fill the slot |
| 3 | **iPhone Duo, inner display** (the hero set) | **2007 × 2853** (the tabletop canvas at 3×) | D1–D6 | `store-duo` | Upload **if** App Store Connect shows an iPhone Duo slot. Submitting Duo screenshots earns the "optimized for iPhone Duo" badge, and from **April 2027** every submission built with the iOS 27.1 SDK needs them |
| – | iPhone Duo, outer (cover) display | 1398 × 2034 | none | – | Not made: Hush isn't played on the cover (it shows only the sleeping-mimic card). One capture of that card only if the slot insists |

**Does App Store Connect have an iPhone Duo slot?** Apple's specification page lists one, but in October 2026 developers reported no Duo entry in the version page's device selector or the API (Apple Developer Forums 845505). So: **look for an "iPhone Duo" entry on upload day.** If it's there, upload `store-duo` (D1–D6). If it isn't, ship 1.0 with the 6.9" and 6.3" sets only (frame 1 still carries the Duo pitch: see below) and add the Duo set with 1.0.1, before April 2027.

Rules: PNG, **no alpha channel**, 1–10 per size (we use 6). In search results a portrait set shows its **first three frames**, so frames 1–3 must each sell the game alone.

## Frame 1: the Duo standing like a little laptop, lid raised, gold glowing

The pitch is physical: **the raised half is the lid.** A flat frame of the inner display shows the screen but not the pose, so frame 1 should be a **tabletop composite** (`ci/store-frame.swift --tabletop`, to port from Swoop's `--book` composite, `DECISIONS.md` §2 request #3): D1's real Duo capture split at the fold, the floor half mapped flat onto a stylised Duo lying on a table, the lid half mapped onto its raised half at about 130°, seen from in front and slightly above. Graphite bezel, a hinge barrel, a soft table shadow. **No hands.**
- **Truthful:** every screen pixel is the app's, only warped. Nothing is drawn on the screen. The device is the real tabletop pose Hush is played in, never a non-folding iPhone drawn folded, never flat or closed.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture), because without a Duo slot the 6.9" set is all anyone sees. The iPhone caption's sub-line says other iPhones play with the lid slider.
- **Fallback:** if the composite isn't ready by code freeze, D1 and P1 are the flat captures with the same caption. The caption ("Open the lid. *Slowly.*") still makes sense on a flat frame; a real photo of the Duo on a table can replace it in 1.0.1.

## Caption style (what `ci/store-frame.swift` should draw)

- **Layout:** caption band across the top (3–24 % of the height), the screenshot itself under it, unaltered, scaled to fit, rounded corners, a hairline gold edge and a soft shadow. The caption never covers the chest, the loot, the meter or the fold band.
- **Background:** the dungeon teal-black `#12161C` with a warm candle glow (gold `#F2B84B` at low strength, added with plus-lighter blending, never gold at partial alpha over the dark) rising from behind the screenshot.
- **Type:** SF Pro Rounded Heavy (plain system Heavy if missing), parchment `#F3E9D2`. **One** highlighted word, `*word*` in the scenario file, drawn in ink `#12161C` letters on a gold `#F2B84B` marker swash (gold letters are fine on the dark, but the swash reads better as the store's one accent). Sub-line after ` / ` in SF Pro Rounded Semibold at ~46 %, warm grey `#BFB39A`.
- **Six words maximum** per headline (the brief's rule; `store-set.sh` should lint it), no logo, no price, no "#1", no Apple logos or "Made for iPhone Duo" badge (Guideline 2.3.7; Apple adds its own badge).

## A. iPhone Duo, inner display (2007 × 2853): 6 frames

Captured on the tabletop canvas with the hinge held at a fixed angle per frame (`lid=` / `noise=` demo keys hold the state, so the frame is exactly what the player sees), **upright** (`turn=0`). On a real Duo the canvas is drawn turned round by default, but the player turns the phone round too, so the upright capture is the picture they see: don't re-shoot it upside down (Brim's lesson, its screenshots.md "Glasses on the sharp half").

| # | In-game moment | Caption: headline / sub-line | Demo args (`ci/store-scenarios.txt`, to write) |
|---|---|---|---|
| **D1** | An Iron-bound chest with the lid well open: the light washing in from the fold, coins and a gem glinting, the mimic's eye shut with "Zzz" on the lid, the meter low and green | **Open the lid. *Slowly.*** / Your Duo is the treasure chest. | `screen=run;mode=run;seed=7;pilot=expert;freezeOn=reveal` (frame 1 composite source) |
| **D2** | A gem mid-drag towards the bag, the bag showing two coins and its value | **Drag the gold in *gently*.** / Fast hands rattle. Rattles wake mimics. | `screen=run;mode=run;seed=7;pilot=expert;freezeAfter=9` (pick a moment with a held item; add a `freezeOn=drag` tag if needed) |
| **D3** | Waking: the meter red near the top, "FREEZE" pulsing, the tongue curled, the eye half open with teeth showing on the lid | **It's waking. *Freeze!*** / Hold still and it falls back asleep. | `screen=run;mode=run;seed=7;lid=0.7;noise=0.82;freezeOn=waking` |
| **D4** | Banking: the lid eased low, the shut-hold ring filling on the bag, loot glinting | **Ease it shut to *keep* it.** / Bank the haul before the torch burns out. | `screen=run;mode=run;seed=7;pilot=expert;freezeOn=bank` |
| **D5** | The bite: teeth slammed across the fold, coins flying into the mouth | **Too fast? *CHOMP.*** / A bite costs your bag and 15 seconds. | `screen=run;mode=run;seed=7;pilot=novice;freezeOn=bite` |
| **D6** | The Codex, mid progress: found relics drawn, the rest silhouettes "???" | **Twenty-four relics. One *Codex*.** / Daily Dungeon, thief ranks, Game Center. | `screen=codex;progress=mid;fold=1` |

Reserves: `DR1-relic` (a relic found: the golden ray and its name on the floor), **Open wide for the *relics*.** / The best loot sits deepest.; `DR2-results` (Results, mid progress), **One more *chest*?** / No ads. No in-app purchases.; `DR3-lesson` (First Chest, the pose step), **Lift the lid. That's *it*.** / A short lesson shows you how.

**File names** (the App Store Connect tool expects exactly these, `tools/appstore/build-metadata.js`): `D1-hero-open`, `D2-drag-gently`, `D3-freeze`, `D4-bank`, `D5-chomp`, `D6-codex` in `store-duo/duo-screens/store/`, and `P1-hero-open` … `P6-codex` in `store-69/store/` and `store-61/store/`. Rename a frame here and there together.

Every Duo frame must log the folded inner canvas (`HUSH-T canvas 669x951 fold=1 turned=0`), so a cover-display or landscape capture is flagged, never uploaded.

## B. iPhone 6.9" (1320 × 2868) and 6.3" class (1206 × 2622 / 1179 × 2556): 6 frames each

The same moments as A, captured on the iPhone 18 Pro Max and the iPhone 18 Pro (or the newest simulator with a 1179 × 2556 screen), **with the lid slider showing** on the lid half (no hinge, so `usesSlider` is true and the brass lever is drawn: that's what an iPhone player sees). No Duo-only line appears inside an iPhone capture (the app never shows one there).

| # | Caption: headline / sub-line (where it differs from A) | Demo args |
|---|---|---|
| **P1** | **Open the lid. *Slowly.*** / Best on iPhone Duo. Plays on every iPhone. | the frame-1 composite of D1 (fallback: `screen=run;mode=run;seed=7;pilot=expert;freezeOn=reveal`) |
| **P2** | **Slide the lid up *slowly*.** / Then drag the gold into your bag. | as D2 |
| **P3–P6** | as D3–D6 | as D3–D6 (P6 without `fold=1`) |

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture from the app (frame 1: only warped onto the device); captions sit outside it. No composited coins, glows, teeth or eyes.
- [ ] **Frame 1's device is a real iPhone Duo pose** (tabletop, lid raised about 120–150°), never a non-folding iPhone drawn folded, never closed or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build:** a bite costs the bag and 15 s of torch (`Tuning`); "FREEZE" appears at Waking; banking is easing the lid shut; 24 relics in the Codex; the iPhone control is the lid slider. If any of these change, change the caption.
- [ ] **Seeded states are reachable states:** `noise=` and `lid=` hold real levels a player passes through; "mid progress" is rank 4 with 9 relics (ROUND-1 demo keys). Never seed all 24 relics or an impossible haul.
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
- Brim's portrait pipeline and Swoop's book composite (to port): `C:\Users\59527\Fold\ci\store-*`, `C:\Users\59527\Fold\.github\workflows\store.yml`, `C:\Users\59527\Wing\ci\store-frame.swift`
