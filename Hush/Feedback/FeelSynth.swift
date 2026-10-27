import Foundation
import Synchronization

// MARK: - Commands (main thread → audio thread)
//
// Every payload is a plain value (Floats, Ints, enums without payloads), so copying a command never touches ARC and
// the audio thread can read it from the lock-free queue without allocating or locking. Ported from Swoop's FeelSynth.

enum FeelFilterMode: Sendable, Equatable {
    case lowPass, bandPass, highPass
}

/// Partial tables for struck resonators.
enum FeelRingKind: Sendable, Equatable {
    /// A soft, nearly pure bell (harmonic partials 1, 2, 3, 4.2 … rolled off hard).
    case chime
    /// Inharmonic church-bell partials (prime, hum an octave down, minor-third tierce, quint, nominal): gems, ka-ching.
    case bell
    /// A marimba bar (1, 3.93, 9.3 …): soft UI notes.
    case marimba
    /// A wooden tick: UI clicks, teeth, knocks.
    case wood
    /// Glassy, sparse, bright: glints, sparkles.
    case glass
    /// A plucked string (harmonic, a touch stiff): the tiptoe pizzicato.
    case pluck
}

/// A one-shot filtered-noise burst (thumps, cracks, breaths), optionally sweeping its cutoff.
struct FeelNoiseSpec: Sendable, Equatable {
    var mode: FeelFilterMode
    var cutoff: Float
    var cutoffEnd: Float
    var sweep: Float
    var q: Float
    var attack: Float
    /// Exponential decay time constant (s).
    var decay: Float
    var gain: Float
    var delay: Float

