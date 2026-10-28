import Foundation
import Testing
@testable import Hush

// MARK: - Helpers

/// A fake Duo hinge: the hand's angle as a function of time, reported like the real hinge (at `rate` Hz, and only
/// when it moved at least `step` degrees: nothing while still), with display frames at 120 Hz asking for the lid.
@MainActor
private final class FakeHinge {
    let source: HingeLidSource
    private(set) var time: Double = 100
    private var lastReported: Double?
    private var nextReport: Double = 0
    static let frame = 1.0 / 120
    static let step = 0.25
    /// Every frame's lid from the last `run`.
    private(set) var lids: [LidInput] = []

    init(source: HingeLidSource) {
        self.source = source
        source.clock = { [weak self] in self?.time ?? 0 }
    }

    /// Runs for `duration` s; `angle` gives the hand's angle at local time 0…duration. `frames: false` asks no lid
    /// (the game paused). Returns the last lid.
    @discardableResult
    func run(_ duration: Double, rate: Double = 30, frames: Bool = true,
             angle: (Double) -> Double) -> LidInput {
        let start = time
        let steps = Int((duration / Self.frame).rounded())
        var lid = LidInput()
        lids.removeAll()
        for _ in 0..<steps {
            time += Self.frame
            let local = time - start
            if time >= nextReport {
                let a = angle(local)
                var moved = true
                if let previous = lastReported { moved = abs(a - previous) >= Self.step }
                if moved {
                    source.ingest(angleDegrees: a, at: time)
                    lastReported = a
                }
                nextReport = time + 1 / rate
            }
            if frames {
                lid = source.lid(at: time)
                lids.append(lid)
            }
        }
        return lid
    }

    var speeds: [Double] { lids.map { $0.speed } }
}

/// Renders `seconds` of `synth` and reports the RMS, the peak, the share of samples over 0.6 and whether every
/// sample was finite. `each` runs before every 512-frame block (send beds and cues there).
private func feelRender(_ synth: FeelSynth, seconds: Double,
                        each: (Int, Double) -> Void = { _, _ in }) -> (rms: Double, peak: Float, hot: Double,
                                                                       finite: Bool) {
    let frames = 512
    let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { buffer.deallocate() }
    let blocks = max(Int(seconds * Double(synth.sampleRate) / Double(frames)), 1)
    var sum: Double = 0
    var peak: Float = 0
    var hot = 0
    var finite = true
    for block in 0..<blocks {
        each(block, Double(block * frames) / Double(synth.sampleRate))
        synth.render(frames: frames, into: buffer)
        for index in 0..<frames {
            let value = buffer[index]
            if !value.isFinite { finite = false }
            peak = max(peak, abs(value))
            sum += Double(value * value)
            if abs(value) > 0.6 { hot += 1 }
        }
    }
    let count = Double(blocks * frames)
    return ((sum / count).squareRoot(), peak, Double(hot) / count, finite)
}

private func play(speed: Double, noise: Double = 0.1, stage: MimicStage = .asleep, openness: Double = 0.5,
                  drag: Double = 0, torch: Double = 80, playing: Bool = true) -> HeistTelemetry {
    HeistTelemetry(lidSpeed: speed, openness: openness, noise: noise, stage: stage, dragSpeed: drag,
                   torchRemaining: torch, playing: playing)
}

/// One display frame (or, with `frames: false`, one tick of a paused game) with the hand held at `angle`; returns
/// `canResume` after it (the App polls it every frame while paused).
@MainActor
@discardableResult
private func feelHold(_ hinge: FakeHinge, _ angle: Double, frames: Bool = true) -> Bool {
    hinge.run(FakeHinge.frame, frames: frames) { _ in angle }
    return hinge.source.canResume
}

/// R7: a stick-slip hinge under a steady 10°/s hand (DEVICE-RISKS-1 item 2), from 110°: silent for `stick` s, then
/// (optionally a `creep`° report and, one report later) a 2° jump, then 0.5° steps at the hand's 10°/s for 0.3 s;
/// repeated. The Node-port numbers for these traces are in `design/notes/feel-R7.md`.
private func feelStickSlip(stick: Double, creep: Double = 0, rate: Double = 30) -> (Double) -> Double {
    let hand = 10.0
    let slide = 0.3
    let travel = creep + 2 + hand * slide
    let period = stick + (creep > 0 ? 1 / rate : 0) + slide
    return { t in
        let k = (t / period).rounded(.down)
        var a = 110 + k * travel
        var u = t - k * period
        if u < stick { return a }
        u -= stick
        if creep > 0 {
            a += creep
            if u < 1 / rate { return a }
            u -= 1 / rate
        }
        a += 2 + 0.5 * (u * 20 + 1e-9).rounded(.down)
        return min(a, 110 + (k + 1) * travel)
    }
}

/// R7: the lid noise (before any mimic multiplier) Core's rule adds for these 120 Hz frame speeds while opening, with
/// the loud onset: only once the lid has been over the quiet line for `Tuning.loudOnsetSeconds`.
private func feelLidNoise(_ speeds: [Double]) -> Double {
    let dt = 1.0 / 120
    var noise = 0.0
    var loud = 0.0
    for speed in speeds {
        let before = loud
        loud = speed > Tuning.quietSpeed ? loud + dt : 0
        let share = min(max((loud - max(before, Tuning.loudOnsetSeconds)) / dt, 0), 1)
        noise += Noise.lidRate(speed: speed) * share * dt
    }
    return noise
}

/// Every heist event, once.
private let everyEvent: [HeistEvent] = [
    .chestArrived(index: 0, tier: .wooden, mimic: .snorer, name: "Snoring Sam"),
    .chestArrived(index: 6, tier: .royal, mimic: .dreamer, name: "Dozy Dot"),
    .lidCracked,
    .itemRevealed(id: 1, kind: .copper), .itemRevealed(id: 2, kind: .gem(.ruby)),
    .itemRevealed(id: 3, kind: .relic(RelicID("relic01"))), .itemRevealed(id: 4, kind: .oil),
    .itemPicked(id: 1, kind: .copper), .itemDropped(id: 1),
    .itemBagged(id: 1, kind: .copper, value: 8), .itemBagged(id: 5, kind: .silver, value: 30),
    .itemBagged(id: 2, kind: .gem(.sapphire), value: 90), .itemBagged(id: 3, kind: .relic(RelicID("relic01")),
                                                                      value: 400),
    .itemBagged(id: 4, kind: .oil, value: 0), .oilAdded(seconds: 8),
    .stageChanged(from: .asleep, to: .stirring), .stageChanged(from: .stirring, to: .waking),
    .stageChanged(from: .waking, to: .stirring), .stageChanged(from: .waking, to: .biting), .dreamTwitch,
    .bitten(lostValue: 120), .banked(value: 640, items: 4, hushed: true), .relicFound(RelicID("relic01")),
    .relicFound(RelicID("relic02")), .torchLow, .torchOut, .newBest, .finished,
    .chainUp(count: 2, multiplier: 1.2), .chainUp(count: 9, multiplier: 1.5), .chainBroken(count: 3),
    .biteCost(lostValue: 120, seconds: 10), .biteCost(lostValue: 0, seconds: 10),
]

@MainActor
struct FeelTests {
    // MARK: - Speed from the hinge (the skill)

    @Test func tenDegreesPerSecondReadsTen() {
        for rate in [30.0, 25.0] {
            let hinge = FakeHinge(source: HingeLidSource())
            hinge.run(0.5, rate: rate) { _ in 120 }
            hinge.run(1.5, rate: rate) { t in 120 + 10 * t }
            let tail = hinge.speeds.suffix(60)
            #expect((tail.min() ?? 0) >= 9)
            #expect((tail.max() ?? 99) <= 11)
        }
    }

