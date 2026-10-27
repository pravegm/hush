import SwiftUI

@main
struct HushApp: App {
    /// Portrait on phones; portrait + landscapes on a Duo (App/OrientationLock.swift).
    @UIApplicationDelegateAdaptor(HushAppDelegate.self) private var appDelegate
    @StateObject private var store: ProgressStore
    @StateObject private var settings: SettingsStore
    @StateObject private var controller: GameController

    init() {
        let isDemo = DemoMode.current != nil
        // Demo runs never touch the player's saved progress or settings.
        let store = isDemo ? ProgressStore(inMemory: ProgressData()) : ProgressStore(defaults: .standard)
        let settings = SettingsStore(defaults: isDemo ? nil : UserDefaults.standard)
        _store = StateObject(wrappedValue: store)
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: GameController(store: store, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller, store: store, settings: settings)
                .onAppear {
                    settings.apply()
                    FeedbackDirector.shared.start()
                    settings.apply()
                    GameCenterManager.shared.authenticate()
                }
        }
    }
}
