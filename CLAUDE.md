# CLAUDE.md: working on Hush

**Hush: Don't Wake the Mimic** is a paid iPhone game (£1.99, no ads, no IAP, no data collected), built **iPhone Duo
first**. The Duo is Apple's foldable (iOS 27.1).
- Stand the Duo like a little laptop: it's a treasure chest, and the raised half is the lid.
- Open it slowly to light the loot. Drag the loot into your bag gently, then ease the lid shut to keep it.
- Too fast, and the hinge creaks, the mimic wakes and it bites.

The founder (GitHub `pravegm`) is the product owner and is away while this is built. Claude runs the studio as founder,
designer and developer, with parallel subagents per role and a critic loop.

**Sister projects:** Squish (`C:\Users\59527\Squish`), Brim (`C:\Users\59527\Fold`) and Swoop (`C:\Users\59527\Wing`).
Never modify them. Reuse their lessons and code by copying.

## The bar
1. **Duo-first.** Judge every change in tabletop pose first: the floor half flat, the lid raised at 100–165°. The
   lid slider is the fallback for phones without a hinge.
2. **Gentleness is the game.** Lid speed is the input that matters. The creak (sound and haptics) must feel like the
   phone's own hinge.
3. **The blurred half (founder, 27 Oct).**
   - When a fold starts, iOS blurs one fixed physical half for about 1–2 s (the left half in book pose; in iOS
     portrait it is the bottom of a tabletop).
   - So the canvas is drawn **turned round** by default: the lid is the blurring half, and the floor is sharp.
   - Nothing time-critical lives only on the lid.
4. **Gentle on the hinge.** Never ask for flat, a full close or a fast move.
5. **Truthful store frames.** Nothing appears on a frame that the app doesn't do.

## Working rules
- Push straight to `main` (the founder's standing rule; solo project). No PRs.
- **Repo:** https://github.com/pravegm/hush.
  - It was created **private**, because the permission guard blocks creating public repos.
  - Actions on private repos are blocked by billing on this account. Making it public is the founder's one click
    (Settings → General → Danger Zone → Change visibility).
- **No Mac on the Claude side. CI is the compiler.** A Swift change is unverified until a GitHub Actions run passes.
- On this Windows host Bash ignores `cd`. Use absolute paths and `git -C`. There is no Python; use Node.

## Build
`brew install xcodegen && xcodegen generate && open Hush.xcodeproj`
- Xcode 27.1 with the iOS 27.1 SDK. Deployment target iOS 18.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Swift 5 mode.
- The `.xcodeproj` and `Info.plist` are generated, not committed.

## Docs (read in this order)
1. `design/GAME-DESIGN.md`: the game.
2. `design/ARCHITECTURE.md` and `Hush/Shared/Contracts.swift`: modules, owners, APIs.
3. `design/ROUND-N.md` (briefs), `design/REVIEW-N*.md` (critics), `design/notes/` (engineer hand-offs),
   `docs/PROJECT-LOG.md` (what happened when).
4. `research/`: the market, concept and name checks.

## Hinge facts that bite (from the sister projects' real-Duo logs)
- Use the **angle**, never `status == .closed` (it turns on at about 85° on hardware).
- Samples arrive at 25–30 Hz while moving and not at all while still. Speed must decay when samples stop.
- Re-enable `onHingeChange` on each activation to get a fresh reading.
- Full-screen apps are refused upside down, and a Duo lying flat never auto-rotates. So turning round is done by
  drawing, not by iOS.

## Swift Testing gotchas (found on CI)
- `#expect(x.mutatingMethod())` doesn't compile, because the macro captures `x` immutably. Call it first:
  `let r = x.mutatingMethod(); #expect(r)`.
- Compare `CGFloat` with a typed constant and a tolerance, never with literal arithmetic.
