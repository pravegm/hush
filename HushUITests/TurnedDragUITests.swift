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
///  - `debug.canvas` (R6): `accessibilityValue` = "k=<k> w= h= fold= iface=<o> held=<o>" (R8 adds iface/held). R8
///    (QA-5 P1-D): the landscape tests POLL it until k is odd (15 s) and FAIL if it never is (they used to read it once,
///    too early, see k = 2 and skip).
/// All must be pure accessibility (no hit testing), so the synthesized touch reaches the SpriteView underneath.
/// UI tests can't read the app's stdout, hence accessibility instead of `HUSH-T event itemBagged`.
///
/// Until the App adds them the tests SKIP (with the reason), so the non-fatal ci.yml / duo.yml steps report
/// "skipped", not a false failure. Run alone: `xcodebuild test -scheme HushUITests -destination 'platform=iOS Simulator,name=…'`
/// (one test: `-only-testing:HushUITests/TurnedDragUITests/testLandscapeTurnedDragBagsALitItem`).
final class TurnedDragUITests: XCTestCase {
    /// Attract mode never bites or ends; the lid held at 0.9 lights the floor; turned round with the Duo fold layout.
    /// R9b: `orient=portrait`, so on the Duo sim (which boots in book pose) this is a true k=2 control; a phone is
    /// portrait anyway.
    static let demo = "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1;orient=portrait"

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
            // R8 (QA-5 P1-D): `debug.canvas` exists from the first frame, long before the landscape ask (first at
            // 0.4 s, re-asked every 2 s) lands, so one early read saw k = 2 and SKIPPED the R6 P0 path. Poll it until k
            // is odd (up to 15 s), and FAIL if it never is.
            guard let value = waitForOddK(app, label: label, shape: &shape) else { return }
            shape += " canvas=\(value)"
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
        // R9 (design/notes/fix-k3-drag.md): the app frame's ORIGIN is logged too (element frames are screen-absolute,
        // `point` offsets from it), and `debug.state` says what the App saw of the touch.
        shape += " app=\(app.frame)"
        let stateBefore = debugState(app)
        attachText("drag", "\(label): item \(what) at \(loot.frame) → pouch \(bag.frame); in bag before: \(before); "
                   + "\(shape); state before: \(stateBefore)")
        attachScreen(app, "before-drag")

        // A deliberate drag: hold 0.3 s to grab, move at 200 pt/s (well under the drag-noise speed), hold 0.3 s on the
        // pouch, release.
        start.press(forDuration: 0.3, thenDragTo: end, withVelocity: XCUIGestureVelocity(200), thenHoldForDuration: 0.3)

