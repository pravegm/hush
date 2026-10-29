# Hush: reply to App Review (4.3 spam / 4.2.6), 29 Oct 2026

**How to use it:**
- Paste everything under "Reply" into the rejection thread in App Store Connect (App Review → the message → Reply).
- Do **not** resubmit the build. Apple asked for a reply instead of a resubmission when you believe the app complies.
- Every statement below is checked against the repo and TestFlight. Before sending, confirm the two things marked
  **[confirm]**.

---

## Reply

Hello, and thank you for the review. I believe Hush meets guidelines 4.3(a), 4.3(b) and 4.2.6. My answers to each
question are below.

**1. What the app does and the problem it solves**

Hush is a stealth game in which the speed of the iPhone Duo's hinge is the only thing that matters. You stand the
phone up like a treasure chest. The top half is the chest's lid, and inside a mimic (a monster disguised as a chest) is
asleep. You open the phone to open the lid. The faster the hinge moves, the more noise it makes, and if the noise
meter fills, the mimic wakes and bites. You drag the loot you can see into your bag, then close the phone to bank it
before your candle burns out. Each chest has a different mimic temperament (light sleeper, snorer and so on), and
every run is a push-your-luck decision: open a little wider to reach the gem at the back, or bank what you have.

The problem it solves is simple. iPhone Duo owners have a new physical control, the hinge, and almost nothing on the
App Store that turns it into a skill to master. In Hush the input is how slowly and steadily your hands can move the
hinge: a fine-motor skill that a touchscreen cannot measure. The game also plays fully on every other iPhone, with an
on-screen lever that has the same speed-equals-noise rule.

**2. Intended users**

- **Main audience:** iPhone Duo owners, the early adopters of a new form factor, who want a game that uses the fold
  for something only a foldable can do.
- **Secondary audience:** casual players on any iPhone who enjoy short, tense push-your-luck sessions. A run is about
  three minutes, which suits commutes and queues.
- **Who it suits:** it is rated 9+. There are no ads, no in-app purchases, no accounts and no data collection, so it
  suits families.
- **Accessibility:** a Forgiving mode for less steady hands. Every visual cue is also a sound and a haptic.

**3. The gap it fills**

Existing hinge apps for iPhone Duo use the hinge's angle as a position: accordion and bellows apps map the angle to
the bellows' opening, and hinge toys map it to a press. Hush is, to my knowledge, the only app that scores the hinge's
speed and steadiness, so the skill is restraint, not position. Games in the stealth and push-your-luck genres exist on
touchscreens, but none can measure how gently you physically open something. On the Duo that is the whole game: the
mimic reacts to your real hand movement.

Beyond the core mechanic, Hush is a complete game:
- a 24-relic Codex to collect;
- several mimic types;
- a Daily Dungeon that is the same for every player each day, with its own leaderboard;
- 12 Game Center achievements and 2 leaderboards;
- a dedicated outer-screen experience: with the phone shut, the cover display shows the intro and the Play button,
  and reports your banked gold between chests.

**4. Beta testing and feedback applied**

I tested every build on my own iPhone Duo through TestFlight: 11 builds between 27 and 29 October. Between device
tests, every build ran 452 automated unit tests and 16 automated hinge scenarios on the iPhone Duo simulator (slow
open, slam, close to bank, bite, flat open, landscape and others). Four examples of my beta feedback that changed the
production build:
- **Build 1:** opening the phone fully flat got the game stuck, because iOS rotated to landscape. The game now plays
  in any orientation, and a watchdog makes sure it never stalls.
- **Build 7:** with the phone open at 90°, the game still treated the chest as closed. I rebuilt the input so the
  phone's angle is literally the lid's angle: shut is shut, and even a few degrees open means the chest is opening.
- **Build 8:** after pressing Play with the phone already open, the game still asked me to open it. Now the first
  chest simply matches the phone as it is when you press Play.
