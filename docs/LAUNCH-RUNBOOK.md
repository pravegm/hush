# Hush launch runbook (for the founder)

*Written Tue 27 Oct 2026; updated the same day in Round 3 (the device test in §4 is now the Duo specialist's script, in the order you do them; rewritten Wed 28 Oct for build 1.0 (4) with the QA-6 P1-3 release gate at step 10). This is the only document you need to follow. It lists **only the steps that need your own GitHub or Apple login, or your Duo**; Claude does everything else. Each step says exactly where to click and what to type. Everything Apple sees lives in `docs/appstore/`; the reason behind every choice is in `docs/appstore/DECISIONS.md`. Whenever a step says "tell Claude", a one-line message in chat is enough.*

**Launch: Tuesday 1 December 2026, about 08:00 UK time, released by you (manual release).** Brim launches Tue 17 Nov and Swoop Tue 24 Nov, so the three games never share a week.

A few words used below:
- **Repo** (repository): Hush's project page on GitHub, `github.com/pravegm/hush`. It holds the code and these documents.
- **Actions**: GitHub's build robot. It turns the code into an app on Apple's newest Xcode, because your Mac can't.
- **Workflow**: one of the robot's jobs (for example "TestFlight"). You start one from the **Actions** tab with the grey **Run workflow** button.
- **Secret**: a password-like value stored in the repo's settings, which only the build robot can read.
- **TestFlight**: Apple's app for installing test builds on your own phone before launch.

---

## Timeline

| When | What you do | Section |
|---|---|---|
| **Done** | The repo is public | §0a |
| **Today, Tue 27 Oct** | Turn on the website (5 minutes) | §0b |
| Tue 27 – Thu 29 Oct | **First** the trademark check, **then** register Hush with Apple and create the app record (30 minutes) | §1 |
| Tue 27 – Thu 29 Oct | Add the 4 GitHub secrets (10 minutes), then send the featuring nomination (by **Tue 10 Nov**; Apple wants 3 weeks' notice) | §2 |
| When Claude says the build is ready (early November) | Run the TestFlight build (2 clicks) and install it | §3 |
| The same day or weekend | The 17-step Duo test (about 20 minutes; step 10 is a release gate), then send Claude your notes and the copied log | §4 |
| Until about Fri 20 Nov | Claude fixes and tunes from your notes; you repeat §4 on each new build | §4 |
| Tue 17 Nov | **Brim's launch day.** No Hush work today | — |
| **Sat 21 – Sun 22 Nov** | Fill in the listing with the App Store Connect robot, plus four clicks only you can do (one evening) | §5a–c |
| Mon 23 Nov | Claude: code freeze, the final build and the screenshots | — |
| Tue 24 Nov | **Swoop's launch day.** No Hush work today | — |
| **Wed 25 Nov** | Pick the final build, check the screenshots, **submit for review** with manual release (last safe day: Fri 27 Nov) | §5d–f |
| ~Thu 26 – Fri 27 Nov | Apple approves (usually 24–48 hours). Hush then waits for you | §5f |
| Sat 28 – Mon 30 Nov | Promo codes for creators; pre-launch posts | §6 |
| **Tue 1 Dec, ~08:00 UK** | Press **Release This Version**. Launch-day steps | §6 |

**If Hush isn't submitted by Fri 27 Nov:** move the launch to **Tue 15 Dec** (never 8 Dec, which is Swoop's fallback). Change the nomination's Publish Date (§2c) and tell Claude.

---

## §0. The repo is public; turn on the website

### 0a. Make the repo public: **done**

You've already done this (thank you): GitHub Actions only builds public repos on this account. *Check:* github.com/pravegm/hush shows a **Public** label next to the repo name. Nothing personal is in the repo.

### 0b. Turn on the website (support and privacy pages)

Apple needs a working support page and privacy page before it accepts the app. They're already written; this puts them online for free.

1. github.com/pravegm/hush → **Settings** (the gear tab along the top of the repo, on the right) → **Pages** (left list, under "Code and automation").
2. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
3. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
4. Wait 1–2 minutes, then open these on your phone. All three must load:
   - Home: **https://pravegm.github.io/hush/**
   - Support: **https://pravegm.github.io/hush/support.html**
   - Privacy: **https://pravegm.github.io/hush/privacy.html**

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

Support is through **GitHub issues** (`github.com/pravegm/hush/issues`), the same choice you made for Squish, Brim and Swoop, so there's no email address to set up. Check **Settings → General → Features → Issues** is ticked.

**Tell Claude "the site is up".**

---

## §1. Trademark check first, then the app record (about 30 minutes, once)

### 1a. Trademark check for the name "Hush" (10 minutes, before anything else)

Nobody has checked yet whether someone owns "Hush" as a trademark for games. Do this before the name goes into Apple's system. It's a quick search, not legal advice.

1. **UK:** go to **https://trademarks.ipo.gov.uk/ipo-tmtext** (UK IPO, "Search for a trade mark"). Search for the word `HUSH`. Under "Classes", tick **9** (software and downloadable games), **28** (games and toys) and **41** (entertainment and online games). Search.
2. **US:** go to **https://tmsearch.uspto.gov** (USPTO Trademark Search). Search `HUSH`. Use the filters to show **Live** marks only, and look at classes **009**, **028** and **041**.
3. For each result, look at three things: is it **live / registered** (not "dead" or "expired")? Is it for **games or game software**? Who owns it?
4. Tell Claude what you found, in one line per live match: for example "UK: HUSH, class 9, video games, owned by Flavourworks, registered."

What happens next:
- **Nothing live for games in 9, 28 or 41:** carry on with "Hush: Don't Wake the Mimic".
- **A live HUSH mark for games:** stop before 1c. Claude switches the game to the research's runner-up name, **"Tiptoe: Don't Wake the Mimic"** (the home-screen name becomes "Tiptoe"), and updates every page. If you'd rather keep "Hush", that's a question for a trademark solicitor, not a search.

(One known candidate: *HUSH*, a live-action game by Flavourworks. The App Store name being "Hush: Don't Wake the Mimic", not bare "Hush", helps, but a mark in class 9 or 41 is still worth knowing about.)

### 1b. Register the bundle ID (Hush's unique name inside Apple)

Go to **developer.apple.com** → **Account** → **Certificates, IDs & Profiles** → **Identifiers** → the blue **+**.
1. Choose **App IDs** → Continue → **App** → Continue.
2. Description: `Hush`
3. Bundle ID: choose **Explicit** and type `com.pravegm.hush`
4. In the **Capabilities** list, tick **Game Center** (nothing else).
5. **Continue** → **Register**.

### 1c. Create the app record

Go to **appstoreconnect.apple.com** → **Apps** → the blue **+** → **New App**.

| Field | Type or pick |
|---|---|
| Platforms | **iOS** |
| Name | `Hush: Don't Wake the Mimic` (type the apostrophe with your normal keyboard key. If it says the name is taken, try `Hush: The Mimic Chest`, then `Tiptoe: Don't Wake the Mimic`, and tell Claude which one worked) |
| Primary Language | **English (U.K.)** |
| Bundle ID | pick `com.pravegm.hush` from the list (if it's missing, wait 5 minutes and reload) |
| SKU | `hush-2026` |
| User Access | **Full Access** |

Click **Create**.

### 1d. Tell Claude the Apple ID

In the new app, open **App Information** (left list) and copy the **Apple ID** number (10 digits). Send it to Claude: it becomes the App Store link `https://apps.apple.com/app/id<that number>` in the press kit, the website and the posts.

### 1e. Turn on Game Center

In the app, open **Services** (in some layouts **Features**) → **Game Center** → turn it on. The leaderboards and achievements are added for you in §5 (or by hand: `docs/appstore/achievements.md`).

---

## §2. Connect GitHub to Apple, then send the nomination (15 minutes, once)

GitHub builds Hush for you on Apple's newest Xcode, and fills in the App Store listing for you. It needs four secrets: **the same four values you put into `pravegm/squish`, `pravegm/brim` and `pravegm/swoop`**. One Apple key works for all your apps.

You don't need to make any certificate or profile. The build uses **Apple's cloud-managed distribution certificate** through the API key, so the "maximum number of certificates" problem Brim hit can't happen.

**2a. Gather the four values.** GitHub never shows a saved secret again, so you can't copy them out of the other repos' settings. Get them from the source:

| Secret name | Where to find the value |
|---|---|
| `ASC_KEY_ID` | App Store Connect → **Users and Access** → **Integrations** → App Store Connect API → **Team Keys**: the "Key ID" column of the key you used for Brim and Swoop |
| `ASC_ISSUER_ID` | Same page, the **Issuer ID** shown above the table |
| `ASC_PRIVATE_KEY` | The `.p8` file you downloaded when you made that key. Open it in TextEdit (or Notepad) and copy **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `APPLE_TEAM_ID` | developer.apple.com → Account → **Membership details** → Team ID (10 characters) |

*Can't find the `.p8` file?* Apple only lets you download it once. Make a new key on the same Team Keys page: **+**, name `Studio CI`, Access **Admin**, **Generate**, **Download** the file straight away, and use the new Key ID. Don't revoke the old key: the other games keep using it.

**2b. Add them to Hush's repo.** github.com/pravegm/hush → **Settings** → **Secrets and variables** (left list) → **Actions** → **New repository secret**. For each of the four: type the name exactly as above (capitals and underscores), paste the value, click **Add secret**. When you're done the list shows four names.

**2c. The featuring nomination (by Tue 10 Nov; sooner is better).** This asks Apple's editors to consider featuring Hush on launch day. It needs only the app record (§1) and these secrets, not a build.
- **The easy way:** github.com/pravegm/hush → **Actions** → **App Store Connect tool** (left list) → **Run workflow** → tick **Contact App Store Connect** → mode **push** → in "Optional step list" type `nomination` → **Run workflow**. About 10 minutes later it shows a green tick. Then check App Store Connect → the app → **Featuring** → **Nominations**: one nomination, status **Submitted**.
- **By hand, if that fails:** App Store Connect → the app → **Featuring** → **Nominations** → **Create Nomination**. Copy every field from `docs/appstore/featuring-nomination.md`. Press **Submit** (a saved draft doesn't count).

---

## §3. Run TestFlight (when Claude says the game is ready)

**3a. Run a build.** github.com/pravegm/hush → **Actions** (tab along the top) → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → in "What to test" type anything (e.g. `first Duo test`) → leave "Only build…" unticked → **Run workflow**.
- About 20–30 minutes later the run shows a green tick. A red cross with "Missing repository secrets" means a name in 2b is misspelt; anything else, send Claude the link to the run.
- 10–30 minutes after the green tick, the build appears in App Store Connect → the app → **TestFlight**, first as "Processing". You won't be asked about encryption: that answer is already built in.

**3b. Install it (set up once).** App Store Connect → the app → **TestFlight** → **Internal Testing** → **+** → group name `Studio` → add yourself (your Apple Account email) → add the build. On the Duo, open Apple's **TestFlight** app (you have it from the other games) and tap **Install** next to Hush. Later builds appear there automatically.

---

## §4. The Duo test: 17 steps, about 20 minutes

*Rewritten Wed 28 Oct for TestFlight 1.0 (4) (rounds 6 to 10): there is no book card and no "I've stood it up" button any more; Hush plays whichever way iOS turns the screen. Step 10 is a **release gate** (QA-6 P1-3).*

**Why:** some things only your Duo can tell us: when the inner and outer screens switch over, which half blurs, whether touches land in the right place when the screen is turned sideways, and whether it gets warm. Do this on the release-candidate build and again on each new one.

**Before you start:**
- Sit at a table. Ringer **on**, volume about half.
- Words used: the **floor** is the half lying flat on the table; the **lid** is the half you lift. **Upright** means the lid straight up, like a laptop screen.
- **Screen recording** for steps 2, 8, 9 and 10: swipe down from the top-right corner to open Control Centre and tap the round record button (if it isn't there: Settings → Control Centre → add **Screen Recording**). Tap the red time at the top to stop; the video goes to Photos.
- If something goes wrong, carry on with the next step and write it down. If anything ever seems stuck: Settings → About → press and hold **Version** for 2 s → **Copy log**, and paste it to Claude.

| Step | Do this | What should happen (note anything different) |
|---|---|---|
| 1 | If an older Hush is on the Duo, delete it first. Install Hush from TestFlight. Hold the Duo open **like a book** (both halves standing up side by side) and open Hush. Then wiggle it gently for 5 seconds | Home appears **the right way up** for you, and nothing blocks it. A small tip says **"Stand it up like a little laptop"**; its ✕ hides it. The picture should **not keep flipping round** while you wiggle |
| 2 | **Start recording.** Put the Duo on the table and lift the lid like a laptop | The chest or Home is **the right way up**. You should **never see a brass lever** on the Duo |
| 3 | While lifting from flat, watch which half goes blurry for a moment | The half you lifted (the lid) blurs, **never the floor** |
| 4 | The lesson (First Chest): stand the lid upright. Then open it slowly, taking about 8 seconds (count them) | First "That's it" (or "That'll do" after about 4 s), then "Open the lid… slowly. Watch the noise." While opening: **no noise, and a coin starts to glint.** Note whether the lid's picture moves smoothly or in little jumps. **Skip** appears after about 20 s if you want it |
| 5 | Drag the coin into the pouch with one finger | The coin **stays under your finger** all the way |
| 6 | In a real **Run**, ease the lid down to about upright to bank a chest ("Ease the lid down to bank"), then leave it upright for 5 seconds | Note **which screen stays lit**: the inside screen (with no card on it), or the outside screen |
| 7 | Lower the lid **slowly** until it's shut, taking about 5 seconds. Watch the outside screen | The outside screen shows **only the sleeping mimic**, never a small chest flashing up |
| 8 | **Start recording.** Reopen **slowly**: stop for 1 second at upright, then again about halfway between upright and flat, then carry on | The inside screen lights up and the run carries on **with no bite** (after a bank it carries on as you lift; mid-chest a card says **"Hold still…"** first), and the candle **hasn't burned down** while the screen was dark. If the sleeping mimic stays on an open Duo, after 3 s it offers **"Already open?" Carry on / Home** |
| 9 | **Start recording.** Mid-run, open the Duo **fully flat**, wiggle it around for 5 seconds, then stand it back up like a laptop | It **keeps playing** ("That's wide enough" while flat, no pause), and after you stand it up the chest is still **the right way up**. The screen may now stay sideways in iOS's eyes: that's fine, and it's the set-up for step 10 |
| 10 | **RELEASE GATE.** With the screen turned sideways (straight after step 9, or holding the Duo like a book), do these four things: **a)** drag a coin into the bag; **b)** press and hold the pause coin until the menu opens, then tap **Resume**; **c)** go Home → **Settings**, scroll it all the way down, tap **Done**; **d)** start a run, lower the lid until the pause card shows, wait 3 s, tap **Carry on**. Then Settings → About → hold **Version** 2 s → **Copy log** | Each of a–d works first time, with the touch landing where your finger is. In the copied log, a line starting **canvas** ends in **k=1** or **k=3** (that proves the screen really was sideways). Paste the whole log to Claude |
| 11 | Mid-chest, **tap** the pause coin once. Then **press and hold** it. In the menu, tap **Resume** **while you're still moving the lid** | The tap only shows **"Hold to pause"**; the hold fills a ring and opens the menu. After Resume the run **waits until you hold the lid still** before it carries on |
| 12 | Lower the lid to about halfway between upright and shut and keep it there | "Lift the lid a little to carry on". After 3 s **Carry on** and **Home** appear next to it. Then lift the lid back past upright and keep it there with tiny wiggles: within about 6 s it carries on **by itself** |
| 13 | Settings: try **Vibration** (Off / Normal / Strong) and **Lid sensitivity** (Forgiving / Normal / Careful) | The rows say what they do; Lid sensitivity says "The scored Daily always plays Normal." Note which you'd keep |
| 14 | Hold the Duo upright like a normal phone, camera at the top | A gold **"Other way round"** banner appears |
| 15 | Stand it on the table again and lift the **floor** half instead on purpose | Note whether anything tells you |
| 16 | While you were easing the lid in all of the above | Did your fingers ever **pause the game** by accident? |
| 17 | Play **5 runs in a row** | Then note: is the Duo **warm**? Does the **creak** feel like the hinge itself? Is the buzz **in your fingers**, or a buzz on the table? Does careful opening feel fair? |

