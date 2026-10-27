import XCTest

/// R2 turned-drag check (REVIEW-1-duo P1-3, QA-1 P2-7, design/ROUND-2.md CI engineer 1): a REAL synthesized finger
/// drag (XCTest's event synthesis goes through UIKit hit-testing, the SpriteView and the scene's
/// `touch.location(in: world)`, exactly like a finger) on a turned-round Duo layout, from where a lit item is DRAWN to
/// where the pouch is DRAWN. If the turned touch mapping is mirrored, the press lands on empty floor and nothing is
/// bagged.
///
/// It reads two accessibility elements the App exposes (design/NEEDS.md, "CI engineer (R2)"):
///  - `hud.bag`: frame = the IN BAG pouch's on-screen rect (after the turn); `accessibilityValue` = the in-bag item
///    count as a decimal string ("0", "1", …).
///  - `debug.loot` (DEBUG demo runs only): frame = the on-screen rect (after the turn) of the most-lit item that can be
///    grabbed now; `accessibilityValue` = "id=<n> kind=<k>". Absent while nothing is lit.
/// Both must be pure accessibility (no hit testing), so the synthesized touch reaches the SpriteView underneath.
/// UI tests can't read the app's stdout, hence accessibility instead of `HUSH-T event itemBagged`.
///
/// Until the App adds them the test SKIPS (with the reason), so the non-fatal ci.yml step reports "skipped", not a
/// false failure. Run alone: `xcodebuild test -scheme HushUITests -destination 'platform=iOS Simulator,name=…'`.
final class TurnedDragUITests: XCTestCase {
    /// Attract mode never bites or ends; the lid held at 0.9 lights the floor; turned round with the Duo fold layout.
    static let demo = "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1"

    func testTurnedDragBagsALitItem() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hushDemo", Self.demo]
        app.launch()

        let bag = app.descendants(matching: .any)["hud.bag"]
        guard bag.waitForExistence(timeout: 30) else {
            attachScreen(app, "no-hud-bag")
            throw XCTSkip("No `hud.bag` accessibility element yet (design/NEEDS.md, CI engineer R2): can't find the pouch.")
        }
        let loot = app.descendants(matching: .any)["debug.loot"]
        guard loot.waitForExistence(timeout: 20), !loot.frame.isEmpty else {
            attachScreen(app, "no-debug-loot")
            throw XCTSkip("No `debug.loot` accessibility element yet (design/NEEDS.md, CI engineer R2): can't find a lit item.")
        }

        let before = count(bag)
        let start = point(app, loot.frame)
        let end = point(app, bag.frame)
        let what = (loot.value as? String) ?? "?"
        attachText("drag", "item \(what) at \(loot.frame) → pouch \(bag.frame); in bag before: \(before)")
        attachScreen(app, "before-drag")

        // A deliberate drag: hold 0.3 s to grab, move at 200 pt/s (well under the drag-noise speed), hold 0.3 s on the
        // pouch, release.
        start.press(forDuration: 0.3, thenDragTo: end, withVelocity: XCUIGestureVelocity(200), thenHoldForDuration: 0.3)

        let bagged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.count(bag) > before }, object: nil)
        let ok = XCTWaiter.wait(for: [bagged], timeout: 5) == .completed
        attachScreen(app, ok ? "after-drag-bagged" : "after-drag-not-bagged")
        XCTAssertTrue(ok, "Turned drag from the drawn item \(what) to the drawn pouch bagged nothing: hud.bag stayed at "
                      + "\(count(bag)) (was \(before)). The turned touch mapping is probably mirrored (REVIEW-1-duo P1-3).")
    }

    // MARK: - Helpers

    private func count(_ bag: XCUIElement) -> Int {
        if let s = bag.value as? String, let n = Int(s.trimmingCharacters(in: .whitespaces)) { return n }
        if let n = bag.value as? NSNumber { return n.intValue }
        return -1
    }

    /// The centre of a screen-space frame as an app coordinate (no hittability check: the elements are not views).
    private func point(_ app: XCUIApplication, _ frame: CGRect) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY))
    }

    private func attachScreen(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func attachText(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
