import SwiftUI
import UIKit

/// The look (GAME-DESIGN §10): a candlelit dungeon, warm golds against deep teal-black. SF Pro Rounded throughout:
/// Black for the wordmark and the big numbers, Heavy for titles, Bold for buttons, Semibold for body. Every screen takes
/// colour, type, shape and motion from here. The chest art itself comes from `ChestArt.palette` (Scene).
enum HushTheme {
    // Dungeon, darkest → lightest
    static let night = Color(hushHex: 0x071214)
    static let deep = Color(hushHex: 0x0C1C1F)
    static let teal = Color(hushHex: 0x12292D)
    static let moss = Color(hushHex: 0x1B3A3E)
    // Text: primary / secondary / tertiary
    static let parchment = Color(hushHex: 0xF7ECD6)
    static let mist = Color(hushHex: 0xC0CBC3)
    static let haze = Color(hushHex: 0x81958F)
    // Gold: the primary action and earned things
    static let gold = Color(hushHex: 0xF6C45B)
    static let goldLight = Color(hushHex: 0xFFE39B)
    static let goldDeep = Color(hushHex: 0xC4862B)
    static let candle = Color(hushHex: 0xFFB45E)
    // The mimic's moods (the floor meter's colours)
    static let asleep = Color(hushHex: 0x8FD6BE)
    static let amber = Color(hushHex: 0xF2A33A)
    static let danger = Color(hushHex: 0xEC5A43)
    static let velvet = Color(hushHex: 0xB8344F)
    // Surfaces
    static let surface = Color(hushHex: 0x10262A)
    static let surfaceRaised = Color(hushHex: 0x1A383C)
    static let surfacePressed = Color(hushHex: 0x0D2023)
    static let stroke = Color.white.opacity(0.09)
    /// Text on gold.
    static let ink = Color(hushHex: 0x22160A)
    static let shadow = Color(hushHex: 0x030809)

    /// Hit targets are never smaller (ROUND-1 App: ≥ 56 pt).
    static let minTap: CGFloat = 56
    static let primaryHeight: CGFloat = 64
    static let secondaryHeight: CGFloat = 56
    static let buttonRadius: CGFloat = 18
    static let cardRadius: CGFloat = 28

    /// UI settle: spring 0.45 / 0.86. Reduce Motion: a 0.2 s crossfade.
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)
    }

    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.62)
    }

    static func pageTransition(_ reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return AnyTransition.offset(x: 0, y: 24).combined(with: .opacity)
    }

    /// The dungeon backdrop for full screens: a candle glow from the top over teal-black.
    @MainActor static var backdrop: some View {
        ZStack {
            LinearGradient(colors: [teal, deep, night], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [candle.opacity(0.16), candle.opacity(0)], center: .init(x: 0.5, y: 0.18),
                           startRadius: 10, endRadius: 420)
        }
    }

    /// The mimic's mood colour.
    static func stageColor(_ stage: MimicStage) -> Color {
        switch stage {
        case .asleep: return asleep
        case .stirring: return amber
        case .waking, .biting: return danger
        }
    }
}

/// The type scale. `compact` = a short canvas (an iPhone SE-sized screen).
///
/// R2 (UX P2-15, ROUND-2 App 10): menu, Results, Codex and Settings type follows Dynamic Type (`UIFontMetrics`),
/// capped at 1.3× so the halves still fit; those screens scroll or wrap instead of clipping. The big display numbers,
/// the wordmark and the in-run hint stay fixed (the chest's own scale sets those).
enum HushType {
    /// The largest Dynamic Type growth the layouts take.
    static let maxGrowth: CGFloat = 1.3

