# Hush: App Store metadata (v1.0)

*Written Tue 27 Oct 2026 by the launch lead, adapted from Swoop's and Brim's reviewed kits. Paste from the code blocks exactly (or let the App Store Connect tool push them: `tools/appstore/README.md`). Counts are Unicode characters, counted with Node, except keywords, which Apple counts in bytes (all ASCII here, so the same). Each choice has a one-line reason in `DECISIONS.md`. **The game was still being built when this was written** (Round 1), so every feature claim comes from `design/GAME-DESIGN.md` and `design/ROUND-1.md`, and §10 lists each one to tick against the release-candidate build before submission. If a claim is false on the build, change the copy, never the other way round.*

**Words the copy uses** (the game's own words, `GAME-DESIGN.md`): *the lid*, *open slowly*, *ease the lid shut*, *loot*, *the bag*, *bank / keep it*, *the mimic* (Asleep, Stirring, Waking), *creak*, *noise meter*, *FREEZE*, *bite / CHOMP*, *the torch*, *chest* (Wooden, Iron-bound, Gilded, Royal), *relics*, *the Codex*, *thief rank*, *Hushed*, *Daily Dungeon*, *First Chest*, *the lid slider*. Never "slam it", "snap it shut" or "close it fast" as an instruction (it's how you *lose*, and the copy says so once, as a warning).

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
**28 / 30**, both locales. The whole verb in five words (slow is the skill, gold is the goal), and it indexes "open", "slowly", "steal" and "gold" without spending keyword bytes. No price, superlative or Apple mark (Guideline 2.3.7), and it works for both the Duo and the lid slider.