**Send Claude this (copy, fill in, paste in chat), plus the recordings, the copied log and any screenshots:**
```
Hush build [number from TestFlight], iPhone Duo, iOS [version]
1  Home right way up in book pose: [yes/no]   "Stand it up" tip, X hid it: [yes/no]   Kept flipping when I wiggled: [yes/no]
2  Right way up on the table: [yes/no]   Saw a lever: [yes/no]
3  Half that blurred: [lid / floor]
4  "That's it" then "Open the lid... slowly": [yes/no]   Silent + coin glinted: [yes/no]   Lid moved: [smoothly / in jumps]
5  Coin stayed under my finger: [yes/no]
6  Screen lit when resting upright: [inside / outside]
7  Outside screen showed only the sleeping mimic: [yes/no]
8  Carried on after reopening: [yes/no]   Bitten on reopening: [yes/no]   Candle burned down while dark: [yes/no]   Saw "Already open?": [yes/no]
9  Flat and back: kept playing: [yes/no]   Right way up after: [yes/no]
10 GATE (sideways): a) drag [ok/failed]  b) hold-pause + Resume [ok/failed]  c) Settings scroll + Done [ok/failed]  d) Carry on [ok/failed]   Log shows k=[1/3/other]
11 Tap said "Hold to pause": [yes/no]   Hold paused: [yes/no]   Resume waited for a still lid: [yes/no]
12 Carry on + Home after 3 s: [yes/no]   Carried on by itself: [yes/no, after about _ s]
13 Vibration I'd keep: [off/normal/strong]   Lid sensitivity I'd keep: [forgiving/normal/careful]
14 "Other way round" banner: [yes/no]
15 Lifted the floor half: anything told me? [what it said / nothing]
16 Paused by accident: [never / sometimes / often]
17 Warm after 5 runs: [no / a little / hot]   Creak feels like the hinge: [1-5]   Haptic: [in my fingers / on the table]   Careful opening fair: [1-5]
Runs (gold banked, chests, bites): 1 [ ] 2 [ ] 3 [ ] 4 [ ] 5 [ ]
Comfort (hand or wrist tired? ever had to move the lid further or faster than felt natural?):
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
In TestFlight you can also take a screenshot in Hush and tap **Share Beta Feedback**. A phone video of your hand and the Duo from the side while you play helps a lot too.

**The release rule.** The release build is the one where every "should" above happens, nothing in steps 7, 8, 9 or 12 goes wrong, comfort is fine, and **step 10 passes: all four touches work and the log shows k=1 or k=3** (QA-6 P1-3: no automated test has ever passed a touch on a sideways screen, and that is your own path from the first TestFlight). If any of the four fails, don't submit: send Claude the log and the recording. If you genuinely can't get the screen to stay sideways, tell Claude; QA-6's fallback is to ship (Home is always reachable, so the risk is awkward play at one pose, not a dead end) and to make this check the first thing in 1.0.1.

---

## §5. Fill in the listing and submit (Sat 21 – Wed 25 Nov)

### 5a. Let the robot fill in the listing (Sat 21 or Sun 22 Nov, 15 minutes of clicking)

The **App Store Connect tool** (Brim's, copied over) types the whole listing into App Store Connect for you from `docs/appstore/`: name, subtitle, description, keywords, promotional text, web addresses, categories (Games: Casual and Adventure, then Entertainment), the **age rating answers (result 9+)**, the **review notes**, Game Center (2 leaderboards, 12 achievements and their pictures), the **price (£1.99, base country United Kingdom)**, the **territories (everywhere except China mainland and Vietnam)**, **manual release**, and the screenshots. It copies the copyright line and your review contact details from Squish, without ever writing them into the public repo.

1. **Dry run first.** github.com/pravegm/hush → **Actions** → **App Store Connect tool** → **Run workflow** → tick **Contact App Store Connect** → mode **plan** → leave the other boxes as they are → **Run workflow**. It changes nothing.
2. When it shows a green tick (about 10 minutes), **tell Claude "plan done"**. Claude reads what it would change and tells you whether to go ahead.
3. **The real run.** Same steps with mode **push** → **Run workflow**. Green tick = done. A red cross: send Claude the link; running it again is safe (it only changes what's different).

### 5b. The four clicks only you can do (no robot can)

In App Store Connect → the app:
1. **App Privacy** (left list): **Privacy Policy URL** `https://pravegm.github.io/hush/privacy.html` → Save. Then **Get Started** → "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app** → **Save** → **Publish**. The page now says **Data Not Collected**. (Why it's true: `docs/appstore/privacy.md`.)
2. **Family Sharing:** **App Information** → Family Sharing → **On** (it can't be turned off later).
3. **Mac and Vision Pro:** **Pricing and Availability** → "iPhone and iPad Apps on Apple Silicon Macs": untick **Make this app available**; then "iPhone and iPad Apps on Apple Vision Pro": untick it too. **Save**.
4. **EU Digital Services Act:** **App Information** → **App Store Regulations and Permits** → **Digital Services Act** → answer as you did for Squish, Brim and Swoop (a paid app is normally **trader**; the trader details show publicly on EU store pages).

### 5c. Check what the robot did (5 minutes)

Open each page and check:
- **Pricing and Availability:** price **£1.99** with base country **United Kingdom**; the US shows **$1.99**. Availability: every country **except China mainland and Vietnam**. Pre-order: off.
- **App Information → Age Rating:** the result says **9+**. (Why 9+ and not 4+: the mimic's comic bite is "mild cartoon violence" in Apple's terms; `docs/appstore/metadata.md` §8.) If it says anything else, tell Claude before submitting.
- **The 1.0 page → App Review Information:** "Sign-in required" unticked, your contact details filled in, and the **Notes** box starts "Thanks for reviewing Hush". (The text is in `docs/appstore/review-notes.md`.)
- **The 1.0 page → Version Release:** **Manually release this version** is chosen.
- **Services → Game Center:** 2 leaderboards (Best Haul, Daily Dungeon) and 12 achievements, each with a picture (for example **Midas Touch** and **Hush Chain**).

**If the robot can't do something** (it says so in its output, and Claude will tell you), the by-hand version is: paste the code blocks from `docs/appstore/metadata.md` §1–5 into App Information and the 1.0 page (English (U.K.), then switch the language menu to English (U.S.) and paste the U.S. description); answer the age rating exactly as the table in §8; set the price and availability as in 5c; paste `review-notes.md`'s block into Notes; add the Game Center items from `achievements.md` (IDs can never be changed once saved, so type them exactly).

### 5d. Screenshots (Wed 25 Nov)

Claude tells you on Mon 23 Nov whether the robot has uploaded the screenshots or sends you a download link with the order (`docs/appstore/screenshots.md`). On the 1.0 page, **Previews and Screenshots**:
1. **6.9" Display:** P1–P6, in order.
2. **6.3"/6.1" Display** (whichever "iPhone with Dynamic Island" slot it asks for): P1–P6.
3. Open the device list. **If you see iPhone Duo**, add D1–D6 there and check them with Apple's preview. If there's no iPhone Duo entry, skip it (the Duo set comes with 1.0.1).

### 5e. Pick the build (Wed 25 Nov)

On the 1.0 page, **Build** → **+** → the build Claude names as the release build (the one that passed §4). In the **Game Center** section, check both leaderboards and all twelve achievements are listed (they only go live with this version).

### 5f. Submit (Wed 25 Nov; last safe day Fri 27 Nov)

1. Click **Add for Review**. If App Store Connect lists anything missing, fix it (or tell Claude) and click again.
2. Click **Submit to App Review**.
3. Usually 24–48 hours. You'll get an email.
   - **Approved:** the status becomes **Pending Developer Release**. Do nothing until launch morning (§6).
   - **Rejected:** don't panic. Copy Apple's message to Claude. Ready-made replies are in `review-notes.md` ("If rejected under…"). Answer in the Resolution Center the same day.

---

## §6. Launch: Sat 28 Nov – Tue 1 Dec

**Sat 28 – Mon 30 Nov:** App Store Connect → the app → **Promo Codes** → generate codes for the creators in `docs/appstore/social-launch.md` §4. Keep a list of who got which.

**Tue 1 Dec, about 08:00 UK:**
1. App Store Connect → the app → the 1.0 page → **Release This Version** → confirm. It can take a few hours to appear in every country.
2. Open Hush's App Store page on your phone (UK) and check: price £1.99, **9+**, "Data Not Collected", the screenshots, Game Center. Ask a US friend, or switch storefront, for $1.99.
3. **Accessibility labels:** App Store Connect → the app → **App Accessibility** → Get Started → **iPhone**. Tick only the labels `docs/appstore/accessibility.md` marks as passed (planned: **Dark Interface**, **Sufficient Contrast**, **Differentiate Without Color Alone**, **Reduced Motion**). Leave the rest unticked → **Publish**.
4. Post the launch posts from `social-launch.md` §2, and send the launch-day notes from `press-kit.md` #6 (as replies in your earlier email threads).
5. Tell Claude "Hush is live": Claude swaps "On the App Store 1 December" on the website for the real App Store link.
6. Play the first Daily Dungeon yourself and check your haul appears on the Daily Dungeon leaderboard.
7. For the next few days: App Store Connect → the app → **Ratings and Reviews**, and the TestFlight / Xcode crash reports. Forward anything odd to Claude for 1.0.1.