    init(_ mode: FeelFilterMode, cutoff: Float, to cutoffEnd: Float? = nil, sweep: Float = 0, q: Float = 0.8,
         attack: Float = 0.002, decay: Float, gain: Float, delay: Float = 0) {
        self.mode = mode
        self.cutoff = cutoff
        self.cutoffEnd = cutoffEnd ?? cutoff
        self.sweep = sweep
        self.q = q
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// A pitched tone with a glide, vibrato and a 1/n harmonic stack (thumps, chords, the burp-y growl).
struct FeelToneSpec: Sendable, Equatable {
    var start: Float
    var end: Float
    var glide: Float
    var duration: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var harmonics: Int
    var vibratoRate: Float
    var vibratoDepth: Float
    var delay: Float

    init(start: Float, end: Float? = nil, glide: Float = 0.1, duration: Float, attack: Float = 0.01, decay: Float,
         gain: Float, harmonics: Int = 1, vibratoRate: Float = 0, vibratoDepth: Float = 0, delay: Float = 0) {
        self.start = start
        self.end = end ?? start
        self.glide = glide
        self.duration = duration
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.harmonics = harmonics
        self.vibratoRate = vibratoRate
        self.vibratoDepth = vibratoDepth
        self.delay = delay
    }
}

/// A struck modal resonator: up to `FeelSynth.maxPartials` decaying sinusoids.
struct FeelRingSpec: Sendable, Equatable {
    var kind: FeelRingKind
    var fundamental: Float
    var partials: Int
    /// Decay time constant of the first partial (s); higher partials decay faster.
    var decay: Float
    /// Amplitude roll-off per partial, 0…1 (higher = brighter).
    var brightness: Float
    var gain: Float
    var delay: Float
    /// Seeds a ±1.5 % partial detune so two strikes never sound identical.
    var seed: UInt32

    init(_ kind: FeelRingKind, fundamental: Float, partials: Int = 4, decay: Float, brightness: Float = 0.5,
         gain: Float, delay: Float = 0, seed: UInt32 = 1) {
        self.kind = kind
        self.fundamental = fundamental
        self.partials = partials
        self.decay = decay
        self.brightness = brightness
        self.gain = gain
        self.delay = delay
        self.seed = seed
    }
}

/// A water droplet (Minnaert bubble): a decaying sine whose pitch chirps (dungeon drips, the oil glug).
struct FeelDropSpec: Sendable, Equatable {
    var frequency: Float
    /// Pitch ratio reached by the end of the pop (> 1 rises).
    var chirp: Float
    var decay: Float
    var gain: Float
    var delay: Float

    init(frequency: Float, chirp: Float = 1.5, decay: Float, gain: Float, delay: Float = 0) {
        self.frequency = frequency
        self.chirp = chirp
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// A two-operator FM tone: a sine carrier phase-modulated by a sine at `ratio` × the carrier, whose index decays
/// faster than the tone. Inharmonic ratios make metal: the coin clinks.
struct FeelFMSpec: Sendable, Equatable {
    var carrier: Float
    var ratio: Float
    /// Peak modulation index (radians).
    var index: Float
    /// Time constant (s) of the index's decay (the clink's brightness falls away first).
    var indexDecay: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var delay: Float

    init(carrier: Float, ratio: Float, index: Float, indexDecay: Float, attack: Float = 0.0008, decay: Float,
         gain: Float, delay: Float = 0) {
        self.carrier = carrier
        self.ratio = ratio
        self.index = index
        self.indexDecay = indexDecay
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// The continuous layers (sent every frame, glided per sample on the audio thread).
struct FeelBed: Sendable, Equatable {
    /// Master gain (0 = silent; sound off goes through here).
    var master: Float = 0
    /// Time constant (s) of the glide from the current layers to this bed (frames: ~0.05; silence: ~0.35).
    var glide: Float = 0.05

    // The creak (the hero): stick-slip groan + friction grains + squeal.
    /// 0…1 overall level (0 = silent).
    var creak: Float = 0
    /// The groan's stick-slip fundamental (Hz), 140…420.
    var creakHz: Float = 160
    /// Friction grains per second.
    var grainRate: Float = 0
    /// 0…1: how bright the grains and the groan's resonance are.
    var creakBright: Float = 0.3
    /// 0…1 level of the squeal partial (only past ~25°/s).
    var squeal: Float = 0
    var squealHz: Float = 1900

    // The mimic.
    /// 0…1 snore level (breath noise + the nasal tone on the inhale).
    var snore: Float = 0
    /// Mean snore cycle (s); each cycle varies ±15 %.
    var snorePeriod: Float = 4.2
    /// 0…1 growl level.
    var growl: Float = 0

    // Music: the tiptoe pizzicato (92 bpm, eighth notes).
    /// 0…1 level of the motif.
    var motif: Float = 0
    /// 0…1: which notes play (1 all, ~0.5 quarters, ~0.3 downbeats only, 0 none).
    var motifDensity: Float = 1

    // The dungeon.
    /// 0…1: the low drone and the cave air.
    var drone: Float = 0
    /// Drips per second.
    var dripRate: Float = 0
    /// 0…1: the torch's flame breath and crackle.
    var crackle: Float = 0
    /// Crackles per second.
    var crackleRate: Float = 0

    // Loot rattling while dragged fast.
    var rattle: Float = 0
    var rattleRate: Float = 0

    /// True when any continuous layer is audible (the engine stays awake for it).
    var hasLayers: Bool {
        let zero: Float = 0
        if creak > zero || squeal > zero || snore > zero { return true }
        if growl > zero || motif > zero || drone > zero { return true }
        return crackle > zero || rattle > zero || dripRate > zero
    }

    mutating func approach(_ target: FeelBed, _ k: Float) {
        master += (target.master - master) * k
        creak += (target.creak - creak) * k
        creakHz += (target.creakHz - creakHz) * k
        grainRate += (target.grainRate - grainRate) * k
        creakBright += (target.creakBright - creakBright) * k
        squeal += (target.squeal - squeal) * k
        squealHz += (target.squealHz - squealHz) * k
        snore += (target.snore - snore) * k
        snorePeriod += (target.snorePeriod - snorePeriod) * k
        growl += (target.growl - growl) * k
        motif += (target.motif - motif) * k
        motifDensity += (target.motifDensity - motifDensity) * k
        drone += (target.drone - drone) * k
        dripRate += (target.dripRate - dripRate) * k
        crackle += (target.crackle - crackle) * k
        crackleRate += (target.crackleRate - crackleRate) * k
        rattle += (target.rattle - rattle) * k
        rattleRate += (target.rattleRate - rattleRate) * k
    }
}

enum FeelSynthCommand: Sendable, Equatable {
    case bed(FeelBed)
    case noise(FeelNoiseSpec)
    case tone(FeelToneSpec)
    case ring(FeelRingSpec)
    case drop(FeelDropSpec)
    case fm(FeelFMSpec)
    /// Stop every one-shot voice and the continuous layers' grain state now (sound switched off, an interruption).
    case stopAll

    /// Peak gain parameter (0 for `bed`/`stopAll`), for tests.
    var gain: Float {
        switch self {
        case .noise(let spec): return spec.gain
        case .tone(let spec): return spec.gain
        case .ring(let spec): return spec.gain
        case .drop(let spec): return spec.gain
        case .fm(let spec): return spec.gain
        case .bed, .stopAll: return 0
        }
    }

    /// When the voice starts (s after the command), for tests.
    var delay: Float {
        switch self {
        case .noise(let spec): return spec.delay
        case .tone(let spec): return spec.delay
        case .ring(let spec): return spec.delay
        case .drop(let spec): return spec.delay
        case .fm(let spec): return spec.delay
        case .bed, .stopAll: return 0
        }
    }
}

// MARK: - DSP building blocks (audio thread)

/// Topology-preserving state-variable filter (Zavalishin), from Squish/Brim/Swoop. Band-pass normalised to 0 dB at
/// centre.
private struct FeelSVF {
    var a1: Float = 0, a2: Float = 0, a3: Float = 0, k: Float = 1
    var ic1: Float = 0, ic2: Float = 0

    mutating func tune(cutoff: Float, q: Float, sampleRate: Float) {
        let f = min(max(cutoff, 20), sampleRate * 0.45)
        let g = tan(Float.pi * f / sampleRate)
        k = 1 / max(q, 0.1)
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    mutating func process(_ x: Float, _ mode: FeelFilterMode) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        switch mode {
        case .lowPass: return v2
        case .bandPass: return v1 * k
        case .highPass: return x - k * v1 - v2
        }
    }
}

private enum FeelVoiceKind {
    case noise, tone, ring, drop, fm
}

private struct FeelVoice {
    var active = false
    var kind: FeelVoiceKind = .noise
    var delay = 0
    var age = 0
    var attack = 1
    var length = 0
    var decayRate: Float = 1
    var level: Float = 1
    var gain: Float = 0
    // Noise.
    var filter = FeelSVF()
    var mode: FeelFilterMode = .bandPass
    var q: Float = 1
    var cutoff: Float = 1000
    var cutoffEnd: Float = 1000
    var sweepSamples = 0
    // Tone, drop and FM.
    var phase: Float = 0
    var frequency: Float = 0
    var startFrequency: Float = 0
    var endFrequency: Float = 0
    var glide = 1
    var harmonics = 1
    var vibratoPhase: Float = 0
    var vibratoRate: Float = 0
    var vibratoDepth: Float = 0
    var chirpPerSample: Float = 1
    // FM.
    var modPhase: Float = 0
    var modRatio: Float = 1
    var index: Float = 0
    var indexRate: Float = 1
    // Ring (its partial state lives in the synth's bank at this voice's slot).
    var partialCount = 0
}

// MARK: - Synth

/// Hush's real-time synth, rendered inside an `AVAudioSourceNode` (mono Float32). Ported from Swoop's `FeelSynth`
/// (lock-free command queue, voice pool, modal bank, limiter), with Hush's continuous layers: the creak, the snore,
/// the growl, the tiptoe motif, the dungeon and the loot rattle.
///
/// Threading: the main thread calls `send` (single producer); the audio thread calls `render` (single consumer).
/// Commands cross through a fixed-capacity single-producer/single-consumer ring whose two indices are atomics
/// (acquire/release), so the render path takes no locks, never allocates and never touches ARC.
/// Master chain: DC blocker → peak-follower limiter (ceiling 0.9) → tanh soft clip, so the output can never clip.
final class FeelSynth: @unchecked Sendable {
    let sampleRate: Float

    static let voiceCount = 48
    static let maxPartials = 6
    static let queueCapacity = 512
    static let ceiling: Float = 0.9
    private static let partialStride = 5 // re, im, cos, sin, decay
    /// Below this a continuous layer is skipped entirely.
    private static let quiet: Float = 0.00002
    /// The tiptoe motif: 92 bpm, eighth notes, a 32-step loop; D4 is the root.
    static let motifBPM: Float = 92
    static let motifSteps = 32
    static let motifRootHz: Float = 293.66
    /// The groan's mix and the grains' mix inside the creak (before `bed.creak` and master).
    static let groanGain: Float = 0.11
    static let bodyGain: Float = 0.05
    static let grainGain: Float = 2.0
    static let squealGain: Float = 0.06

    private let queue: UnsafeMutablePointer<FeelSynthCommand>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)
    private let peakBits = Atomic<UInt32>(0)
    private let renderCount = Atomic<Int>(0)

    // Audio-thread-only state below.
    private let voices: UnsafeMutablePointer<FeelVoice>
    private let bank: UnsafeMutablePointer<Float>
    private var bed = FeelBed()
    private var target = FeelBed()
    private var glideK: Float = 0
    private var noiseState: UInt32 = 0x2545_F491
    private var retuneCounter = 0

    // Creak.
    private var creakPhase: Float = 0
    private var creakSlip: Float = 0.8
    private var creakJitter: Float = 1
    private var wobbleValue: Float = 0
    private var wobbleTarget: Float = 0
    private var wobbleCountdown = 0
    private var groanFilter = FeelSVF()
    private var bodyFilter = FeelSVF()
    private var grainFilter = FeelSVF()
    private var grainEnv: Float = 0
    private var grainAmp: Float = 0
    private var grainDecay: Float = 0.99
    private var squealPhase: Float = 0
    private var squealVibrato: Float = 0
    private var squealAmp: Float = 0
    // Snore.
    private var snorePhase: Float = 0
    private var snoreCycle: Float = 4.2
    private var snoreTonePhase: Float = 0
    private var snoreFlutter: Float = 0
    private var inhaleFilter = FeelSVF()
    private var exhaleFilter = FeelSVF()
    private var snoreToneFilter = FeelSVF()
    // Growl.
    private var growlPhase: Float = 0
    private var growlRough: Float = 0
    private var growlLFO: Float = 0
    private var growlNoiseFilter = FeelSVF()
    private var growlToneFilter = FeelSVF()
    // Motif.
    private var motifCountdown = 0
    private var motifStep = -1
    // Dungeon.
    private var dronePhaseA: Float = 0
    private var dronePhaseB: Float = 0
    private var dronePhaseC: Float = 0
    private var droneLFO: Float = 0
    private var airFilter = FeelSVF()
    private var flameFilter = FeelSVF()
    private var crackleFilter = FeelSVF()
    private var crackleEnv: Float = 0
    // Rattle.
    private var rattleFilterA = FeelSVF()
    private var rattleFilterB = FeelSVF()
    private var rattleEnv: Float = 0
    // Master.
    private var dcIn: Float = 0
    private var dcOut: Float = 0
    private var envelope: Float = 0

    private let wobbleStep: Float
    private let squealAmpStep: Float
    private let crackleDecay: Float
    private let rattleDecay: Float
    private let envelopeRelease: Float
    private let dcCoefficient: Float
    private let motifStepSamples: Int

    init(sampleRate: Float) {
        let rate: Float = sampleRate > 1000 ? sampleRate : 48_000
        self.sampleRate = rate
        queue = UnsafeMutablePointer<FeelSynthCommand>.allocate(capacity: FeelSynth.queueCapacity)
        queue.initialize(repeating: .stopAll, count: FeelSynth.queueCapacity)
        voices = UnsafeMutablePointer<FeelVoice>.allocate(capacity: FeelSynth.voiceCount)
        voices.initialize(repeating: FeelVoice(), count: FeelSynth.voiceCount)
        let bankSize = FeelSynth.voiceCount * FeelSynth.maxPartials * FeelSynth.partialStride
        bank = UnsafeMutablePointer<Float>.allocate(capacity: bankSize)
        bank.initialize(repeating: 0, count: bankSize)
        glideK = 1 - exp(-1 / (0.05 * rate))
        wobbleStep = 1 - exp(-1 / (0.05 * rate))
        squealAmpStep = 1 - exp(-1 / (0.0015 * rate))
        crackleDecay = exp(-1 / (0.0016 * rate))
        rattleDecay = exp(-1 / (0.0028 * rate))
        envelopeRelease = exp(-1 / (0.08 * rate))
        dcCoefficient = 1 - 2 * Float.pi * 30 / rate
        motifStepSamples = max(Int(rate * 60 / FeelSynth.motifBPM / 2), 1)
        tuneFixedFilters()
        retuneContinuous()
    }

    deinit {
        queue.deinitialize(count: FeelSynth.queueCapacity)
        queue.deallocate()
        voices.deinitialize(count: FeelSynth.voiceCount)
        voices.deallocate()
        bank.deallocate()
    }

    // MARK: Main thread

    /// Queue a command (main thread only). Returns false if the queue is full (the command is dropped, never blocks).
    @discardableResult
    func send(_ command: FeelSynthCommand) -> Bool {
        let write = writeIndex.load(ordering: .relaxed)
        let next = (write + 1) % FeelSynth.queueCapacity
        guard next != readIndex.load(ordering: .acquiring) else { return false }
        queue[write] = command
        writeIndex.store(next, ordering: .releasing)
        return true
    }

    /// Loudest output sample so far (linear), for tests and diagnostics.
    var peak: Float { Float(bitPattern: peakBits.load(ordering: .relaxed)) }

    /// Render callbacks so far: if it stops climbing, the engine isn't pulling audio.
    var renderCallbacks: Int { renderCount.load(ordering: .relaxed) }

    // MARK: Audio thread

    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        drain()
        let twoPi = 2 * Float.pi
        var blockPeak: Float = 0
        for frame in 0..<frames {
            bed.approach(target, glideK)
            retuneCounter += 1
            if retuneCounter >= 32 {
                retuneCounter = 0
                retuneContinuous()
            }

            var sample: Float = 0
            if bed.creak > FeelSynth.quiet || bed.squeal > FeelSynth.quiet {
                sample += renderCreak()
            }
            if bed.snore > FeelSynth.quiet {
                sample += renderSnore()
            }
            if bed.growl > FeelSynth.quiet {
                sample += renderGrowl()
            }
            if bed.motif > FeelSynth.quiet {
                runMotif()
            } else {
                motifCountdown = 0
            }
            if bed.drone > FeelSynth.quiet {
                droneLFO += twoPi * 0.07 / sampleRate
                if droneLFO > twoPi { droneLFO -= twoPi }
                dronePhaseA += twoPi * 146.83 / sampleRate
                if dronePhaseA > twoPi { dronePhaseA -= twoPi }
                dronePhaseB += twoPi * 220.6 / sampleRate
                if dronePhaseB > twoPi { dronePhaseB -= twoPi }
                dronePhaseC += twoPi * 293.1 / sampleRate
                if dronePhaseC > twoPi { dronePhaseC -= twoPi }
                let breathe: Float = 0.75 + 0.25 * sin(droneLFO)
                let hum: Float = 0.5 * sin(dronePhaseA) + 0.3 * sin(dronePhaseB) * breathe + 0.16 * sin(dronePhaseC)
                let air = airFilter.process(nextNoise(), .lowPass) * 0.5
                sample += (hum * 0.026 * breathe + air * 0.024) * bed.drone
            }
            if bed.dripRate > 0.001, unitNoise() < bed.dripRate / sampleRate {
                let f: Float = 1100 + 1300 * unitNoise()
                let gain: Float = 0.035 + 0.04 * unitNoise()
                start(.drop(FeelDropSpec(frequency: f, chirp: 1.7, decay: 0.025 + 0.02 * unitNoise(), gain: gain)))
                // A faint cave echo.
                start(.drop(FeelDropSpec(frequency: f * 0.98, chirp: 1.6, decay: 0.03, gain: gain * 0.28,
                                         delay: 0.13 + 0.05 * unitNoise())))
            }
            if bed.crackle > FeelSynth.quiet {
                if unitNoise() < bed.crackleRate / sampleRate { crackleEnv = 0.3 + 0.7 * unitNoise() }
                crackleEnv *= crackleDecay
                let flame = flameFilter.process(nextNoise(), .bandPass) * 0.04
                let pop = crackleFilter.process(nextNoise() * crackleEnv, .highPass) * 0.26
                sample += (flame + pop) * bed.crackle
            }
            if bed.rattle > FeelSynth.quiet {
                if unitNoise() < bed.rattleRate / sampleRate { rattleEnv = 0.4 + 0.6 * unitNoise() }
                rattleEnv *= rattleDecay
                if rattleEnv > 0.0005 {
                    let n = nextNoise() * rattleEnv
                    sample += (rattleFilterA.process(n, .bandPass) + rattleFilterB.process(n, .bandPass) * 0.7)
                        * 0.9 * bed.rattle
                }
            }
            for index in 0..<FeelSynth.voiceCount where voices[index].active {
                sample += renderVoice(&voices[index], slot: index)
            }
            sample *= bed.master

            // DC blocker (30 Hz), then a peak follower that keeps the drive at or below the ceiling, then tanh.
            let blocked = sample - dcIn + dcCoefficient * dcOut
            dcIn = sample
            dcOut = blocked
            let magnitude = abs(blocked)
            envelope = max(magnitude, envelope * envelopeRelease)
            let drive = envelope > FeelSynth.ceiling ? FeelSynth.ceiling / envelope : 1
            var shaped = tanh(blocked * drive)
            if !shaped.isFinite {
                shaped = 0
                resetFilters()
            }
            shaped = min(max(shaped, -0.98), 0.98)
            blockPeak = max(blockPeak, abs(shaped))
            out[frame] = shaped
        }
        let previous = Float(bitPattern: peakBits.load(ordering: .relaxed))
        if blockPeak > previous { peakBits.store(blockPeak.bitPattern, ordering: .relaxed) }
        renderCount.store(renderCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
    }

    // MARK: The creak

    /// Wood friction, the hero. Three parts, all following the bed per sample (no zipper):
    /// - the **groan**: a stick-slip pulse train (a band-limited saw whose every period has its own slip strength and a
    ///   ±7 % period jitter, with an occasional "catch") through a resonant low-pass at ~3× its pitch, plus a fixed
    ///   wooden body formant (1.1 kHz). Its pitch wavers on a slow random walk (±9 %);
    /// - **friction grains**: tiny noise bursts (1.5–5.5 ms) at `grainRate`, each through its own resonant band
    ///   (600–2,500 Hz, brighter with speed): the dry ticking of the fibres;
    /// - the **squeal**: a sine partial (1.7–2.6 kHz) whose amplitude flutters with the slips.
    private func renderCreak() -> Float {
        // Pitch wobble: a smoothed random walk, a new target every 40–120 ms.
        wobbleCountdown -= 1
        if wobbleCountdown <= 0 {
            wobbleTarget = 2 * unitNoise() - 1
            wobbleCountdown = Int(sampleRate * (0.04 + 0.08 * unitNoise())) + 1
        }
        wobbleValue += (wobbleTarget - wobbleValue) * wobbleStep
        let pitch = min(max(bed.creakHz, 40), 900) * (1 + 0.09 * wobbleValue)
        let dt = min(pitch * creakJitter / sampleRate, 0.25)
        creakPhase += dt
        if creakPhase >= 1 {
            creakPhase -= 1
            // A new slip: its strength, and its period's jitter. Now and then the wood "catches" (a weak slip).
            if unitNoise() < 0.08 {
                creakSlip = 0.15 + 0.15 * unitNoise()
            } else {
                creakSlip = 0.55 + 0.45 * unitNoise()
            }
            creakJitter = 1 + 0.07 * (2 * unitNoise() - 1)
        }
        let saw = (2 * creakPhase - 1 - FeelSynth.polyBlep(creakPhase, dt)) * creakSlip
        let groan = groanFilter.process(saw, .lowPass) * FeelSynth.groanGain
        let body = bodyFilter.process(saw, .bandPass) * FeelSynth.bodyGain

        // Friction grains.
        if bed.grainRate > 0.01, unitNoise() < bed.grainRate / sampleRate {
            grainAmp = 0.35 + 0.65 * unitNoise()
            grainEnv = 1
            grainDecay = exp(-1 / ((0.0015 + 0.004 * unitNoise()) * sampleRate))
            let spread: Float = min(max(0.7 * bed.creakBright + 0.45 * unitNoise() - 0.1, 0), 1)
            let band: Float = 2500.0 / 600.0
            grainFilter.tune(cutoff: 600 * pow(band, spread), q: 3.5, sampleRate: sampleRate)
        }
        grainEnv *= grainDecay
        let grain = grainFilter.process(nextNoise() * grainEnv * grainAmp, .bandPass) * FeelSynth.grainGain

        var squeal: Float = 0
        if bed.squeal > FeelSynth.quiet {
            let twoPi = 2 * Float.pi
            squealVibrato += twoPi * 6.5 / sampleRate
            if squealVibrato > twoPi { squealVibrato -= twoPi }
            let wander: Float = 1 + 0.012 * sin(squealVibrato) + 0.02 * wobbleValue
            let f: Float = min(max(bed.squealHz, 200), sampleRate * 0.4) * wander
            squealPhase += twoPi * f / sampleRate
            if squealPhase > twoPi { squealPhase -= twoPi }
            squealAmp += (creakSlip - squealAmp) * squealAmpStep
            squeal = sin(squealPhase) * (0.4 + 0.6 * squealAmp) * FeelSynth.squealGain * bed.squeal
        }
        return (groan + body + grain) * bed.creak + squeal
    }

    /// Band-limited step correction for the saw (PolyBLEP), so the groan doesn't alias.
    private static func polyBlep(_ t: Float, _ dt: Float) -> Float {
        guard dt > 0 else { return 0 }
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        }
        if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    // MARK: The snore

    /// A 3.5–5 s cycle: a nasal inhale ("snrrk": breath noise round 420 Hz plus a fluttering 95 Hz tone), a softer
    /// breathy exhale ("hhhh", round 900 Hz), then a pause.
    private func renderSnore() -> Float {
        let twoPi = 2 * Float.pi
        snorePhase += 1 / (max(snoreCycle, 1) * sampleRate)
        if snorePhase >= 1 {
            snorePhase -= 1
            snoreCycle = min(max(bed.snorePeriod, 2), 8) * (0.85 + 0.3 * unitNoise())
        }
        var out: Float = 0
        if snorePhase < 0.42 {
            let s = sin(Float.pi * snorePhase / 0.42)
            let env = s * s
            snoreFlutter += twoPi * 27 / sampleRate
            if snoreFlutter > twoPi { snoreFlutter -= twoPi }
            let flutter: Float = 0.45 + 0.55 * (0.5 + 0.5 * sin(snoreFlutter))
            let dt: Float = 95 / sampleRate
            snoreTonePhase += dt
            if snoreTonePhase >= 1 { snoreTonePhase -= 1 }
            let saw = 2 * snoreTonePhase - 1 - FeelSynth.polyBlep(snoreTonePhase, dt)
            let tone = snoreToneFilter.process(saw, .lowPass) * 0.08 * flutter
            let breath = inhaleFilter.process(nextNoise(), .bandPass) * 0.11 * flutter
            out = (tone + breath) * env
        } else if snorePhase > 0.48 && snorePhase < 0.86 {
            let s = sin(Float.pi * (snorePhase - 0.48) / 0.38)
            out = exhaleFilter.process(nextNoise(), .bandPass) * 0.065 * s * s
        }
        return out * bed.snore
    }

    // MARK: The growl

    /// A low rough growl: noise through a resonant 260 Hz low-pass, rattled at ~23 Hz (vocal fry), over a buzzy 78 Hz
    /// saw through a 420 Hz low-pass whose pitch drifts slowly.
    private func renderGrowl() -> Float {
        let twoPi = 2 * Float.pi
        growlLFO += twoPi * 0.7 / sampleRate
        if growlLFO > twoPi { growlLFO -= twoPi }
        growlRough += twoPi * 23 / sampleRate
        if growlRough > twoPi { growlRough -= twoPi }
        let rough: Float = 0.35 + 0.65 * (0.5 + 0.5 * sin(growlRough))
        let drift: Float = 1 + 0.06 * sin(growlLFO)
        let dt: Float = 78 * drift / sampleRate
        growlPhase += dt
        if growlPhase >= 1 { growlPhase -= 1 }
        let saw = 2 * growlPhase - 1 - FeelSynth.polyBlep(growlPhase, dt)
        let tone = growlToneFilter.process(saw, .lowPass) * 0.065
        let noise = growlNoiseFilter.process(nextNoise(), .lowPass) * 0.12
        return (tone + noise) * rough * bed.growl
    }

    // MARK: The tiptoe motif

    /// Semitones above the root for each of the 32 eighth-note steps (D minor, a sneaking ostinato), or nil for a rest.
    /// A switch, not an array: no lazy global initialisation on the audio thread.
    static func motifNote(_ step: Int) -> Int? {
        switch step {
        // D · A · F · A ·
        case 0: return 0
        case 2: return 7
        case 4: return 3
        case 6: return 7
        // D · A · B♭ A G F
        case 8: return 0
        case 10: return 7
        case 12: return 8
        case 13: return 7
        case 14: return 5
        case 15: return 3
        // C · G · E · G ·
        case 16: return -2
        case 18: return 5
        case 20: return 2
        case 22: return 5
        // C♯ · E · G F E C♯
        case 24: return -1
        case 26: return 2
        case 28: return 5
        case 29: return 3
        case 30: return 2
        case 31: return -1
        default: return nil
        }
    }

    /// How essential a step is (1 = a bar's downbeat … 0.33 = an off-beat eighth). A step plays when its weight
    /// reaches `1.001 − density`.
    static func motifWeight(_ step: Int) -> Float {
        if step % 8 == 0 { return 1 }
        if step % 4 == 0 { return 0.8 }
        if step % 2 == 0 { return 0.6 }
        return 0.33
    }

    private func runMotif() {
        motifCountdown -= 1
        guard motifCountdown <= 0 else { return }
        motifCountdown = motifStepSamples
        motifStep = (motifStep + 1) % FeelSynth.motifSteps
        guard let note = FeelSynth.motifNote(motifStep) else { return }
        let weight = FeelSynth.motifWeight(motifStep)
        guard weight >= 1.001 - bed.motifDensity else { return }
        let f = FeelSynth.motifRootHz * pow(2, Float(note) / 12)
        let accent: Float = weight >= 1 ? 1 : 0.75
        start(.ring(FeelRingSpec(.pluck, fundamental: f, partials: 5, decay: 0.14, brightness: 0.42,
                                 gain: 0.075 * bed.motif * accent, seed: UInt32(motifStep * 7 + 3))))
    }

    // MARK: Plumbing

    private func tuneFixedFilters() {
        bodyFilter.tune(cutoff: 1100, q: 2.5, sampleRate: sampleRate)
        grainFilter.tune(cutoff: 1200, q: 3.5, sampleRate: sampleRate)
        inhaleFilter.tune(cutoff: 420, q: 1.3, sampleRate: sampleRate)
        exhaleFilter.tune(cutoff: 900, q: 0.9, sampleRate: sampleRate)
        snoreToneFilter.tune(cutoff: 600, q: 1.2, sampleRate: sampleRate)
        growlNoiseFilter.tune(cutoff: 260, q: 3, sampleRate: sampleRate)
        growlToneFilter.tune(cutoff: 420, q: 2, sampleRate: sampleRate)
        airFilter.tune(cutoff: 240, q: 0.7, sampleRate: sampleRate)
        flameFilter.tune(cutoff: 1300, q: 0.5, sampleRate: sampleRate)
        crackleFilter.tune(cutoff: 2400, q: 0.7, sampleRate: sampleRate)
        rattleFilterA.tune(cutoff: 3150, q: 12, sampleRate: sampleRate)
        rattleFilterB.tune(cutoff: 4720, q: 12, sampleRate: sampleRate)
    }

    private func retuneContinuous() {
        let pitch = min(max(bed.creakHz, 40), 900) * (1 + 0.09 * wobbleValue)
        let bright = min(max(bed.creakBright, 0), 1)
        groanFilter.tune(cutoff: pitch * (2.4 + 2 * bright), q: 5, sampleRate: sampleRate)
    }

    private func drain() {
        var read = readIndex.load(ordering: .relaxed)
        let write = writeIndex.load(ordering: .acquiring)
        var handled = 0
        while read != write && handled < 128 {
            let command = queue[read]
            read = (read + 1) % FeelSynth.queueCapacity
            handled += 1
            apply(command)
        }
        readIndex.store(read, ordering: .releasing)
    }

    private func apply(_ command: FeelSynthCommand) {
        switch command {
        case .bed(let params):
            target = params
            let glide = params.glide.isFinite ? max(params.glide, 0.004) : 0.05
            glideK = 1 - exp(-1 / (glide * sampleRate))
        case .stopAll:
            for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
            grainEnv = 0
            crackleEnv = 0
            rattleEnv = 0
        case .noise, .tone, .ring, .drop, .fm:
            start(command)
        }
    }

    private func resetFilters() {
        groanFilter = FeelSVF()
        bodyFilter = FeelSVF()
        grainFilter = FeelSVF()
        inhaleFilter = FeelSVF()
        exhaleFilter = FeelSVF()
        snoreToneFilter = FeelSVF()
        growlNoiseFilter = FeelSVF()
        growlToneFilter = FeelSVF()
        airFilter = FeelSVF()
        flameFilter = FeelSVF()
        crackleFilter = FeelSVF()
        rattleFilterA = FeelSVF()
        rattleFilterB = FeelSVF()
        tuneFixedFilters()
        retuneContinuous()
        grainEnv = 0
        crackleEnv = 0
        rattleEnv = 0
        envelope = 0
        dcIn = 0
        dcOut = 0
        for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
    }

    private func nextNoise() -> Float {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }

    private func unitNoise() -> Float {
        (nextNoise() + 1) * 0.5
    }

    private func start(_ command: FeelSynthCommand) {
        var slot = -1
        var oldest = -1
        var oldestAge = -1
        for index in 0..<FeelSynth.voiceCount {
            if !voices[index].active {
                slot = index
                break
            }
            if voices[index].age > oldestAge {
                oldestAge = voices[index].age
                oldest = index
            }
        }
        if slot < 0 { slot = oldest }
        guard slot >= 0 else { return }
        var voice = FeelVoice()
        voice.active = true
        switch command {
        case .noise(let spec):
            voice.kind = .noise
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.mode = spec.mode
            voice.q = spec.q
            voice.cutoff = spec.cutoff
            voice.cutoffEnd = spec.cutoffEnd
            voice.sweepSamples = abs(spec.cutoffEnd - spec.cutoff) > 1 ? max(Int(spec.sweep * sampleRate), 1) : 0
            voice.filter.tune(cutoff: spec.cutoff, q: spec.q, sampleRate: sampleRate)
        case .tone(let spec):
            voice.kind = .tone
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.length = max(Int(spec.duration * sampleRate), voice.attack + 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.gain = spec.gain
            voice.startFrequency = spec.start
            voice.endFrequency = spec.end
            voice.glide = max(Int(spec.glide * sampleRate), 1)
            voice.harmonics = min(max(spec.harmonics, 1), 8)
            voice.vibratoRate = spec.vibratoRate
            voice.vibratoDepth = spec.vibratoDepth
        case .drop(let spec):
            voice.kind = .drop
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0015 * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 6)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.frequency, 40), sampleRate * 0.4)
            voice.chirpPerSample = pow(max(spec.chirp, 0.25), 1 / Float(max(voice.length, 1)))
        case .fm(let spec):
            voice.kind = .fm
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.carrier, 40), sampleRate * 0.42)
            voice.modRatio = max(spec.ratio, 0.01)
            voice.index = max(spec.index, 0)
            voice.indexRate = exp(-1 / max(spec.indexDecay * sampleRate, 1))
        case .ring(let spec):
            voice.kind = .ring
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0005 * sampleRate), 1)
            voice.decayRate = 1
            voice.length = min(Int(spec.decay * sampleRate * 7), Int(sampleRate * 6))
            voice.gain = 1
            configureRing(spec, slot: slot, voice: &voice)
        case .bed, .stopAll:
            return
        }
        voices[slot] = voice
    }

    private static func ratio(_ kind: FeelRingKind, _ n: Int) -> Float {
        switch kind {
        case .chime:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.0
            case 3: return 4.2
            case 4: return 5.4
            default: return 6.8
            }
        case .bell:
            switch n {
            case 0: return 1      // prime
            case 1: return 0.5    // hum
            case 2: return 1.19   // tierce (minor third)
            case 3: return 1.5    // quint
            case 4: return 2.0    // nominal
            default: return 2.66
            }
        case .marimba:
            switch n {
            case 0: return 1
            case 1: return 3.93
            case 2: return 9.3
            case 3: return 12.0
            case 4: return 15.2
            default: return 18.6
            }
        case .wood:
            switch n {
            case 0: return 1
            case 1: return 2.6
            case 2: return 3.9
            case 3: return 5.4
            case 4: return 6.9
            default: return 8.6
            }
        case .glass:
            switch n {
            case 0: return 1
            case 1: return 2.32
            case 2: return 4.25
            case 3: return 6.63
            case 4: return 9.38
            default: return 12.1
            }
        case .pluck:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.005
            case 3: return 4.015
            case 4: return 5.03
            default: return 6.05
            }
        }
    }

    private func configureRing(_ spec: FeelRingSpec, slot: Int, voice: inout FeelVoice) {
        let count = min(max(spec.partials, 1), FeelSynth.maxPartials)
        voice.partialCount = count
        let brightness = min(max(spec.brightness, 0.05), 0.98)
        var total: Float = 0
        for n in 0..<count { total += pow(brightness, Float(n)) }
        var jitter = spec.seed | 1
        let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
        for n in 0..<count {
            jitter ^= jitter << 13
            jitter ^= jitter >> 17
            jitter ^= jitter << 5
            let detune: Float = n == 0 ? 1 : 1 + 0.015 * (Float(jitter % 2001) / 1000 - 1)
            let frequency = spec.fundamental * FeelSynth.ratio(spec.kind, n) * detune
            let offset = base + n * FeelSynth.partialStride
            guard frequency > 20, frequency < sampleRate * 0.45 else {
                bank[offset] = 0
                bank[offset + 1] = 0
                bank[offset + 2] = 1
                bank[offset + 3] = 0
                bank[offset + 4] = 0
                continue
            }
            var tau = spec.decay / (1 + 0.7 * Float(n))
            // A bell's hum (an octave under the prime) is what lingers in a real bell.
            if spec.kind == .bell && n == 1 { tau = spec.decay * 1.3 }
            if frequency > 2500 && frequency < 4500 && n > 0 { tau *= 0.5 } // no lingering screech in the ear's peak
            let omega = 2 * Float.pi * frequency / sampleRate
            bank[offset] = spec.gain * pow(brightness, Float(n)) / total * 1.6
            bank[offset + 1] = 0
            bank[offset + 2] = cos(omega)
            bank[offset + 3] = sin(omega)
            bank[offset + 4] = exp(-1 / max(tau * sampleRate, 1))
        }
    }

    private func renderVoice(_ voice: inout FeelVoice, slot: Int) -> Float {
        if voice.delay > 0 {
            voice.delay -= 1
            return 0
        }
        let age = voice.age
        voice.age += 1
        if age >= voice.length {
            voice.active = false
            return 0
        }
        let envelope: Float
        if age < voice.attack {
            envelope = Float(age) / Float(voice.attack)
        } else {
            voice.level *= voice.decayRate
            envelope = voice.level
        }
        if envelope < 0.0003 && age > voice.attack {
            voice.active = false
            return 0
        }
        // A gentle release over the last 30 ms so nothing ever clicks off.
        let left = voice.length - age
        let release = min(Float(left) / (0.03 * sampleRate), 1)
        let twoPi = 2 * Float.pi
        switch voice.kind {
        case .noise:
            if voice.sweepSamples > 0 && age % 32 == 0 {
                let progress = min(Float(age) / Float(voice.sweepSamples), 1)
                let cutoff = voice.cutoff * pow(voice.cutoffEnd / max(voice.cutoff, 1), progress)
                voice.filter.tune(cutoff: cutoff, q: voice.q, sampleRate: sampleRate)
            }
            return voice.filter.process(nextNoise(), voice.mode) * envelope * voice.gain * release
        case .tone:
            let progress = min(Float(age) / Float(voice.glide), 1)
            var frequency = voice.startFrequency + (voice.endFrequency - voice.startFrequency) * progress
            if voice.vibratoDepth > 0 {
                voice.vibratoPhase += twoPi * voice.vibratoRate / sampleRate
                if voice.vibratoPhase > twoPi { voice.vibratoPhase -= twoPi }
                frequency *= 1 + voice.vibratoDepth * sin(voice.vibratoPhase)
            }
            voice.phase += twoPi * frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            var value: Float = 0
            let limit = sampleRate * 0.45
            var harmonic = 1
            while harmonic <= voice.harmonics {
                if frequency * Float(harmonic) < limit {
                    value += sin(voice.phase * Float(harmonic)) / Float(harmonic)
                }
                harmonic += 1
            }
            return value * envelope * voice.gain * release
        case .drop:
            voice.frequency *= voice.chirpPerSample
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            return sin(voice.phase) * envelope * voice.gain * release
        case .fm:
            voice.modPhase += twoPi * voice.frequency * voice.modRatio / sampleRate
            if voice.modPhase > twoPi { voice.modPhase -= twoPi }
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            voice.index *= voice.indexRate
            return sin(voice.phase + voice.index * sin(voice.modPhase)) * envelope * voice.gain * release
        case .ring:
            let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
            var sum: Float = 0
            for n in 0..<voice.partialCount {
                let o = base + n * FeelSynth.partialStride
                let re = bank[o]
                let im = bank[o + 1]
                let c = bank[o + 2]
                let s = bank[o + 3]
                let d = bank[o + 4]
                let newIm = (re * s + im * c) * d
                bank[o] = (re * c - im * s) * d
                bank[o + 1] = newIm
                sum += newIm
            }
            return sum * envelope * release
        }
    }
}
