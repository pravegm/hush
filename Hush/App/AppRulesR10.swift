import CoreGraphics
import Foundation

// MARK: - R10 (design/VISUAL-REGRESSION-R9.md, design/notes/r10.md): visual regressions after the orientation rounds

extension AppRules {
    /// R10 (VISUAL-REGRESSION-R9 R5): whether PlayLayer hides the pause coin: under the pause menu and the closing
    /// card, and while the First Chest's final card is up (the bite hides it on the scene's own flag, `hud.biting`).
    /// The scene's brass seat fades out with it (`ChestScene.pauseSeatHidden`), so no empty dark recess is left by a
    /// card. Pure; tested.
    static func pauseCoinHidden(menuOpen: Bool, closingPaused: Bool, finalLessonCard: Bool, biting: Bool = false)
        -> Bool {
        menuOpen || closingPaused || finalLessonCard || biting
    }
}
