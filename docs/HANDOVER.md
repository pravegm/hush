# Hush: morning handover (28 Oct)

## TL;DR
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
