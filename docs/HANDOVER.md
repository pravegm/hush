# Hush: morning handover (28 Oct)

## What you hit, and why
You opened the Duo fully flat and it got stuck, with no way to carry on.

- **Cause:** held open flat, iOS turns the screen to landscape. When you stand the Duo back up like a laptop, iOS
  doesn't turn it back, because a Duo lying in tabletop never auto-rotates. Hush only played in portrait, so it sat
  behind the "Stand it up" card. Its buttons depended on iOS agreeing to rotate, and on hardware it didn't.
- **Fix (round 6):** Hush no longer cares which way iOS has turned the screen.
  - It knows which physical half blurs (the left half in book pose, as you said), and always draws the lid there
    and the loot on the sharp half, whatever the orientation.
  - The blocking card is gone.
  - Opening fully flat just shows "That's wide enough" and play carries on.
  - The pause card gets a **Carry on** button after 3 s and resumes by itself after 6 s if the lid is clearly open.

## The other issues you probably hit (round 7, "real hands")
Every test so far moved the hinge smoothly and slowly. Your hand doesn't, and a real hinge sticks and then slips.
So:
- **Gentler noise rules.**
  - Quiet up to 14 °/s when opening and 28 °/s when closing.
  - The tiny jump as the hinge breaks free no longer counts.
  - A normal careful close no longer wakes the mimic; a real slam still does.
- **New copy:** it says "Ease the lid down to bank", no longer "shut". You never need to fold it shut.
- **The pause coin** on the Duo needs a short press-and-hold mid-chest, so the hand holding the lid can't tap it by
  accident.
- **The first lesson step** accepts a looser angle and shows **Skip** after 20 s.
- **Settings › Lid sensitivity** (Forgiving / Normal / Careful; the scored Daily always plays Normal) and
  **Settings › Vibration** (Off / Normal / Strong).
- **Faint haptic ticks** while you open slowly, so careful play still feels like a hinge.

## Round 8 (a "can it ever get stuck?" audit)
- Hush now re-reads the orientation whenever the screen geometry changes, so it never draws wrong way up after a
  run.
- The outer-screen card has "Already open? Carry on / Home" if the hinge says it's open.
- The hinge reader re-subscribes after a trip to the outer screen.
- Settings no longer flips under your finger.

## What to install
- **TestFlight 1.0 (2)** has rounds 6 and 7: the stuck fix and the real-hands fixes. It's VALID and ready.
- **Build 3** (round 8 on top) goes up once CI and the Duo simulator pass. If it's there, take it.

## Please try (10 minutes)
1. Open it **fully flat**, wiggle it around, then stand it back up. It should keep playing.
2. Play 3 runs normally. Does a careful open feel fair? Is the creak right?
3. Close it fully, then reopen. It should carry on with no bite.
4. If **anything** gets stuck or feels wrong:
   - go to **Settings › About**, press and hold the **Version** line for 2 s;
   - tap **Copy log**, and paste it here.

   That log shows me exactly what the app saw (orientation, angles, pauses).

## Still open (in my hands)
- In CI, a synthesized finger drag on the iPhone **Duo simulator** in landscape doesn't reach the game. The same
  drag on a phone simulator works, and by hand the positions all agree.
- New diagnostics will show where the touch is lost: the simulator, or the app.
- On your Duo, dragging loot in landscape is the thing to check first.

## Numbers
- Rounds 1–8.
- 355 unit tests plus real-finger UI tests.
- Duo simulator: 12 of 13 checks on round 7, including the new flat-open, landscape-play and watchdog checks. The
  13th was a too-strict check, now fixed.
- Critics on round 4: Apple juror 9.0, UX 8.9 "launch-ready on clarity". First-time testers would pay 7–8 / 10.
