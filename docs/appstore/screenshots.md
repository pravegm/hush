# Hush: App Store screenshots, header and search art (v1.0, R15 set)

*Rewritten Wed 28 Oct 2026 (Round 15) by the launch lead. The R11 set (store run 40675006542, 6 + 6 + 6 frames) predates
Rounds 13–15 (the phone IS the chest, the outer screen's intro with Play, no forced lesson) and is retired. Owner: the
store pipeline (`.github/workflows/store.yml`, `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`,
`ci/store-upright.sh`, `ci/store-placements.sh`); the launch lead writes captions; the founder approves. **Every frame
comes from a real demo state**: the app's own rendering, launched with `-hushDemo "…"` (keys in the header of
`Hush/App/DemoMode.swift`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The
scenario files are the source of truth for args and captions: `ci/duo-store-scenarios.txt` (Duo) and
`ci/store-scenarios.txt` (iPhone). Change a caption there and here together. Apple's rules and sources:
`docs/appstore/REQUIREMENTS-CHECK.md`.*

## Re-shoot (one command)

```
gh workflow run store.yml --ref main
```

About 25–35 minutes: three jobs (phones, duo, assemble). Then, from `C:\Users\59527\Lid`:

```
gh run list --workflow store.yml -L 1                      # the run ID
gh run watch <id> --interval 30 > /dev/null 2>&1
gh run download <id> -n store-69 -n store-61 -n store-duo -n store-placements -D <empty folder>
```

Read each `store/MANIFEST.txt` (every row `OK`, `summary: ok 10 flagged 0 missing 0`) and
`store-placements/MANIFEST.txt` (`summary: ok 2  problems 0`), look at every PNG (the checklist below), then put the
run ID in `.github/workflows/asc.yml` as both `DEFAULT_STORE_RUN` and `DEFAULT_PLACEMENTS_RUN`. Only the Duo or only
the phones: untick the other job on the Actions page; `duo_from_run=<id>` reuses an earlier run's Duo captures (frame
1 of every set and the header come from D01).

**Current signed-off run: see `DEFAULT_STORE_RUN` in `.github/workflows/asc.yml`** (the run list and image sizes are in
`docs/appstore/REQUIREMENTS-CHECK.md`).

## Sets, sizes and slots

Hush plays in **portrait** (tabletop: the 669 × 951 pt inner canvas with the fold across the middle), so every set is
portrait.

| Upload order | App Store Connect slot | Pixels (portrait) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** ("Dynamic Island, large display") | **1320 × 2868** | P01–P10 | `store-69` | Upload. Without it Apple would need the "Face ID (large)" class instead |
| 2 | **iPhone 6.3"** ("Dynamic Island, medium display") | **1206 × 2622** (or 1179 × 2556) | P01–P10 | `store-61` | **Required** (Apple's only always-required iPhone class) |
| 3 | **iPhone Duo** (inner display) | **2007 × 2853** | D01–D10 | `store-duo` | Optional until April 2027; submitting it earns the "optimized for iPhone Duo" badge. Upload it |
| – | iPhone Duo (outer display) | 1398 × 2034 | none as its own set | – | Not needed: the outer screen's only content is the intro, which is D02 (captured on the outer display, framed in the inner slot) |
| – | Product page header (optional creative asset) | **3840 × 1646** (21:9) | 1 | `store-placements` | Upload in *Header and Search Results* (iOS 27 App Store) |
| – | Search results art (optional creative asset) | **3840 × 2560** (3:2) | 1 | `store-placements` | Same tab. Without it, search shows frames 1–3 |

Rules: PNG, **no alpha channel**, 1–10 per size (we use 10). Search results (without the art) show a portrait set's
**first three frames**, so frames 1–3 sell the game alone: the Duo is the chest, how to start, drag the loot.

## Caption style (what `ci/store-frame.swift` draws)

- **Layout:** caption band across the top (3–21.5 % of the height), the screenshot under it, unaltered, scaled to fit,
  rounded corners, a hairline gold edge and a soft shadow. The caption never covers the app.
