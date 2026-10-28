import UIKit
import UIKit.UIGestureRecognizerSubclass

#if DEBUG
/// R9c diagnostics (CI's Duo drag: `raw=0`, no touch reached the SKView). A passive window-level recognizer that
/// counts every touch reaching ANY of the app's windows, then fails at once so it never blocks, delays or cancels a
/// touch. Demo runs only (installed from `GameController.refreshDebugState`). If `win=0` too, the synthesized touches
/// never reached the app at all (the simulator's event injection), not a SwiftUI layer swallowing them.
final class DebugWindowTouchCounter: UIGestureRecognizer {
    static var began = 0
    static var last = "none"

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches {
            Self.began += 1
            let p = t.location(in: view)
            let hit = view?.hitTest(p, with: event).map { String(describing: type(of: $0)) } ?? "nil"
            Self.last = "(\(Int(p.x)),\(Int(p.y)))hit=\(hit)"
        }
        state = .failed
    }

    /// Idempotent: one counter per window, on every connected scene (inner and cover displays).
    static func install() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows
            where !(window.gestureRecognizers ?? []).contains(where: { $0 is DebugWindowTouchCounter }) {
                let counter = DebugWindowTouchCounter(target: nil, action: nil)
                counter.cancelsTouchesInView = false
                counter.delaysTouchesBegan = false
                counter.delaysTouchesEnded = false
                window.addGestureRecognizer(counter)
            }
        }
    }

    /// `win=<n> winAt=<point + hit view> screens=<w>x<h>,…` for `debug.state`.
    static var summary: String {
        let screens = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.size }
            .map { "\(Int($0.width))x\(Int($0.height))" }.joined(separator: ",")
        return "win=\(began) winAt=\(last) screens=\(screens.isEmpty ? "-" : screens)"
    }
}
#endif
