# Hush: morning handover (29 Oct)

## Build 11: the one to submit (round 15)
You said about build 9: "why cant i just have an intro screen on the outer screen to begin with with the play
button? so that the duo is closed, i press play, and then i open the chest… it does not make sense that my duo is
open, i click play and the game thinks its closed… as a first time user i will have zero clue". Done, exactly so.

**How it plays now:**
1. **Phone shut:** the outer screen is the intro. It shows the mimic, "Steal the mimic's gold while it sleeps", the
   three rules and a **Play** button.
2. **Press Play, then open the phone slowly.** The chest opens with the phone, from the first degree.
3. **Drag the loot into your bag.**
4. **Close the phone to bank it.** Closing is always safe with loot in the bag, at any speed. The outer screen says
   "Banked +N gold!" and "Open the phone slowly for the next chest", with **End run** if you're done.
5. **Phone already open?** Tap Play on the inner screen and the chest is open at once. It never asks you to close it
   first.
6. **The three rules** are on the outer intro and on Home for your first runs:
   - The chest opens with the phone. Move it slowly.
   - Drag the loot into your bag.
   - Close the phone to bank it before your candle runs out.

**Fixed overnight, from four independent reviews** (two code walkthroughs of your exact steps, a three-person
first-time player panel and an App Review juror):
- **New buyers:** a brand-new install launched shut now shows the intro, not Home, on the outer screen.
- **Open and still phone:** the game asks iOS for the angle straight away, so no "Move the phone a little" wait.
- **Bite moment:** closing the phone during it deals the next chest. It never asks to close an already-closed phone.
- **Snap shut:** a close with loot never bites. Closing banks, just as you said.
- **Ending on the outer screen:** End run there, or the candle running out, shows "Run over · N gold".
- **Settings › About** links to the privacy and support pages, which Apple asks for.
- **Store text, review notes and support page** are rewritten for this version. The screenshots are re-shot from it.

**Tested:** all unit tests pass. The iPhone Duo simulator passed **all 16 hinge checks** on build 11: slow open, slam,
close to bank, bite then close for the next chest, the outer screen, flat open, landscape and the watchdog.

**Please try on your Duo (2 minutes):**
1. **Phone shut:** open the app and press Play on the outer screen. Open the phone slowly, drag a coin into the bag,
   then close the phone. You should see "Banked +N gold!".
2. **Open again for the next chest.** Then open it fast once and the mimic should bite. Close the phone, then open it
   for the next chest.
3. **Home with the phone open:** tap Play. The chest should be open straight away.

If anything is wrong: Settings › About, hold Version for 2 s, tap Copy log, and paste it to me.

**To submit:** see "Submission steps" below. Everything is prepared except what needs your Apple login.

## Submission steps (about 20 minutes, all need your Apple login)
**Ready and checked:** build 11 is VALID on TestFlight. The store set is store run 40809079356, and every image was
checked for size, format (RGB PNG, no alpha) and by eye:

| Where in App Store Connect | Files | Size |
|---|---|---|
| iPhone 6.9" | P01–P10 (`store-69`) | 1320×2868 |
| iPhone 6.3" | P01–P10 (`store-61`) | 1206×2622 |
| iPhone Duo (optional until April 2027; earns the "optimized for iPhone Duo" badge) | D01–D10 (`store-duo`) | 2007×2853 |
| Product page header (iOS 27) | header-3840x1646.png (`store-placements`) | 3840×1646 |
| Search results image | search-3840x2560.png (`store-placements`) | 3840×2560 |

All text is within Apple's limits. The rules behind each item are in docs/appstore/REQUIREMENTS-CHECK.md.

**1. In App Store Connect (Hush › App Store tab), answer what only you can:**
- **App Privacy:** Data Not Collected.
- **Age rating:**
  - Cartoon or Fantasy Violence: Infrequent.
  - Horror/Fear Themes: Infrequent.
  - Contests: Infrequent.
  - Everything else: None or No.
  - The result should be **9+**.
