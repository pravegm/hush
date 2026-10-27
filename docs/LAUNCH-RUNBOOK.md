# Hush launch runbook (for the founder)

*Written Tue 27 Oct 2026. This is the only document you need to follow. It lists **only the steps that need your own GitHub or Apple login**; Claude does everything else. It goes in order, and each step says exactly where to click and what to type. Everything Apple sees lives in `docs/appstore/`; the reason behind every choice is in `docs/appstore/DECISIONS.md`. Whenever a step says "tell Claude", a one-line message in chat is enough.*

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
| **Today, Tue 27 Oct** | Make the repo public and turn on the website (5 minutes). **This unblocks everything else** | §0 |
| Tue 27 – Thu 29 Oct | Trademark check, then register Hush with Apple and create the app record (30 minutes) | §1a–e |
| Tue 27 – Thu 29 Oct | Add the 4 GitHub secrets (10 minutes) | §2 |
| **By Tue 10 Nov** (sooner is better) | The featuring nomination (Apple wants 3 weeks' notice) | §1f |
| When Claude says the build is ready (early November) | Run the TestFlight build (2 clicks) and install it | §3 |
| The same weekend | First play on your Duo: the 10-minute check, then send Claude your notes | §4 |
| Until about Fri 20 Nov | Claude tunes the feel from your notes; you repeat the 10-minute check on each new build | §4 |
| Tue 17 Nov | **Brim's launch day.** No Hush work today | — |
| **Sat 21 – Sun 22 Nov** | Fill in the listing with the App Store Connect robot, plus four clicks only you can do (one evening) | §5a–c |
| Mon 23 Nov | Claude: code freeze, the final build and the screenshots | — |
| Tue 24 Nov | **Swoop's launch day.** No Hush work today | — |
| **Wed 25 Nov** | Pick the final build, check the screenshots, **submit for review** with manual release (last safe day: Fri 27 Nov) | §5d–f |
| ~Thu 26 – Fri 27 Nov | Apple approves (usually 24–48 hours). Hush then waits for you | §5f |
| Sat 28 – Mon 30 Nov | Promo codes for creators; pre-launch posts | §6 |
| **Tue 1 Dec, ~08:00 UK** | Press **Release This Version**. Launch-day steps | §6 |

**If Hush isn't submitted by Fri 27 Nov:** move the launch to **Tue 15 Dec** (never 8 Dec, which is Swoop's fallback). Change the nomination's Publish Date (§1f) and tell Claude.

---

## §0. Make the repo public and turn on the website (do this first)

### 0a. Make the repo public

**Why:** this GitHub account's billing blocks GitHub Actions on **private** repos, which stops every build, test and TestFlight upload. Public repos build for free. Squish, Brim and Swoop are already public for the same reason. Nothing personal is in the repo. (Claude had to create it private: its safety rules don't allow it to create public repos.)

1. Go to **github.com/pravegm/hush** and sign in.
2. Click **Settings** (the gear tab along the top of the repo, on the right).
3. Stay on **General** (the first item in the left list) and scroll to the very bottom, to the red **Danger Zone** box.
4. Click **Change visibility** → **Change to public**.
5. GitHub asks you to confirm (it may ask you to type `pravegm/hush`, and to confirm with your password or phone). Confirm.

*Check:* the Danger Zone button now says **Change to private**, and the repo name at the top has a **Public** label next to it.

### 0b. Turn on the website (support and privacy pages)

Apple needs a working support page and privacy page before it accepts the app. They're already written; this puts them online for free.

1. github.com/pravegm/hush → **Settings** → **Pages** (left list, under "Code and automation").
2. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
3. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
4. Wait 1–2 minutes, then open these on your phone. All three must load:
   - Home: **https://pravegm.github.io/hush/**
   - Support: **https://pravegm.github.io/hush/support.html**
   - Privacy: **https://pravegm.github.io/hush/privacy.html**

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

Support is through **GitHub issues** (`github.com/pravegm/hush/issues`), the same choice you made for Squish, Brim and Swoop, so there's no email address to set up. Check **Settings → General → Features → Issues** is ticked.

