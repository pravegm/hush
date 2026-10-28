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

### 27 Oct, late afternoon: round 3 and its review
| Time | What happened |
|---|---|
| ~15:20 | **R3 built.** One CI fix (a main-actor helper called from a texture closure). 252 tests pass; the turned-drag XCUITest passes. The icon was redrawn in the game's style and committed as RGB. |
| ~15:40 | Store pipeline run 40533069481: the 6.9", 6.3" and Duo sets rendered (P1–P6, D1–D6). |
| — | **R3 review:** juror **8.5** ("fix P0 plus P1s → 9 and yes"), UX **8.8** ("launch-ready on clarity: yes"). QA-3: no P0, 1 P1. Fresh testers 7 and 8: understood 8 / 8, premium 7 / 6.5, would pay 7 / 7. |
| — | **R4 dispatched** (`design/ROUND-4.md`): a polish-only round. Plate text padding, the chain medal, the pause socket, the bank beat dimmed, the gum curve, the stage-labelled meter, one golden number, the phone extension plaque, seams, icon safe area, the Play-anyway hinge hold, VoiceOver throttling, Dynamic Type wraps, the pose screen redraw, Diagnostics for the device test, re-shot frames. |

### 27 Oct, evening: the founder sets up TestFlight
- The founder created the App Store Connect record (**Apple ID 6827663529**, link https://apps.apple.com/app/id6827663529, live
  from launch day), added the four ASC secrets and turned on GitHub Pages (https://pravegm.github.io/hush/ answers 200).
- **TestFlight 1.0 (1) uploaded** (run 40551080405, R4 commit; archive unsigned + ad-hoc entitlements, App Store signature by the cloud-managed certificate). R4 CI 40546513602 green: 278 tests + the turned-drag XCUITest.

### 27–28 Oct, night: the founder's real-Duo test of TF 1.0 (1), then rounds 6–8 unsupervised
- **Founder (evening, going to sleep):** "lots of issues i saw when i tested. when i open the whole phone it gets
  stuck and there is no way for me to continue playing. please fix all issues", plus 8 hours of unsupervised work.
- **Diagnosis:** opened flat and held, iOS rotates to landscape. Back in tabletop a Duo never rotates back, and play
  was gated on portrait behind the blocking book card. A dead end.
- **R6 "any way up":** the game draws itself with quarter turns k, from the physical blurring half, in ANY interface
  orientation.
  - There is no blocking card.
  - The closing card has "Carry on" after 3 s and a watchdog after 6 s.
  - Flat (172–180°) keeps playing.
  - There is an on-device event log with Copy.
  - CI: 313 tests green; the landscape drag XCUITest passed.
- **R7 "real hands"** (`design/DEVICE-RISKS-1.md`, which predicts the founder's other issues from Squish, Brim and
  Swoop device history):
  - quiet 14 °/s, closing quiet 28 °/s, a 0.08 s loud onset;
  - estimator breakaway, deadband and snap rules; resume hysteresis 92/88;
  - fresh-chest resume; press-and-hold pause on the Duo;
  - a lenient lesson; Lid sensitivity and Vibration settings; the raw hinge trace in Diagnostics.
  - CI: 342 tests green.
- **Duo sim run 40612801283 (R7): 12 / 13 PASS**, including the new FLAT-OPEN, LANDSCAPE-PLAY and WATCHDOG. The one
  FAIL was the check wrongly requiring a portrait inner canvas; now fixed.
- **TestFlight 1.0 (2) uploaded** (run 40614564978): R6 + R7.
- **QA-5 never-stuck audit:** no P0; 4 P1s (wrong way up after a run, a cover card on an open Duo, a silent hinge
  after a cover trip, the landscape UI test racing and skipping). **R8** is fixing them.
- **Duo-sim drag investigation (R9 diagnostics):**
  - `debug.state` showed `touches=0/0/0 raw=0 win=0`: no synthesized XCUITest touch reached ANY app window on the
    two-display Duo simulator, in any orientation. XCUITest reports the app frame as 669 × 951 while the window is
    951 × 669.
  - Verdict: a simulator touch-injection limit, not the app. The phone-sim drag passes; the overlay/scene mapping
    for every k is unit-tested and hand-checked.
  - The Duo UI tests now skip with that evidence when `win=0`.
  - A real-finger drag at a quarter turn on hardware is in the founder's test list.
- **TestFlight 1.0 (3)** (R8) is VALID.
- **TestFlight 1.0 (3)** (R8, VALID); the R9 diagnostics followed.
- **R10 polish** (`design/VISUAL-REGRESSION-R9.md`): the pause coin/seat share one canvas centre for every k; Settings
  and other pages scroll and use both Duo halves; the Results mimic ≥ 90 pt; the empty seat fades; the Hushed and
  chain frames use the perfect pilot. CI 40643737595: **368 tests green**.
- **Duo sim run 40641939161: 13 / 13 PASS** (FLAT-OPEN, LANDSCAPE-PLAY, WATCHDOG, both cover checks, slam, creak,
  pauses).
- **TestFlight 1.0 (4)** uploaded (run 40647337828). `docs/HANDOVER.md` is the founder's morning summary.
