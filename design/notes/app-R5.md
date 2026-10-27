# App engineer, Round 5 hand-off: the release candidate (27 Oct)

Nothing here has been compiled (CI is the compiler). Nothing is committed. I touched these files:
- `Hush/App/`: GameController, AppRules, AppModels;
- `Hush/UI/`: Layout, PlayHUD, HomeView, HushTheme, ResultsView, AchievementArt;
- `Hush/Persistence/ProgressStore.swift`;
- `HushTests/AppTests.swift` (new `R5Tests`, 9 tests);
- `design/NEEDS.md`.

The Scene's R5 hooks had all landed by the end of the round, and I call them by their exact names:
`ChestLayout.chestCenterX`, `pauseSeat(viewScale:)` and `ChestScene.biteActive`. The App only ever reads `meterRect`
for its y, the VoiceOver element and the lesson ring, so the new meter (x 56…414) and chain tab (x 424…590) need no
App change.

## The 8 items
1. **Home at accessibility sizes (QA-4 P1-A, frame 44).** `HomeMenu` reads `dynamicTypeSize`. At AX sizes:
   - the Daily status moves under "Daily Dungeon" in a leading VStack, with 8 pt of vertical padding;
   - Codex / Badges and Settings / Game Center become one per row (`AnyLayout` switches HStack to VStack);
   - both fold and phone Home scroll in a `FadingScroll`, with the fade and the chevron.

   For the Daily tile to grow, `HushButtonStyle`'s background is now `.frame(minHeight: h)` instead of `height: h`.
   That changes nothing at any other size, because the label is never shorter than `h`.
   Test: `accessibilityHomeStacksOnePerRow`.
2. **The fold layout on a phone (UX P1-1, juror P1-1, frames 30 and 39).** The cause was R4's taller plates. The
   content ran 5 pt (Home, 358 vs 353) and about 40 pt (the card, ~394) over a 402 pt phone's turned floor half. So
   `ViewThatFits` chose the bare scroll, which hard-clips.
   - **The rule:** `AppCanvas.tightFloor` (a fold whose floor half is under 420 pt) switches on compact metrics.
   - **Home with compact metrics:** spacing 8, and Play 60 pt.
   - **The final card with compact metrics:** the compact title, rows 6 apart, 24 pt icons, a 56 pt "Got it" and
     padding 14.
   - **The Duo** (floor ~440 pt) keeps the R4 metrics, so `duo-ui-home-150` is unchanged.
   - **Scrolling:** only AX sizes scroll, or a non-AX layout that still doesn't fit, as a last resort. They use
     `FadingScroll`, and the card's scroll is anchored at the bottom (`FadingScroll(anchor:)`), so "Got it" shows.

   Test: `foldLayoutsFitTheFloorHalf` measures both views with `UIHostingController.sizeThatFits` at Large, on these
   canvases:
   - the Duo (669 × 951);
   - a 393 × 852 phone with `fold=1`, turned (floor 345 pt) and unturned (370 pt).

   It asserts each view is ≤ `AppCanvas.floorHalf.height`, the SwiftUI floor half. `HUDLayout.floor` is a canvas rect
   (274 pt on a phone), and the card is a modal over it.
3. **The lever on `fold=1;turn=0` (UX P1-2): it isn't there.**
   - **The ci9s frames:** frames 32 and 13c draw no lever. Compare 13b, the same moment unturned on a phone, which
     does show the lever on the lid's right band.
   - **Why they look like the phone layout:** on a 402 pt phone, the unturned fold layout uses the same canvas,
     lid-up, as the phone layout. Apart from the lever, the two are pixel-identical, and that is what UX saw. The R4
     fix (`AppRules.usesSlider` and `ChestScene.showsLever`, both keyed on `layout.hasFold`) is the fix, and the
     scene re-checks it every frame.
   - **The trace:** `RootView` `AppRules.hasFold` → `updateCanvas(hasFold:)` → `ScreenLayout` → `scene.layout`. A
     fold change re-chooses the input (`.hinge`), and `sliderTouch` is guarded by `usesSlider`.
   - **A real Duo with "Turn the chest round" off can't hit it.** Its inner portrait canvas is always a fold
     (`hingeSeen` + ≥ 760 pt, or `looksLikeDuo`). That holds before the first hinge report too, so the input is
     `.hinge`. The only Duo lever is Play anyway, which is landscape.
   - **Test:** `anUnturnedFoldNeverUsesTheLever`. It drives the real controller and scene from a phone (lever drawn)
     to `fold=1, turned=0`. The lever is hidden, the input is the hinge, and slider touches move nothing.