**Tell Claude "Hush is public"**: the first build runs straight away.

---

## §1. Register Hush with Apple and create the app record (about 30 minutes, once)

### 1a. Trademark check for the name "Hush" (10 minutes, before anything else)

Nobody has checked yet whether someone owns "Hush" as a trademark for games. Do this before the name goes public. It's a quick search, not legal advice.

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

### 1f. Featuring nomination (by Tue 10 Nov; sooner is better)

This asks Apple's editors to consider featuring Hush on launch day. It needs only the app record from 1c, not a build. Do it once §2 is done (the robot needs the secrets):
- **The easy way:** github.com/pravegm/hush → **Actions** → **App Store Connect tool** (left list) → **Run workflow** → tick **Contact App Store Connect** → mode **push** → in "Optional step list" type `nomination` → **Run workflow**. About 10 minutes later it shows a green tick. Then check App Store Connect → the app → **Featuring** → **Nominations**: one nomination, status **Submitted**.
- **By hand, if that fails:** App Store Connect → the app → **Featuring** → **Nominations** → **Create Nomination**. Copy every field from `docs/appstore/featuring-nomination.md`. Press **Submit** (a saved draft doesn't count).

---

## §2. Connect GitHub to Apple (10 minutes, once)

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

---

## §3. Run TestFlight (when Claude says the game is ready)

**3a. Run a build.** github.com/pravegm/hush → **Actions** (tab along the top) → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → in "What to test" type anything (e.g. `first Duo test`) → leave "Only build…" unticked → **Run workflow**.
- About 20–30 minutes later the run shows a green tick. A red cross with "Missing repository secrets" means a name in 2b is misspelt; anything else, send Claude the link to the run.
- 10–30 minutes after the green tick, the build appears in App Store Connect → the app → **TestFlight**, first as "Processing". You won't be asked about encryption: that answer is already built in.

**3b. Install it (set up once).** App Store Connect → the app → **TestFlight** → **Internal Testing** → **+** → group name `Studio` → add yourself (your Apple Account email) → add the build. On the Duo, open Apple's **TestFlight** app (you have it from the other games) and tap **Install** next to Hush. Later builds appear there automatically.

---

## §4. Play it on your Duo: the 10-minute check

**Before you start:** sit at a table. Ringer **on**, volume about half. Have a clock or timer nearby. You'll stand the Duo on the table like a little laptop: one half lying flat on the table (the **floor** of the chest), the other half raised (the **lid**).

| Minute | Try this | Notice |
|---|---|---|
| 0–1 | Open Hush. The first time, it starts **First Chest** (the lesson). Its first card shows a diagram and says which half to lift | Was it obvious **which half** to lift? Did you have to **turn the Duo round** (swap which half is on the table)? Did that feel odd or fine? |
| 1–3 | Follow the lesson: open the lid slowly, drag the coin into the bag, freeze when it says so, ease the lid shut | Did each step make sense from its one sentence? Did "Slower…" appear when you went too fast? Anything you didn't understand? |
| 3–5 | Your first **Run**. Open each chest slowly, take what you can see, ease the lid shut to bank it | **The creak:** at what speed does it start? Does the sound **and the buzz in your fingers** feel like the phone's own hinge creaking? Too loud, too quiet, too buzzy? |
| 5–6 | **Blur test.** Start with the lid almost shut (about where banking happens), then lift it. Watch **both** halves the moment you start | Did one half go blurry for a moment? **Which half: the lid (raised) or the floor (on the table)?** For about how long? Did the loot, the noise meter and the warnings stay **sharp**? |
| 6–7 | **Fairness test.** Open one chest at what feels like a "normal, careful" speed, and another a bit quicker. Let the mimic wake once on purpose | Did it ever wake when you **thought you were being gentle**? When it bit, did you know **why** (the creak, the meter, the heartbeat)? Did "FREEZE" give you enough time to stop? Did freezing actually calm it? |
| 7–8 | **Bank and wide test.** Ease the lid shut to bank. Then on the next chest open the lid as wide as feels natural (never flat) | Did banking happen reliably when the lid was low, or did you have to close it further than felt comfortable? Did "That's wide enough" ever appear? Did you ever want to push it flat? |
| 8–9 | Close the Duo fully, look at the outer screen, then reopen it. Then open **Settings**: turn **Turn the chest round** off, play a few seconds, turn it back on. Flip the **silent switch on** and try **Sound**, **Haptics** and **Respect silent switch** | What does the outer screen show? Did it pause with "Lift the lid a little" and carry on when you opened? With "Turn the chest round" **off**, which half blurred, and was it worse? Is there sound on silent? Do the switches work? |
| 9–10 | Play the **Daily Dungeon**, then one more Run, however you like | Did you want "one more go" when the torch went out? |

**Comfort check (important):** at any point did your hand or wrist get tired? Did you ever have to move the lid further or faster than felt natural, or worry about the hinge? Did the Duo stay stable on the table while you opened and dragged?

**Send Claude this (copy, fill in, paste in chat):**
```
Hush build [number from TestFlight], iPhone Duo, iOS [version]
Which half the card told me to lift: [the one I'd naturally lift / I had to turn the Duo round]  Clear? [yes/no]
Scores 1-5:
  slow opening feels like sneaking [ ] / the creak feels like the phone's hinge [ ]
  creak sound [ ] / creak haptics [ ] (too weak / right / too strong: ...)
  the mimic is fair (wakes only when I deserve it) [ ] / FREEZE gives me time [ ]
  banking by easing shut feels good [ ] / comfort [ ] / want one more go [ ]
Blur: did half the screen blur? [yes/no]  Which half: [lid / floor]  How long: [ ] s
  Loot, meter and warnings stayed sharp: [yes/no]
  With "Turn the chest round" OFF, which half blurred: [lid / floor]
Speed where the creak starts: [very slow / normal / only when fast]
Times the mimic woke when I thought I was gentle: [ ]
Banking: worked every time? [yes/no]  Had to close further than comfortable? [yes/no]
Sound on silent: [yes/no]   "Respect silent switch" works: [yes/no]
Runs (gold banked, chests, bites): 1 [ ] 2 [ ] 3 [ ]
Did the screen ever dim or lock while playing? [yes/no]
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
A phone video of your hand and the Duo from the side while you play helps a lot: send it if you can. In TestFlight you can also take a screenshot in Hush and tap **Share Beta Feedback**.

Repeat the check on each new build Claude sends. The release build is the one where every score is 4 or 5, comfort is 5, and the floor half stays sharp.

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
- **Services → Game Center:** 2 leaderboards (Best Haul, Daily Dungeon) and 12 achievements, each with a picture.

**If the robot can't do something** (it says so in its output, and Claude will tell you), the by-hand version is: paste the code blocks from `docs/appstore/metadata.md` §1–5 into App Information and the 1.0 page (English (U.K.), then switch the language menu to English (U.S.) and paste the U.S. description); answer the age rating exactly as the table in §8; set the price and availability as in 5c; paste `review-notes.md`'s block into Notes; add the Game Center items from `achievements.md` (IDs can never be changed once saved, so type them exactly).

### 5d. Screenshots (Wed 25 Nov)

Claude tells you on Mon 23 Nov whether the robot has uploaded the screenshots or sends you a download link with the order (`docs/appstore/screenshots.md`). On the 1.0 page, **Previews and Screenshots**:
1. **6.9" Display:** P1–P6, in order.
2. **6.3"/6.1" Display** (whichever "iPhone with Dynamic Island" slot it asks for): P1–P6.
3. Open the device list. **If you see iPhone Duo**, add D1–D6 there and check them with Apple's preview. If there's no iPhone Duo entry, skip it (the Duo set comes with 1.0.1).

### 5e. Pick the build (Wed 25 Nov)

On the 1.0 page, **Build** → **+** → the build Claude names as the release build. In the **Game Center** section, check both leaderboards and all twelve achievements are listed (they only go live with this version).

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