- **Content rights:** No third-party content.
- **Category:** Games, then Casual and Adventure.
- **Pricing:**
  - £1.99 (Tier 2).
  - All territories except China mainland and Vietnam.
  - Untick "Mac" and "Apple Vision Pro" availability.
  - Family Sharing on.
- **Paid Apps agreement, banking and tax:** check they are still Active (Business tab).
- **EU Digital Services Act:** trader status, the same answer as Squish.
- **Version release:** Manually release this version.
- **Export compliance:** nothing to answer, because the build already declares it uses no non-exempt encryption.

**2. Fill in the rest with the tool:**
1. On GitHub, go to pravegm/hush › Actions › "App Store Connect" › Run workflow.
2. Tick `asc`, leave `mode` = plan, and run it. It is read-only. Check the summary lists no errors.
3. Run it again with:
   - `mode` = push;
   - `build` = 11;
   - `placements_run` = 40809079356.

   This fills in:
   - the name, subtitle, description, keywords, promo text and review notes;
   - the URLs: support https://pravegm.github.io/hush/support.html and privacy …/privacy.html;
   - the copyright line and App Review contact, copied from Squish;
   - Game Center leaderboards and achievements;
   - attaches build 11;
   - uploads the 6.9" and 6.3" screenshots, plus the header and search art.
4. **iPhone Duo screenshots:** if the run says the API has no Duo type yet, upload them by hand:
   1. Download the `store-duo` artifact from store run 40809079356 (Actions › App Store screenshots).
   2. Open the iPhone Duo tab under Previews and Screenshots.
   3. Drag in D01–D10, in order.
5. **By hand instead of the tool:** the same artifacts work by drag and drop:
   - `store-69` into 6.9";
   - `store-61` into 6.3";
   - `store-placements` into Header and Search.

**3. Check, then submit:**
- Look at the product page preview on iPhone and iPhone Duo.
- Make sure Game Center is ticked on the 1.0 version with the leaderboards and achievements attached.
- Press **Add for Review**, then **Submit**.

**Optional:** the support page's contact is "Open an issue on GitHub", the same as Brim's, which went through review.
If you'd rather give an email address, tell me which one and I'll add it to the support page.

## Build 9: simple (round 14, your build 8 test)
You said: "right when i start it asks me to open the phone, i open the phone, click play, now in that open state it
still asks me to open the phone… why do i need to open the phone to start playing? playing starts with the chest
closed… the game also feels super complicated". Agreed on all of it.

**The whole game, in four lines:**
1. **Closed phone = closed chest.** Every chest starts closed.
2. **Open the phone slowly.** The chest opens with it. Too fast and the mimic wakes.
3. **Drag the loot into your bag**, slowly.
4. **Close the phone to bank it.** The next chest waits, closed. Repeat until the candle runs out.

**What changed:**
- **One gesture to play:** with the phone shut, the outer screen says "Open slowly to play". Open it and you're
  playing, no Play tap. If you tap Play with the phone open, it says "Close the phone to start". Close it, then open
  it slowly. The candle doesn't burn until the chest opens.
- **Nothing asks you to "stand it like a laptop" any more:** the pose tip, the lesson's pose step and the "Lift this
  half" marker are gone. Flat, laptop, any angle plays.
- **No forced lesson:** first launch goes straight to Home. The first chest's card gives the three rules.
- **Closing the phone always ends the chest:** with loot it banks, and with an empty bag the next chest comes. No
  "Hold still…", no "That's wide enough", no "carry on" state.
- **Fewer things at once:** the Hush Chain, jingle, golden and relic tips wait until your third run. A fast drag now
  says "Slower…", so a bite is never a mystery.
- **Every instruction says "phone":** "Close the phone to bank", "Open the phone slowly".

**Please try:** with the phone shut, open it slowly and play one chest. Close it to bank, then open it again. That
should be the whole game.

## Build 8: the phone IS the chest (round 13, your build 7 test)
You said: "the iphone lid is at 90 degrees open and it says that the chest is closed… even 1 degree open lid means
chest is opening". You were right, and build 7 hadn't fixed it.