    /// `size` for the reader's text size (never below 0.9× nor above `maxGrowth` × the design size). Pure given the
    /// category; tested.
    static func scaled(_ size: CGFloat, _ style: UIFont.TextStyle, category: UIContentSizeCategory? = nil) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: style)
        let grown: CGFloat
        if let category {
            grown = metrics.scaledValue(for: size,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
        } else {
            grown = metrics.scaledValue(for: size)
        }
        return min(max(grown, size * 0.9), size * maxGrowth)
    }

    static func wordmark(_ c: Bool) -> Font { .system(size: c ? 60 : 84, weight: .black, design: .rounded) }
    static func hero(_ c: Bool) -> Font { .system(size: c ? 56 : 76, weight: .black, design: .rounded).monospacedDigit() }
    static func title(_ c: Bool) -> Font { .system(size: scaled(c ? 26 : 32, .title1), weight: .heavy, design: .rounded) }
    static func headline(_ c: Bool) -> Font {
        .system(size: scaled(c ? 19 : 22, .headline), weight: .bold, design: .rounded)
    }
    static func hint(_ c: Bool) -> Font { .system(size: c ? 22 : 26, weight: .heavy, design: .rounded) }
    /// The in-run hint at the chest's scale (QA-1 P2-11: a phone's hint band is about 30 pt tall).
    static func hint(scale: CGFloat) -> Font { .system(size: 26 * scale, weight: .heavy, design: .rounded) }
    static func button(_ c: Bool) -> Font { .system(size: scaled(c ? 19 : 21, .body), weight: .bold, design: .rounded) }
    static func body(_ c: Bool) -> Font {
        .system(size: scaled(c ? 15 : 17, .body), weight: .semibold, design: .rounded)
    }
    static func caption(_ c: Bool) -> Font {
        .system(size: scaled(c ? 13 : 14, .footnote), weight: .medium, design: .rounded)
    }
    static func overline(_ c: Bool) -> Font {
        .system(size: scaled(c ? 11 : 13, .caption1), weight: .bold, design: .rounded)
    }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
}

extension Color {
    /// 0xRRGGBB.
    init(hushHex hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }

    /// A catalogue / palette colour (Contracts' platform-neutral RGBA).
    init(hush c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

// MARK: - Buttons

struct HushButtonStyle: ButtonStyle {
    /// R3 (decision 5): `leather` is the in-chest secondary (the bag strip's leather and stitching, never a teal card).
    enum Kind { case primary, secondary, quiet, leather }
    var kind: Kind = .primary
    var height: CGFloat = HushTheme.primaryHeight
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let h = max(height, HushTheme.minTap)
        return configuration.label
            .font(kind == .quiet ? HushType.body(compact) : HushType.button(compact))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: h)
            .padding(.horizontal, 14)
            .background(HushButtonBackground(kind: kind, pressed: pressed).frame(height: h))
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(kind == .quiet && pressed ? 0.6 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return HushTheme.ink
        case .secondary, .leather: return HushTheme.parchment
        case .quiet: return HushTheme.mist
        }
    }
}

struct HushButtonBackground: View {
    let kind: HushButtonStyle.Kind
    let pressed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HushTheme.buttonRadius, style: .continuous)
        ZStack {
            switch kind {
            case .primary:
                // A 4 pt lip that presses to 1 pt: a chunky, chest-like button.
                shape.fill(HushTheme.goldDeep).offset(y: pressed ? 1 : 4)
                shape.fill(LinearGradient(colors: [HushTheme.goldLight, HushTheme.gold], startPoint: .top,
                                          endPoint: .bottom))
                    .offset(y: pressed ? 3 : 0)
                    .shadow(color: HushTheme.candle.opacity(0.28), radius: 14, y: 4)
            case .secondary:
                shape.fill(pressed ? HushTheme.surfacePressed : HushTheme.surfaceRaised)
                    .overlay(shape.stroke(HushTheme.stroke, lineWidth: 1))
            case .quiet:
                Color.clear
            case .leather:
                PlateBackground(style: .leather, radius: HushTheme.buttonRadius, pressed: pressed)
            }
        }
    }
}

// MARK: - R3 (founder decision 5): the in-world plate

/// The one plate for everything SwiftUI draws over the chest: the hint, the lesson cards, the pause, resume and
/// closing cards and the callouts. The Scene draws it (`ChestArt.plateImage(size:style:)`, one art source with the
/// scene's own plates): parchment for hints, lesson steps and callouts; leather for the pause, resume and closing
/// cards; urgent (oxblood) for "Freeze!". No black pills, no teal cards, one prompt at a time.
///
/// `PlateArt.image` is the one line that picks the image source; if it returns nil the plate is drawn here from the
/// Scene's own plate colours (`ChestArt.plateColors`).
enum PlateArt {
    static func image(size: CGSize, style: PlateStyle) -> CGImage? {
        ChestArt.plateImage(size: size, style: style)
    }

    /// Text and icon colours on a plate (the Scene's palette for it).
    static func text(_ style: PlateStyle) -> Color { Color(hush: ChestArt.plateColors(style).text) }
    static func accent(_ style: PlateStyle) -> Color { Color(hush: ChestArt.plateColors(style).accent) }
    static func muted(_ style: PlateStyle) -> Color { Color(hush: ChestArt.plateColors(style).muted) }
    /// "Phew. Snoring again." and "Hold it there…" on parchment: a deep moss that reads on the paper.
    static let calm = Color(hushHex: 0x2E6B4E)
}

struct PlateBackground: View {
    var style: PlateStyle = .parchment
    var radius: CGFloat = 16
    var pressed = false