Alternative to try later (a version change; Product Page Optimization can't test the subtitle): `The game where you're gentle` (28), the design's store line.

## 3. Promotional text (limit 170; can change any time without a new version)

```
Stand your iPhone Duo like a little laptop and lift the lid, slowly. Grab the gold, ease it shut, don't wake the mimic. Lid slider on other iPhones. No ads, no IAP.
```
**164 / 170**, both locales. It leads with the Duo pose, because if the Duo screenshot slot is missing on upload day this line, frame 1 and the description carry the Duo pitch, and it says straight away that other iPhones can play.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Dungeon is open: the same chests for everyone and one try that counts. How much gold can you carry out before the torch burns down?` (145)
- After a press mention: `"[real quote]" ([outlet]). ...` (only with a real quote).

## 4. Description (limit 4,000)

**en-GB 3,446 / 4,000; en-US 3,446 / 4,000** (the two spelling changes keep the length).

### en-GB (English U.K.)

```
Your iPhone Duo is a treasure chest. The chest is a sleeping mimic.

Stand your Duo like a little laptop: the raised half is the lid. Open it slowly and the candlelight spills in, showing the gold. Drag the loot into your bag gently, then ease the lid shut to keep it. Too fast, and the lid creaks, the mimic wakes, and it bites.

The game where you have to be gentle.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

SLOW HANDS WIN
- Open the lid slowly: the light reaches deeper into the chest as it opens
- Coins sit near the front, gems further back, and relics deep inside: open wide for those
- Drag gently: a fast drag rattles, and loot dropped outside the bag clunks
- Ease the lid shut with loot in your bag to bank it. Close it too quickly and the mimic can bite on the way down
- A bite costs everything in your bag and 15 seconds of torch

WATCH THE MIMIC
Every chest starts asleep. The noise meter on the chest floor fills when you move too fast and drains when you keep still. Snoring is good. When the snoring stops and the velvet tongue twitches, it's stirring. When the meter turns red and FREEZE appears, hold still and let it settle. Every mimic wears a name tag, and each has a habit: Snorers, Light Sleepers, Heavy Sleepers, and Dreamers who twitch in their sleep.

PUSH YOUR LUCK
Your torch burns down while you loot, and torch oil found in a chest buys more time. The chests get richer as you go, from Wooden to Iron-bound, Gilded and Royal, and so does the gold they pay. The ruby is deeper in: open wider, or bank what you have? When the torch goes out the run ends, and anything still in your bag is lost.

DAILY DUNGEON
The same chests for everyone, every day, and one try that counts. Then practise as much as you like.

RELICS AND THIEF RANKS
Twenty-four named relics hide deep in the better chests. Find each one once and it stays in your Relic Codex. Every coin you bank counts towards your thief rank: twelve ranks, from Pickpocket to Mimic Whisperer.

FIRST CHEST
Your first chest is a short lesson with a very heavy sleeper: open, grab, freeze, bank. Replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo the hinge is the lid, and how gently you move it is the whole skill: about two slow strokes per chest. You never lay the phone flat, close it or move it fast. Moving fast is how you lose. iPhone Duo softens one half of its screen for a moment when a fold starts, so Hush keeps the loot, the noise meter and every warning on the half that stays sharp, and shows you which half to lift. On any other iPhone, slide the lid open and shut with the lid slider. Same chests, same mimic, same leaderboards, but on the Duo you feel the lid creak under your fingers.

SOUND AND FEEL
The creak follows your exact speed, in sound and in haptics. The snores, the heartbeat, the coin clinks, the heavy thunk of a banked haul and the CHOMP are all synthesised live in the app. Every warning is shown on screen too, so you can play with the sound off. Sound plays with the silent switch on; a setting makes Hush respect it instead. Sound and haptics each have a switch, and there's a Reduce Motion setting.

GAME CENTER
Leaderboards for your Best Haul and the Daily Dungeon, and 12 achievements. It's optional: Hush works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except two spellings: practise → practice, synthesised → synthesized. Full text, ready to paste:

```
Your iPhone Duo is a treasure chest. The chest is a sleeping mimic.

Stand your Duo like a little laptop: the raised half is the lid. Open it slowly and the candlelight spills in, showing the gold. Drag the loot into your bag gently, then ease the lid shut to keep it. Too fast, and the lid creaks, the mimic wakes, and it bites.

The game where you have to be gentle.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

SLOW HANDS WIN
- Open the lid slowly: the light reaches deeper into the chest as it opens
- Coins sit near the front, gems further back, and relics deep inside: open wide for those
- Drag gently: a fast drag rattles, and loot dropped outside the bag clunks
- Ease the lid shut with loot in your bag to bank it. Close it too quickly and the mimic can bite on the way down
- A bite costs everything in your bag and 15 seconds of torch

WATCH THE MIMIC
Every chest starts asleep. The noise meter on the chest floor fills when you move too fast and drains when you keep still. Snoring is good. When the snoring stops and the velvet tongue twitches, it's stirring. When the meter turns red and FREEZE appears, hold still and let it settle. Every mimic wears a name tag, and each has a habit: Snorers, Light Sleepers, Heavy Sleepers, and Dreamers who twitch in their sleep.

PUSH YOUR LUCK
Your torch burns down while you loot, and torch oil found in a chest buys more time. The chests get richer as you go, from Wooden to Iron-bound, Gilded and Royal, and so does the gold they pay. The ruby is deeper in: open wider, or bank what you have? When the torch goes out the run ends, and anything still in your bag is lost.

DAILY DUNGEON
The same chests for everyone, every day, and one try that counts. Then practice as much as you like.

RELICS AND THIEF RANKS
Twenty-four named relics hide deep in the better chests. Find each one once and it stays in your Relic Codex. Every coin you bank counts towards your thief rank: twelve ranks, from Pickpocket to Mimic Whisperer.

FIRST CHEST
Your first chest is a short lesson with a very heavy sleeper: open, grab, freeze, bank. Replay it from Settings any time.

MADE FOR THE FOLD. PLAYS ON EVERY iPhone.
On iPhone Duo the hinge is the lid, and how gently you move it is the whole skill: about two slow strokes per chest. You never lay the phone flat, close it or move it fast. Moving fast is how you lose. iPhone Duo softens one half of its screen for a moment when a fold starts, so Hush keeps the loot, the noise meter and every warning on the half that stays sharp, and shows you which half to lift. On any other iPhone, slide the lid open and shut with the lid slider. Same chests, same mimic, same leaderboards, but on the Duo you feel the lid creak under your fingers.

SOUND AND FEEL
The creak follows your exact speed, in sound and in haptics. The snores, the heartbeat, the coin clinks, the heavy thunk of a banked haul and the CHOMP are all synthesized live in the app. Every warning is shown on screen too, so you can play with the sound off. Sound plays with the silent switch on; a setting makes Hush respect it instead. Sound and haptics each have a switch, and there's a Reduce Motion setting.

GAME CENTER
Leaderboards for your Best Haul and the Daily Dungeon, and 12 achievements. It's optional: Hush works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Duo first, then "plays on every iPhone".** The lid slider is described honestly and not oversold ("on the Duo you feel the lid creak under your fingers"). The store page may talk about the Duo; the *app* never shows a Duo line on a non-Duo iPhone (the lesson's pose step becomes "Slide the lid up… slowly"), and nothing here promises otherwise.
- **The blur is explained once, plainly** ("softens one half of its screen for a moment when a fold starts"), as an iOS behaviour Hush works around, never as a Hush or Duo fault.
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **No hinge-wear bait.** The copy never tells anyone to slam, snap or close fast; it says fast is how you lose, and that Hush never asks for flat, closed or fast.
- **No named relics** in the copy until `RelicCatalog` exists (the design's two examples may be renamed); the description says "twenty-four named relics".
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
First Chest. Stand your Duo like a little laptop and lift the lid slowly. Bank the gold before your torch burns out. Don't wake the mimic. Other iPhones: the lid slider.
```
(169 characters.) Template for 1.0.1 (fill in only what actually shipped):
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
- **What happens on screen.** The mimic is cute-scary: one big eye, round teeth and a velvet tongue. When it bites, its teeth slam across the fold, the chest shakes, there's a red flash and a loud CHOMP, and before that a growl and a fast heartbeat in your hand. Nobody is shown hurt (no blood, no body, no injury: you lose your loot and some torch time), and the tone is comic. That is mild cartoon peril, and building tension before a sudden snap is a mild fear theme. Apple's 4+ means *no* such content; 9+ is defined as mild or infrequent cartoon or fantasy violence and mild horror or fear themes. So **Infrequent** is the honest answer to both, and 9+ follows.
- **Why "Infrequent", not "Frequent".** Bites are a fail moment, short and comic, and a careful player sees none in a whole run (the perfect pilot is never bitten, `ROUND-1.md` BalanceTests). The game's content is looting quietly, not violence.
- **What it costs.** Very little. Paid games are bought by adults, Duo owners are adults, and 9+ doesn't change charts, featuring or Family Sharing. Under-rating costs more: App Review can reject or re-rate a 4+ claim it disagrees with, and parents who see a monster lunge at their 5-year-old leave 1-star reviews.
- **What would make it 4+ later:** nothing we'd want to cut. Keep the bite comic; never add blood, injury or realistic harm (that would push it higher).

Why the other risky items are None or No:
- **Simulated gambling / loot boxes:** "loot" here is gold you see and choose to grab, not a random prize you pay for. Nothing is bought; chests are seeded, and the Daily Dungeon is the same fixed chests for everyone, not a draw.
- **Social media / messaging / UGC:** none. Game Center's own friend features are Apple's.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Hush is for everyone 9 and up, not built for children. Once approved, Made for Kids can't be changed.
- **Korea (GRAC):** no Rating Classification Number needed (only for 17+/19 games or frequent gambling, sex, drugs or realistic violence).

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99** (Apple's £1.99 price point); Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam**: paid games in China mainland need an NPPA (ISBN) approval number, and Vietnam requires a Vietnamese game licence. Hush has neither (as Brim: `C:\Users\59527\Fold\docs\appstore\COMPLIANCE.md` #15) |
| Apple silicon Mac / Apple Vision Pro | **Untick both** (Pricing and Availability → "iPhone and iPad Apps on Apple Silicon Macs" and "… on Apple Vision Pro"): no hinge, no lid slider tuned for a mouse, untested. iPad keeps running the iPhone app (Guideline 2.4.1) |
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

**The three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/hush/` (runbook §0b). The pages are `docs/index.html`, `docs/support.html` and `docs/privacy.html` themselves (no forwarding pages, unlike Swoop).

## 10. Claims to check against the release-candidate build

Written from the design on Tue 27 Oct, before the code existed. Before submission, Claude (or whoever cuts the release candidate) ticks each line on that build ("RC"), or changes the copy here, in `review-notes.md`, the site and the press kit. Never the build to match the words.

| Claim (where) | Source in the design (27 Oct) | Where to check in the code | RC |
|---|---|---|---|
| Tabletop pose: the raised half is the lid; open slowly to light the loot by depth; drag to the bag; ease shut (shut zone, 0.35 s hold) to bank | `GAME-DESIGN.md` §3–4 | `Core/HeistSession.swift`, `Core/Tuning.swift` | [ ] |
| Too fast = creak, the mimic wakes and bites; a bite costs the bag and 15 s of torch | §4.5, §5 | `Core/Tuning.swift` (bite torch cost) | [ ] |
| Coins near the front, gems further back, relics deep (open wide) | §6 (depth table) | `Core/ChestFactory.swift` | [ ] |
| A fast drag rattles; dropping outside the bag clunks (noise) | §4.3, §5 | `Core/Tuning.swift` | [ ] |
| Closing too quickly can bite on the way down | §4.4 | lid-speed noise applies while closing | [ ] |
| Noise meter on the floor fills/drains; snoring stops at Stirring; tongue twitches; red + FREEZE at Waking | §5 stage table | `Scene/ChestScene.swift`, `Feedback/` | [ ] |
| Name tags; Snorer, Light Sleeper, Heavy Sleeper, Dreamer (lid-only fake twitches) | §5 personalities | `Core/MimicNames.swift`, `Core/Tuning.swift` | [ ] exact kind names |
| Torch burns down; torch oil adds time; run ends at torch out; bag lost | §4 "The run" | `Core/Tuning.swift` | [ ] |
| "Runs last about two minutes" (site, press kit, nomination) | §4 "Typical run: 2 minutes" | `BalanceTests` (`HUSH-BAL` casual run length) | [ ] |
| Wooden, Iron-bound, Gilded, Royal; richer as you go | §6 tier table | `Core/Tuning.swift` | [ ] exact tier names |
| Daily Dungeon: same chests for everyone, one scored try a day, then practice | §7 | `Core/DailySeed.swift`, `UI/` Daily screen | [ ] and the day boundary (UTC: `DECISIONS.md` #19) |
| 24 named relics, found once, kept in the Relic Codex | §7 | `Core/RelicCatalog.swift`, `UI/CodexView.swift` | [ ] the screen's name ("Codex"/"Relic Codex") |
| 12 thief ranks, Pickpocket to Mimic Whisperer, by lifetime gold | §7 | `Core/Ranks.swift` (`ThiefRanks`) | [ ] first and last titles |
| First Chest: a lesson with a heavy sleeper (open, grab, freeze, bank), replay from Settings | §8, ROUND-1 Settings "Replay First Chest" | `App/` lesson, `UI/SettingsView.swift` | [ ] |
| About two slow strokes per chest; never flat, closed or fast | §2, §3 (shut zone 110°, closing pause below 85°, "That's wide enough" above 172°) | `Core/Tuning.swift`, `Input/HingeLidSource.swift` | [ ] |
| Loot, meter and warnings on the sharp half; the game shows which half to lift; "Turn the chest round" setting | §3 blurred half | `UI/RootView.swift`, pose card, `UI/SettingsView.swift` | [ ] exact setting label |
| Other iPhones: the lid slider | §9 | `Input/SliderLidSource.swift`, `Scene/` slider art | [ ] |
| Creak follows speed in sound and haptics; all sound synthesised live; no audio files | §10, ROUND-1 Feel | `Feedback/`; no audio files in the bundle | [ ] |
| Every warning also on screen (playable with sound off) | §3 "Nothing time-critical lives only on the lid", §5 | the floor tells (meter, tongue, FREEZE) | [ ] |
| Sound on silent; "Respect silent switch"; Sound and Haptics switches; Reduce Motion setting | ROUND-1 Settings | `UI/SettingsView.swift` | [ ] exact labels |
| 2 leaderboards + 12 achievements report from the build | §7, `achievements.md` | `App/GameCenterManager.swift` | [ ] |
| No network code, no SDKs | `privacy.md` §3 grep | `Hush/` | [ ] |

## Sources
- Swoop's metadata (structure, copy rules): `C:\Users\59527\Wing\docs\appstore\metadata.md`
- Brim's metadata and compliance check (the 2025 age-rating questionnaire, Contests, China and Vietnam, Mac and Vision Pro, DSA): `C:\Users\59527\Fold\docs\appstore\metadata.md`, `COMPLIANCE.md`
- Apple, *Age ratings values and definitions*: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App Review Guidelines 2.3.7 (metadata): https://developer.apple.com/app-store/review/guidelines/
