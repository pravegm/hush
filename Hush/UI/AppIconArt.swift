import SwiftUI

/// The App Store icon. R3 (founder decision 6): drawn by the Scene in the game's own style (`ChestArt.appIcon(size:)`:
/// a slit amber eye, a shield lock, pointed fangs, star coins, the dark outlines), readable at 60 px, opaque. The App
/// only shows it (demo `screen=icon`) and writes it as an RGB PNG with no alpha (`IconExport`, OpaquePNG).
struct AppIconArt: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Color.black
                if let image = AppIconCache.image() {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: side, height: side)
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The master icon (1024 px), drawn once.
@MainActor
enum AppIconCache {
    static let side: CGFloat = 1024
    private static var cached: CGImage?

    static func image() -> CGImage? {
        if let cached { return cached }
        let made = ChestArt.appIcon(size: side)
        cached = made
        return made
    }
}
