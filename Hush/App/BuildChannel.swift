import Foundation

/// Which channel this build came from, and whether the Diagnostics line shows in Settings › About.
///
/// R3 (QA-2 P2-15): App Review installs carry a sandbox receipt too, so the receipt alone never shows test UI. The
/// Diagnostics line (input, screen, mask, hand-off angles: the founder's device test, REVIEW-2-duo step 9) shows in
/// DEBUG builds, or after the hidden gesture: a 2-second press on Settings › About's text toggles it (remembered).
enum BuildChannel {
    static let diagnosticsKey = "hush.diagnostics"

    /// R4 (ROUND-4 App 10): where this build came from, shown INSIDE Diagnostics only. It never decides whether any
    /// UI shows (App Review installs carry a sandbox receipt too, so "TestFlight" also covers them; that is why the
    /// panel itself needs the hidden press in every Release build).
    enum Kind: String, Equatable {
        case debug, testFlight, appStore

        var label: String {
            switch self {
            case .debug: return "Debug"
            case .testFlight: return "TestFlight (sandbox receipt)"
            case .appStore: return "App Store"
            }
        }
    }

    /// Pure; tested.
    static func kind(isDebug: Bool, receiptName: String?) -> Kind {
        if isDebug { return .debug }
        return receiptName == "sandboxReceipt" ? .testFlight : .appStore
    }

    static var current: Kind {
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        return kind(isDebug: debug, receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent)
    }

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