- **Look:** the dungeon teal-black `#12161C` with a warm candle glow (gold `#F2B84B`, plus-lighter). SF Pro Rounded
  Heavy in parchment `#F3E9D2`; **one** `*word*` in ink on a gold marker swash; the sub-line after ` / ` in Semibold
  warm grey `#BFB39A`.
- **Six words maximum for the headline, and six for the sub-line** (`store-set.sh` lints both). No logo, price, "#1",
  Apple logos or "Made for iPhone Duo" badge (Guideline 2.3.7).
- **The app's words, exactly:** the phone (Duo), the lever (iPhone), "Freeze!", CHOMP, the candle, bank. Never "lid",
  "laptop", "ease it down", "lift", "torch".

## A. iPhone Duo (2007 × 2853): ten frames

Captured on the Duo simulator held open at 150° (inner display), upright (`turn=0`); runs hold the book-pose landscape
interface and are turned upright from the logged k (`ci/store-upright.sh`, R11: only the capture turns, the pixels are
the app's). D02 is captured by a second pass with the hinge **shut** (0°), so the app is on the **outer display**
(1398 × 2034) showing the R15 intro exactly as a player with the phone shut sees it. A fold layout never draws the lever.

| # | File | In-game moment | Caption: headline / sub-line | Frame |
|---|---|---|---|---|
| 1 | `D01-hero-open` | The chest open, candlelight on coins and a gem, the mimic asleep, meter low | **Open the phone. *Slowly.*** / Your Duo is the treasure chest. | tabletop composite |
| 2 | `D02-play` | Phone shut: the outer screen's intro (wordmark, mimic, "Steal the mimic's gold while it sleeps", the three rules, **Play**, "Press Play, then open the phone slowly.") | **Phone shut? Press *Play*.** / Then open the phone slowly. | cover |
| 3 | `D03-loot` | Looting chest #1: a coin dropping into the bag, "6 not safe yet", the hint "Close the phone to bank" (iPhone: "Slower…") | **Drag the loot to your *bag*.** / Slowly: quick hands make noise. | flat |
| 4 | `D04-freeze` | Waking: "Freeze!", the meter red, the eye opening | **It's waking. *Freeze!*** / Stay still and it settles. | flat |
| 5 | `D05-bank` | "Hushed! BANKED +197 / Hush Chain ×1.1" | **Close the phone to *bank*.** / Bank before the candle burns out. | flat |
| 6 | `D06-chomp` | The bite after the flash: teeth across the fold, "CHOMP!", "−10s" | **Too loud? *CHOMP.*** / Lose your bag and 10 seconds. | flat |
| 7 | `D07-chain` | A Hushed bank with the chain medal ×1.2 or more | **Sleepy banks pay *more*.** / Hush Chain: up to ×1.5 gold. | flat |
| 8 | `D08-relic` | The relic card (art and name) | **Open wide for *relics*.** / The best loot sits deepest. | flat |
| 9 | `D09-codex` | The Relic Codex, 9 of 24 | **Twenty-four relics. One *Codex*.** / Daily Dungeon, ranks, Game Center. | flat |
| 10 | `D10-results` | Results of a real casual run | **One more *chest*?** / No ads. No in-app purchases. | flat |

Reserves (`duo_filter: ^(D[0-9]|DR)`): `DR1-golden` (a golden mimic), `DR2-home` (the inner Home with the three rules:
the fallback for D02 if the outer-display capture fails).

## B. iPhone 6.9" (1320 × 2868) and 6.3" (1206 × 2622 / 1179 × 2556): ten frames each

The same moments on the iPhone 18 Pro Max and the iPhone 18 Pro, **with the lever** (no fold, so the app draws the
lever and speaks its words). The outer-screen intro is Duo-only, so P02 is Home's three lever rules (shown for the first
runs). P01 is the D01 tabletop composite (the Duo pitch), captioned for any iPhone.