    var body: some View {
        GeometryReader { geo in
            Group {
                if geo.size.width >= 8, geo.size.height >= 8, let art = PlateArt.image(size: geo.size, style: style) {
                    Image(decorative: art, scale: 3)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    drawn(geo.size)
                }
            }
            .brightness(pressed ? -0.12 : 0)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 5, y: 3)
    }

    /// The fallback: the same plate in the Scene's colours.
    private func drawn(_ size: CGSize) -> some View {
        let c = ChestArt.plateColors(style)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inset = min(6, min(size.width, size.height) * 0.12)
        return ZStack {
            shape.fill(LinearGradient(colors: [Color(hush: c.fill), Color(hush: c.fillDark)],
                                      startPoint: .top, endPoint: .bottom))
            shape.stroke(Color(hush: c.edge), lineWidth: 2.5)
            RoundedRectangle(cornerRadius: max(radius - inset, 2), style: .continuous)
                .inset(by: inset)
                .stroke(Color(hush: c.stitch).opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }
        .frame(width: size.width, height: size.height)
    }
}

extension View {
    /// R3: wraps the view in the in-world plate (decision 5).
    func hushPlate(_ style: PlateStyle = .leather, padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
        self.padding(.horizontal, padding + 8)
            .padding(.vertical, padding)
            .background(PlateBackground(style: style, radius: radius))
    }
}

/// A drawn plate icon (the Scene's `ChestArt.glyphImage`): the lesson's stakes, never SF Symbols in the chest.
struct PlateGlyphView: View {
    let glyph: PlateGlyph
    var side: CGFloat = 28

    var body: some View {
        Group {
            if let image = ChestArt.glyphImage(glyph, side: side) {
                Image(decorative: image, scale: 3)
                    .resizable()
            } else {
                Color.clear
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

// MARK: - R3: drawn glyphs (no SF Symbols inside the chest)

/// Two rounded bars.
struct PauseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.36
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height),
                         cornerSize: CGSize(width: w * 0.3, height: w * 0.3))
        p.addRoundedRect(in: CGRect(x: rect.maxX - w, y: rect.minY, width: w, height: rect.height),
                         cornerSize: CGSize(width: w * 0.3, height: w * 0.3))
        return p
    }
}

/// A chunky arrow, up or down.
struct ArrowGlyph: Shape {
    var up = true

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let shaft = w * 0.34
        let head = h * 0.5
        var p = Path()
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w, y: head))
        p.addLine(to: CGPoint(x: (w + shaft) / 2, y: head))
        p.addLine(to: CGPoint(x: (w + shaft) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - shaft) / 2, y: h))
        p.addLine(to: CGPoint(x: (w - shaft) / 2, y: head))
        p.addLine(to: CGPoint(x: 0, y: head))
        p.closeSubpath()
        let t = up ? CGAffineTransform(translationX: rect.minX, y: rect.minY)
            : CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.minY + h)
        return p.applying(t)
    }
}

/// A tick (the pose step's "Hold it there…").
struct TickGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + rect.height * 0.86))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.16))
        return p.strokedPath(StrokeStyle(lineWidth: max(rect.width * 0.18, 2), lineCap: .round, lineJoin: .round))
    }
}

/// A button that ticks the UI sound/haptic (FeedbackDirector.uiTap) before acting.
struct HushButton<Content: View>: View {
    var kind: HushButtonStyle.Kind = .primary
    var height: CGFloat = HushTheme.primaryHeight
    var compact = false
    var confirm = false
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button {
            if confirm { FeedbackDirector.shared.uiConfirm() } else { FeedbackDirector.shared.uiTap() }
            action()
        } label: {
            label()
        }
        .buttonStyle(HushButtonStyle(kind: kind, height: height, compact: compact))
    }
}

/// A round icon button (pause, close): 52 pt visual, 56 pt tap.
struct HushIconButton: View {
    let systemName: String
    let label: String
    var visual: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: visual * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(HushTheme.parchment)
                .frame(width: visual, height: visual)
                .background(Circle().fill(HushTheme.surface.opacity(0.86))
                    .overlay(Circle().stroke(HushTheme.stroke, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3))
                .frame(width: max(visual, HushTheme.minTap), height: max(visual, HushTheme.minTap))
                .contentShape(Circle())
        }
        .buttonStyle(HushPressStyle())
        .accessibilityLabel(label)
    }
}

struct HushPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Cards and small pieces

