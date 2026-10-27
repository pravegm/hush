import SwiftUI

/// A little drawing of the Duo, the pose cards' and the lesson's diagram.
/// - `.tabletop(angle:)`: seen from the side, like a little laptop: the floor flat, the lid raised at `angle`° (gold).
/// - `.halves(lift:)`: seen from above, open flat in book pose: the half to lift glows gold, with "Lift this half".
struct DuoDiagram: View {
    enum Style: Equatable {
        case tabletop(angle: Double)
        case halves(lift: ScreenSide)
    }

    let style: Style
    var reduceMotion = false
    @State private var rock = false

    var body: some View {
        switch style {
        case let .tabletop(angle):
            GeometryReader { geo in
                tabletop(size: geo.size, angle: rock && !reduceMotion ? angle + 10 : angle)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { rock = true }
            }
            .accessibilityLabel("The Duo stood like a little laptop, lid raised")
        case let .halves(lift):
            GeometryReader { geo in
                halves(size: geo.size, lift: lift)
            }
            .accessibilityLabel(lift == .left ? "Lift the left half" : "Lift the right half")
        }
    }

    private func tabletop(size: CGSize, angle: Double) -> some View {
        let w = size.width
        let h = size.height
        let thickness = max(h * 0.08, 5)
        let floorLen = w * 0.5
        let hinge = CGPoint(x: w * 0.38, y: h - thickness)
        // The lid's angle from the floor: 180 = flat (pointing away), 90 = upright.
        let a = (180 - angle) * Double.pi / 180
        let dx = CGFloat(cos(a)) * floorLen
        let dy = CGFloat(sin(a)) * floorLen
        let lidEnd = CGPoint(x: hinge.x - dx, y: hinge.y - dy)
        return ZStack {
            // The table.
            Path { p in
                p.move(to: CGPoint(x: 0, y: h - 1))
                p.addLine(to: CGPoint(x: w, y: h - 1))
            }
            .stroke(HushTheme.haze.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6]))
            // The floor half, flat.
            Path { p in
                p.move(to: hinge)
                p.addLine(to: CGPoint(x: hinge.x + floorLen, y: hinge.y))
            }
            .stroke(HushTheme.mist, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            // The lid half, raised.
            Path { p in
                p.move(to: hinge)
                p.addLine(to: lidEnd)
            }
            .stroke(HushTheme.gold, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            Circle()
                .fill(HushTheme.goldDeep)
                .frame(width: thickness * 1.6, height: thickness * 1.6)
                .position(hinge)
        }
    }

    private func halves(size: CGSize, lift: ScreenSide) -> some View {
        let gap: CGFloat = 6
        let halfW = (size.width - gap) / 2
        let r = RoundedRectangle(cornerRadius: min(halfW, size.height) * 0.12, style: .continuous)
        return HStack(spacing: gap) {
            half(r, lifted: lift == .left, width: halfW, height: size.height)
            half(r, lifted: lift == .right, width: halfW, height: size.height)
        }
    }

    private func half(_ r: RoundedRectangle, lifted: Bool, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            r.fill(lifted ? HushTheme.gold.opacity(0.22) : HushTheme.surfaceRaised)
            r.stroke(lifted ? HushTheme.gold : HushTheme.haze.opacity(0.6), lineWidth: lifted ? 4 : 2)
            VStack(spacing: 6) {
                Image(systemName: lifted ? "arrow.up" : "square.grid.2x2.fill")
                    .font(.system(size: min(width, height) * 0.22, weight: .black, design: .rounded))
                Text(lifted ? "Lift this half" : "Floor")
                    .font(.system(size: max(min(width, height) * 0.1, 12), weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(lifted ? HushTheme.goldLight : HushTheme.mist)
            .padding(8)
        }
        .frame(width: width, height: height)
    }
}

/// Book pose (landscape on a Duo): "Stand it up like a little laptop", with the half to lift marked. Drawn in the
/// interface's own orientation (never turned round).
struct StandUpCard: View {
    let insets: EdgeInsets
    let liftSide: ScreenSide
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            HushTheme.backdrop
            HStack(spacing: 36) {
                DuoDiagram(style: .halves(lift: liftSide), reduceMotion: reduceMotion)
                    .frame(width: 300, height: 200)
                VStack(alignment: .leading, spacing: 14) {
                    HushOverline(text: "Hush", color: HushTheme.gold)
                    Text("Stand it up like a little laptop")
                        .font(HushType.title(false))
                        .foregroundStyle(HushTheme.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The glowing half is the chest's lid. Lift it, and keep the other half flat.")
                        .font(HushType.body(false))
                        .foregroundStyle(HushTheme.mist)
                        .fixedSize(horizontal: false, vertical: true)
                    DuoDiagram(style: .tabletop(angle: 115), reduceMotion: reduceMotion)
                        .frame(width: 140, height: 80)
                }
                .frame(maxWidth: 360, alignment: .leading)
            }
            .padding(.leading, insets.leading + 24)
            .padding(.trailing, insets.trailing + 24)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}

/// Shut, on the cover display: the sleeping mimic and "Open to carry on".
struct CoverCard: View {
    let midRun: Bool
    let reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        ZStack {
            HushTheme.backdrop
            VStack(spacing: 18) {
                SleepingMimic(breathe: breathe)
                    .frame(width: 180, height: 120)
                Text(midRun ? "Open to carry on" : "Open me… gently")
                    .font(HushType.title(true))
                    .foregroundStyle(HushTheme.parchment)
                    .multilineTextAlignment(.center)
                Text(midRun ? "The mimic is fast asleep. So is your torch." : "There's gold in here. And something else.")
                    .font(HushType.body(true))
                    .foregroundStyle(HushTheme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The mimic asleep: a closed eye on the lid's wood, a little "z".
struct SleepingMimic: View {
    var breathe: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hushHex: 0x8A5A32), Color(hushHex: 0x5C3A1F)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: h * 0.22, style: .continuous)
                        .stroke(Color(hushHex: 0x3A3F42), lineWidth: 6))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.3, y: h * 0.5))
                    p.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.5), control: CGPoint(x: w * 0.5, y: h * 0.68))
                }
                .stroke(HushTheme.parchment, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Text("z")
                    .font(.system(size: h * 0.3, weight: .black, design: .rounded))
                    .foregroundStyle(HushTheme.goldLight)
                    .position(x: w * 0.82, y: breathe ? h * 0.12 : h * 0.24)
                    .opacity(breathe ? 1 : 0.5)
            }
            .scaleEffect(breathe ? 1.03 : 1)
        }
        .accessibilityHidden(true)
    }
}