**Why build 7 was still wrong:** from round 1 the game treated the Duo standing like a laptop (about 90°) as a *shut*
chest. Only opening past 100° counted as open. Round 12 removed the confusing prompts but kept that dead zone.

**Now:**
- **The chest follows the phone, degree for degree.** Fully shut is a closed chest. The moment you open it, even a
  crack, the chest opens with it, and at 90° it is clearly open. Wider means deeper loot shows (relics need it wide).
- **Closed means closed.** Close the phone (all the way, or near enough, ≤ 15°) to bank. If the outer screen comes
  on first, it still banks.
- **What you see while it's closed:** the outer screen and the pause card both say "Open the lid slowly", with "The
  chest opens with the lid, from the very first degree." Home says "Open the lid slowly. The chest opens with it."
- **The noise is the same game:** the chest moves the same amount per second for the same noise, and the phone's
  longer travel is taken into account.
- **The first lesson** no longer asks you to close the lid first. Stand it like a laptop and the chest is open.
- **Other iPhones (the lever):** lever down is a closed chest (it settles shut when you let go near the bottom), a
  second finger can no longer make the lid jump, and the phone's copy no longer mentions a lid or hinge.

**Please try:** start with the phone shut, open it slowly to about 30° and then 90°. The chest should be open the
whole way. Take a coin, close the phone fully (bank), then open it again for the next chest.

## Build 7: the lid IS the chest (round 12, your build 6 test)
You said: "the chest closed means lid closed, chest open means lid open". Now it does, everywhere.

- **No "open the lid" gate.** If the lid is already open when you tap Play, the first chest is already open: start
  looting straight away. If the lid is shut, you see the chest closed, and lifting the lid opens it.
- **Moving chest to chest.** You close the lid to bank, so the next chest arrives closed under a closed lid. Open the
  lid and it opens. It never asks you to open a lid that's already open.
- **After a bite** the robbed chest stays open and empty, with "Close the lid for the next chest". The mimic grumbles
  instead of snoring. Close the lid and the next chest is waiting, closed.
- **Closing banks, however you close.** Close it slowly, quickly, or all the way shut so the outer screen comes on:
  the loot in the bag banks with a ka-ching as the lid comes down. Before, closing all the way could switch to the
  outer screen before the bank registered.
- **A closed chest is drawn closed.** With the lid shut you see the chest's lid from above. It lifts as you open.
- Copy now says "Close the lid to bank" (you close it, so the next chest arrives closed).
- **Sound and feel:** a richer creak, a louder coin and ka-ching, a heavier CHOMP, and stronger layered vibration.
- 428 unit tests green.

**Please try:** open the lid, tap Play. Loot, close the lid to bank, open it again for the next chest. Then get bitten
once and close the lid. At no point should it ask you to open a lid that is already open.

## TL;DR (build 6)
- **Install TestFlight 1.0 (6)**, the release candidate.
- **The stuck-when-opened-flat bug is fixed at the root.** Hush now plays whichever way iOS turns the screen.
- 11 rounds, 396 unit tests green.
- Latest reviews:
  - Apple juror **9.2, "yes"**.
  - UX **8.8**, launch-ready on clarity.
  - QA: ship.
  - A first-time tester: **8 / 8 / 8 / 8**, including "would pay £1.99".
- **Round 11**, on top of the overnight work:
  - Callouts never overlap.
  - Lid sensitivity is Forgiving / Normal / **Strict**, with a one-time "Make it forgiving" offer if it keeps
    waking.
  - Skip still teaches the stakes.
  - VoiceOver covers Carry on and pause.
  - New badge art.
- The **iPhone Duo simulator passes all 13 hinge checks**, including the new **flat-open** (to 180° and back while
  playing), **landscape play** and **watchdog** checks.

## What you hit, and why
You opened the Duo fully flat and it got stuck, with no way to carry on.

- **Cause:** held open flat, iOS turns the screen to landscape. When you stand the Duo back up like a laptop, iOS
  doesn't turn it back, because a Duo lying in tabletop never auto-rotates. Hush only played in portrait, so it sat
  behind a "Stand it up" card whose buttons depended on iOS agreeing to rotate. On hardware, it didn't.
