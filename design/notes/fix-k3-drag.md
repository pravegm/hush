# Fix: the landscape (k = 3) drag on the Duo bags nothing

The failure (Duo CI runs duo6 and duo7, `uitest-unsigned.log`):

> Landscape turned drag from the drawn item id=0 kind=gem.amethyst to the drawn pouch bagged nothing: hud.bag stayed
> at 0 (was 0); device=4 window=(951.0, 669.0) canvas=k=3 w=951 h=669 fold=1

The drag went from (692.0, 217.3) to (895.0, 334.5). Both runs gave the same numbers, so the failure is deterministic.
The same k = 3 test passed on the phone simulator in ci11 and ci12, at (566.8, 130.7) → (688.8, 201.0) in an 874 × 402
window.

## What the code does at k = 3 in a 951 × 669 window

**(a) Is the run taking touches?** For this test, yes. With `lid=0.9`, `chooseInput()` returns `.fixed` before it
looks at the hinge: `demo?.lid` is checked before `hinge.hasHinge`. Each `hingeSample` then calls `refreshInput()`,
which keeps `.fixed`.

The holds you might suspect all need `input == .hinge`, so none of them can happen in this test:
- the first-hinge hold;
- `switchHolds` (`HUSH-T input switch hold fixed->hinge`);
- the hand-over hold;
- the return from the cover display;
- `checkClosing`.

The `fixed->hinge` lines in `duo7/.../logs/*.txt` all come from duo.sh runs without `lid=`. The pose is `.play`,
because the window's long side is 951, which is at least `coverMaxSide`. Demo runs never open the menu or the Game
Center sheet.

**This covers the CI test only.** On the founder's real Duo, with hinge input, touches ARE dropped while the
first-report hold or a closing pause is up. `floorTouchBegan` is ignored then, and only ends get through.

**(b) Do the SwiftUI frames sit where the scene draws?** Yes. CanvasFit in the drawn 669 × 951 frame has scale
max(669/670, 951/952) = 0.99895. RootView's +270° `rotationEffect` turns 90° counter-clockwise on screen. This puts the
pouch's canvas centre (335, 56) at (895.06, 334.5) and the floor point (452, 197) at (692.3, 217.6). These are exactly
the frames the test read.

The scene works it out independently and gets the same answer. It is 952 × 670 with aspect-fill, the same 0.99895
scale. Its world zRotation is −3π/2 and its position is (952, 0), so it draws the pouch at scene (896, 335), which is
view (895, 334.6).

The screenshot `duo-h11-landscape-play-160.png` (2853 × 2007, 3×) confirms it: the pouch is drawn at about (894, 333)
pt and an amethyst at about (694, 214) pt. The extension height is 0 at 952 tall, and the scale mode rule matches
CanvasFit's (min in a landscape drawn frame, else max).

**(c) Does a touch there reach the bag?** Yes. `touch.location(in: world)` inverts the same transform, giving canvas
(335, 56) and floor (335, 400). 400 is at least `FloorSpace.bagMinY` (346), so `touchEnded` would bag. SceneTests R6
already cover this for every k at 951 × 669.

## Root cause, as far as code and artefacts can show

There is no App-side defect on this path. Geometry, input and pause state are all correct for this launch, and the
drawn positions match the accessibility frames to within 3 pt. So the touch is being lost somewhere between XCTest's
synthesised event and the SKView, on the Duo simulator only. Either:
- no touch reached the scene, for example because the event was synthesised for the other display or in another
  coordinate space; or
- it arrived at different coordinates.

**The Duo has never run a passing synthesised drag in CI.** duo.yml only runs the landscape test, so the evidence does
not single out k = 3 at all.

I did not invent an App change to hide this. Instead:

1. **`debug.state`**, in demo runs only. It is a pure accessibility element (RootView, `DebugStateElement`) with its
   own `DebugStateProbe` object, so it never re-renders RootView or the SpriteView during a drag. Its value is
   `phase= paused= input= k= lastTouch=floor(x,y)|none hit=<id|none|ignored|missed> ended=<inBag|dropped|ignored|->
   touches=b/m/e route= frozen= scene=WxH view=WxH mode=fill|fit` (`AppRules.debugStateValue`, `DebugTouchTrace`).
   Every floor touch also logs `HUSH-T touch floor=x,y hit= ended= paused= input=`. How to read it:
   - `touches=0/0/0`: no floor touch reached the App. That is synthesis on the Duo, or a press on the lid half.
   - `hit=ignored`: the touch arrived while the App was paused or not taking input.
   - `hit=missed`: the press was not on the item, so the mapping is off.
   - `ended=dropped`: the release was not in the bag, so the mapping is off.
2. **The UI test** puts `debug.state` (before and after) and `app.frame` in its failure message and attachments. Its
   point maths now subtracts the app frame's origin: element frames are in screen coordinates and the offset is applied
   from that origin. This changes nothing while the origin is (0, 0), as on a phone.
3. **One scale-mode rule**: `AppRules.sceneScaleMode(drawn:)` is used by `updateCanvas` and by the tests.
4. **Unit tests** (AppTests `R9Tests`):
   - CanvasFit → rotated window point and scene → SKView point agree within 1 pt for every k, at 951 × 669 and
     669 × 951.
   - The inverse returns the canvas point.
   - The pouch's centre lands in the bag.
   - The duo7 numbers are worked by hand.
   - Trace and format tests.

## Next steps (outside the files this fix may touch)

- Add `testTurnedDragBagsALitItem` (k = 2, portrait) to duo.yml's `-only-testing` as a control. If that also bags
  nothing on the Duo, the cause is Duo synthesis, not the quarter turn.
- duo.yml's summary grep `Landscape turned drag from[^(]*` stops at "(was"; the full message is in the log and the
  xcresult.
- ci15 (R8, phone): both landscape tests failed with `iface=portrait`, window 874 × 402 against an App window of
  402 × 874. iOS kept the phone portrait, so `quarter=3` could not apply. This is a separate issue.
