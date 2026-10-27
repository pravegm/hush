import AVFoundation
import Foundation
import os
import QuartzCore
import UIKit

/// Owns the audio session and the AVAudioEngine that hosts `FeelSynth` (Swoop's `FeelAudioEngine`, itself from Brim).
///
/// Session: `.playback` + `.mixWithOthers` by default, so the game is heard even with the silent switch on (the
/// founder's rule since Squish); `.ambient` when the player turns on "Respect silent switch".
/// Self-healing: interruptions, route changes, engine configuration changes and media-services resets all restart or
/// rebuild it; `heal()` (called ~1/s by the director) restarts a stopped engine. Every failure is logged and the game
/// simply goes silent: nothing here can crash.
@MainActor
final class FeelAudioEngine {
    /// Master trim applied to everything (the bed's master).
    static let masterGain: Float = 1.25
    /// Seconds of quiet while idle before the engine naps (lets a tap, a bell or the calm pad ring out).
    static let napAfter: Double = 6

    private static let log = Logger(subsystem: "com.pravegm.hush", category: "audio")

    /// Sound on/off. Off pauses the engine (no battery spent); on starts it again.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                if isStarted { ensureRunning(reason: "sound switched on") } else if wantsStart { start() }
            } else {
                synth?.send(.stopAll)
                if engine.isRunning { engine.pause() }
            }
        }
    }

    /// Menus and long pauses: while idle the engine naps (`AVAudioEngine.pause()`, no render callbacks) once nothing
    /// has played for `napAfter` seconds; a one-shot (a menu tap) wakes it for that sound. Off: awake at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                scheduleNap()
            } else {
                napTask?.cancel()
                napTask = nil
                wake(reason: "game")
            }
        }
    }

    var respectSilentSwitch = false {
        didSet {
            guard oldValue != respectSilentSwitch, isStarted else { return }
            configureSession()
            activateSession()
            ensureRunning(reason: "silent-switch setting changed")
        }
    }

    private var engine = AVAudioEngine()
    private(set) var synth: FeelSynth?
    private var sourceNode: AVAudioSourceNode?
    private var observers: [NSObjectProtocol] = []
    private var engineObserver: NSObjectProtocol?
    private(set) var isStarted = false
    private var wantsStart = false
    private(set) var lastError: String?
    private var startFailures = 0
    private var lastRebuild: CFTimeInterval = -Double.infinity
    private var lastBed = FeelBed()
    /// Paused on purpose (see `idle`): nothing restarts it except a sound or leaving idle.
    private(set) var isNapping = false
    private var napTask: Task<Void, Never>?
    private var lastSoundTime: CFTimeInterval = -Double.infinity
    /// An interruption (a call, Siri) is in progress: `heal()` leaves the engine alone until it ends.
    private var interrupted = false

    init() {}

    var isRunning: Bool { engine.isRunning }

    /// Session, graph, engine. Lazy: does nothing until sound is on. Idempotent.
    func start() {
        wantsStart = true
        guard enabled, !isStarted else { return }
        isStarted = true
        configureSession()
        activateSession()
        buildGraph()
        startEngine(reason: "launch")
        observeSystem()
    }

    /// Queue one-shot sounds. Dropped while sound is off, the engine never came up, or it is stopped (an
    /// interruption): queued sounds would otherwise burst out together when it restarts. A napping engine wakes.
    func play(_ commands: [FeelSynthCommand]) {
        guard enabled, isStarted, !commands.isEmpty else { return }
        if isNapping { wake(reason: "sound") }
        guard let synth, engine.isRunning else { return }
        lastSoundTime = CACurrentMediaTime()
        for command in commands { synth.send(command) }
        if idle { scheduleNap() }
    }

    /// The continuous layers (always forwarded while awake). Remembered, so a synth built later (lazy start, rebuild
    /// after a media-services reset) or woken from a nap starts from it.
    ///
    /// Hush: an audible bed (the Home creak while the App has set `idle`) counts as sound, so it wakes a napping
    /// engine and holds off the next nap; the nap comes `napAfter` s after it falls quiet.
    func setBed(_ bed: FeelBed) {
        lastBed = bed
        if bed.hasLayers && bed.master > 0 && enabled && isStarted {
            lastSoundTime = CACurrentMediaTime()
            if idle && napTask == nil { scheduleNap() }
            if isNapping {
                wake(reason: "continuous sound") // sends `lastBed`
                return
            }
        }
        if isNapping { return }
        synth?.send(.bed(bed))
    }

    /// The app became active again (calls, Siri, background). Also ends a tracked interruption (`.ended` isn't
    /// guaranteed to arrive).
    func resume() {
        interrupted = false
        guard isStarted, enabled, !isNapping else { return }
        activateSession()
        ensureRunning(reason: "app active again")
    }

    /// Cheap check from the frame loop (the director calls it about once a second). Not during an interruption.
    func heal() {
        guard isStarted, enabled, !isNapping, !interrupted, synth != nil, !engine.isRunning else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        ensureRunning(reason: "found stopped")
    }

    // MARK: - Naps (battery)

    private func scheduleNap() {
        napTask?.cancel()
        let delay: Double = Self.napAfter
        napTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            self?.napIfQuiet()
        }
    }

    private func napIfQuiet() {
        napTask = nil
        guard idle, !isNapping else { return }
        if CACurrentMediaTime() - lastSoundTime < Self.napAfter - 0.05 {
            scheduleNap()
            return
        }
        isNapping = true
        // Nothing may be left ringing (or queued) to burst out on waking.
        synth?.send(.stopAll)
        if engine.isRunning { engine.pause() }
    }

    private func interruptionBegan() {
        interrupted = true
        // Whatever was queued must not burst out when the call ends.
        synth?.send(.stopAll)
    }

    private func wake(reason: String) {
        guard isNapping else { return }
        isNapping = false
        synth?.send(.bed(lastBed))
        ensureRunning(reason: reason)
    }

    // MARK: - Session and graph

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if respectSilentSwitch {
                try session.setCategory(.ambient, mode: .default, options: [])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
        } catch {
            record("Couldn't set the audio category", error)
        }
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(0.005)
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            record("Couldn't activate the audio session", error)
        }
    }

    /// Source node → main mixer → output, mono Float32 at the session rate (the mixer converts on route changes).
    private func buildGraph() {
        let session = AVAudioSession.sharedInstance()
        let sampleRate = session.sampleRate > 0 ? session.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            lastError = "Couldn't make a \(Int(sampleRate)) Hz format"
            Self.log.error("Couldn't make an audio format")
            return
        }
        let synth = FeelSynth(sampleRate: Float(sampleRate))
        let node = AVAudioSourceNode(format: format, renderBlock: Self.renderBlock(for: synth))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        synth.send(.bed(lastBed))
        self.synth = synth
        sourceNode = node

        if let engineObserver { NotificationCenter.default.removeObserver(engineObserver) }
        engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureRunning(reason: "audio hardware changed")
            }
        }
    }

    /// Built outside the main actor on purpose: the block runs on the real-time audio thread and touches only the
    /// synth (an `@unchecked Sendable` object whose render path is lock-free and allocation-free).
    private nonisolated static func renderBlock(for synth: FeelSynth) -> AVAudioSourceNodeRenderBlock {
        return { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let first = buffers.first, let data = first.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            synth.render(frames: Int(frameCount), into: data)
            if buffers.count > 1 {
                for index in 1..<buffers.count {
                    buffers[index].mData?.copyMemory(from: data, byteCount: Int(first.mDataByteSize))
                }
            }
            return noErr
        }
    }

    private func startEngine(reason: String) {
        guard sourceNode != nil, enabled else { return }
        do {
            try engine.start()
            startFailures = 0
        } catch {
            startFailures += 1
            record("Couldn't start the audio engine (\(reason), try \(startFailures))", error)
            if startFailures == 2 {
                // Let the mixer → output connection renegotiate the hardware format, then try once more.
                engine.disconnectNodeOutput(engine.mainMixerNode)
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
                do {
                    try engine.start()
                    startFailures = 0
                } catch {
                    startFailures += 1
                    record("Couldn't start the audio engine after reconnecting", error)
                }
            } else if startFailures >= 4 {
                let now = CACurrentMediaTime()
                if now - lastRebuild > 5 {
                    lastRebuild = now
                    startFailures = 0
                    rebuild()
                }
            }
        }
    }

    private func ensureRunning(reason: String) {
        // A napping engine stays paused through route and configuration changes; a sound wakes it.
        guard isStarted, enabled, !isNapping else { return }
        if synth == nil {
            rebuild()
            return
        }
        guard !engine.isRunning else { return }
        activateSession()
        startEngine(reason: reason)
    }

    /// The audio server restarted (or the engine kept failing): every audio object is dead, so start from scratch.
    private func rebuild() {
        guard isStarted else { return }
        if let engineObserver {
            NotificationCenter.default.removeObserver(engineObserver)
            self.engineObserver = nil
        }
        engine = AVAudioEngine()
        synth = nil
        sourceNode = nil
        configureSession()
        activateSession()
        buildGraph()
        if !isNapping { startEngine(reason: "rebuild") }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let ended = type == .ended
            let began = type == .began
            MainActor.assumeIsolated {
                if began { self?.interruptionBegan() }
                if ended { self?.resume() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureRunning(reason: "route changed")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuild()
            }
        })
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
