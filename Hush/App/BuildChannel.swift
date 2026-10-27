import Foundation

/// Which channel this build came from: Debug, TestFlight and sandbox builds are "test" builds (Settings → About shows
/// the build number and the input in use for the founder's device tests); App Store builds never are.
enum BuildChannel {
    static let isTestBuild: Bool = {
        #if DEBUG
        return true
        #else
        // TestFlight and Xcode-installed sandbox builds carry a sandbox receipt; App Store builds never do.
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    /// "1.0 (12)".
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
