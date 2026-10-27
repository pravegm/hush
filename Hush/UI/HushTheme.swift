import SwiftUI

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
enum HushType {
    static func wordmark(_ c: Bool) -> Font { .system(size: c ? 60 : 84, weight: .black, design: .rounded) }
    static func hero(_ c: Bool) -> Font { .system(size: c ? 56 : 76, weight: .black, design: .rounded).monospacedDigit() }
    static func title(_ c: Bool) -> Font { .system(size: c ? 26 : 32, weight: .heavy, design: .rounded) }
    static func headline(_ c: Bool) -> Font { .system(size: c ? 19 : 22, weight: .bold, design: .rounded) }
    static func hint(_ c: Bool) -> Font { .system(size: c ? 22 : 26, weight: .heavy, design: .rounded) }
    static func button(_ c: Bool) -> Font { .system(size: c ? 19 : 21, weight: .bold, design: .rounded) }
    static func body(_ c: Bool) -> Font { .system(size: c ? 15 : 17, weight: .semibold, design: .rounded) }
    static func caption(_ c: Bool) -> Font { .system(size: c ? 13 : 14, weight: .medium, design: .rounded) }
    static func overline(_ c: Bool) -> Font { .system(size: c ? 11 : 13, weight: .bold, design: .rounded) }
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
    enum Kind { case primary, secondary, quiet }
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
        case .secondary: return HushTheme.parchment
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
            }
        }
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

/// A thin progress bar (the rank bar).
struct HushProgressBar: View {
    let value: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let v = CGFloat(min(max(value.isFinite ? value : 0, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(HushTheme.night.opacity(0.8))
                Capsule()
                    .fill(LinearGradient(colors: [HushTheme.goldDeep, HushTheme.gold], startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: max(geo.size.width * v, v > 0 ? height : 0))
            }
        }
        .frame(height: height)
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
