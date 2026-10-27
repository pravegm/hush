# Hush: App Store metadata (v1.0)

*Rewritten Tue 27 Oct 2026 (Round 3, QA-2 P1-2) by the launch lead, from the code as it is now (`Hush/Core/Tuning.swift`, `Ranks.swift`, `Catalogs.swift`, `Hush/UI/PlayHUD.swift`, `Pages.swift`) and the founder's Round 3 decisions (`design/ROUND-3.md`). Paste from the code blocks exactly (or let the App Store Connect tool push them: `tools/appstore/README.md`). Counts are Unicode characters, counted with Node by `tools/appstore/build-metadata.js`, except keywords, which Apple counts in bytes (all ASCII here, so the same). Each choice has a one-line reason in `DECISIONS.md`. §10 lists every claim with the code that makes it true; tick each one again on the release-candidate build. If a claim is false on the build, change the copy, never the other way round.*

**Words the copy uses** (the game's own words, as the app shows them): *the lid*, *open slowly*, *ease the lid shut*, *bank* (the one verb for keeping loot), *loot*, *the bag* (IN BAG: not safe yet), *BANKED*, *the mimic* (Asleep, Stirring, Waking), *creak*, *the noise meter*, *"Freeze!"*, *bite / CHOMP*, *the candle* (the art is a candle; never another word for it), *oil*, *chest* (Wooden, Iron-bound, Gilded, Royal), *golden mimic*, *Hushed*, *Hush Chain*, *relics*, *the Relic Codex*, *thief rank*, *Daily Dungeon*, *First Chest*, *the lever* (other iPhones). Never "slam it", "snap it shut" or "close it fast" as an instruction (it's how you *lose*, and the copy says so once, as a warning).

Localisations: **English (U.K.)** is the primary language, plus **English (U.S.)**. Every other storefront shows en-GB. Only the description differs between the two (§4).

---

## 1. App name (limit 30)

```
Hush: Don't Wake the Mimic
```
**26 / 30.** The apostrophe is the plain ASCII `'`. "Hush" alone is crowded by sleep-sound apps ("Hush: Sleep Sounds & Calm") and clashes with Flavourworks' *HUSH* (`research/02-names.md`); the subtitle-style name says what the game is in four words and is the game's own title.

If App Store Connect says the name is taken when you create the record, use the first that works, and tell Claude:

| Order | Fallback | Count |
|---|---|---|
| 1 | `Hush: The Mimic Chest` | 21 |
| 2 | `Tiptoe: Don't Wake the Mimic` | 28 |
| 3 | `Hush - Don't Wake the Mimic` | 27 |