4. **QA-4 P2s.**
   - **D, the hint over the relic card after Resume:** `relicCardUntil` now runs on session time (`snapshot.time`),
     the clock the card runs on. A menu pause freezes the card and the gate together.
   - **E, VoiceOver "Slower…":** `LessonSpeechGate` says "Slower…" at most once per lesson step, and repeats no line
     within 3 s. It is reset per lesson.
   - **F, overflow on a tampered save:**
     - every total is clamped to 0…1,000,000,000 on decode (`ProgressRules.clampTotal`);
     - the pending run is too (`sanitized`);
     - `record` uses saturating `adding`.

   Tests: `lessonVoiceOverNeverRepeatsSlower` and `savedTotalsAreClamped`. D is covered by the pure rules only.
5. **Plates.**
   - **The hint band:** the plate's band is `HUDLayout.hintPlateRect(viewScale:)`. It runs from the band's left end
     to 16 pt short of the pause seat as drawn at that scale: ≈ 574 on the Duo, ≈ 528 on a 402 pt phone.
   - **Fold clearance:** the band is moved to canvas y 388…436, 20 pt off the fold edge (`clearOfFold`).
   - **Centring:** `AxisCentredLayout` centres the hugging plate on `chestCenterX` while it fits. A longer line is
     pushed in only as far as it must go, so text never shrinks to centre. On the Duo almost every line is centred.
     On a phone a short line ("Freeze!") is centred, and the longest hints sit about 20 pt left of the axis.
   - **The Daily marker** (`dailyMarkerCenter`) sits on the axis, at least 12 pt above the phone's plaque, and may
     use up to 6 pt of the top inset. That inset is below the Island, and on a Duo it is the home indicator's.
   - **The pause coin** hides (opacity 0, no hits) on `ChestScene.biteActive`, the flag the Scene dims its seat on.

   Test: `platesSitOnTheChestsAxis`.
6. **Results (frames 20, 38).** On the phone, the hero portrait gives way: it shrinks from up to 150 pt to no less
   than 60. That keeps the bottom of the strip, both rows with "+N more" as the last chip, above the 36 pt fade.
   - **How:** the strip's maxY (in the column's named coordinate space, so scrolling doesn't move it) and the scroll's
     height are measured with `onGeometryChange`. `ResultsView.fittedPortrait` settles it in one step, and changes
     under 0.5 pt are ignored.
   - **Expected size:** about 75 pt on a 402 pt phone. A 393 pt phone hits the 60 pt floor, about 4 pt into the top
     of the fade.
   - The fold layout is unchanged.

   Test: `resultsStripClearsTheFade`.
7. **The first Hush Chain tip.**
   - **When:** it shows AT the first chain bank. `AppRules.calloutBlocked` lets the bank's own tip through the bank
     beat, but never under the relic card. If a relic was banked too, it waits for the card, as before.
   - **How long:** it is up for 3.5 s. For the first 3 s, only "Freeze!" may replace it. No other hint may, and a
     newer callout such as the golden banner waits for it.
   - **Queued callouts:** a queued callout never cuts off one already on screen.

   Test: `theFirstChainTipOwnsItsBank`.
8. **Badges (frame 40).** Light Fingers is now the feather (light), Heavy Bag the golden idol (heavy), and Dragon's
   Hoard the jewelled goblet. The Hoard used to have the idol. Test: `badgeArtMatchesItsMeaning`. **Founder:**
   re-upload those 3 Game Center images if the old ones are already in App Store Connect.

## Risks
- `foldLayoutsFitTheFloorHalf` measures real SwiftUI layouts. My estimates leave about 20 pt of margin on the 393 pt
  phone. If CI's text metrics differ, the failure message prints the measured height.
- The hint plate now sits 16 canvas pt lower, so it covers a little more of the interior's back edge, where the
  deepest loot lies.
- `onGeometryChange` drives a state change in Results. It is guarded against loops (one-step fixed point, 0.5 pt
  dead band, clamped) and is phone-only.
- Not done: QA-3 P2-1 (Play anyway on a flat Duo), P2-6 (lever grace) and P2-7 (per-frame cost). They were not in the
  brief.