    @Test func stillForHalfASecondReadsUnderOne() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(1.5) { t in 120 + 10 * t }
        // The hand stops: the Duo sends nothing at all.
        let lid = hinge.run(0.5) { _ in 135 }
        #expect(lid.speed < 1)
        #expect(lid.speed >= 0)
        // And it keeps falling to nothing (CI's STILL check reads < 1.0 after 1.5 s).
        let later = hinge.run(1.0) { _ in 135 }
        #expect(later.speed < 0.05)
    }

    @Test func aSampleAfterALongGapDoesNotSpike() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.3) { _ in 120 }
        hinge.run(1.0) { t in 120 + 20 * t }
        // Two seconds of silence, then one report a degree away, then (much later) a 9° jump.
        hinge.run(2.0) { _ in 140 }
        hinge.run(0.5) { _ in 141 }
        #expect((hinge.speeds.max() ?? 99) < 1)
        hinge.run(0.6) { _ in 150 }
        #expect((hinge.speeds.max() ?? 99) < 1)
        // A real move after the silence ramps up to its true speed and never overshoots it.
        hinge.run(1.0) { t in 150 - 12 * t }
        #expect((hinge.speeds.max() ?? 99) <= 13.2)
        #expect((hinge.speeds.last ?? 0) > 10.5)
    }

    @Test func aSlamReadsLoudAtOnce() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(1.0) { _ in 150 }
        hinge.run(0.4) { t in 150 - 120 * t }
        let speeds = hinge.speeds
        // Past the loud line within 0.15 s of the first report, and close to the true 120°/s by 0.3 s.
        #expect(speeds.count == 48)
        #expect(speeds[18] > Tuning.loudSpeed)
        #expect(speeds[36] > 90)
        #expect((speeds.max() ?? 999) < 140)
    }

    @Test func reportJitterDoesNotChangeTheSpeedMuch() {
        let hinge = FakeHinge(source: HingeLidSource())
        var dice = FeelDice(seed: 21)
        hinge.run(0.5) { _ in 120 }
        // ±0.5° of report noise on a steady 10°/s.
        hinge.run(2.0) { t in 120 + 10 * t + dice.range(-0.5, 0.5) }
        let tail = hinge.speeds.suffix(120)
        #expect((tail.min() ?? 0) > 7)
        #expect((tail.max() ?? 99) < 13.5)
    }

    @Test func handTremorAtRestStaysQuiet() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 130 }
        hinge.run(3.0) { t in 130 + 0.5 * sin(2 * Double.pi * 6 * t) }
        let tail = hinge.speeds.suffix(240)
        #expect((tail.max() ?? 99) < Tuning.quietSpeed * 0.5)
    }

    @Test func speedIsNeverNegativeOrNaN() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.3) { _ in 120 }
        hinge.run(1.0) { t in 120 + 30 * sin(2 * Double.pi * 1.5 * t) }
        hinge.source.ingest(angleDegrees: Double.nan, at: hinge.time)
        hinge.source.ingest(angleDegrees: 400, at: hinge.time - 5)
        let lid = hinge.run(0.2) { _ in 180 }
        for speed in hinge.speeds {
            #expect(speed.isFinite)
            #expect(speed >= 0)
        }
        #expect(lid.openness >= 0 && lid.openness <= 1)
    }

    // MARK: - The lid from the hinge

    @Test func noHingeMeansAShutStillLid() {
        let source = HingeLidSource()
        #expect(source.hasHinge == false)
        #expect(source.angle == nil)
        let lid = source.lid(at: 1)
        #expect(lid == LidInput())
        #expect(lid.inShutZone)
        #expect(source.isClosing == false)
    }

    @Test func angleMapsToOpennessAndZones() {
        let shut = HingeLidSource.lidInput(angle: Tuning.shutAngle, speed: 0)
        #expect(abs(shut.openness) < 1e-9)
        #expect(shut.inShutZone)
        #expect(HingeLidSource.lidInput(angle: Tuning.shutZoneAngle, speed: 0).inShutZone)
        #expect(HingeLidSource.lidInput(angle: Tuning.shutZoneAngle + 0.5, speed: 0).inShutZone == false)
        let wide = HingeLidSource.lidInput(angle: Tuning.wideAngle, speed: 0)
        #expect(abs(wide.openness - 1) < 1e-9)
        #expect(wide.tooWide == false)
        #expect(HingeLidSource.lidInput(angle: Tuning.tooWideAngle + 0.5, speed: 0).tooWide)
        #expect(HingeLidSource.lidInput(angle: 60, speed: 0).openness == 0)
        #expect(HingeLidSource.lidInput(angle: 180, speed: 0).openness == 1)
        #expect(HingeLidSource.lidInput(angle: Double.nan, speed: Double.nan).speed == 0)
        #expect(HingeLidSource.lidInput(angle: 130, speed: -4).speed == 0)
    }

    @Test func theFilteredLidSettlesOnTheHinge() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 105 }
        #expect(hinge.source.hasHinge)
        #expect(hinge.lids.last?.inShutZone == true)
        hinge.run(4.0) { t in min(105 + 10 * t, 140) }
        let lid = hinge.run(1.0) { _ in 140 }
        let expected = Lid.openness(angle: 140)
        #expect(abs(lid.openness - expected) < 0.02)
        #expect(lid.inShutZone == false)
        #expect(abs((hinge.source.angle ?? 0) - 140) < 1)
        // The same frame asked twice gives the same answer.
        let again = hinge.source.lid(at: hinge.time)
        #expect(again == lid)
    }

    @Test func closingNeedsTheFullDwellAndClearsOnReopening() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(0.3) { t in 120 - 60 * t / 0.3 }
        hinge.run(0.15) { _ in 60 }
        #expect(hinge.source.isClosing == false)
        hinge.run(0.5) { _ in 60 }
        #expect(hinge.source.isClosing)
        hinge.run(0.5) { t in 60 + 60 * min(t / 0.3, 1) }
        #expect(hinge.source.isClosing == false)
        // A dip under 70° shorter than the dwell never pauses.
        hinge.run(0.1) { t in 120 - 54 * t / 0.1 }
        hinge.run(0.1) { _ in 66 }
        hinge.run(0.3) { t in 66 + 54 * min(t / 0.1, 1) }
        #expect(hinge.source.isClosing == false)
    }

    /// REVIEW-1-duo P1-4: an upright lid resting at about 90° (the Duo reads ±5°) never pauses the game.
    @Test func anUprightRestNeverPauses() {
        #expect(FeelClosingGate.closeBelow == 70)
        #expect(FeelClosingGate.reopenAbove == 78)
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(0.5) { t in 120 - 35 * min(t / 0.4, 1) }
        var paused = false
        for _ in 0..<30 {
            hinge.run(0.1) { t in 85 + 5 * sin(2 * Double.pi * 1.3 * t) }
            if hinge.source.isClosing { paused = true }
        }
        #expect(paused == false)
    }

    @Test func closingIsJudgedFromReportsWhileThePauseStopsTheFrames() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        // The game pauses (no frames) as the lid folds to 60° and the hinge goes still.
        hinge.run(0.3, frames: false) { t in 120 - 60 * t / 0.3 }
        hinge.run(0.6, frames: false) { _ in 60 }
        #expect(hinge.source.closing(at: hinge.time))
        #expect(hinge.source.isClosing)
        // Lifting the lid back up resumes, still without frames.
        hinge.run(0.5, frames: false) { t in 60 + 60 * min(t / 0.3, 1) }
        #expect(hinge.source.isClosing == false)
        #expect(abs((hinge.source.angle ?? 0) - 120) < 3)
    }

    @Test func closingGateHasHysteresis() {
        var gate = FeelClosingGate()
        let below = FeelClosingGate.closeBelow - 1
        gate.update(angle: below, at: 0)
        #expect(gate.isClosing(at: 0.39) == false)
        #expect(gate.isClosing(at: 0.41))
        gate.update(angle: below, at: 0.5)
        #expect(gate.latched)
        // Between the closing line and the reopen line it stays closed.
        gate.update(angle: FeelClosingGate.reopenAbove - 1, at: 0.6)
        #expect(gate.isClosing(at: 0.6))
        gate.update(angle: FeelClosingGate.reopenAbove + 0.5, at: 0.7)
        #expect(gate.isClosing(at: 0.7) == false)
        gate.update(angle: Double.nan, at: 0.8)
        #expect(gate.isClosing(at: 5) == false)
    }

    @Test func resetKeepsTheHingeButForgetsTheMotion() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.3) { _ in 120 }
        hinge.run(0.5) { t in 120 + 40 * t }
        #expect(hinge.source.speed > 20)
        hinge.source.reset()
        #expect(hinge.source.hasHinge)
        #expect(hinge.source.speed == 0)
        let lid = hinge.run(0.6) { _ in 140 }
        #expect(lid.speed < 1)
    }

    @Test func speedEstimatorBasics() {
        var estimator = FeelSpeedEstimator()
        let none = estimator.speed(at: 1)
        #expect(none == 0)
        estimator.sample(100, at: 1)
        estimator.sample(Double.nan, at: 1.01)
        let first = estimator.speed(at: 1.02)
        #expect(first == 0)
        var t = 1.0
        for _ in 0..<60 {
            t += 1.0 / 60
            estimator.sample(100 + 20 * (t - 1), at: t)
            _ = estimator.speed(at: t)
        }
        let moving = estimator.speed(at: t + 0.001)
        #expect(moving > 18 && moving < 22)
        let same = estimator.speed(at: t + 0.001)
        #expect(same == moving)
        let older = estimator.speed(at: t - 1)
        #expect(older == moving)
        estimator.reset()
        let cleared = estimator.speed(at: t + 1)
        #expect(cleared == 0)
    }

    // MARK: - The lid slider (no hinge)

    @Test func sliderSpeedIsFractionPerSecondTimesTheLidTravel() {
        let slider = SliderLidSource()
        #expect(abs(slider.degreesPerFraction - (Tuning.wideAngle - Tuning.shutAngle)) < 1e-9)
        var t = 50.0
        slider.touch(began: true, ended: false, fraction: 0.3, time: t)
        _ = slider.lid(at: t)
        // 0.15 of the strip per second for a second (≈ 9.75°/s), touches and frames at 120 Hz.
        var lid = LidInput()
        for step in 1...120 {
            t += 1.0 / 120
            slider.touch(began: false, ended: false, fraction: 0.3 + 0.15 * Double(step) / 120, time: t)
            lid = slider.lid(at: t)
        }
        let expected = 0.15 * (Tuning.wideAngle - Tuning.shutAngle)
        #expect(abs(lid.speed - expected) < 1)
        #expect(abs(lid.openness - 0.15) < 1e-6)
        // The finger holds still (no touch events): the speed decays like a still hinge.
        for _ in 0..<72 {
            t += 1.0 / 120
            lid = slider.lid(at: t)
        }
        #expect(lid.speed < 1)
        slider.touch(began: false, ended: true, fraction: 0.45, time: t)
        #expect(slider.isTouching == false)
    }

    @Test func sliderDragIsRelativeAndNeverJumps() {
        let slider = SliderLidSource()
        // A finger lands high on the strip: the lid stays shut.
        slider.touch(began: true, ended: false, fraction: 0.8, time: 1)
        let landed = slider.lid(at: 1)
        #expect(landed.openness == 0)
        #expect(landed.inShutZone)
        #expect(landed.tooWide == false)
        // Pulling down past shut, then up: the lid opens at once by the distance moved up.
        slider.touch(began: false, ended: false, fraction: 0.6, time: 1.1)
        #expect(slider.openness == 0)
        slider.touch(began: false, ended: false, fraction: 0.7, time: 1.2)
        #expect(abs(slider.openness - 0.1) < 1e-9)
        #expect(slider.lid(at: 1.2).inShutZone)
        slider.touch(began: false, ended: false, fraction: 0.9, time: 1.3)
        #expect(abs(slider.openness - 0.3) < 1e-9)
        #expect(slider.lid(at: 1.3).inShutZone == false)
        slider.touch(began: false, ended: true, fraction: 0.9, time: 1.4)
        // A new touch elsewhere keeps the lid where it is.
        slider.touch(began: true, ended: false, fraction: 0.1, time: 2)
        #expect(abs(slider.openness - 0.3) < 1e-9)
        // Never past wide; NaN is ignored.
        slider.touch(began: false, ended: false, fraction: 1.0, time: 2.1)
        slider.touch(began: false, ended: false, fraction: Double.nan, time: 2.2)
        #expect(slider.openness <= 1)
        #expect(slider.openness.isFinite)
        slider.reset(openness: 0)
        #expect(slider.openness == 0)
        #expect(slider.lid(at: 3).speed == 0)
    }

    // MARK: - The creak curve (the hero)

    @Test func creakIsSilentBelowTheQuietSpeedSoftToTwentyLoudPastThirty() {
        var speed = 0.0
        while speed <= Tuning.quietSpeed {
            #expect(FeelSoundBook.creakLevel(speed: speed) == 0)
            #expect(FeelHapticBook.creakLevel(speed: speed) == 0)
            var bed = FeelBed()
            FeelSoundBook.applyCreak(to: &bed, speed: speed)
            #expect(bed.creak == 0)
            #expect(bed.squeal == 0)
            #expect(bed.grainRate == 0)
            speed += 0.25
        }
        #expect(FeelSoundBook.creakLevel(speed: Tuning.quietSpeed + 2) > 0)
        #expect(FeelSoundBook.creakLevel(speed: 20) <= FeelSoundBook.softLevel + 1e-9)
        #expect(FeelSoundBook.creakLevel(speed: Tuning.loudSpeed) >= FeelSoundBook.loudLevel - 1e-9)
        #expect(FeelSoundBook.creakLevel(speed: 200) <= 1)
        #expect(FeelSoundBook.creakLevel(speed: Double.nan) == 0)
        // Monotonic and continuous: it swells and fades with the hand, never switching on with a click.
        var previous = 0.0
        speed = 0
        while speed <= 120 {
            let level = FeelSoundBook.creakLevel(speed: speed)
            #expect(level >= previous - 1e-12)
            #expect(level - previous < 0.02)
            previous = level
            speed += 0.05
        }
        // The squeal only past ~25°/s; the groan's pitch rises 140 → 420 Hz.
        #expect(FeelSoundBook.squealLevel(speed: 25) == 0)
        #expect(FeelSoundBook.squealLevel(speed: 32) > 0)
        #expect(abs(FeelSoundBook.squealLevel(speed: 45) - 1) < 1e-9)
        #expect(abs(FeelSoundBook.groanHz(speed: 8) - 140) < 1e-9)
        #expect(abs(FeelSoundBook.groanHz(speed: 90) - 420) < 1e-9)
        #expect(FeelSoundBook.groanHz(speed: 30) > FeelSoundBook.groanHz(speed: 15))
        #expect(FeelSoundBook.grainRate(speed: 40) > FeelSoundBook.grainRate(speed: 12))
    }

    @Test func creakRendersSilentBelowTheQuietSpeedAndGrowsWithSpeed() {
        let silent = FeelSynth(sampleRate: 48_000)
        silent.send(.bed(FeelSoundBook.homeBed(speed: Tuning.quietSpeed - 0.1, openness: 0.5,
                                               master: FeelAudioEngine.masterGain)))
        let quiet = feelRender(silent, seconds: 0.5)
        #expect(quiet.finite)
        #expect(quiet.peak == 0)

        var levels: [Double] = []
        for speed in [Tuning.quietSpeed + 3, 30.0, 60.0] {
            let synth = FeelSynth(sampleRate: 48_000)
            var bed = FeelSoundBook.homeBed(speed: speed, openness: 0.5, master: FeelAudioEngine.masterGain)
            bed.glide = 0.005
            synth.send(.bed(bed))
            let result = feelRender(synth, seconds: 1.5)
            #expect(result.finite)
            #expect(result.peak < 1)
            levels.append(result.rms)
        }
        // Soft is clearly there (above −46 dBFS), loud is much louder (−6 dB or more), and flat out stays sane.
        #expect(levels[0] > 0.005)
        #expect(levels[1] > levels[0] * 2)
        #expect(levels[2] > levels[1])
        #expect(levels[2] < 0.3)
    }

    @Test func creakFollowsASweepWithoutBlowingUp() {
        // The lid speeds up from 0 to 70°/s and back over 4 s, beds at 60 Hz (the director's rate).
        let synth = FeelSynth(sampleRate: 48_000)
        let result = feelRender(synth, seconds: 4) { _, t in
            let speed = 70 * sin(Double.pi * t / 4)
            synth.send(.bed(FeelSoundBook.homeBed(speed: speed, openness: 0.6, master: FeelAudioEngine.masterGain)))
        }
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(result.rms > 0.01)
        #expect(result.hot < 0.01)
    }

    // MARK: - The bed

    @Test func theBedFollowsTheMimicsStage() {
        let master = FeelAudioEngine.masterGain
        let asleep = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.1, stage: .asleep), master: master,
                                            ambience: 1)
        #expect(asleep.creak == 0)
        #expect(asleep.snore > 0)
        #expect(asleep.motif == 1)
        #expect(asleep.motifDensity > 0.8)
        #expect(asleep.growl == 0)
        #expect(asleep.drone > 0)
        #expect(asleep.dripRate > 0)
        #expect(asleep.crackle > 0)
        // A shut lid muffles the snore; a lighter sleep thins the tiptoe.
        let shut = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.1, openness: 0), master: master,
                                          ambience: 1)
        #expect(shut.snore < asleep.snore)
        let lighter = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.33), master: master, ambience: 1)
        #expect(lighter.motifDensity < asleep.motifDensity)
        #expect(lighter.snore < asleep.snore)

        let stirring = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.5, stage: .stirring),
                                              master: master, ambience: 1)
        #expect(stirring.snore == 0)
        #expect(stirring.motif > 0)
        #expect(stirring.motifDensity <= 0.3)
        #expect(stirring.growl == 0)

        let waking = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.85, stage: .waking), master: master,
                                            ambience: 1)
        #expect(waking.snore == 0)
        #expect(waking.motif == 0)
        #expect(waking.growl > 0)
        let wider = FeelSoundBook.heistBed(telemetry: play(speed: 4, noise: 0.97, stage: .waking), master: master,
                                           ambience: 1)
        #expect(wider.growl > waking.growl)

        #expect(FeelSoundBook.heartInterval(stage: .asleep) == nil)
        #expect(abs((FeelSoundBook.heartInterval(stage: .stirring) ?? 0) - 1.0) < 1e-9)
        #expect(abs((FeelSoundBook.heartInterval(stage: .waking) ?? 0) - 60.0 / 110) < 1e-9)
    }

    @Test func notPlayingKeepsOnlyTheCreakAndTheAmbience() {
        let master = FeelAudioEngine.masterGain
        let resting = FeelSoundBook.heistBed(telemetry: play(speed: 30, noise: 0.9, stage: .waking, drag: 900,
                                                             playing: false), master: master, ambience: 0)
        #expect(resting.master == master)
        #expect(resting.snore == 0)
        #expect(resting.growl == 0)
        #expect(resting.motif == 0)
        #expect(resting.rattle == 0)
        #expect(resting.drone == 0)
        #expect(resting.crackle == 0)
        #expect(resting.dripRate == 0)
        // The hinge still creaks (a little softer): it is the phone's own hinge.
        let live = FeelSoundBook.heistBed(telemetry: play(speed: 30), master: master, ambience: 1)
        #expect(resting.creak > 0)
        #expect(resting.creak < live.creak)
        let idle = FeelSoundBook.idleBed(master: master)
        #expect(idle.hasLayers == false)
        #expect(idle.glide >= FeelSoundBook.frameGlide)
    }

    @Test func theTorchCracklesLouderAtTheEndAndDragsRattle() {
        let master: Float = 1
        let normal = FeelSoundBook.heistBed(telemetry: play(speed: 0, torch: 60), master: master, ambience: 1)
        let low = FeelSoundBook.heistBed(telemetry: play(speed: 0, torch: 4), master: master, ambience: 1)
        let out = FeelSoundBook.heistBed(telemetry: play(speed: 0, torch: 0), master: master, ambience: 1)
        #expect(low.crackle > normal.crackle)
        #expect(low.crackleRate > normal.crackleRate)
        #expect(out.crackle == 0)
        let gentle = FeelSoundBook.heistBed(telemetry: play(speed: 0, drag: 200), master: master, ambience: 1)
        let fast = FeelSoundBook.heistBed(telemetry: play(speed: 0, drag: 900), master: master, ambience: 1)
        #expect(gentle.rattle == 0)
        #expect(fast.rattle > 0)
        #expect(fast.rattleRate > 0)
        let home = FeelSoundBook.homeBed(speed: 25, openness: 0.4, master: master)
        #expect(home.creak > 0)
        #expect(home.snore == 0)
        #expect(home.drone == 0)
    }

    // MARK: - Moments

    @Test func everyRecipeIsSane() {
        var dice = FeelDice(seed: 11)
        var recipes: [[FeelSynthCommand]] = [
            FeelSoundBook.heartbeat(fast: true), FeelSoundBook.heartbeat(fast: false), FeelSoundBook.wakeSting(),
            FeelSoundBook.sigh(), FeelSoundBook.relicChoir(), FeelSoundBook.oilGlug(), FeelSoundBook.lidCracked(),
            FeelSoundBook.torchLow(), FeelSoundBook.torchTick(), FeelSoundBook.torchOut(), FeelSoundBook.newBest(),
            FeelSoundBook.uiTap(), FeelSoundBook.uiConfirm(),
        ]
        recipes.append(FeelSoundBook.snort(dice: &dice))
        recipes.append(FeelSoundBook.chomp(dice: &dice))
        recipes.append(FeelSoundBook.itemDropped(dice: &dice))
        recipes.append(FeelSoundBook.celebrate(dice: &dice))
        recipes.append(FeelSoundBook.bank(value: 20, hushed: false, dice: &dice))
        recipes.append(FeelSoundBook.bank(value: 9_000, hushed: true, dice: &dice))
        // R2 moments.
        for count in [0, 1, 2, 5, 9] {
            recipes.append(FeelSoundBook.chainUp(count: count, dice: &dice))
            recipes.append(FeelSoundBook.chainUp(count: count, delay: FeelSoundBook.chainAfterBank, dice: &dice))
        }
        recipes.append(FeelSoundBook.chainBroken(dice: &dice))
        recipes.append(FeelSoundBook.chainBroken(delay: 1.1, dice: &dice))
        recipes.append(FeelSoundBook.goldenArrived(dice: &dice))
        for value in [0, 8, 120, 5_000, Int.max] {
            recipes.append(FeelSoundBook.coinSpill(lostValue: value, seconds: 10, dice: &dice))
        }
        recipes.append(FeelSoundBook.glimmerTwinkle(dice: &dice))
        // R3 moments.
        recipes.append(FeelSoundBook.creakAccent(dice: &dice))
        recipes.append(FeelSoundBook.stageCue(from: .asleep, to: .stirring, dice: &dice))
        recipes.append(FeelSoundBook.stageCue(from: .waking, to: .asleep, dice: &dice))
        for urgent in [false, true] {
            for tock in [false, true] {
                recipes.append(FeelSoundBook.torchTick(urgent: urgent, tock: tock))
            }
        }
        for tier in ChestTier.allCases {
            recipes.append(FeelSoundBook.chestArrived(tier: tier, dice: &dice))
        }
        let kinds: [LootKind] = [.copper, .silver, .gem(.ruby), .gem(.emerald), .gem(.sapphire), .gem(.amethyst),
                                 .relic(RelicID("relic07")), .oil]
        for kind in kinds {
            recipes.append(FeelSoundBook.itemPicked(kind, dice: &dice))
            recipes.append(FeelSoundBook.itemBagged(kind, dice: &dice))
            recipes.append(FeelSoundBook.itemRevealed(kind, dice: &dice))
        }
        for recipe in recipes {
            #expect(!recipe.isEmpty)
            for command in recipe {
                #expect(command.gain.isFinite)
                #expect(command.gain > 0)
                #expect(command.gain <= 0.4)
                #expect(command.delay >= 0)
                #expect(command.delay < 3)
            }
        }
        // The CHOMP is the biggest sound; a coin is small and bright.
        let chompPeak = FeelSoundBook.chomp(dice: &dice).map { $0.gain }.max() ?? 0
        let coinPeak = FeelSoundBook.coinClink(dice: &dice).map { $0.gain }.max() ?? 1
        #expect(chompPeak > coinPeak * 3)
        let coin = FeelSoundBook.coinClink(dice: &dice)
        var bright = true
        for command in coin {
            if case .fm(let fm) = command { bright = bright && fm.carrier > 2000 } else { bright = false }
        }
        #expect(bright)
        // Gems are pitched by colour.
        #expect(FeelSoundBook.gemHz(.ruby) < FeelSoundBook.gemHz(.amethyst))
    }

    @Test func bankCascadeCountsByValueAndItsHapticLandsWithIt() {
        #expect(FeelSoundBook.cascadeCount(value: 0) == 6)
        #expect(FeelSoundBook.cascadeCount(value: 50) == 6)
        #expect(FeelSoundBook.cascadeCount(value: 1_000_000) == 14)
        var previous = 0
        for value in stride(from: 0, through: 20_000, by: 37) {
            let count = FeelSoundBook.cascadeCount(value: value)
            #expect(count >= previous)
            #expect(count >= 6 && count <= 14)
            previous = count
        }
        let times = FeelSoundBook.cascadeTimes(count: 10)
        #expect(times.count == 10)
        for index in 1..<times.count { #expect(times[index] > times[index - 1]) }
        #expect((times.first ?? 0) >= 0.1)
        #expect((times.last ?? 9) <= 0.95)
        // The ka-ching comes after the cascade.
        #expect(Double(FeelSoundBook.kaChingAt) > (times.last ?? 9))
        let cue = FeelHapticBook.bank(cascade: times)
        for time in times {
            #expect(cue.notes.contains { abs($0.time - time) < 1e-9 && $0.kind == .transient })
        }
        var dice = FeelDice(seed: 3)
        let small = FeelSoundBook.bank(value: 20, hushed: false, dice: &dice)
        let big = FeelSoundBook.bank(value: 5_000, hushed: false, dice: &dice)
        #expect(big.count > small.count)
    }

    @Test func motifIsAMinorKeyOstinatoThatThins() {
        var notes = 0
        var downbeats = 0
        for step in 0..<FeelSynth.motifSteps {
            if let note = FeelSynth.motifNote(step) {
                notes += 1
                #expect(note >= -2 && note <= 8)
                if FeelSynth.motifWeight(step) >= 1 { downbeats += 1 }
            }
        }
        #expect(notes >= 16)
        #expect(downbeats == 4)
        #expect(FeelSynth.motifNote(FeelSynth.motifSteps) == nil)
        // Density 0.3 keeps only the strongest beats.
        var kept = 0
        for step in 0..<FeelSynth.motifSteps where FeelSynth.motifNote(step) != nil {
            if FeelSynth.motifWeight(step) >= 1.001 - 0.3 { kept += 1 }
        }
        #expect(kept > 0)
        #expect(kept < notes / 2)
    }

    // MARK: - The synth

    @Test func tenSecondsOfMixedEventsNeverClipOrNaN() {
        let synth = FeelSynth(sampleRate: 48_000)
        var dice = FeelDice(seed: 9)
        let blocksPerSecond = 48_000.0 / 512
        var nextCue = 0.0
        var cueIndex = 0
        let result = feelRender(synth, seconds: 10) { block, t in
            // A whole heist in 10 s: slow opening, a fast stroke, the stages climbing, a drag, the torch low.
            let speed = t < 3 ? 6 + 4 * t : (t < 5 ? 45 : 12)
            let noise = min(t / 9, 1)
            let stage: MimicStage = noise < 0.35 ? .asleep : (noise < 0.7 ? .stirring : .waking)
            let telemetry = play(speed: speed, noise: noise, stage: stage, openness: min(t / 4, 1),
                                 drag: t > 6 && t < 7 ? 900 : 0, torch: 20 - t)
            if block % max(Int(blocksPerSecond / 60), 1) == 0 {
                synth.send(.bed(FeelSoundBook.heistBed(telemetry: telemetry, master: FeelAudioEngine.masterGain,
                                                       ambience: 1)))
            }
            if t >= nextCue {
                nextCue += 0.35
                cueIndex += 1
                let cue: [FeelSynthCommand]
                switch cueIndex % 9 {
                case 0: cue = FeelSoundBook.chomp(dice: &dice)
                case 1: cue = FeelSoundBook.itemBagged(.copper, dice: &dice)
                case 2: cue = FeelSoundBook.bank(value: 800, hushed: true, dice: &dice)
                case 3: cue = FeelSoundBook.heartbeat(fast: true)
                case 4: cue = FeelSoundBook.itemRevealed(.gem(.ruby), dice: &dice)
                case 5: cue = FeelSoundBook.relicChoir()
                case 6: cue = FeelSoundBook.itemDropped(dice: &dice)
                case 7: cue = FeelSoundBook.wakeSting()
                default: cue = FeelSoundBook.celebrate(dice: &dice)
                }
                for command in cue { synth.send(command) }
            }
        }
        #expect(result.finite)
        #expect(result.peak < 1.0)
        #expect(synth.peak < 1.0)
        #expect(result.rms > 0.01)
        // The limiter is a safety net, not the mix: almost nothing sits above 0.6.
        #expect(result.hot < 0.02)
    }

    @Test func aHotPileUpStillNeverClips() {
        let synth = FeelSynth(sampleRate: 44_100)
        var bed = FeelSoundBook.heistBed(telemetry: play(speed: 120, noise: 0.95, stage: .waking, drag: 1500,
                                                         torch: 2), master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        var dice = FeelDice(seed: 5)
        for command in FeelSoundBook.chomp(dice: &dice) { synth.send(command) }
        for command in FeelSoundBook.bank(value: 9_999, hushed: true, dice: &dice) { synth.send(command) }
        for index in 0..<20 {
            synth.send(.ring(FeelRingSpec(.bell, fundamental: 300 + Float(index) * 37, partials: 6, decay: 0.5,
                                          gain: 2)))
            synth.send(.fm(FeelFMSpec(carrier: 2000 + Float(index) * 90, ratio: 1.41, index: 3, indexDecay: 0.05,
                                      decay: 0.3, gain: 2)))
        }
        let result = feelRender(synth, seconds: 2)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(synth.peak < 1)
        #expect(synth.renderCallbacks > 0)
    }

    @Test func synthIsSilentWithMasterAtZero() {
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelSoundBook.heistBed(telemetry: play(speed: 40), master: 0, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        synth.send(.ring(FeelRingSpec(.chime, fundamental: 880, decay: 0.3, gain: 0.3)))
        let result = feelRender(synth, seconds: 0.4)
        #expect(result.peak < 0.0001)
    }

    @Test func eachContinuousLayerIsAudibleButGentle() {
        var beds: [FeelBed] = []
        var snore = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        snore.snore = 1
        beds.append(snore)
        var growl = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        growl.growl = 1
        beds.append(growl)
        var motif = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        motif.motif = 1
        motif.motifDensity = 1
        beds.append(motif)
        var dungeon = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        dungeon.drone = 1
        dungeon.dripRate = 2
        dungeon.crackle = 1
        dungeon.crackleRate = 12
        beds.append(dungeon)
        var rattle = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        rattle.rattle = 1
        rattle.rattleRate = 50
        beds.append(rattle)
        for bed in beds {
            let synth = FeelSynth(sampleRate: 48_000)
            synth.send(.bed(bed))
            let result = feelRender(synth, seconds: 4.5)
            #expect(result.finite)
            #expect(result.rms > 0.001)
            // A bed, not a moment: under −20 dBFS RMS.
            #expect(result.rms < 0.1)
            #expect(result.peak < 0.9)
        }
    }

    @Test func commandQueueDropsInsteadOfBlockingWhenFull() {
        let synth = FeelSynth(sampleRate: 48_000)
        var accepted = 0
        for _ in 0..<(FeelSynth.queueCapacity * 2) {
            if synth.send(.stopAll) { accepted += 1 }
        }
        #expect(accepted == FeelSynth.queueCapacity - 1)
    }

    // MARK: - Haptics

    @Test func theCreakTextureFollowsTheSpeed() {
        #expect(FeelHapticBook.creakLevel(speed: Tuning.quietSpeed) == 0)
        #expect(abs(FeelHapticBook.creakLevel(speed: Tuning.quietSpeed + 15) - 0.5) < 1e-6)
        #expect(FeelHapticBook.creakLevel(speed: Tuning.quietSpeed + 30) == 1)
        #expect(FeelHapticBook.creakLevel(speed: 500) == 1)
        #expect(FeelHapticBook.creakLevel(speed: Double.nan) == 0)
        var previous: Float = -1
        var speed = 0.0
        while speed <= 80 {
            let level = FeelHapticBook.creakLevel(speed: speed)
            #expect(level >= previous)
            previous = level
            let sharpness = FeelHapticBook.creakSharpness(speed: speed)
            #expect(sharpness >= FeelHapticBook.creakSharpnessLow && sharpness <= FeelHapticBook.creakSharpnessHigh)
            speed += 1
        }
        #expect(FeelHapticBook.creakSharpness(speed: 50) > FeelHapticBook.creakSharpness(speed: 10))
        #expect(FeelHapticBook.creakLevel(speed: 20, profile: .off) == 0)
        #expect(FeelHapticBook.creakLevel(speed: 20, profile: .strong) > FeelHapticBook.creakLevel(speed: 20,
                                                                                               profile: .normal))
        #expect(FeelHapticBook.creakLevel(speed: 90, profile: .strong) <= 1)
        #expect(FeelHapticBook.rattleLevel(dragSpeed: 200, profile: .normal) == 0)
        #expect(FeelHapticBook.rattleLevel(dragSpeed: 900, profile: .normal) > 0)
        #expect(FeelHapticBook.rattleLevel(dragSpeed: 900, profile: .off) == 0)
    }

    @Test func hapticMomentsHaveTheirShapes() {
        let cues: [FeelHapticCue] = [
            FeelHapticBook.coinTick, FeelHapticBook.pick, FeelHapticBook.drop, FeelHapticBook.bagThump,
            FeelHapticBook.bagTreasure, FeelHapticBook.bank(cascade: FeelSoundBook.cascadeTimes(count: 14)),
            FeelHapticBook.heartbeat, FeelHapticBook.bite, FeelHapticBook.stirring, FeelHapticBook.waking,
            FeelHapticBook.chestArrived, FeelHapticBook.lidCracked, FeelHapticBook.oil, FeelHapticBook.torchLow,
            FeelHapticBook.torchOut, FeelHapticBook.newBest, FeelHapticBook.uiTap, FeelHapticBook.uiConfirm,
            FeelHapticBook.celebrate,
            FeelHapticBook.chainUp(count: 1), FeelHapticBook.chainUp(count: 7, delay: 1.55),
            FeelHapticBook.chainBroken(), FeelHapticBook.chainBroken(delay: 1.1), FeelHapticBook.goldenArrived(),
            FeelHapticBook.coinSpill(times: FeelSoundBook.spillTimes(count: 10)),
            FeelHapticBook.candleTick(urgent: false), FeelHapticBook.candleTick(urgent: true),
            FeelHapticBook.creakAccent, FeelHapticBook.quietTick,
        ]
        let bitePeak = FeelHapticBook.bite.notes.map { $0.intensity }.max() ?? 0
        #expect(bitePeak == 1)
        #expect(FeelHapticBook.bite.length >= 0.3)
        for cue in cues {
            #expect(!cue.notes.isEmpty)
            #expect(cue.curve.count <= 16)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
        }
        // The bite is the strongest transient: nothing else hits harder on its first tap.
        for cue in cues where cue != FeelHapticBook.bite {
            let first = cue.notes.first { $0.kind == .transient }?.intensity ?? 0
            #expect(first <= bitePeak)
        }
        // Strong turns taps into bursts the Duo's weak actuator can push, and keeps the curve.
        let strong = FeelHapticBook.adapt(FeelHapticBook.bite, to: .strong)
        #expect(strong.notes.allSatisfy { $0.kind == .continuous })
        #expect(strong.curve == FeelHapticBook.bite.curve)
        #expect(FeelHapticBook.adapt(FeelHapticBook.coinTick, to: .normal) == FeelHapticBook.coinTick)
        #expect(FeelHapticProfile.defaultFor(hasFold: true) == .strong)
        #expect(FeelHapticProfile.defaultFor(hasFold: false) == .normal)
    }

    // MARK: - The director

    /// Sound and haptics off: the director takes a whole run's worth of events and frames, Home's creak, the menu
    /// sounds, idling and silences without starting any engine or crashing.
    @Test func directorHandlesEverythingWithFeedbackOff() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.respectSilentSwitch = true
        director.start()
        director.start()
        director.handle([], telemetry: HeistTelemetry())
        for frame in 0..<360 {
            let t = Double(frame) / 120
            let noise = min(t, 1)
            let stage: MimicStage = noise < 0.35 ? .asleep : (noise < 0.7 ? .stirring : .waking)
            let telemetry = play(speed: 40 * sin(t * 3), noise: noise, stage: stage, openness: 0.5,
                                 drag: frame % 90 < 20 ? 800 : 0, torch: 16 - t * 3)
            director.handle(frame == 30 ? everyEvent : [], telemetry: telemetry)
        }
        director.handle([.bitten(lostValue: 50)], telemetry: play(speed: 0, playing: false))
        director.handle([.finished], telemetry: HeistTelemetry())
        director.idle = true
        for frame in 0..<60 {
            director.homeLid(speed: Double(frame), openness: Double(frame) / 60)
        }
        director.uiTap()
        director.uiConfirm()
        director.celebrate()
        director.silence()
        director.silence()
        director.idle = false
        #expect(director.soundOn == false)
        #expect(director.hapticsOn == false)
        #expect(director.respectSilentSwitch)
        #expect(director.idle == false)
    }

    @Test func directorEdgeCasesDoNotCrash() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        let weird = HeistTelemetry(lidSpeed: Double.nan, openness: Double.infinity, noise: -3, stage: .waking,
                                   dragSpeed: Double.nan, torchRemaining: Double.nan, playing: true)
        director.handle([.banked(value: -5, items: 0, hushed: false), .banked(value: Int.max, items: 99, hushed: true),
                         .itemRevealed(id: 1, kind: .copper), .itemRevealed(id: 2, kind: .copper),
                         .itemRevealed(id: 3, kind: .copper), .itemRevealed(id: 4, kind: .copper),
                         .itemRevealed(id: 5, kind: .copper), .itemRevealed(id: 6, kind: .copper),
                         .stageChanged(from: .asleep, to: .asleep)], telemetry: weird)
        director.homeLid(speed: Double.nan, openness: -1)
        director.silence()
        director.handle([], telemetry: weird)
        let bed = FeelSoundBook.heistBed(telemetry: weird, master: 1, ambience: 1)
        #expect(bed.creak.isFinite)
        #expect(bed.creakHz.isFinite)
        #expect(bed.growl.isFinite)
        #expect(bed.snore.isFinite)
        #expect(bed.crackle.isFinite)
        #expect(bed.rattle == 0)
    }

    @Test func hapticsToggleRestoresTheProfile() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        #expect(director.hapticsOn == false)
        director.deviceHasFold = true
        director.hapticsOn = true
        #expect(director.hapticProfile == .strong)
        director.hapticProfile = .normal
        director.hapticsOn = false
        director.hapticsOn = true
        #expect(director.hapticProfile == .normal)
        director.hapticsOn = false
    }

    // MARK: - R2: the resume rule (REVIEW-1-duo P0-2)

    /// Closing pause, then a normal-speed reopen (150°/s, the evidence run's 30–90°/s and more): never resumable while
    /// the hand moves, even past 95°; resumable once it has been still for the hold; `reset()` starts the hold again.
    @Test func resumeWaitsForTheLidToBeOpenAndStill() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(0.4) { t in 120 - 60 * min(t / 0.3, 1) }
        hinge.run(0.6) { _ in 60 }
        #expect(hinge.source.isClosing)
        #expect(hinge.source.canResume == false)
        var early = false
        for k in 1...48 {
            if feelHold(hinge, 60 + 60 * Double(k) / 48) { early = true }
        }
        #expect(early == false)
        #expect(hinge.source.isClosing == false)
        // Still at 120°: not within the hold, but within about a second.
        var firstResumable: Int?
        for frame in 1...180 where firstResumable == nil {
            if feelHold(hinge, 120) { firstResumable = frame }
        }
        let seconds = Double(firstResumable ?? 999) * FakeHinge.frame
        #expect(seconds >= HingeLidSource.resumeHold)
        #expect(seconds <= 1.2)
        #expect(hinge.source.canResume)
        // The resume: forget the motion; the hold starts again from nothing, and a still lid reads still.
        hinge.source.reset()
        #expect(hinge.source.speed == 0)
        #expect(hinge.source.canResume == false)
        var again = false
        for _ in 0..<48 { again = feelHold(hinge, 120) }
        #expect(again)
        #expect(hinge.source.lid(at: hinge.time + 0.001).speed < 0.5)
    }

    /// R7 (DEVICE-RISKS-1 item 7): resume is lifted from 92° and stays lifted down to 88°, so a lid resting near the
    /// line (±5° accuracy) never flickers "Lift the lid" ↔ "Hold still…"; `effectiveResumeAngle` is the line in force.
    @Test func resumeHasHysteresisAtNinetyTwoAndEightyEight() {
        #expect(HingeLidSource.resumeAngle == 92)
        #expect(HingeLidSource.resumeSpeed == 6)
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(0.4) { t in 120 - 60 * min(t / 0.3, 1) }
        hinge.run(0.6) { _ in 60 }
        // Eased up to 89.5° and held perfectly still: closing has cleared (> 78°) but it isn't lifted yet.
        hinge.run(1.3) { t in 60 + 29.5 * min(t / 1.2, 1) }
        var below = false
        for _ in 0..<240 {
            if feelHold(hinge, 89.5) { below = true }
        }
        #expect(hinge.source.isClosing == false)
        #expect(below == false)
        #expect(hinge.source.effectiveResumeAngle == HingeLidSource.resumeAngle)
        // Up to 93°: lifted, and it resumes once still.
        hinge.run(0.3) { t in 89.5 + 3.5 * min(t / 0.2, 1) }
        var lifted = false
        for _ in 0..<180 {
            if feelHold(hinge, 93) { lifted = true }
        }
        #expect(lifted)
        #expect(hinge.source.effectiveResumeAngle == HingeLidSource.resumeAngle - 4)
        // Sinking back to 89° keeps it lifted (88° is the line now).
        hinge.run(0.5) { t in 93 - 4 * min(t / 0.4, 1) }
        var stillLifted = false
        for _ in 0..<180 {
            if feelHold(hinge, 89) { stillLifted = true }
        }
        #expect(stillLifted)
        #expect(hinge.source.canResume)
        // Under 88°: not lifted any more, and the line is 92° again.
        hinge.run(0.4) { t in 89 - 3 * min(t / 0.3, 1) }
        var dropped = false
        for _ in 0..<180 {
            if feelHold(hinge, 86) { dropped = true }
        }
        #expect(dropped == false)
        #expect(hinge.source.effectiveResumeAngle == HingeLidSource.resumeAngle)
    }

    /// R7 (DEVICE-RISKS-1 item 7): above 100° a hand resting on the lid may drift under 10°/s and still resume; under
    /// 100° the line stays 6°/s. A lid hovering at 95° with ±1° wiggles at 10 Hz (CI's HOVER-95) resumes within 2 s.
    @Test func aHandRestingOnTheLidStillResumes() {
        let wide = HingeLidSource()
        let w = FakeHinge(source: wide)
        w.run(0.5) { _ in 120 }
        w.run(1.0) { t in 120 + 8 * t }
        #expect(wide.canResume)
        let narrow = HingeLidSource()
        let n = FakeHinge(source: narrow)
        n.run(0.5) { _ in 92.5 }
        n.run(0.8) { t in 92.5 + 8 * t }
        #expect(narrow.canResume == false)
        let hover = FakeHinge(source: HingeLidSource())
        hover.run(0.5) { _ in 120 }
        hover.run(0.4) { t in 120 - 60 * min(t / 0.3, 1) }
        hover.run(0.6) { _ in 60 }
        hover.run(0.4) { t in 60 + 35 * min(t / 0.3, 1) }
        var resumedAt: Int?
        for frame in 1...240 where resumedAt == nil {
            let wiggle = 95 + sin(2 * Double.pi * 10 * (Double(frame) / 120))
            hover.run(FakeHinge.frame) { _ in wiggle }
            if hover.source.canResume { resumedAt = frame }
        }
        #expect(resumedAt != nil)
    }

    /// The App runs frames while paused, but the rule must not depend on them (the game can pause its frames).
    @Test func resumeIsJudgedWithoutFrames() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 120 }
        hinge.run(0.4, frames: false) { t in 120 - 60 * min(t / 0.3, 1) }
        hinge.run(0.6, frames: false) { _ in 60 }
        #expect(hinge.source.isClosing)
        var early = false
        for k in 1...48 {
            if feelHold(hinge, 60 + 60 * Double(k) / 48, frames: false) { early = true }
        }
        #expect(early == false)
        var resumed = false
        for _ in 0..<150 {
            if feelHold(hinge, 120, frames: false) { resumed = true }
        }
        #expect(resumed)
        // Slow wobble at 3°/s still counts as still; 15°/s does not.
        let source = HingeLidSource()
        let slow = FakeHinge(source: source)
        slow.run(0.5) { _ in 120 }
        slow.run(1.0) { t in 120 + 3 * t }
        #expect(source.canResume)
        slow.run(1.0) { t in 123 + 15 * t }
        #expect(source.canResume == false)
    }

    @Test func noHingeNeverResumes() {
        let source = HingeLidSource()
        #expect(source.canResume == false)
        #expect(source.resumable(at: 5) == false)
        #expect(source.motionSpeed == 0)
        source.reset()
        #expect(source.hasHinge == false)
        #expect(source.canResume == false)
    }

    // MARK: - R2: the speed only counts inside the play range (REVIEW-1-duo P1-5)

    @Test func motionOutsideThePlayRangeIsSilent() {
        #expect(HingeLidSource.speedAngleRange.lowerBound == Tuning.shutAngle - 3)
        // R7 (DEVICE-RISKS-1 item 10): the top is capped at 162° (relics need ≤ 161°; the last degrees may snap).
        let top: Double = min(Tuning.wideAngle + 3, 162)
        #expect(HingeLidSource.speedAngleRange.upperBound == top)
        #expect(HingeLidSource.speedAngle(180) == top)
        #expect(HingeLidSource.speedAngle(40) == Tuning.shutAngle - 3)
        #expect(HingeLidSource.speedAngle(130) == 130)
        // Near flat: a 180 → 170 snap (40°/s) makes no noise, though the hinge really moved.
        let flat = FakeHinge(source: HingeLidSource())
        flat.run(0.5) { _ in 180 }
        var loudest = 0.0
        flat.run(0.25) { t in 180 - 40 * t }
        loudest = max(loudest, flat.speeds.max() ?? 99)
        #expect(flat.source.motionSpeed > 20)
        flat.run(0.5) { _ in 170 }
        loudest = max(loudest, flat.speeds.max() ?? 99)
        #expect(loudest < 0.5)
        // Folding the phone shut below the chest's shut line (96° → 30° at 110°/s) is silent too.
        let fold = FakeHinge(source: HingeLidSource())
        fold.run(0.5) { _ in 96 }
        fold.run(0.6) { t in 96 - 110 * t }
        #expect((fold.speeds.max() ?? 99) < 0.5)
        // Inside the range nothing changed: 10°/s still reads 10.
        let play = FakeHinge(source: HingeLidSource())
        play.run(0.5) { _ in 110 }
        play.run(1.5) { t in 110 + 10 * t }
        #expect(abs((play.speeds.last ?? 0) - 10) < 1)
    }

    @Test func speedPeekNeverAdvancesAndDecays() {
        var estimator = FeelSpeedEstimator()
        #expect(estimator.peekSpeed(at: 1) == 0)
        var t = 1.0
        estimator.sample(100, at: t)
        for _ in 0..<30 {
            t += 1.0 / 30
            estimator.sample(100 + 30 * (t - 1), at: t)
        }
        let moving = estimator.peekSpeed(at: t)
        #expect(moving > 25 && moving < 35)
        #expect(estimator.peekSpeed(at: t) == moving)
        // Once the samples stop it decays like the display speed.
        #expect(estimator.peekSpeed(at: t + FeelSpeedEstimator.hold * 0.5) == moving)
        #expect(estimator.peekSpeed(at: t + 0.4) < moving * 0.2)
        #expect(estimator.peekSpeed(at: t + 2) < 0.01)
        #expect(estimator.peekSpeed(at: Double.nan) == 0)
    }

    // MARK: - R2: the creak follows the noise rule

    @Test func closingIsQuieterThanOpening() {
        #expect(FeelSoundBook.closeQuietSpeed >= Tuning.quietSpeed)
        let close = FeelSoundBook.closeQuietSpeed
        #expect(FeelSoundBook.creakLevel(speed: FeelSoundBook.creakSpeed(close, closing: true)) == 0)
        #expect(FeelSoundBook.creakLevel(speed: FeelSoundBook.creakSpeed(close + 1, closing: true)) > 0)
        #expect(FeelHapticBook.creakLevel(speed: FeelSoundBook.creakSpeed(close, closing: true)) == 0)
        if close > Tuning.quietSpeed {
            let between = (close + Tuning.quietSpeed) / 2
            #expect(FeelSoundBook.creakLevel(speed: FeelSoundBook.creakSpeed(between, closing: false)) > 0)
            #expect(FeelSoundBook.creakLevel(speed: FeelSoundBook.creakSpeed(between, closing: true)) == 0)
        }
        #expect(FeelSoundBook.creakSpeed(Double.nan, closing: true) == 0)
        #expect(FeelSoundBook.creakSpeed(-5, closing: false) == 0)
        #expect(FeelSoundBook.creakSpeed(40, closing: false) == 40)
        #expect(FeelSoundBook.closeQuietSpeed == Tuning.closeQuietSpeed)
        // The direction comes from the openness, exactly as HeistSession judges it: falling = closing; still or
        // pinned = not closing.
        // (#expect can't call a mutating method: CLAUDE.md gotcha, CI 40504438508.)
        var direction = FeelLidDirection()
        let d1 = direction.update(openness: 0.5)
        let d2 = direction.update(openness: 0.49)
        let d3 = direction.update(openness: 0.49)
        let d4 = direction.update(openness: 0.48)
        let d5 = direction.update(openness: Double.nan)
        let d6 = direction.update(openness: 0.6)
        #expect(d1 == false)
        #expect(d2)
        #expect(d3 == false)
        #expect(d4)
        #expect(d5)
        #expect(d6 == false)
        direction.reset()
        #expect(direction.closing == false)
    }

    /// QA-1 P1-1: a pause that began mid-motion hands the director a frozen speed; it must stop creaking by itself.
    @Test func aFrozenSpeedStopsCreaking() {
        var guardrail = FeelFrozenSpeedGuard()
        #expect(guardrail.filter(28.7, at: 0) == 28.7)
        #expect(guardrail.filter(28.7, at: 0.2) == 28.7)
        #expect(guardrail.filter(28.7, at: FeelFrozenSpeedGuard.after + 0.01) == 0)
        #expect(guardrail.filter(28.7, at: 9) == 0)
        // A live speed changes every frame and passes untouched.
        var t = 10.0
        var speed = 30.0
        for _ in 0..<120 {
            t += 1.0 / 120
            speed *= 0.995
            #expect(guardrail.filter(speed, at: t) == speed)
        }
        #expect(guardrail.filter(Double.nan, at: t) == 0)
        #expect(guardrail.filter(-3, at: t) == 0)
        #expect(guardrail.filter(0, at: t + 1) == 0)
    }

    // MARK: - R2: the new moments

    @Test func theChainClimbsAStepPerHushedBank() {
        var previousTop: Float = 0
        for count in 1...FeelSoundBook.chainLadder.count {
            let notes = FeelSoundBook.chainNotes(count: count)
            #expect(notes.count == min(count, 3))
            #expect((notes.last ?? 0) > previousTop)
            for index in 1..<max(notes.count, 1) where notes.count > 1 { #expect(notes[index] > notes[index - 1]) }
            previousTop = notes.last ?? 0
        }
        #expect(FeelSoundBook.chainNotes(count: 0).count == 1)
        #expect(FeelSoundBook.chainNotes(count: 99).last == FeelSoundBook.chainLadder.last)
        // After a bank it waits for the ka-ching; its haptic lands with its notes.
        #expect(FeelSoundBook.chainAfterBank > FeelSoundBook.kaChingAt)
        var dice = FeelDice(seed: 4)
        let delayed = FeelSoundBook.chainUp(count: 3, delay: FeelSoundBook.chainAfterBank, dice: &dice)
        #expect(delayed.allSatisfy { $0.delay >= FeelSoundBook.chainAfterBank })
        let cue = FeelHapticBook.chainUp(count: 3, delay: Double(FeelSoundBook.chainAfterBank))
        #expect(cue.notes.count == 3)
        #expect(abs((cue.notes.first?.time ?? 0) - Double(FeelSoundBook.chainAfterBank)) < 1e-6)
        #expect(FeelHapticBook.chainBroken().notes.count == FeelSoundBook.chainShardTimes.count + 1)
    }

    @Test func aBiteSpillsCoinsByValue() {
        #expect(FeelSoundBook.spillCount(lostValue: 0) == 0)
        #expect(FeelSoundBook.spillCount(lostValue: -4) == 0)
        var previous = 0
        for value in stride(from: 1, through: 50_000, by: 97) {
            let count = FeelSoundBook.spillCount(lostValue: value)
            #expect(count >= 4 && count <= 10)
            #expect(count >= previous)
            previous = count
        }
        let times = FeelSoundBook.spillTimes(count: 10)
        #expect(times.count == 10)
        for index in 1..<times.count { #expect(times[index] > times[index - 1]) }
        // After the CHOMP's slam and teeth, done within a second.
        #expect((times.first ?? 0) >= FeelSoundBook.spillStart)
        #expect((times.last ?? 9) < 1.0)
        let cue = FeelHapticBook.coinSpill(times: times)
        for time in times {
            #expect(cue.notes.contains { abs($0.time - time) < 1e-9 && $0.kind == .transient })
        }
        var dice = FeelDice(seed: 8)
        #expect(FeelSoundBook.coinSpill(lostValue: 0, seconds: 0, dice: &dice).isEmpty)
        #expect(FeelSoundBook.coinSpill(lostValue: 0, seconds: 10, dice: &dice).count == 1)
        let small = FeelSoundBook.coinSpill(lostValue: 20, seconds: 10, dice: &dice)
        let big = FeelSoundBook.coinSpill(lostValue: 5_000, seconds: 10, dice: &dice)
        #expect(big.count > small.count)
    }

    @Test func theCandleTicksFasterInItsLastFiveSeconds() {
        #expect(FeelSoundBook.torchTickSlot(remaining: 15.5) == nil)
        #expect(FeelSoundBook.torchTickSlot(remaining: 0) == nil)
        #expect(FeelSoundBook.torchTickSlot(remaining: Double.nan) == nil)
        // A 15 s countdown at 120 Hz, played exactly as the director does.
        var last: Int?
        var slow = 0
        var fast = 0
        var tickTimes: [Double] = []
        var remaining = 15.0
        while remaining > 0 {
            if let slot = FeelSoundBook.torchTickSlot(remaining: remaining) {
                if let previous = last, slot < previous {
                    if remaining <= FeelSoundBook.torchUrgentSeconds { fast += 1 } else { slow += 1 }
                    tickTimes.append(remaining)
                }
                last = slot
            }
            remaining -= 1.0 / 120
        }
        #expect(slow == 9)
        #expect(fast == 10)
        // Once a second, then twice a second.
        for index in 1..<tickTimes.count {
            let gap = tickTimes[index - 1] - tickTimes[index]
            let expected = tickTimes[index] <= FeelSoundBook.torchUrgentSeconds && index > 9 ? 0.5 : 1.0
            #expect(abs(gap - expected) < 0.02)
        }
        // Oil raising the candle never ticks (the slot goes up).
        let before = FeelSoundBook.torchTickSlot(remaining: 4.2) ?? 0
        let after = FeelSoundBook.torchTickSlot(remaining: 10.2) ?? 0
        #expect(after > before)
        // The urgent tick is louder and higher.
        let calm = FeelSoundBook.torchTick().map { $0.gain }.max() ?? 1
        let urgent = FeelSoundBook.torchTick(urgent: true).map { $0.gain }.max() ?? 0
        #expect(urgent > calm)
        let calmTap = FeelHapticBook.candleTick(urgent: false).notes.first?.intensity ?? 1
        let urgentTap = FeelHapticBook.candleTick(urgent: true).notes.first?.intensity ?? 0
        #expect(urgentTap > calmTap)
    }

    @Test func theNewMomentsRenderCleanly() {
        let synth = FeelSynth(sampleRate: 48_000)
        var dice = FeelDice(seed: 12)
        var bed = FeelSoundBook.heistBed(telemetry: play(speed: 20, noise: 0.3), master: FeelAudioEngine.masterGain,
                                         ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        // A bite with its spill and a broken chain, a big Hushed bank with its chain chime, a golden arrival, and the
        // glimmer throughout.
        var cues: [[FeelSynthCommand]] = []
        cues.append(FeelSoundBook.chomp(dice: &dice))
        cues.append(FeelSoundBook.coinSpill(lostValue: 900, seconds: 10, dice: &dice))
        cues.append(FeelSoundBook.chainBroken(delay: 1.1, dice: &dice))
        cues.append(FeelSoundBook.bank(value: 2_400, hushed: true, dice: &dice))
        cues.append(FeelSoundBook.chainUp(count: 5, delay: FeelSoundBook.chainAfterBank, dice: &dice))
        cues.append(FeelSoundBook.chestArrived(tier: .gilded, dice: &dice))
        cues.append(FeelSoundBook.goldenArrived(dice: &dice))
        cues.append(FeelSoundBook.creakAccent(dice: &dice))
        for _ in 0..<6 { cues.append(FeelSoundBook.glimmerTwinkle(dice: &dice)) }
        for cue in cues {
            for command in cue { synth.send(command) }
        }
        let result = feelRender(synth, seconds: 3)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(result.rms > 0.003)
        // The glimmer is a whisper: far under a coin.
        let twinklePeak = FeelSoundBook.glimmerTwinkle(dice: &dice).map { $0.gain }.max() ?? 1
        let coinPeak = FeelSoundBook.coinClink(dice: &dice).map { $0.gain }.max() ?? 0
        #expect(twinklePeak < coinPeak * 0.5)
    }

    @Test func glimmerAndGoldenThroughTheDirector() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        #expect(director.glimmering == false)
        director.glimmer(on: true)
        director.glimmer(on: true)
        #expect(director.glimmering)
        for frame in 0..<120 {
            director.handle([], telemetry: play(speed: Double(frame % 20), torch: 6 - Double(frame) / 20))
        }
        #expect(director.glimmering)
        // A bank (or a bite, a new chest, the candle out, a silence) ends it by itself.
        director.handle([.banked(value: 300, items: 3, hushed: true), .chainUp(count: 3, multiplier: 1.3)],
                        telemetry: play(speed: 0))
        #expect(director.glimmering == false)
        director.glimmer(on: true)
        director.silence()
        #expect(director.glimmering == false)
        director.glimmer(on: true)
        director.glimmer(on: false)
        #expect(director.glimmering == false)
        director.goldenArrived()
        director.handle([.stageChanged(from: .asleep, to: .stirring), .chainBroken(count: 4)],
                        telemetry: play(speed: 0, stage: .stirring))
        director.handle([.bitten(lostValue: 200), .biteCost(lostValue: 200, seconds: 10), .chainBroken(count: 2)],
                        telemetry: play(speed: 0, playing: false))
        // A pause that froze the speed mid-stroke: the director keeps taking frames without trouble.
        for _ in 0..<60 { director.handle([], telemetry: play(speed: 28.7, playing: false)) }
        #expect(director.soundOn == false)
    }

    // MARK: - R2: frame rate under Low Power and heat (REVIEW-1-duo P2-10)

    @Test func preferredFPSDropsUnderLowPowerOrHeat() {
        #expect(FeedbackDirector.fps(lowPower: false, thermal: .nominal) == 120)
        // R3 (REVIEW-2-duo P2-7): `.fair` already drops to 60.
        #expect(FeedbackDirector.fps(lowPower: false, thermal: .fair) == 60)
        #expect(FeedbackDirector.fps(lowPower: false, thermal: .serious) == 60)
        #expect(FeedbackDirector.fps(lowPower: false, thermal: .critical) == 60)
        #expect(FeedbackDirector.fps(lowPower: true, thermal: .nominal) == 60)
        let director = FeedbackDirector()
        let info = ProcessInfo.processInfo
        let ceiling: Int = director.preferredFPS
        let expected = FeedbackDirector.fps(lowPower: info.isLowPowerModeEnabled, thermal: info.thermalState)
        #expect(ceiling == expected)
        let shared: Int = FeedbackDirector.preferredFPS
        #expect([60, 120].contains(shared))
    }

    // MARK: - R3: 120 fps only while something moves (REVIEW-2-duo P2-7)

    @Test func frameRateIsFastOnlyWhileSomethingMoves() {
        var rule = FeelFrameRate()
        // Idle from the start.
        let idle = rule.fps(ceiling: 120, lidSpeed: 0, animating: false, at: 10)
        #expect(idle == 60)
        // The lid moves: the ceiling, held for a second after it stops.
        let moving = rule.fps(ceiling: 120, lidSpeed: 8, animating: false, at: 11)
        #expect(moving == 120)
        let justAfter = rule.fps(ceiling: 120, lidSpeed: 0.5, animating: false, at: 11.9)
        #expect(justAfter == 120)
        let later = rule.fps(ceiling: 120, lidSpeed: 0, animating: false, at: 12.2)
        #expect(later == 60)
        // A tremor under 1°/s never counts as moving.
        let tremor = rule.fps(ceiling: 120, lidSpeed: 0.9, animating: false, at: 14)
        #expect(tremor == 60)
        // Something animating (a held item, a moment, flying loot) with the lid still.
        let animating = rule.fps(ceiling: 120, lidSpeed: 0, animating: true, at: 20)
        #expect(animating == 120)
        let settled = rule.fps(ceiling: 120, lidSpeed: 0, animating: false, at: 21.5)
        #expect(settled == 60)
        // Low Power or heat (a ceiling of 60) always wins.
        let hot = rule.fps(ceiling: 60, lidSpeed: 40, animating: true, at: 30)
        #expect(hot == 60)
        // Garbage in: never a crash, never above the ceiling.
        let nan = rule.fps(ceiling: 120, lidSpeed: Double.nan, animating: false, at: Double.nan)
        #expect(nan == 60 || nan == 120)
        let zero = rule.fps(ceiling: 0, lidSpeed: 50, animating: true, at: 40)
        #expect(zero == 1)
        #expect(FeelFrameRate.idleFPS == 60)
        // Through the director: the same rule under its own ceiling.
        let director = FeedbackDirector()
        let ceiling: Int = director.preferredFPS
        let fast = director.preferredFPS(lidSpeed: 20, animating: false, at: 100)
        #expect(fast == ceiling)
        let still = director.preferredFPS(lidSpeed: 0, animating: false, at: 102)
        #expect(still == min(60, ceiling))
    }

    // MARK: - R3: the CREAK accent (the slam)

    @Test func aSlamCracksOnceAndAScriptedJumpNever() {
        var detector = FeelCreakDetector()
        let frame = 1.0 / 120
        var t = 50.0
        var cracks: [Double] = []
        // A careful open: the noise creeps up, no crack.
        for k in 0..<240 {
            t += frame
            let fired = detector.update(noise: 0.05 + 0.1 * Double(k) / 240, lidSpeed: 14, dragSpeed: 0,
                                        playing: true, at: t)
            if fired { cracks.append(t) }
        }
        #expect(cracks.isEmpty)
        // A slam: 120°/s and the noise climbing 1.6 a second (Tuning's slam rate).
        let slamStart = t
        for _ in 0..<36 {
            t += frame
            let noise = min(0.15 + 1.6 * (t - slamStart), 0.99)
            let fired = detector.update(noise: noise, lidSpeed: 120, dragSpeed: 0, playing: true, at: t)
            if fired { cracks.append(t) }
        }
        #expect(cracks.count == 1)
        // It cracked as the rise passed 0.25 (about 0.16 s in), well inside the 0.3 s window.
        let latency = (cracks.first ?? 99) - slamStart
        #expect(latency > 0.1)
        #expect(latency < FeelCreakDetector.window)
        let firstCrack = detector.lastFired
        #expect(firstCrack == cracks.first)
        // The refractory: a claim right after is refused; after it, a fresh rise of 0.25 is needed.
        let refused = detector.claim(at: t + 0.01)
        #expect(refused == false)
        for _ in 0..<120 {
            t += frame
            let fired = detector.update(noise: 0.99, lidSpeed: 0, dragSpeed: 0, playing: true, at: t)
            if fired { cracks.append(t) }
        }
        #expect(cracks.count == 1)

        // A scripted jump (the lesson's stir, a demo preset) with a still lid: never a crack.
        var scripted = FeelCreakDetector()
        var s = 10.0
        for k in 0..<60 {
            s += frame
            let noise = k < 30 ? 0.05 : Tuning.lessonStirNoise
            let fired = scripted.update(noise: noise, lidSpeed: 3, dragSpeed: 100, playing: true, at: s)
            #expect(fired == false)
        }
        // Not playing (a pause, the bank or bite moment): no crack, and the history is forgotten.
        var paused = FeelCreakDetector()
        let a = paused.update(noise: 0.1, lidSpeed: 90, dragSpeed: 0, playing: false, at: 1)
        let b = paused.update(noise: 0.9, lidSpeed: 90, dragSpeed: 0, playing: false, at: 1.1)
        #expect(a == false)
        #expect(b == false)
        let c = paused.update(noise: 0.9, lidSpeed: 90, dragSpeed: 0, playing: true, at: 1.2)
        #expect(c == false)
        // A slow rise of 0.3 over 0.6 s is never "a jump within 0.3 s".
        var slow = FeelCreakDetector()
        var u = 0.0
        var slowCracks = 0
        for k in 0..<72 {
            u += frame
            let fired = slow.update(noise: 0.1 + 0.3 * Double(k) / 72, lidSpeed: 40, dragSpeed: 0, playing: true,
                                    at: u)
            if fired { slowCracks += 1 }
        }
        #expect(slowCracks == 0)
        // A flicked drag counts as loud input too.
        var flick = FeelCreakDetector()
        let f0 = flick.update(noise: 0.1, lidSpeed: 0, dragSpeed: 3_000, playing: true, at: 5)
        let f1 = flick.update(noise: 0.4, lidSpeed: 0, dragSpeed: 3_000, playing: true, at: 5.2)
        #expect(f0 == false)
        #expect(f1)
        // NaN never fires or crashes.
        var weird = FeelCreakDetector()
        let w = weird.update(noise: Double.nan, lidSpeed: Double.nan, dragSpeed: Double.nan, playing: true,
                             at: Double.nan)
        #expect(w == false)
    }

    @Test func theCreakAccentIsSharpAndPlaysThroughTheDirector() {
        var dice = FeelDice(seed: 21)
        let crack = FeelSoundBook.creakAccent(dice: &dice)
        #expect(!crack.isEmpty)
        for command in crack {
            #expect(command.gain > 0)
            #expect(command.gain <= 0.4)
            #expect(command.delay >= 0)
            #expect(command.delay < 0.1)
        }
        // Louder than a coin, smaller than the CHOMP.
        let crackPeak = crack.map { $0.gain }.max() ?? 0
        let chompPeak = FeelSoundBook.chomp(dice: &dice).map { $0.gain }.max() ?? 0
        let coinPeak = FeelSoundBook.coinClink(dice: &dice).map { $0.gain }.max() ?? 1
        #expect(crackPeak < chompPeak)
        #expect(crackPeak > coinPeak * 2)
        // It renders cleanly over a loud creak.
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelSoundBook.heistBed(telemetry: play(speed: 90, noise: 0.6, stage: .stirring),
                                         master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        for command in crack { synth.send(command) }
        let result = feelRender(synth, seconds: 0.5)
        #expect(result.finite)
        #expect(result.peak < 1)
        // Its haptic is keen, short, and under the bite.
        let tap = FeelHapticBook.creakAccent
        #expect(tap.length < 0.1)
        #expect((tap.notes.first?.sharpness ?? 0) >= 0.9)
        let bitePeak = FeelHapticBook.bite.notes.map { $0.intensity }.max() ?? 0
        #expect((tap.notes.map { $0.intensity }.max() ?? 2) <= bitePeak)

        // Through the director (sound and haptics off, so nothing starts): the live path is `handle`.
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        var heard = 0
        director.onCreakAccent = { heard += 1 }
        // A scripted jump with a still lid: silent.
        director.handle([], telemetry: play(speed: 0, noise: 0.05))
        director.handle([], telemetry: play(speed: 0, noise: 0.6, stage: .stirring))
        #expect(director.creakAccents == 0)
        // Out of play: silent.
        director.handle([], telemetry: play(speed: 90, noise: 0.05, playing: false))
        director.handle([], telemetry: play(speed: 90, noise: 0.7, playing: false))
        #expect(director.creakAccents == 0)
        // A slam in play: one crack.
        director.handle([], telemetry: play(speed: 90, noise: 0.1))
        director.handle([], telemetry: play(speed: 110, noise: 0.5, stage: .stirring))
        #expect(director.creakAccents == 1)
        #expect(heard == 1)
        // A bite on the same frame keeps the CHOMP alone (the detector still takes the slam).
        let biter = FeedbackDirector()
        biter.soundOn = false
        biter.hapticsOn = false
        biter.handle([], telemetry: play(speed: 90, noise: 0.2))
        biter.handle([.bitten(lostValue: 40)], telemetry: play(speed: 120, noise: 1, stage: .biting))
        #expect(biter.creakAccents == 0)
        // The manual call shares the refractory: right after a crack it is refused (or, if this test stalled for
        // over half a second, it plays). Either way the count and the callback agree.
        let played = director.creakAccent()
        #expect(director.creakAccents == (played ? 2 : 1))
        #expect(heard == director.creakAccents)
        director.silence()
    }

    // MARK: - R3: the stage cues (VoiceOver players hear them)

    @Test func everyStageChangeHasItsCue() {
        var dice = FeelDice(seed: 4)
        let stages: [MimicStage] = [.asleep, .stirring, .waking, .biting]
        for from in stages {
            for to in stages {
                let sound = FeelSoundBook.stageCue(from: from, to: to, dice: &dice)
                let touch = FeelHapticBook.stageCue(from: from, to: to)
                if to == from || to == .biting && from < to {
                    // No change, or a bite (the `bitten` event speaks).
                    #expect(sound.isEmpty)
                    #expect(touch == nil)
                } else if to > from {
                    #expect(!sound.isEmpty)
                    #expect(touch != nil)
                } else {
                    // Any step down: the sigh (sound only).
                    #expect(!sound.isEmpty)
                    #expect(touch == nil)
                }
            }
        }
        let wake = FeelSoundBook.stageCue(from: .stirring, to: .waking, dice: &dice)
        #expect(wake == FeelSoundBook.wakeSting())
        #expect(FeelHapticBook.stageCue(from: .asleep, to: .waking) == FeelHapticBook.waking)
        #expect(FeelHapticBook.stageCue(from: .asleep, to: .stirring) == FeelHapticBook.stirring)
    }

    // MARK: - R3: the resume angle after a cover trip (REVIEW-2-duo P1-3)

    @Test func aCoverTripCanLowerTheResumeAngle() {
        // R7: the usual angle is 92° (`resumeAngle`).
        #expect(HingeLidSource.coverResumeAngle(relight: nil) == HingeLidSource.resumeAngle)
        #expect(HingeLidSource.coverResumeAngle(relight: Double.nan) == HingeLidSource.resumeAngle)
        #expect(HingeLidSource.coverResumeAngle(relight: 80) == 90)
        #expect(HingeLidSource.coverResumeAngle(relight: 88) == 91)
        #expect(HingeLidSource.coverResumeAngle(relight: 100) == HingeLidSource.resumeAngle)
        let source = HingeLidSource()
        #expect(source.requiredResumeAngle == HingeLidSource.resumeAngle)
        source.requiredResumeAngle = Double.nan
        #expect(source.effectiveResumeAngle == HingeLidSource.resumeAngle)
        source.requiredResumeAngle = 10
        #expect(source.effectiveResumeAngle == 90)
        source.requiredResumeAngle = 500
        #expect(source.effectiveResumeAngle == 150)
        // Held still at 110°: not resumable while the App asks for 120°, resumable once it lowers the angle to 91°.
        source.requiredResumeAngle = 120
        let hinge = FakeHinge(source: source)
        hinge.run(0.5) { _ in 110 }
        var resumed = false
        for _ in 0..<180 {
            if feelHold(hinge, 110) { resumed = true }
        }
        #expect(resumed == false)
        source.requiredResumeAngle = HingeLidSource.coverResumeAngle(relight: 88)
        var lowered = false
        for _ in 0..<120 {
            if feelHold(hinge, 110) { lowered = true }
        }
        #expect(lowered)
        // `reset()` leaves the App's angle alone.
        source.reset()
        #expect(source.requiredResumeAngle == 91)
    }

    // MARK: - R7: real hands (ROUND-7 Feel 1, DEVICE-RISKS-1 items 2 and 10)

    /// A careful 10°/s open on a sticky hinge (2° slips, then 0.5° steps) reads as the slow open it is: never over 14°/s
    /// after 0.15 s, and no noise. With a creep report before every slip (the worst hardware shape) a slip reads
    /// briefly over the line, but Core's loud onset leaves ten seconds of it all but silent (R3's estimator: ~0.06).
    @Test func aStickSlipSlowOpenReadsSlow() {
        for stick in [0.2, 0.3] {
            let hinge = FakeHinge(source: HingeLidSource())
            hinge.run(0.5) { _ in 110 }
            hinge.run(10, angle: feelStickSlip(stick: stick))
            var late = 0.0
            for (index, speed) in hinge.speeds.enumerated() where Double(index + 1) * FakeHinge.frame >= stick + 0.15 {
                late = max(late, speed)
            }
            #expect(late <= 14)
            #expect(late > 5)
            #expect(feelLidNoise(hinge.speeds) < 0.001)
        }
        for rate in [30.0, 25.0] {
            let hinge = FakeHinge(source: HingeLidSource())
            hinge.run(0.5, rate: rate) { _ in 110 }
            hinge.run(10, rate: rate, angle: feelStickSlip(stick: 0.3, creep: 0.3, rate: rate))
            #expect((hinge.speeds.max() ?? 99) < 22)
            #expect(feelLidNoise(hinge.speeds) < 0.03)
        }
    }

    /// DEVICE-RISKS-1 item 2: a free-stop hinge breaks away with a tiny first report and a 2° jump 25–33 ms later. R3
    /// read that as 25–29°/s ("Slower…" for a careful hand); the breakaway floor keeps it under 12.
    @Test func aBreakawayFromStillDoesNotSpike() {
        for rate in [50.0, 30.0] {
            let hinge = FakeHinge(source: HingeLidSource())
            hinge.run(0.5, rate: rate) { _ in 120 }
            hinge.run(0.6, rate: rate) { t in t < 1 / rate ? 120.3 : 122.3 }
            #expect((hinge.speeds.max() ?? 99) < 12)
        }
    }

    /// The hygiene never hides a real move: 40°/s from still reads 36–44°/s from 0.32 s on (R3 itself only reached 36
    /// at about 0.28 s: One-Euro start-up and the 0.25 s window) and never over 44; slams stay loud.
    @Test func aRealMoveAndASlamStillReadTrue() {
        for rate in [30.0, 25.0] {
            let hinge = FakeHinge(source: HingeLidSource())
            hinge.run(1.0, rate: rate) { _ in 110 }
            hinge.run(1.0, rate: rate) { t in 110 + 40 * t }
            var settled = 99.0
            for (index, speed) in hinge.speeds.enumerated() where Double(index + 1) * FakeHinge.frame >= 0.32 {
                settled = min(settled, speed)
            }
            #expect(settled >= 36)
            #expect((hinge.speeds.max() ?? 99) <= 44)
        }
        let slam = FakeHinge(source: HingeLidSource())
        slam.run(1.0) { _ in 150 }
        slam.run(0.4) { t in 150 - 200 * min(t, 0.25) }
        #expect((slam.speeds.max() ?? 0) > 80)
        // A 470°/s fling down from 165°: 15° per report, but it leaves the snap zone at once, so it counts.
        let fling = FakeHinge(source: HingeLidSource())
        fling.run(1.0) { _ in 165 }
        fling.run(0.4) { t in max(165 - 470 * t, 100) }
        #expect((fling.speeds.max() ?? 0) > 80)
    }

    /// DEVICE-RISKS-1 item 10: one report jumping more than 8° with both ends at or above 150° is the hinge settling,
    /// not a hand: no speed for the game or for the resume rule. A jump that starts under 150° still counts.
    @Test func aSnapNearFlatCreditsNoSpeed() {
        let hinge = FakeHinge(source: HingeLidSource())
        hinge.run(0.5) { _ in 150 }
        hinge.run(0.6) { t in 150 + 5 * t }
        let creeping = hinge.speeds.max() ?? 0
        #expect(creeping > 3 && creeping < 6)
        var speedPeak = 0.0
        var motionPeak = 0.0
        for _ in 0..<60 {
            hinge.run(FakeHinge.frame) { _ in 162 }
            speedPeak = max(speedPeak, hinge.source.speed)
            motionPeak = max(motionPeak, hinge.source.motionSpeed)
        }
        #expect(speedPeak < 6)
        #expect(motionPeak < 1)
        #expect(hinge.source.traceText().contains("snaps 1"))
        // From still: nothing at all.
        let still = FakeHinge(source: HingeLidSource())
        still.run(0.5) { _ in 153 }
        still.run(0.5) { _ in 162 }
        #expect((still.speeds.max() ?? 99) < 0.5)
        // Crossing up through 150° (149 → 158): a real move, loud.
        let crossing = FakeHinge(source: HingeLidSource())
        crossing.run(0.5) { _ in 140 }
        crossing.run(0.3) { t in 140 + 30 * t }
        crossing.run(0.3) { _ in 158 }
        #expect((crossing.speeds.max() ?? 0) > Tuning.loudSpeed)
        #expect(crossing.source.traceText().contains("snaps 0"))
    }

    // MARK: - R7: haptics for careful play (ROUND-7 Feel 3, DEVICE-RISKS-1 item 6)

    @Test func carefulPlayTicksEveryFourDegrees() {
        // 10°/s for 4 s of quiet play: a tick per 4° (0.4 s apart).
        var ticker = FeelQuietTicker()
        var t = 10.0
        var ticks: [Double] = []
        for _ in 0..<480 {
            t += 1.0 / 120
            let tick = ticker.update(speed: 10, quiet: true, playing: true, at: t)
            if tick { ticks.append(t) }
        }
        #expect(ticks.count >= 9 && ticks.count <= 10)
        for (a, b) in zip(ticks, ticks.dropFirst()) {
            #expect(abs(b - a - 0.4) < 0.02)
        }
        // The creak takes over (loud): no ticks, and the count starts again.
        var loudTicks = 0
        for _ in 0..<240 {
            t += 1.0 / 120
            let tick = ticker.update(speed: 40, quiet: false, playing: true, at: t)
            if tick { loudTicks += 1 }
        }
        #expect(loudTicks == 0)
        #expect(ticker.travel == 0)
        // Never more than 20 a second, however fast a "quiet" speed is.
        var fast = FeelQuietTicker()
        var u = 50.0
        var fastTicks: [Double] = []
        for _ in 0..<120 {
            u += 1.0 / 120
            let tick = fast.update(speed: 400, quiet: true, playing: true, at: u)
            if tick { fastTicks.append(u) }
        }
        #expect(fastTicks.count >= 10 && fastTicks.count <= 21)
        for (a, b) in zip(fastTicks, fastTicks.dropFirst()) {
            #expect(b - a >= FeelQuietTicker.minInterval - 1e-9)
        }
        // Not playing, a still lid (tremor, decay tails) and garbage: nothing.
        var other = FeelQuietTicker()
        var v = 80.0
        var otherTicks = 0
        for k in 0..<480 {
            v += 1.0 / 120
            let paused = other.update(speed: 20, quiet: true, playing: false, at: v)
            let tremor = other.update(speed: 1.5, quiet: true, playing: true, at: v + 0.001)
            let weird = other.update(speed: k % 2 == 0 ? Double.nan : 10, quiet: true, playing: true,
                                     at: k % 3 == 0 ? Double.nan : v + 0.002)
            if paused || tremor || weird { otherTicks += 1 }
        }
        #expect(otherTicks == 0)
        // The tick itself is faint (it must never compete with a creak), and Strong makes it a burst like every cue.
        let tickCue = FeelHapticBook.quietTick
        #expect((tickCue.notes.map { $0.intensity }.max() ?? 1) <= 0.25)
        #expect(FeelHapticBook.adapt(tickCue, to: .strong).notes.allSatisfy { $0.kind == .continuous })
        #expect(FeelHapticBook.stirring.notes.first?.intensity == 0.5)
        // Through the director (haptics off, nothing starts): careful play takes frames without trouble.
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        for frame in 0..<360 {
            director.handle([], telemetry: play(speed: 10, openness: 0.3 + Double(frame) / 1_200))
        }
        director.silence()
        #expect(director.hapticsOn == false)
    }

    @Test func vibrationStrengthFollowsTheDeviceUntilChosen() {
        #expect(HapticStrength.allCases == [.off, .normal, .strong])
        #expect(HapticStrength.defaultFor(hasFold: true) == .strong)
        #expect(HapticStrength.defaultFor(hasFold: false) == .normal)
        for strength in HapticStrength.allCases {
            #expect(HapticStrength(profile: strength.profile) == strength)
            #expect(strength.rawValue == strength.profile.rawValue)
            #expect(!strength.title.isEmpty)
        }
        let director = FeedbackDirector()
        director.soundOn = false
        #expect(director.hapticStrength == .normal)
        // A Duo: Strong until the player chooses.
        director.deviceHasFold = true
        #expect(director.hapticStrength == .strong)
        director.hapticStrength = .normal
        #expect(director.hapticProfile == .normal)
        director.deviceHasFold = false
        director.deviceHasFold = true
        #expect(director.hapticStrength == .normal)
        // Off is the haptics toggle; turning it back on restores the last strength.
        director.hapticStrength = .off
        #expect(director.hapticsOn == false)
        director.hapticsOn = true
        #expect(director.hapticStrength == .normal)
        director.hapticStrength = .strong
        #expect(director.hapticProfile == .strong)
        #expect(director.hapticsOn)
        director.hapticStrength = .off
        #expect(director.hapticStrength == .off)
    }

    // MARK: - R7: the raw hinge trace (ROUND-7 Feel 4, DEVICE-RISKS-1 D4)

    @Test func theHingeTraceKeepsTheLastTenSeconds() {
        var trace = FeelHingeTrace()
        #expect(trace.reports.isEmpty)
        #expect(trace.text(now: nil).contains("no reports"))
        // 20 s at 100 Hz overflows the ring; only the last 10 s are kept, oldest first.
        for k in 0..<2_000 {
            trace.record(angle: 100 + Double(k % 50), at: Double(k) / 100)
        }
        trace.record(angle: Double.nan, at: 30)
        trace.record(angle: 120, at: Double.infinity)
        let kept = trace.reports
        #expect(kept.count >= 1_000 && kept.count <= 1_002)
        #expect(kept.last == FeelHingeTrace.Report(time: Double(1_999) / 100, angle: 100 + Double(1_999 % 50)))
        #expect((kept.first?.time ?? 0) >= Double(1_999) / 100 - FeelHingeTrace.span - 1e-9)
        var ordered = true
        for (a, b) in zip(kept, kept.dropFirst()) where b.time <= a.time { ordered = false }
        #expect(ordered)
        let text = trace.text(now: 20.5, snaps: 3)
        let lines = text.split(separator: "\n")
        #expect(lines.count == 2 + (kept.count + FeelHingeTrace.perLine - 1) / FeelHingeTrace.perLine)
        #expect(text.hasPrefix("Hinge trace (raw, last 10 s): "))
        #expect(text.contains("newest 0.51 s ago"))
        #expect(text.contains("rate 100.0 Hz"))
        #expect(text.contains("snaps 3"))
        trace.removeAll()
        #expect(trace.reports.isEmpty)
        // Through the source: every raw report, unclamped, on the hinge clock.
        let source = HingeLidSource()
        #expect(source.traceText().contains("no reports"))
        let hinge = FakeHinge(source: source)
        hinge.run(0.5) { _ in 120 }
        hinge.run(1.0) { t in 120 + 20 * t }
        let live = source.traceText()
        #expect(live.contains("reports over"))
        #expect(live.contains("120.00"))
        #expect(live.contains("snaps 0"))
    }

    // MARK: - Logging

    @Test func demoLogIsDebugAndHushDemoOnly() {
        #if DEBUG
        #expect(FeelDemoLog.isEnabled == ProcessInfo.processInfo.arguments.contains("-hushDemo"))
        #else
        #expect(FeelDemoLog.isEnabled == false)
        #endif
        #expect(FeelHingeLog.isEnabled == FeelDemoLog.isEnabled)
    }
}
