# Scene R6 hand-off (Scene engineer): "any way up"

**Not verified:** nothing here has been compiled (no Mac). CI is the check. No new files, no new textures. The new
pure helpers are `nonisolated static` (`normalisedTurns`, `sceneSize`, `turnCosSin`); nothing new is called from a
texture-drawing closure. `MimicPortraitScene` is unchanged (it never used `turned`). No git commit.
Tests: 5 new `@Test`s in `HushTests/SceneTests.swift` (section `// MARK: R6`). No existing assertion changed.

## For the App (names are final)
| Item | API / rule |
|---|---|
| **Quarter turns** | `ChestScene.quarterTurns: Int` (get/set). 0…3 CLOCKWISE screen quarter turns; any Int is taken mod 4 (`ChestScene.normalisedTurns`). Set it to `AppRules.quarterTurns(...)`. `world.zRotation = −k·π/2` about the scene centre. |
| **Layout** | Keep giving `scene.layout` the **portrait-equivalent** layout: `ScreenLayout.make(hasFold:viewSize:)` with the window's w and h swapped when k is odd (`make` already treats landscape as portrait, so passing the raw window gives the same result). Set `layout` and `quarterTurns` in either order. |
| **Scene size** | The scene sizes ITSELF: `ChestScene.sceneSize(layout:quarterTurns:)` = `layout.size` for even k, w/h swapped for odd k (e.g. 952 × 670 for a 951 × 669 window). **Do not set `scene.size` yourself.** The SKView / SpriteView is the real window. If the scene is ever given another size, the world aspect-fills it (`worldScale`, ≈ 1, ≤ 1 pt overhang); the drawing and the touches stay right. |
| **Scale mode** | `.aspectFill` or `.aspectFit` both work (the aspects match, to rounding). Your current `size.width > size.height ? .aspectFit : .aspectFill` on the real window is fine. The pause seat's view scale now follows the scene's own `scaleMode` (`ChestScene.scaleFor(view:scene:mode:)` × `worldScale`). For a turned landscape scene that is the same number as the portrait rule (tested). |
| **`turned`** | A computed alias kept for compatibility: get = `quarterTurns == 2`; set true → k = 2, false → k = 0. **Prefer `quarterTurns`**: setting `turned = false` while k = 1 or 3 gives k = 0. |
| **Touches** | Nothing to do. They are still `touch.location(in: world)` for every k. |
| **Your overlays** | Canvas rects (`ChestLayout.*`, `CanvasFit.viewRect`) stay in **unturned portrait canvas terms**. Lay them out in your portrait frame and rotate that frame by `.degrees(90 * k)` (clockwise), exactly as the scene does. Both turn about the window centre, so they line up. |
| **Read-outs** | `scene.sceneRect(fromCanvas:)` (a canvas rect as drawn in the scene, y up), `scene.drawnWorldRect` (the portrait canvas plus extensions as drawn: equals the scene rect), `scene.worldScale`, plus the old `scenePoint(fromCanvas:)` / `canvasPoint(fromScene:)` / `worldNode`. |

Where the lid ends up on the screen: k 0 top, 1 right, 2 bottom, 3 left (the canvas top turned k quarter turns
clockwise). With ROUND-6's table that is the blurring side when "Turn the chest round" is on.

## Delivered (ROUND-6 Scene, items 1–3)
1. **`quarterTurns`.** `placeWorld()` turns the whole portrait scene (world x 0…670, y −contentOffsetY …
   height − contentOffsetY) by k clockwise quarter turns and puts its centre on the scene's centre, at scale 1 when
   the scene has its own size. k = 0 gives position (0, offset) and k = 2 gives (W, H − offset): R2's placements
   exactly, so every R2–R5 test still holds. Exact cos/sin per k (no float fuzz). The scene's size follows the layout
   and k (`applyLayout`, `applyTurns`), and `didChangeSize` re-places the world.
2. **Turned-dependent details.** Audited every Scene file. Only `placeWorld` ever read `turned`. Everything else is
   drawn under `world`, so all four k look identical to the player: the text, the glints and particles (their
   gravity is the world's −y), the shake (the `shaker` inside the world), the eye's gaze (canvas points), the keyhole
   (art), the overlays (sized to the extension, so they cover the turned scene), and the lever and slider fraction
   (canvas). No node is placed in scene or screen space.
   The one screen-space number was the pause seat's view scale, which now follows the real scale mode.
3. **Tests (`// MARK: R6`).**
   - `quarterTurnsNormaliseAndTurnedIsKTwo`: mod 4, the alias, the landscape size, −k·π/2, and that the layout and
     k survive each other.
   - `everyQuarterTurnMapsATouchToTheItemsFloorPoint`: for every k and window sizes 951 × 669, 669 × 951, the Duo
     and a phone, each item's on-screen point matches a hand-worked quarter turn and lies inside the scene. The touch
     there reports the item's floor point, and the drawn world equals the scene rect.
   - `lidHalfIsOnTheExpectedSideForEveryQuarterTurn`: the lid is on the expected side with the floor opposite, it
     spans the canvas width across the fold, and the fold is at the centre. Same sizes.
   - `windowSizedScenesStillFillAndMapTouches`: the scene forced to 951 × 669 or 669 × 951 still fills (≤ 1.5 pt
     overhang), touches still map, and the lid side is right. Also checks the scale-mode rule.
   - `everyQuarterTurnDrawsEveryMoment`: a smoke run of the moments and a bite at k = 1 and 3. The world keeps its
     turn and its place through the shake.

## Not done / notes
- The scene doesn't log k. The App's `HUSH-T canvas` line should carry it (CI's LANDSCAPE-PLAY wants "k odd").
- In raw capture at odd k the chest is drawn sideways. That's correct for the player (CI note).