- **Build 9:** as a first-time user I could not tell how to start. I added an intro with a Play button on the outer
  screen, so you press Play with the phone shut and then open the phone slowly to begin.

**5. Standalone product or part of a suite?**

Hush is a standalone product. My developer account publishes a small number of separate paid games, each built
around a different way of using the iPhone Duo's hinge. Each is a different genre with its own rules, art, sound,
progression and audience:
- **Squish:** a hydraulic-press toy. You close the phone slowly to crush an object and watch it deform.
- **Brim:** a pouring game. You lay the phone flat and lift one half to tip and pour.
- **Swoop:** a flying game. You hold the phone like a book, the halves are a bird's wings, and folding them makes the
  bird dive.
- **Snapjaw:** a reflex game. You hold the phone like a book and it becomes a flytrap. Snap it shut to catch flies and
  spare the bees.
- **Hush:** a stealth push-your-luck game. The phone stands like a chest, and opening speed is noise.

They share a platform feature, the hinge, in the way that several games share touch or tilt controls. They do not
share content, levels or gameplay.

**6. Could this be an in-app purchase inside another app?**

Technically any game can be put inside another app. I kept Hush separate because it would not be a natural part of
any of the others. A player who buys a pouring puzzle or a press toy is not looking for a stealth game, and Hush has
its own complete progression (Codex, Daily Dungeon, achievements and leaderboards) that would be buried as a mode
inside an unrelated app. Each game is priced and described on its own, so customers know exactly what they are buying.

**7. Shared code with my other apps**

There are no shared asset files. No image, level or text in Hush appears in any of my other apps, and its art is its
own. Hush has no recorded sound files: its sounds are generated in code by an audio engine adapted from my earlier
games (see below).

Some low-level code began as code from my earlier games and was then adapted. About a quarter of Hush's non-trivial
lines of code also appear in at least one of my other apps. The shared components are:
- **Hinge reader:** a small wrapper around Apple's hinge-angle API that reports the angle and whether it is moving.
- **Input smoothing filters:** they smooth the roughly 5° hinge readings into a steady angle and speed.
- **Audio synthesis engine:** generates the sound effects in real time.
- **Game Center wrapper:** sign-in, score submission and achievement reporting.
- **Seeded random numbers and the daily seed:** for the Daily mode.
- **Particle effects, the app icon renderer and an image utility.**

The gameplay, rules, scenes, balancing, interface and content are written specifically for Hush.

**8. Shared code with any third-party app**

No. Hush uses only Apple frameworks: SwiftUI, SpriteKit, AVFoundation and GameKit. There is no third-party SDK,
template, engine or content library.

**9. Was the app made for a client, or from a template or app generation service?**

No. Hush is my own game. I conceived and directed it, and I publish it under my own developer account. No client,
partner or third party provided its content, concept or branding. It was not made from a commercial template or an
app generation service. I developed it with an AI coding assistant (Anthropic's Claude), which I directed through
the design, the code and many rounds of device-test feedback. The original game design and all of its content are
specific to Hush.

Thank you for considering this. If anything above is unclear, or a screen recording of the hinge gameplay on an
iPhone Duo would help, I'm happy to provide one.

[Founder's name]

---

## Before you send: check these

- **[confirm] Question 5's list:** it names every app currently on your account or in review: Squish, Brim, Swoop,
  Snapjaw and Hush. Glint is not submitted, so it's left out. If anything else is on the account, add it, because
  Apple can see the whole account.
- **[confirm] Question 4:** the beta testing was you alone. That's stated truthfully. Don't add testers who didn't
  take part.
- **Question 9:** it says plainly that an AI coding assistant was used. Guideline 4.2.6 is about commercial
  templates and app-generation services submitting for clients, which this is not. Apple's guidelines (5.6.2, and
  the introduction on "trying to trick the review process") make accuracy matter more than anything else here, so I
  would not remove that sentence.