- **Fix (round 6, "any way up"):** Hush no longer cares which way iOS turned the screen.
  - It knows which physical half blurs (your "left half" in book pose) and always draws the lid there and the loot
    on the sharp half, in any orientation.
  - The blocking card is gone.
  - Fully flat just says "That's wide enough" and play carries on.
  - The pause card shows **Carry on** after 3 s and resumes by itself after 6 s if the lid is clearly open.
- **Round 8 ("can it ever get stuck?" audit):**
  - Hush re-reads the orientation whenever the screen changes.
  - The outer-screen card offers "Already open? Carry on / Home".
  - The hinge reader re-subscribes after a trip to the outer screen.
  - Settings no longer flips under your finger.

## The other issues you probably hit (round 7, "real hands")
Every earlier test moved the hinge smoothly and slowly. A real hand is faster and jerky, and a real hinge sticks then
slips. So:
- **Gentler noise rules.**
  - Quiet up to 14 °/s when opening and 28 °/s when closing.
  - The jump as the hinge breaks free no longer counts.
  - A careful close no longer wakes it; a real slam still does.
- **New copy:** "Ease the lid down to bank" (never "shut"). You never need to fold it shut.
- **The pause coin** on the Duo is a short press-and-hold mid-chest, so the hand holding the lid can't tap it by
  accident.
- **The lesson** accepts a looser first pose and offers **Skip** after 20 s.
- **Settings › Lid sensitivity** (Forgiving / Normal / Careful; the scored Daily always plays Normal) and
  **Settings › Vibration** (Off / Normal / Strong).
- **Faint haptic ticks** while opening slowly, so careful play still feels like a hinge.
- **Round 10:**
  - The pause coin always sits in its brass seat.
  - Settings scrolls and uses both halves on the Duo.
  - Results shows a proper mimic.

## Please try (10 minutes)
1. Open it **fully flat**, wiggle it around, then stand it back up. It should keep playing, drawn the right way up.
2. **Release gate: with the screen still sideways after step 1** (or holding the Duo like a book), drag a coin into
   the bag, press and hold the pause coin then tap Resume, scroll Settings and tap Done, and lower the lid until the
   pause card shows, wait 3 s, tap **Carry on**. Then Copy log (step 5): a `canvas` line must end `k=1` or `k=3`.
   This is the one thing I couldn't automate: the Duo simulator can't inject touches, though every position checks
   out by hand and in tests. Full script: runbook §4, step 10.
3. Play 3 runs. Does careful opening feel fair? Does the creak feel like the hinge?
4. Close it fully, then reopen. It should carry on with no bite.
5. If anything gets stuck or feels wrong:
   - go to **Settings › About**, press and hold **Version** for 2 s;
   - tap **Copy log**, and paste it to me.

   The log shows exactly what the app saw: orientation, angles, pauses and the raw hinge trace.

## Known, in my hands
- In CI, the landscape drag and Carry-on UI tests never actually run: the Duo simulator skips them (its touch
  injection never reaches the app) and the phone job doesn't run the landscape tests. So no automated test has passed
  a touch on a sideways screen (QA-6 P1-3). Your step 2 is the real check, and a release gate.
- App Store steps after your test are unchanged (runbook §5).
- **The docs did NOT match build 4 until 28 Oct** (QA-6 P1-1, P1-2, P2-6, P2-7). The review notes still described the
  R3 game (a book card, "Play anyway", resume at 95°, speed to 168°) and the privacy policy said the hinge reading
  "isn't stored", though the on-device diagnostics log keeps the last 80 events with their angles. Both are now
  rewritten from the code, as are the description ("ease the lid down to bank", Vibration and Lid sensitivity), the
  site, support page, press kit, social plan, nomination and runbook §4. Before Submit, tick the check tables in
  `docs/appstore/review-notes.md` and `metadata.md` on the release candidate.
- The D3 Duo screenshot caption is fixed in `ci/duo-store-scenarios.txt` ("Ease it down to *bank*."). The store set
  is re-shot after round 11.