The home-screen name under the icon is **Hush** (`CFBundleDisplayName` in `project.yml`), whichever store name is used. (If the trademark check in runbook §1a finds a live "HUSH" mark for games, fallback 2, "Tiptoe", is the research's runner-up name; the home-screen name would change too.)

## 2. Subtitle (limit 30)

```
Open slowly. Steal the gold.
```
**28 / 30**, both locales. The whole verb in five words (slow is the skill, gold is the goal), and it indexes "open", "slowly", "steal" and "gold" without spending keyword bytes. No price, superlative or Apple mark (Guideline 2.3.7), and it works for both the Duo and the lever.

Alternative to try later (a version change; Product Page Optimization can't test the subtitle): `The game where you're gentle` (28), the design's store line.

## 3. Promotional text (limit 170; can change any time without a new version)

```
Stand your iPhone Duo like a little laptop and lift the lid, slowly. Grab the gold, ease it shut to bank it, don't wake the mimic. Lever on other iPhones. No ads, no IAP.
```
**170 / 170**, both locales. It leads with the Duo pose, because if the Duo screenshot slot is missing on upload day this line, frame 1 and the description carry the Duo pitch, and it says straight away that other iPhones can play.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Dungeon is open: the same chests for everyone and one try that counts. How much gold can you carry out before the candle burns down?` (146)
- After a press mention: `"[real quote]" ([outlet]). ...` (only with a real quote).

## 4. Description (limit 4,000)

**en-GB 3,935 / 4,000; en-US 3,935 / 4,000** (counted by `build-metadata.js`; the two spelling changes keep the length). Any addition must cut as much elsewhere.

### en-GB (English U.K.)

```
Your iPhone Duo is a treasure chest. The chest is a sleeping mimic.

Stand your Duo like a little laptop: the raised half is the lid. Open it slowly and the candlelight spills in, showing the gold. Drag the loot into your bag gently, then ease the lid shut to bank it. Too fast, and the lid creaks, the mimic wakes, and it bites.

The game where you have to be gentle.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

SLOW HANDS WIN
- Open the lid slowly: the light reaches deeper into the chest as it opens
- Coins sit near the front, gems further back, and relics deep inside: open wide for those
- Drag gently: a fast drag rattles, and loot dropped outside the bag clunks
- Loot in your bag isn't safe yet. Ease the lid shut to bank it, and gently: closing fast is noisy too
- A bite costs everything in your bag and 10 seconds of candle

WATCH THE MIMIC
Every chest starts asleep. The noise meter on the chest floor fills when you move too fast and drains when you keep still. When the snoring stops, a slow heartbeat starts and the velvet tongue twitches, it's stirring. When the meter turns red and "Freeze!" appears, hold still and let it settle. Loot in your bag keeps a little noise in the air, so the more you carry, the less the mimic settles. Every mimic wears a name tag, and each has a habit: Snorers, Light Sleepers, Heavy Sleepers, and Dreamers who twitch in their sleep.

PUSH YOUR LUCK
Your candle burns down while you loot, and a flask of oil found in a chest buys six more seconds. The chests get richer as you go, from Wooden to Iron-bound, Gilded and Royal. When something glints deeper in, a relic is hiding at the back: open wider, or bank what you have? When the candle goes out the run ends, and anything still in your bag is lost.

HUSH CHAIN AND GOLDEN MIMICS
Bank a chest without the mimic ever stirring and it's Hushed. Hushed banks in a row build a Hush Chain, and each one pays more: gold ×1.1, ×1.2, up to ×1.5. One stir breaks the chain. Now and then a golden mimic turns up: double gold, but it sleeps lighter.

DAILY DUNGEON
The same chests for everyone, every day, and one try that counts. Then practise as much as you like.

RELICS AND THIEF RANKS
Twenty-four named relics hide deep in the better chests, from the Moth-Eaten Crown to the Idol of the Sleepy God. Find each one once and it stays in your Relic Codex. Every coin you bank counts towards your thief rank: twelve ranks, from Pickpocket to Mimic Whisperer.

FIRST CHEST
Your first chest is a short lesson: open, grab, freeze, bank. Replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo the hinge is the lid, and how gently you move it is the whole skill: about two slow strokes per chest. You never need to lay the phone flat, close it or move it fast. Moving fast is how you lose. iPhone Duo softens one half of its screen for a moment when a fold starts, so Hush keeps the loot, the noise meter and every warning on the half that stays sharp, and shows you which half to lift. Fold the lid down past upright, or close the Duo, and the run pauses, candle and all. On any other iPhone, an on-screen lever opens and shuts the lid. Same chests, same mimic, same leaderboards, but on the Duo you feel the lid creak under your fingers.

SOUND AND FEEL
The creak follows your exact speed, in sound and in haptics. The snores, the heartbeat, the coin clinks, the cascade of a banked haul and the CHOMP are all synthesised live in the app. Every warning is shown on screen too, so you can play with the sound off. Sound plays on silent unless you switch that off, and Settings has switches for sound, haptics and Reduce motion.

GAME CENTER
Leaderboards for your Best Haul and the Daily Dungeon, and 12 achievements. It's optional: Hush works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except two spellings: practise → practice, synthesised → synthesized. Full text, ready to paste:

```
Your iPhone Duo is a treasure chest. The chest is a sleeping mimic.

Stand your Duo like a little laptop: the raised half is the lid. Open it slowly and the candlelight spills in, showing the gold. Drag the loot into your bag gently, then ease the lid shut to bank it. Too fast, and the lid creaks, the mimic wakes, and it bites.

The game where you have to be gentle.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

SLOW HANDS WIN
- Open the lid slowly: the light reaches deeper into the chest as it opens
- Coins sit near the front, gems further back, and relics deep inside: open wide for those
- Drag gently: a fast drag rattles, and loot dropped outside the bag clunks
- Loot in your bag isn't safe yet. Ease the lid shut to bank it, and gently: closing fast is noisy too
- A bite costs everything in your bag and 10 seconds of candle

WATCH THE MIMIC
Every chest starts asleep. The noise meter on the chest floor fills when you move too fast and drains when you keep still. When the snoring stops, a slow heartbeat starts and the velvet tongue twitches, it's stirring. When the meter turns red and "Freeze!" appears, hold still and let it settle. Loot in your bag keeps a little noise in the air, so the more you carry, the less the mimic settles. Every mimic wears a name tag, and each has a habit: Snorers, Light Sleepers, Heavy Sleepers, and Dreamers who twitch in their sleep.

PUSH YOUR LUCK
Your candle burns down while you loot, and a flask of oil found in a chest buys six more seconds. The chests get richer as you go, from Wooden to Iron-bound, Gilded and Royal. When something glints deeper in, a relic is hiding at the back: open wider, or bank what you have? When the candle goes out the run ends, and anything still in your bag is lost.

HUSH CHAIN AND GOLDEN MIMICS
Bank a chest without the mimic ever stirring and it's Hushed. Hushed banks in a row build a Hush Chain, and each one pays more: gold ×1.1, ×1.2, up to ×1.5. One stir breaks the chain. Now and then a golden mimic turns up: double gold, but it sleeps lighter.

DAILY DUNGEON
The same chests for everyone, every day, and one try that counts. Then practice as much as you like.

RELICS AND THIEF RANKS
Twenty-four named relics hide deep in the better chests, from the Moth-Eaten Crown to the Idol of the Sleepy God. Find each one once and it stays in your Relic Codex. Every coin you bank counts towards your thief rank: twelve ranks, from Pickpocket to Mimic Whisperer.

FIRST CHEST
Your first chest is a short lesson: open, grab, freeze, bank. Replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo the hinge is the lid, and how gently you move it is the whole skill: about two slow strokes per chest. You never need to lay the phone flat, close it or move it fast. Moving fast is how you lose. iPhone Duo softens one half of its screen for a moment when a fold starts, so Hush keeps the loot, the noise meter and every warning on the half that stays sharp, and shows you which half to lift. Fold the lid down past upright, or close the Duo, and the run pauses, candle and all. On any other iPhone, an on-screen lever opens and shuts the lid. Same chests, same mimic, same leaderboards, but on the Duo you feel the lid creak under your fingers.

SOUND AND FEEL
The creak follows your exact speed, in sound and in haptics. The snores, the heartbeat, the coin clinks, the cascade of a banked haul and the CHOMP are all synthesized live in the app. Every warning is shown on screen too, so you can play with the sound off. Sound plays on silent unless you switch that off, and Settings has switches for sound, haptics and Reduce motion.

GAME CENTER
Leaderboards for your Best Haul and the Daily Dungeon, and 12 achievements. It's optional: Hush works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Duo first, then "plays on every iPhone".** The lever is described honestly and not oversold ("on the Duo you feel the lid creak under your fingers"). The store page may talk about the Duo; the *app* keys its words on the layout (founder decision 4, `ROUND-3.md`): a fold layout uses lid words and never draws the lever, a phone uses lever words ("Slide the lever up… slowly"), and nothing here promises otherwise.
- **The blur is explained once, plainly** ("softens one half of its screen for a moment when a fold starts"), as an iOS behaviour Hush works around, never as a Hush or Duo fault.
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **No hinge-wear bait.** The copy never tells anyone to slam, snap or close fast; it says fast is how you lose, and that Hush never needs flat, closed or fast. Closing the Duo is mentioned only as a pause.
- **Two relic names only**, the first and last in `RelicCatalog.all` ("The Moth-Eaten Crown", "The Idol of the Sleepy God"); if Core renames either, change the line.
- **The multipliers are the code's** (`Tuning.chainStep` 0.1, `chainMax` 5; `goldenValueMultiplier` 2; `goldenNoiseMultiplier` 1.25 = "sleeps lighter"). "Now and then" for golden mimics (6 % of chests from the third) and no percentage in the copy.
- **No horror words** beyond the game's own comic ones (bite, CHOMP): no "terrifying", "jump scare", "monster attack". The mimic is cute-scary (`GAME-DESIGN.md` §10).
- **Plain hyphen bullets** (`- `), so the text is identical in every field and tool.

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
treasure,chest,loot,thief,stealth,sneak,dungeon,gentle,monster,hinge,foldable,lid,tiptoe,relic,heist
```
**100 / 100 bytes**, both locales.
- Nothing repeats the name or subtitle: hush, don't, wake, the, mimic, open, slowly, steal, gold are already indexed from them.
- Singular forms only ("relic", not "relics"): Apple matches plurals.
- No competitor names, and no "creak": Amanita Design's *Creaks* is on Apple Arcade (`research/02-names.md`). No Apple marks ("iPhone", "Duo").
- Apple combines words across fields, so "treasure" + "chest", "steal" + "gold", "mimic" + "chest", "stealth" + "game" and "hinge" + "foldable" form the searches people type.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `treasure,chest,loot,thief,stealth,sneak,dungeon,quiet,monster,hinge,foldable,nap,tiptoe,relic,heist` (99)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
First Chest. Stand your Duo like a little laptop and lift the lid slowly. Bank the gold before your candle burns out. Don't wake the mimic. Other iPhones: the lever.
```
(165 characters.) Template for 1.0.1 (fill in only what actually shipped):
```
A gentler creak on iPhone Duo, [one real change], and small fixes. Thanks for keeping the mimic asleep.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Casual** | `GAMES_CASUAL` |
| Game subcategory 2 | **Adventure** | `GAMES_ADVENTURE` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Casual is where paid one-input games chart, and its paid chart is shallow enough for a launch spike to show (as for Brim and Swoop). **Adventure, not Puzzle:** there is no puzzle to solve (it's push-your-luck stealth), Puzzle is the most crowded free chart on the store, and a dungeon, a thief and a treasure chest are what Adventure browsers look for. If the founder prefers **Puzzle**, it's a one-word change (`GAMES_PUZZLE`) with no other effect. Arcade is out: Apple's live subcategory list dropped it on 26 Oct (Brim's run 40340641267); the tool checks the live list before it writes. Entertainment (optional) catches "look what my phone does" browsers.

## 8. Age rating: 9+

Apple's current scheme (since the July 2025 overhaul) has five global ratings, **4+, 9+, 13+, 16+, 18+**, plus regional ones App Store Connect works out from the same answers. App Store Connect → the app → **App Information** → Age Ratings → **Set Up Age Ratings** (later: **Edit**). Step 1 is a tick-list of in-app controls and capabilities: **tick nothing**. Then answer each section. Yes/No items are marked (Y/N); the rest are a frequency: **None / Infrequent / Frequent**.

| Section | Item | Answer |
|---|---|---|
| In-app controls | Parental Controls | **No** (not ticked) |
| | Age Assurance | **No** (not ticked) |
| Capabilities | Unrestricted Web Access | **No** |
| | User-Generated Content | **No** |
| | Social Media | **No** |
| | Social Media Disabled for Users Under 13 | **No** |
| | Messaging and Chat | **No** |
| | Advertising | **No** |
| Mature themes | Profanity or Crude Humor | **None** |
| | Horror/Fear Themes | **Infrequent** (see below) |
| | Alcohol, Tobacco, or Drug Use or References | **None** |
| Medical or wellness | Medical or Treatment Information | **None** |
| | Health or Wellness Topics | **None** |
| Sexuality or nudity | Mature or Suggestive Themes | **None** |
| | Sexual Content or Nudity | **None** |
| | Graphic Sexual Content and Nudity | **None** |
| Violence | Cartoon or Fantasy Violence | **Infrequent** (see below) |
| | Realistic Violence | **None** |
| | Prolonged Graphic or Sadistic Realistic Violence | **None** |
| | Guns or Other Weapons | **None** |
| Chance-based activities | Simulated Gambling | **None** |
| | Contests | **Infrequent** (the optional Game Center leaderboards, as Brim) |
| | Gambling (Y/N) | **No** |
| | Loot Boxes (Y/N) | **No** |
| Age Categories and Override | Made for Kids / Override to Higher Age Rating | **Not Applicable** |
| | Age Suitability URL (optional) | leave empty |

**Expected result: 9+.** In Apple's table, Infrequent Cartoon or Fantasy Violence and Infrequent Horror/Fear Themes each give 9+ (Frequent would give 13+, so don't pick that); Infrequent Contests stays at 4+. If App Store Connect shows any other result, or an item not listed here, stop and tell Claude before saving.

**Why 9+ and not 4+ (the decision):**
- **What happens on screen.** The mimic is cute-scary: one big eye, pointed but rounded-tip fangs and a velvet tongue. When it bites, its teeth slam across the fold, the chest shakes, there's a red flash and a loud CHOMP, and before that a growl and a fast heartbeat in your hand. Nobody is shown hurt (no blood, no body, no injury: you lose your loot and 10 seconds of candle), and the tone is comic. That is mild cartoon peril, and building tension before a sudden snap is a mild fear theme. Apple's 4+ means *no* such content; 9+ is defined as mild or infrequent cartoon or fantasy violence and mild horror or fear themes. So **Infrequent** is the honest answer to both, and 9+ follows.
- **Why "Infrequent", not "Frequent".** Bites are a fail moment, short and comic, and a careful player sees none in a whole run (the balance sim's casual, expert and perfect players median 0 bites, `design/notes/core-R2.md`). The game's content is looting quietly, not violence.
- **What it costs.** Very little. Paid games are bought by adults, Duo owners are adults, and 9+ doesn't change charts, featuring or Family Sharing. Under-rating costs more: App Review can reject or re-rate a 4+ claim it disagrees with, and parents who see a monster lunge at their 5-year-old leave 1-star reviews.
- **What would make it 4+ later:** nothing we'd want to cut. Keep the bite comic; never add blood, injury or realistic harm (that would push it higher).

Why the other risky items are None or No:
- **Simulated gambling / loot boxes:** "loot" here is gold you see and choose to grab, not a random prize you pay for. Nothing is bought; chests are seeded, golden mimics are a free in-run surprise, and the Daily Dungeon is the same fixed chests for everyone, not a draw.
- **Social media / messaging / UGC:** none. Game Center's own friend features are Apple's.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Hush is for everyone 9 and up, not built for children. Once approved, Made for Kids can't be changed.
- **Korea (GRAC):** no Rating Classification Number needed (only for 17+/19 games or frequent gambling, sex, drugs or realistic violence).

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99** (Apple's £1.99 price point); Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam**: paid games in China mainland need an NPPA (ISBN) approval number, and Vietnam requires a Vietnamese game licence. Hush has neither (as Brim: `C:\Users\59527\Fold\docs\appstore\COMPLIANCE.md` #15) |
| Apple silicon Mac / Apple Vision Pro | **Untick both** (Pricing and Availability → "iPhone and iPad Apps on Apple Silicon Macs" and "… on Apple Vision Pro"): no hinge, a lever untested with a mouse or gaze. iPad keeps running the iPhone app (Guideline 2.4.1) |
| EU Digital Services Act | Asked again for each new app: App Information → App Store Regulations and Permits → Digital Services Act. A paid app is normally **trader**; the trader address, phone and email are **shown publicly on EU product pages** (founder's call, as for Squish and Brim; never in the repo) |
| Pre-order | **No** |
| Release | **Manually release this version**. The founder presses Release on **Tue 1 Dec 2026 at about 08:00 UK time** (runbook §6) |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | The same line as Squish's (the App Store Connect tool copies it from Squish at run time, never into the repo). Typing it by hand: copy Squish's 1.0 page's Copyright field exactly |
| Support URL | `https://pravegm.github.io/hush/support.html` |
| Marketing URL | `https://pravegm.github.io/hush/` |
| Privacy Policy URL | `https://pravegm.github.io/hush/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Dark Interface**, **Sufficient Contrast**, **Differentiate Without Color Alone**, **Reduced Motion**, each only after its check passes, published on launch day (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` |
| Game Center | On; 2 leaderboards and 12 achievements, 525 points (`achievements.md`) |
| Sign-in required | No |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`) |

**The three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/hush/` (runbook §0). The pages are `docs/index.html`, `docs/support.html` and `docs/privacy.html` themselves (no forwarding pages, unlike Swoop).

## 10. Claims, and the code that makes each one true

Checked against the code on Tue 27 Oct 2026 (Round 3). Before submission, Claude (or whoever cuts the release candidate) ticks each line again on that build ("RC"), or changes the copy here, in `review-notes.md`, the site and the press kit. Never the build to match the words.

| Claim (where) | The code (27 Oct, R3) | RC |
|---|---|---|
| Tabletop pose: the raised half is the lid; open slowly to light the loot by depth; drag to the bag; ease shut to bank (shut zone ≤ 110°, held 0.35 s, loot in the bag) | `Tuning.shutZoneAngle` 110, `shutHoldSeconds` 0.35; `lightRamp`, `revealLight`, `grabLight` | [ ] |
| Too fast = creak, the mimic wakes and bites; a bite costs the bag and **10 s of candle** | `Tuning` bite penalty 10 s; `HeistEvent.biteCost` | [ ] |
| Coins near the front, gems further back, relics deep (open wide) | `Tuning` copper 0–0.45, silver 0.2–0.6, gem 0.45–0.8, relic 0.80–0.88 depth | [ ] |
| A fast drag rattles; dropping outside the bag clunks | `Tuning.dragQuietSpeed` 350, `dropNoise` 0.08 | [ ] |
| Closing fast is noisy too | `Tuning.closeQuietSpeed` 18 (lid noise applies while closing) | [ ] |
| Noise meter on the floor fills/drains; snoring stops and a slow heartbeat starts at Stirring; tongue twitches; red + **"Freeze!"** at Waking | `HushCopy.hint(.freeze)` = "Freeze!"; `FeedbackDirector` heartbeat (slow at Stirring, fast + haptic at Waking) | [ ] |
| Loot in the bag keeps a little noise in the air (the bag jingle) | `Tuning.jinglePerItem` 0.035 × items, max 0.30 (under Stirring) | [ ] |
| Name tags; Snorer, Light sleeper, Heavy sleeper, Dreamer (fake twitches) | `MimicNames`, `Tuning` personalities, the lid nameplate's trait line | [ ] |
| The candle burns down (100 s); oil adds **6 s**; the run ends at candle out; the bag is lost | `Tuning` candle 100 s, `oilSeconds` 6, `oilChance` 0.33 | [ ] |
| "Something glints deeper" = a relic is hiding | `HushCopy.hint(.relicDeeper)` "Something glints deeper…"; `Tuning.relicGlimmerRange` 0.25; the scene's twinkle | [ ] |
| "Runs last about two minutes" (site, press kit, nomination) | balance sim: casual 131 s, expert 144 s (`design/notes/core-R2.md`) | [ ] |
| Wooden, Iron-bound, Gilded, Royal; richer as you go | `Tuning` tiers ×1 / ×1.5 / ×2 / ×3 from chests 1 / 3 / 5 / 7 | [ ] |
| Hushed = banked without the mimic ever stirring; Hush Chain ×1.1 … ×1.5; one stir (or a bite) breaks it | `Tuning.chainStep` 0.10, `chainMax` 5 | [ ] |
| Golden mimics "now and then": double gold, sleeps lighter | `Tuning.goldenChance` 0.06 from chest 3, `goldenValueMultiplier` 2, `goldenNoiseMultiplier` 1.25 | [ ] |
| Daily Dungeon: same chests for everyone, one scored try a day, then practice | `Core/DailySeed.swift`; `AppRules` Daily clock (00:00 UTC); `UI/Pages.swift` Daily page | [ ] |
| 24 named relics (Moth-Eaten Crown … Idol of the Sleepy God), found once, kept in the **Relic Codex** | `RelicCatalog.all`; `Pages.swift` "Relic Codex" | [ ] |
| 12 thief ranks, Pickpocket to Mimic Whisperer, by lifetime gold | `ThiefRanks.titles` | [ ] |
| First Chest: a short lesson (open, grab, freeze, bank); Settings "Replay First Chest" | `App/LessonScript.swift`; `Pages.swift` | [ ] |
| About two slow strokes per chest; never flat, closed or fast; folding past upright or closing pauses, candle and all | `Tuning.closingAngle` 70 (0.4 s), `tooWideAngle` 172; resume at ≥ 95° held still (`HingeLidSource.canResume`); noise and candle frozen while paused (`ROUND-3.md` decision 2) | [ ] |
| Loot, meter and warnings on the sharp half; the game shows which half to lift; Settings "Turn the chest round" | `Pages.swift` `turnTitle`; the pose card | [ ] |
| Other iPhones: an on-screen lever; a Duo never shows it | `ROUND-3.md` decision 4; the scene's lever (no fold) | [ ] |
| Creak follows speed in sound and haptics; all sound synthesised live; no audio files | `Feedback/FeelSoundBook.swift`; no audio files in the bundle | [ ] |
| Every warning also on screen (playable with sound off) | the floor tells (meter, tongue, "Freeze!"), the candle countdown | [ ] |
| Sound on silent by default, switchable ("Play sound on silent"); Sound and Haptics switches; "Reduce motion" | `Pages.swift` `SettingsView` | [ ] |
| 2 leaderboards + 12 achievements report from the build | `App/GameCenterManager.swift`; `achievements.md` | [ ] |
| No network code, no SDKs | `privacy.md` §3 grep | [ ] |

## Sources
- Swoop's metadata (structure, copy rules): `C:\Users\59527\Wing\docs\appstore\metadata.md`
- Brim's metadata and compliance check (the 2025 age-rating questionnaire, Contests, China and Vietnam, Mac and Vision Pro, DSA): `C:\Users\59527\Fold\docs\appstore\metadata.md`, `COMPLIANCE.md`
- Apple, *Age ratings values and definitions*: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App Review Guidelines 2.3.7 (metadata): https://developer.apple.com/app-store/review/guidelines/
