import Foundation

/// Which channel this build came from, and whether the Diagnostics line shows in Settings › About.
///
/// R3 (QA-2 P2-15): App Review installs carry a sandbox receipt too, so the receipt alone never shows test UI. The
/// Diagnostics line (input, screen, mask, hand-off angles: the founder's device test, REVIEW-2-duo step 9) shows in
/// DEBUG builds, or after the hidden gesture: a 2-second press on Settings › About's text toggles it (remembered).
enum BuildChannel {
    static let diagnosticsKey = "hush.diagnostics"

    /// DEBUG builds always; any other build only once the hidden gesture has unlocked it.
    static func showsDiagnostics(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return true
        #else
        return defaults.bool(forKey: diagnosticsKey)
        #endif
    }

    /// The hidden gesture. Returns whether Diagnostics now show.
    @discardableResult
    static func toggleDiagnostics(defaults: UserDefaults = .standard) -> Bool {
        let on = !defaults.bool(forKey: diagnosticsKey)
        defaults.set(on, forKey: diagnosticsKey)
        return showsDiagnostics(defaults: defaults)
    }

    /// "1.0 (12)".
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
