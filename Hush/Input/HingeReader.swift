import Foundation
import QuartzCore
import SwiftUI

/// Reads the iPhone Duo hinge (iOS 27.1+) and reports `(angleDegrees, time)`: 180 = flat, time = `CACurrentMediaTime()`
/// on receipt (samples carry no timestamp of their own). On devices without a hinge (or below iOS 27.1) it calls
/// `onUnavailable` instead. Never use the hinge's `status` for play (it reads `.closed` at ~85° on hardware).
/// Copied from Swoop (`Input/HingeReader.swift`, itself from Brim), battle-tested on a real Duo.
///
/// Lifecycle trap (Squish, real Duo): back from the background with the phone open and still, iOS may send no hinge
/// change at all. On every scene activation the subscription is switched off and on again, which delivers the current
/// state. After a hinge has been seen, a transient nil (display handover) must not demote the app to the slider; that
/// policy belongs to the caller (`HingeLidSource.hasHinge` never goes back to false).
///
/// R8 (Hush QA-5 P1-C): iOS may also go silent after a display hand-off WITHOUT a scene-phase change (the app moved
/// back to the inner display, the subscription delivers nothing). The caller can bump `refreshToken` to make the same
/// off/on re-subscription happen at any time (Hush bumps it on every cover ↔ inner change, after 3 s of silence on the
/// closing card, and on "Carry on"). The default (0, never changed) behaves exactly as before.
///
/// Usage: `view.modifier(HingeReader(onUpdate: { angle, time in … }, onUnavailable: { … }, refreshToken: n))`
struct HingeReader: ViewModifier {
    let onUpdate: (Double, TimeInterval) -> Void
    let onUnavailable: () -> Void
    /// R8: any change re-subscribes (off, then on 30 ms later), which delivers the current hinge state.
    let refreshToken: Int

    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled = true
    @State private var refresh = 0

    init(onUpdate: @escaping (Double, TimeInterval) -> Void, onUnavailable: @escaping () -> Void = {},
         refreshToken: Int = 0) {
        self.onUpdate = onUpdate
        self.onUnavailable = onUnavailable
        self.refreshToken = refreshToken
    }

    /// The off/on toggle: off now, on again 30 ms later (unless another re-subscription started meanwhile).
    @MainActor
    private func resubscribe() {
        refresh &+= 1
        let ticket = refresh
        enabled = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            guard ticket == refresh else { return }
            enabled = true
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .onHingeChange(isEnabled: enabled) { _, newContext in
                    if let hinge = newContext.hinge {
                        let time = CACurrentMediaTime()
                        let degrees = hinge.angle.degrees
                        FeelHingeLog.record(angle: degrees, at: time)
                        onUpdate(degrees, time)
                    } else {
                        onUnavailable()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    resubscribe()
                }
                .onChange(of: refreshToken) { _, _ in
                    resubscribe()
                }
        } else {
            content.onAppear(perform: onUnavailable)
        }
    }
}

/// `HUSH-H <t> <angle>` stdout lines for CI (`ci/duo.sh` greps them), only in DEBUG with the `-hushDemo` launch
/// argument, at most 10 per second. Don't rename the prefix. Called on the main thread only (hinge callbacks).
enum FeelHingeLog {
    static let isEnabled: Bool = FeelDemoLog.isEnabled
    nonisolated(unsafe) private static var lastLine: TimeInterval = -.infinity

    static func record(angle: Double, at time: TimeInterval) {
        guard isEnabled, time - lastLine >= 0.1 else { return }
        lastLine = time
        print(String(format: "HUSH-H %.3f %.1f", time, angle))
        fflush(stdout)
    }
}