extension View {
    /// A card: solid surface, a top-lit hairline, a soft shadow.
    func hushCard(padding: CGFloat = 18, radius: CGFloat = HushTheme.cardRadius) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(HushTheme.surface.opacity(0.96))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(LinearGradient(colors: [HushTheme.candle.opacity(0.22), Color.white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.4), radius: 18, y: 8)
            )
    }

    /// Text over the live chest: a legibility shadow.
    func hushLegible() -> some View {
        self.shadow(color: HushTheme.shadow.opacity(0.75), radius: 5, y: 1)
    }
}

/// A section label (caps, tracked).
struct HushOverline: View {
    let text: String
    var compact = false
    var color: Color = HushTheme.mist

    var body: some View {
        Text(text.uppercased())
            .font(HushType.overline(compact))
            .kerning(compact ? 1.3 : 1.6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// A capsule label ("New best!", "Scored try").
struct HushPill: View {
    let text: String
    var fill: Color = HushTheme.gold
    var foreground: Color = HushTheme.ink
    var fontSize: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(fontSize * 0.06)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
    }
}

/// A thin progress bar (the rank bar). R2 (UX P1-14): the track is always visible (a lighter groove with a hairline)
/// and an empty bar still shows a 4 % sliver, so a fresh thief sees where the bar is.
struct HushProgressBar: View {
    let value: Double
    var height: CGFloat = 10
    static let minimumShown: Double = 0.04

    /// The fill drawn for `value` (never below the sliver). Pure; tested.
    static func shown(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, minimumShown), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let v = CGFloat(Self.shown(value))
            ZStack(alignment: .leading) {
                Capsule().fill(HushTheme.parchment.opacity(0.12))
                    .overlay(Capsule().stroke(HushTheme.parchment.opacity(0.18), lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(colors: [HushTheme.goldDeep, HushTheme.gold], startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: max(geo.size.width * v, height))
            }
        }
        .frame(height: height)
    }
}

/// R2 (juror P1-10): the pause button as a round brass stud, like the chest's hinges, never a flat SwiftUI circle.
struct BrassCoinButton: View {
    let label: String
    var visual: CGFloat = 50
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            ZStack {
                Circle().fill(Color(hush: ChestArt.outline)).frame(width: visual + 5, height: visual + 5)
                Circle()
                    .fill(RadialGradient(colors: [HushTheme.goldLight, HushTheme.gold, HushTheme.goldDeep],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: visual * 0.7))
                    .frame(width: visual, height: visual)
                Circle().stroke(HushTheme.goldDeep.opacity(0.9), lineWidth: 2)
                    .frame(width: visual * 0.74, height: visual * 0.74)
                // R3 (decision 5): drawn, never an SF Symbol inside the chest.
                PauseGlyph()
                    .fill(HushTheme.ink)
                    .frame(width: visual * 0.3, height: visual * 0.34)
            }
            .shadow(color: Color.black.opacity(0.45), radius: 5, y: 3)
            .frame(width: max(visual, HushTheme.minTap), height: max(visual, HushTheme.minTap))
            .contentShape(Circle())
        }
        .buttonStyle(HushPressStyle())
        .accessibilityLabel(label)
    }
}

/// "Hush" in Black rounded type, with a finger-to-lips "shh" mark in gold.
struct HushWordmark: View {
    var size: CGFloat = 84

    var body: some View {
        VStack(spacing: size * 0.04) {
            Text("Hush")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(HushTheme.parchment)
                .kerning(-size * 0.01)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: HushTheme.candle.opacity(0.35), radius: size * 0.18)
            Text("DON'T WAKE THE MIMIC")
                .font(.system(size: max(size * 0.17, 11), weight: .heavy, design: .rounded))
                .kerning(size * 0.035)
                .foregroundStyle(HushTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hush: Don't Wake the Mimic")
    }
}

/// A number that counts up to `value` (the Results haul). Reduce Motion: shown at once.
struct CountingNumber: View, Animatable {
    var value: Double
    var font: Font

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value.rounded()).formatted())
            .font(font)
            .contentTransition(.identity)
    }
}

/// A gold coin glyph (code-drawn, no emoji).
struct CoinGlyph: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(HushTheme.goldDeep).offset(y: size * 0.06)
            Circle().fill(LinearGradient(colors: [HushTheme.goldLight, HushTheme.gold], startPoint: .top,
                                         endPoint: .bottom))
            Circle().stroke(HushTheme.goldDeep.opacity(0.7), lineWidth: max(size * 0.07, 1)).padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A Path drawn from a CGPath (made on the main actor) scaled to fit its frame, keeping its aspect.
struct FittedPathShape: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        let box = path.boundingRect
        guard box.width > 0, box.height > 0 else { return Path() }
        let s = min(rect.width / box.width, rect.height / box.height)
        let t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -box.midX, y: -box.midY)
        return path.applying(t)
    }
}