        let bagged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.count(bag) > before }, object: nil)
        let ok = XCTWaiter.wait(for: [bagged], timeout: 5) == .completed
        let stateAfter = debugState(app)
        attachText("state", "before: \(stateBefore)\nafter: \(stateAfter)")
        attachScreen(app, ok ? "after-drag-bagged" : "after-drag-not-bagged")
        XCTAssertTrue(ok, "\(label) from the drawn item \(what) to the drawn pouch bagged nothing: hud.bag stayed at "
                      + "\(count(bag)) (was \(before)); \(shape); debug.state before=[\(stateBefore)] "
                      + "after=[\(stateAfter)]. Read it as: touches=0/0/0 = no floor touch reached the App; hit=ignored "
                      + "= it arrived while paused (see paused=/input=); hit=missed = the press was not on the item "
                      + "(mapping); ended=dropped = the release was not in the bag (mapping) (REVIEW-1-duo P1-3, "
                      + "ROUND-6 scene 1, fix-k3-drag).")
    }

    /// R9: `debug.state`'s value (demo runs), or why there is none.
    private func debugState(_ app: XCUIApplication) -> String {
        let probe = app.descendants(matching: .any)["debug.state"]
        guard probe.waitForExistence(timeout: 2) else { return "no debug.state element" }
        return (probe.value as? String) ?? "?"
    }

    // MARK: - R8 (QA-5 P2-7): a SwiftUI control tapped at an odd k

    /// `hold=closing` starts the run on the closing card (held whatever drives the lid); its "Carry on" shows after
    /// 3 s. In landscape (k odd) the card is drawn turned a quarter turn, so this is a real synthesized tap through
    /// SwiftUI's `rotationEffect` at 90°: if hit-testing doesn't follow the turn, the tap misses and the card stays.
    static let carryOnDemo = "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1;orient=landscape;quarter=3;hold=closing"

    func testLandscapeCarryOnTapsAtOddK() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hushDemo", Self.carryOnDemo]
        app.launch()
        let label = "Landscape Carry on tap"
        var shape = "device=\(XCUIDevice.shared.orientation.rawValue) window=\(app.windows.firstMatch.frame.size)"
        let canvas = app.descendants(matching: .any)["debug.canvas"]
        guard canvas.waitForExistence(timeout: 30) else {
            attachScreen(app, "no-debug-canvas")
            throw XCTSkip("No `debug.canvas` accessibility element (design/NEEDS.md, CI R6): can't verify k.")
        }
        guard let value = waitForOddK(app, label: label, shape: &shape) else { return }
        shape += " canvas=\(value)"
        let carryOn = app.buttons["Carry on"]
        guard carryOn.waitForExistence(timeout: 12) else {
            attachText("carry-on", shape)
            attachScreen(app, "no-carry-on")
            XCTFail("\(label) from the held closing card: no \"Carry on\" button within 12 s; \(shape)")
            return
        }
        attachText("carry-on", "\(label): button at \(carryOn.frame); \(shape)")
        attachScreen(app, "before-tap")
        carryOn.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: carryOn)
        let ok = XCTWaiter.wait(for: [gone], timeout: 5) == .completed
        attachScreen(app, ok ? "after-tap-resumed" : "after-tap-still-held")
        XCTAssertTrue(ok, "\(label) from the drawn button at \(carryOn.frame) did nothing: the closing card is still up; "
                      + "\(shape). SwiftUI hit-testing through a 90° rotationEffect may be off (QA-5 P2-7).")
    }

    // MARK: - Helpers

    /// R8 (QA-5 P1-D): polls `debug.canvas` until its k is odd (15 s). Returns the value, or records a FAILURE (never
    /// a skip: the R6 P0 path must have evidence) and returns nil.
    private func waitForOddK(_ app: XCUIApplication, label: String, shape: inout String) -> String? {
        let canvas = app.descendants(matching: .any)["debug.canvas"]
        guard canvas.waitForExistence(timeout: 10) else {
            attachScreen(app, "no-debug-canvas")
            XCTFail("\(label) from a landscape launch: no `debug.canvas` element, so k can't be verified; \(shape)")
            return nil
        }
        let odd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let k = self.quarterTurns((canvas.value as? String) ?? "") else { return false }
            return k % 2 == 1
        }, object: nil)
        let reached = XCTWaiter.wait(for: [odd], timeout: 15) == .completed
        let value = (canvas.value as? String) ?? ""
        guard reached else {
            shape += " canvas=\(value)"
            attachText("canvas", shape)
            attachScreen(app, "even-k")
            XCTFail("\(label) from a landscape launch: the layout never reached an odd k in 15 s, last \(value); "
                    + "\(shape). The interface stayed portrait and `quarter=` could not apply, so the R6 P0 path "
                    + "went untested (QA-5 P1-D).")
            return nil
        }
        return value
    }

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
    /// R9: element frames are in SCREEN coordinates and `coordinate(withNormalizedOffset: .zero)` is the app frame's
    /// origin, so the offset is taken from that origin (it was added on top of it: right only while the app frame starts
    /// at 0, 0, as on a phone; a Duo with two displays need not).
    private func point(_ app: XCUIApplication, _ frame: CGRect) -> XCUICoordinate {
        let origin = app.frame.origin
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - origin.x, dy: frame.midY - origin.y))
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
