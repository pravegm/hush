# Hush project log

*Times are UTC. Facts only; the reasoning lives in `design/` and `research/`.*

## Tue 27 Oct 2026: day 1

- **Brief:** a fourth iPhone Duo-first paid game (after Squish, Brim and Swoop), built unsupervised. £1.99, no ads,
  no in-app purchases, no data collected. It must use the hinge, be unique, and be "simple, fun, addictive,
  satisfying".
- **Concepts:**
  - A concept agent scored 14 ideas plus an accordion rhythm game.
  - The accordion was the founder-Claude's own first pick. It was **dropped**: the market agent found six
    hinge-as-bellows accordion apps already on the Duo (Fold Accordion, Foldissimo, Accorduon and others).
  - **Chosen: the mimic chest** (67/80, rank 1), where hinge **speed** is the skill. No Duo app found uses speed or
    stealth, and none uses a chest or mimic.
- **Name:** "Hush: Don't Wake the Mimic" (`research/02-names.md`).
- **Founder message mid-build:** "make sure we account for the fact that when the duo screen is folded, the left half
  gets blurred for a second or so."
  - **Answer:** the play canvas is drawn turned round (Brim build 8's method, confirmed on the founder's Duo), so the
    lid is the blurring half and the floor (loot, meters, warnings) is sharp.
  - Every tell is also a sound and a haptic.
  - There is a "Turn the chest round" setting.
- **Repo:** `pravegm/hush`, created **private**, because the guard blocks creating public repos. Actions need it
  public.

### 27 Oct, midday: round 1 build and the first internal review
| Time | What happened |
|---|---|
| ~10:31 | **Round 1 pushed.** It compiled first time on CI. 144 of 145 tests passed; the one failure was a UTC-zone-name test, fixed. CI 40490298403 green. The Swift balance matches the Node sim exactly. |
| ~10:41 | **Duo sim run 40490356351:** PORTRAIT, SLOW-OPEN, STILL, SLAM and CLOSE-PAUSE all PASS. The floor draws turned round onto the sharp half. |
| — | **Founder:** "do extensive internal testing with all your agents and get this app to a level where this is at a standard of launch" before setting up TestFlight. |
| — | **R1 review:** Apple juror 6.0, UX 6.5, Duo specialist 6.0. Three fresh testers: understood 6 / 7 / 8, premium 5–7, would pay 5–6. The game-feel designer found there was no real gamble yet and proposed tuning plus four features. QA-1: 1 P0 (the placeholder icon), 3 P1s. |
| — | **R2 dispatched** (`design/ROUND-2.md`): art unification, HUD labels, no bars on phones, turning round inside the scene, the two Duo blockers (Release orientation, bite on reopen), the R2 balance, Hush Chain, golden mimic, relic glimmer, bag jingle, and every QA-1 item. |

### 27 Oct, afternoon: round 2 and its review
| Time | What happened |
|---|---|
| ~12:20 | **R2 built.** It took three CI fix-ups: an unqualified static in Contracts, a mutating call inside `#expect`, a test arithmetic slip. Then 220 tests passed. A real-finger XCUITest drag through the turned scene **passed**. |
| ~12:45 | **Duo run 40506125012: 1 PASS, 6 FAIL.** A regression: a portrait lock set while landscape letterboxed the app to 469 × 669. **Fix:** lock only once the interface is portrait. |
| ~13:35 | **Duo run 40510297922: 6 PASS.** REOPEN-NO-BITE failed only on a log race in the check. The app paused at 62.7°, resumed at 117.9° and didn't bite. The check is fixed. |
| — | **R2 review:** juror 7.5, UX 8.0, Duo 7.0. QA-2: no P0, 2 P1s. Fresh testers 4–6: would pay 7 / 7 / 7, premium 8 / 6.5 / 8. |
| — | **R3 dispatched** (`design/ROUND-3.md`). The cover fallback is deleted; noise is frozen in pause; one verb, "bank"; copy follows the layout; in-world plates; the icon redrawn; the bank black-out, the sleeping mouth, the tongue, collisions, edges, the relic card, the CREAK accent; Results restructured; the store pipeline; the docs made truthful. |
