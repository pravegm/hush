import XCTest

/// R2 turned-drag check (REVIEW-1-duo P1-3, QA-1 P2-7, design/ROUND-2.md CI engineer 1): a REAL synthesized finger
/// drag (XCTest's event synthesis goes through UIKit hit-testing, the SpriteView and the scene's
/// `touch.location(in: world)`, exactly like a finger) on a turned-round Duo layout, from where a lit item is DRAWN to
/// where the pouch is DRAWN. If the turned touch mapping is mirrored, the press lands on empty floor and nothing is
/// bagged.
///
/// R6 (design/ROUND-6.md "CI engineer" 1, the real-Duo P0 "stuck when opened flat and iOS went landscape"): the same
/// drag with the interface in LANDSCAPE, where the portrait canvas is drawn with an odd number of clockwise quarter
/// turns (k = 3 for interface `.landscapeLeft` with "Turn the chest round" on). A wrong k, a wrong rotation sense or a
/// touch mapping that ignores the world's zRotation all put the press on empty floor.
///
/// It reads accessibility elements the App exposes (design/NEEDS.md, "CI engineer (R2)" and "(R6)"):
///  - `hud.bag`: frame = the IN BAG pouch's on-screen rect (after the turn); `accessibilityValue` = the in-bag item
///    count as a decimal string ("0", "1", …).
///  - `debug.loot` (DEBUG demo runs only): frame = the on-screen rect (after the turn) of the most-lit item that can be
///    grabbed now; `accessibilityValue` = "id=<n> kind=<k>". Absent while nothing is lit.
///  - `debug.canvas` (R6 ask, optional): `accessibilityValue` = "k=<k> …". When present the landscape test checks that
///    k is odd (else it SKIPS: it would only re-test a portrait layout). When absent the window shape is recorded.
/// All must be pure accessibility (no hit testing), so the synthesized touch reaches the SpriteView underneath.
/// UI tests can't read the app's stdout, hence accessibility instead of `HUSH-T event itemBagged`.
///
/// Until the App adds them the tests SKIP (with the reason), so the non-fatal ci.yml / duo.yml steps report
/// "skipped", not a false failure. Run alone: `xcodebuild test -scheme HushUITests -destination 'platform=iOS Simulator,name=…'`
/// (one test: `-only-testing:HushUITests/TurnedDragUITests/testLandscapeTurnedDragBagsALitItem`).
final class TurnedDragUITests: XCTestCase {
    /// Attract mode never bites or ends; the lid held at 0.9 lights the floor; turned round with the Duo fold layout.
    static let demo = "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1"

    /// R6: the same, asked into landscape. `orient=landscape` makes the App ask iOS for a landscape interface (and
    /// never for portrait); `quarter=3` (R6 App key, ignored until it exists) forces k = 3 where iOS refuses to rotate
    /// (a phone sim with `fold=1` may stay portrait).
    static let landscapeDemo = "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1;orient=landscape;quarter=3"

    override func tearDown() {
        // The simulator keeps a device rotation across tests and launches: put it back.
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTurnedDragBagsALitItem() throws {
        try dragBagsALitItem(demo: Self.demo, label: "Turned drag", wantOddK: false)
    }

    /// The device is rotated to `.landscapeRight` (home edge on the LEFT), which is the INTERFACE orientation
    /// `.landscapeLeft`: ROUND-6's table gives k = 3 for it with turn round on, so the rule and `quarter=3` agree.
    /// (UIDeviceOrientation and UIInterfaceOrientation name the landscapes oppositely.)
    func testLandscapeTurnedDragBagsALitItem() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        try dragBagsALitItem(demo: Self.landscapeDemo, label: "Landscape turned drag", wantOddK: true)
    }

    // MARK: - The drag

    private func dragBagsALitItem(demo: String, label: String, wantOddK: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hushDemo", demo]
        app.launch()

        let bag = app.descendants(matching: .any)["hud.bag"]
        guard bag.waitForExistence(timeout: 30) else {
            attachScreen(app, "no-hud-bag")
            throw XCTSkip("No `hud.bag` accessibility element yet (design/NEEDS.md, CI engineer R2): can't find the pouch.")
        }

        var shape = "device=\(XCUIDevice.shared.orientation.rawValue) window=\(app.windows.firstMatch.frame.size)"
        if wantOddK {
            // Give the orientation ask (re-asked every 2 s) time to land before the item is looked up.
            let canvas = app.descendants(matching: .any)["debug.canvas"]
            if canvas.waitForExistence(timeout: 6) {
                let v = (canvas.value as? String) ?? ""
                shape += " canvas=\(v)"
                if let k = quarterTurns(v), k % 2 == 0 {
                    attachText("canvas", shape)
                    attachScreen(app, "even-k")
                    throw XCTSkip("Landscape drag: the layout is k=\(k), not odd (no landscape interface and no `quarter=` "
                                  + "key, design/NEEDS.md CI R6), so this would only re-test a portrait layout. \(shape)")
                }
            } else {
                shape += " canvas=no debug.canvas element (k not verified)"
            }
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
        attachText("drag", "\(label): item \(what) at \(loot.frame) → pouch \(bag.frame); in bag before: \(before); \(shape)")
        attachScreen(app, "before-drag")

        // A deliberate drag: hold 0.3 s to grab, move at 200 pt/s (well under the drag-noise speed), hold 0.3 s on the
        // pouch, release.
        start.press(forDuration: 0.3, thenDragTo: end, withVelocity: XCUIGestureVelocity(200), thenHoldForDuration: 0.3)

        let bagged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.count(bag) > before }, object: nil)
        let ok = XCTWaiter.wait(for: [bagged], timeout: 5) == .completed
        attachScreen(app, ok ? "after-drag-bagged" : "after-drag-not-bagged")
        XCTAssertTrue(ok, "\(label) from the drawn item \(what) to the drawn pouch bagged nothing: hud.bag stayed at "
                      + "\(count(bag)) (was \(before)); \(shape). The turned touch mapping is probably wrong for this "
                      + "quarter turn (REVIEW-1-duo P1-3, ROUND-6 scene 1).")
    }

    // MARK: - Helpers

    /// "k=<n>" in a `debug.canvas` value, or nil.
    private func quarterTurns(_ value: String) -> Int? {
        for part in value.split(whereSeparator: { $0 == " " || $0 == ";" || $0 == "," }) where part.hasPrefix("k=") {
            return Int(part.dropFirst(2))
        }
        return nil
    }

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