| # | File | Caption (where it differs from A) |
|---|---|---|
| 1 | `P01-hero-open` | **Open the chest. *Slowly.*** / Any iPhone. Best on iPhone Duo. (tabletop composite of D01) |
| 2 | `P02-rules` | **Learn it in *three* lines.** / No tutorial to sit through. (Home, first launch: the lever's three rules) |
| 5 | `P05-bank` | **Slide it down to *bank*.** / Bank before the candle burns out. |
| 6 | `P06-chomp` | as D06. The moment differs: since R15c the novice pilot no longer bites on a phone, so P06 is a real bite on chest 1 (the chest open, the noise held at a Waking 0.98 until the bite, the first bag clink tips it over: CHOMP, −66, −10s; "Candle lit. Gently does it." is still up) |
| 3–4, 7–10 | `P03-loot`, `P04-freeze`, `P07-chain` … `P10-results` | as D03–D04, D07–D10 |

## C. Product page header and search results art (optional, iOS 27)

`ci/store-placements.sh` draws both from D01's clean Duo capture with `store-frame.swift --banner` (the same tabletop
composite, the same type):
- `header-3840x1646.png`: **Hush** on the gold swash / "Steal the mimic's gold while it sleeps." (the outer intro's own
  headline) on the left, the Duo on the right, all inside the area an iPhone shows.
- `search-3840x2560.png`: **Open the chest. *Slowly.*** / "Steal the mimic's gold while it sleeps." over the Duo.
`asc.yml` places them only from `placements_run` (or `DEFAULT_PLACEMENTS_RUN`); they can also be dragged into App Store
Connect → the version → *Header and Search Results*. Check both in App Store Connect's product page preview.

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1 and the header/search art: only
  warped onto the device; D02: only scaled). Captions sit outside it.
- [ ] **Every caption is true of the build:** the phone is the chest (any opening opens it, closing with loot banks;
  R15c: silent at any speed); a fast drag is noise ("Slower…"); "Freeze!" at Waking and it settles when still; a bite
  costs the bag and 10 s of candle; the Hush Chain tops out at ×1.5; 24 relics; no ads, no IAP.
- [ ] **D02 shows the R15 intro** with Play and the three rules, on the outer display (MANIFEST: `cover display
  1398x2034 scaled`); no "Open to carry on", no "Close the phone to start".
- [ ] **No stale copy** anywhere in a frame: "Lift the lid", "Ease the lid down", "Stand it up like a little laptop",
  "Hold still…", "That's wide enough", "Close the phone to start", a lesson card.
- [ ] **D03/P03 show the bag being filled** (loot in the bag, "not safe yet"; `freezeAfter=3.25` of the casual pilot); else re-time
  `freezeAfter`.
- [ ] **D07 shows a chain medal** (×1.2 or more); **D08 shows the relic card**; **D06 is after the red flash**.
- [ ] **Seeded states are reachable:** pilots play real runs; "mid progress" is 9 relics and a 5,200 best.
- [ ] **No debug overlays, no camera-hole clash** (the Dynamic Island sits over the status bar only), nothing sideways.
- [ ] **No prices, dates, "#1", Apple logos or badges** in a frame (Guideline 2.3.7).
- [ ] **Exact size, PNG, no alpha** (MANIFEST `slot yes`, `alpha no`).

## Upload order

`tools/appstore/asc.swift` (asc.yml, `mode=push`, founder-run) uploads from the run in `DEFAULT_STORE_RUN` in this
order: 6.9" P01–P10, 6.3" P01–P10, iPhone Duo D01–D10 (if the API offers the Duo group; else by hand in App Store
Connect's iPhone Duo tab). By hand: drag `store/*.png` in name order. **Never upload** anything in `_flagged/`, a
`raw-*` artifact or `ci.yml`'s `screenshots` artifact.

## Sources
- Apple, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple, *Creative assets specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- Apple, *Prepare and submit your apps for iPhone Duo* (5 Oct 2026): https://developer.apple.com/news/?id=kkphp5qo
- App Review Guidelines 2.3.3, 2.3.7: https://developer.apple.com/app-store/review/guidelines/
