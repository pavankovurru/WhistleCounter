import AVFoundation
import AudioToolbox
import Combine
import Foundation

@MainActor
final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    @Published private(set) var isAlarmPlaying = false
    @Published private(set) var previewingPack: SoundPack? = nil

    private var alarmPlayer: AVAudioPlayer?
    private var alarmEngine: AVAudioEngine?
    private var alarmNode: AVAudioPlayerNode?
    private var alarmBuffer: AVAudioPCMBuffer?
    private var alarmStopTask: Task<Void, Never>?
    private var previewPlayer: AVAudioPlayer?
    private var previewStopTask: Task<Void, Never>?
    private var effectPlayer: AVAudioPlayer?
    private var isPreviewSessionConfigured = false

    private init() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let typeValue = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue)
            }
        }
        #endif
    }

    private func handleInterruption(typeValue: UInt) {
        #if os(iOS)
        guard AVAudioSession.InterruptionType(rawValue: typeValue) == .ended, isAlarmPlaying else { return }
        // A call paused the alarm mid-ring; pick it back up. The auto-stop
        // task kept counting, so this can't ring longer than intended.
        try? AVAudioSession.sharedInstance().setActive(true)
        alarmPlayer?.play()
        #endif
    }

    func playWhistle() {
        playResource(name: "whistle_boing", fallback: 1104)
    }

    func playCelebration() {
        playResource(name: "celebration", fallback: 1025)
    }

    func playAlarm(pack: SoundPack) {
        stopAlarmPreview()
        stopAlarm()            // stop & clear the old player first
        // If whistle listening is live, pause it for the duration of the alarm:
        // whistles are ignored while an alarm rings anyway, and its .measurement
        // session makes alarm playback quiet. Listening resumes on stopAlarm().
        WhistleDetector.activeDetector?.suspendForAlarm()
        configureAlarmSession()
        guard let player = makeAlarmPlayer(pack: pack) else {
            AudioServicesPlaySystemSound(1005)
            return
        }
        alarmPlayer = player
        // Report the real playback state — callers use it to decide whether a
        // backup notification sound is needed.
        isAlarmPlaying = player.play()
        if !isAlarmPlaying {
            // The fast mode-only session tweak wasn't enough; retry once on a full
            // playback session (slower — it re-routes audio — but most compatible).
            forcePlaybackSession()
            isAlarmPlaying = player.play()
        }
        if isAlarmPlaying {
            scheduleAlarmAutoStop()
        } else {
            WhistleDetector.activeDetector?.resumeAfterAlarm()
        }
    }

    private func makeAlarmPlayer(pack: SoundPack) -> AVAudioPlayer? {
        let resourceName = "alarm_\(pack.rawValue.lowercased())"
        let player: AVAudioPlayer?
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3") {
            player = try? AVAudioPlayer(contentsOf: url)
        } else if let data = proceduralAlarmData(pack: pack) {
            player = try? AVAudioPlayer(data: data)
        } else {
            player = nil
        }
        guard let player else { return nil }
        player.numberOfLoops = -1  // loop until stopped
        player.volume = pack == .zen ? 0.9 : 1
        player.prepareToPlay()
        return player
    }

    // Synthesizing ~5s of WAV takes tens of milliseconds — do it once per pack,
    // not on the alarm-critical path.
    private var proceduralAlarmCache: [SoundPack: Data] = [:]

    private func proceduralAlarmData(pack: SoundPack) -> Data? {
        if let cached = proceduralAlarmCache[pack] {
            return cached
        }
        let data = makeProceduralAlarmWAV(pack: pack)
        proceduralAlarmCache[pack] = data
        return data
    }

    private func scheduleAlarmAutoStop() {
        alarmStopTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(60))
            stopAlarm()
        }
    }

    func previewAlarm(pack: SoundPack, duration: TimeInterval = 2) {
        stopAlarmPreview()
        // Configure the session only once — calling setCategory/setActive on every tap
        // interrupts the audio hardware and causes play() to silently fail.
        if !isPreviewSessionConfigured {
            configureAlarmSession()
            isPreviewSessionConfigured = true
        }
        previewingPack = pack
        let resourceName = "alarm_\(pack.rawValue.lowercased())"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            previewPlayer = player
            player.numberOfLoops = 0
            player.volume = 0.9
            player.currentTime = 0
            player.prepareToPlay()
            player.play()
            previewStopTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                stopAlarmPreview()
            }
        } else if let data = makeProceduralAlarmWAV(pack: pack),
                  let player = try? AVAudioPlayer(data: data) {
            previewPlayer = player
            player.numberOfLoops = 0
            player.volume = pack == .zen ? 0.85 : 0.9
            player.currentTime = 0
            player.prepareToPlay()
            player.play()
            previewStopTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                stopAlarmPreview()
            }
        } else {
            previewingPack = nil
            AudioServicesPlaySystemSound(1005)
        }
    }

    func stopAlarm() {
        let wasPlaying = isAlarmPlaying
        alarmStopTask?.cancel()
        alarmStopTask = nil
        alarmPlayer?.stop()
        alarmPlayer = nil
        alarmNode?.stop()
        alarmEngine?.stop()
        alarmEngine?.reset()
        alarmNode = nil
        alarmEngine = nil
        alarmBuffer = nil
        isAlarmPlaying = false
        isPreviewSessionConfigured = false
        if wasPlaying {
            // Bring back whistle listening that was paused for this alarm.
            WhistleDetector.activeDetector?.resumeAfterAlarm()
        }
    }

    func stopAlarmPreview() {
        previewStopTask?.cancel()
        previewStopTask = nil
        previewPlayer?.stop()
        previewPlayer = nil
        previewingPack = nil
    }

    private func playResource(name: String, fallback: SystemSoundID) {
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            // Must stay retained while playing — a local would deallocate mid-sound.
            effectPlayer = player
            player.play()
        } else {
            AudioServicesPlaySystemSound(fallback)
        }
    }


    private func makeProceduralAlarmWAV(pack: SoundPack) -> Data? {
        let sampleRate: Float = 44_100
        let duration: Float = pack == .zen ? 7.2 : 4.8
        let frameCount = Int(sampleRate * duration)
        let channelCount: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(Int(sampleRate) * Int(channelCount) * Int(bitsPerSample) / 8)
        let blockAlign = UInt16(Int(channelCount) * Int(bitsPerSample) / 8)
        let audioBytes = UInt32(frameCount * Int(channelCount) * MemoryLayout<Int16>.size)
        let chunkSize = UInt32(36) + audioBytes

        var data = Data()
        data.reserveCapacity(44 + Int(audioBytes))
        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(chunkSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channelCount)
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(audioBytes)

        let twoPi = Float.pi * 2

        for frame in 0..<frameCount {
            let t = Float(frame) / sampleRate
            let sample: Float

            switch pack {
            case .classic:
                let local = t.truncatingRemainder(dividingBy: 1.0)
                let isOnBeat = local < 0.36 || (local > 0.50 && local < 0.86)
                let beatTime = local < 0.50 ? local : local - 0.50
                let attack = min(1, beatTime / 0.025)
                let release = min(1, max(0, 0.36 - beatTime) / 0.08)
                let envelope = isOnBeat ? min(attack, release) : 0
                let frequency: Float = local < 0.50 ? 880 : 1046.50
                let bell = sin(twoPi * frequency * t) * 0.54
                    + sin(twoPi * frequency * 2 * t) * 0.18
                    + sin(twoPi * frequency * 3 * t) * 0.08
                let bite = sin(twoPi * 2400 * t) * 0.05
                sample = (bell + bite) * envelope * 0.84

            case .funny:
                let local = t.truncatingRemainder(dividingBy: 1.05)
                let beatIndex = local < 0.25 ? 0 : (local < 0.52 ? 1 : (local < 0.82 ? 2 : -1))
                let beatStart: Float = beatIndex == 0 ? 0 : (beatIndex == 1 ? 0.27 : 0.56)
                let beatTime = max(0, local - beatStart)
                let envelope = beatIndex >= 0 ? min(1, beatTime / 0.018) * min(1, max(0, 0.24 - beatTime) / 0.07) : 0
                let frequency: Float = beatIndex == 0 ? 440 : (beatIndex == 1 ? 660 : 520)
                let chirp = frequency + sin(twoPi * 9 * beatTime) * 42
                let tone = sin(twoPi * chirp * t) * 0.52
                    + sin(twoPi * chirp * 2.02 * t) * 0.18
                let thump = beatTime < 0.05 ? sin(twoPi * 180 * t) * (1 - beatTime / 0.05) * 0.20 : 0
                sample = (tone + thump) * envelope * 0.88

            case .zen:
                let local = t.truncatingRemainder(dividingBy: 1.8)
                let phrase = Int(t / 1.8) % 4
                let root: Float = [523.25, 659.25, 783.99, 587.33][phrase]
                let envelope = exp(-2.2 * local)
                let shimmer = sin(twoPi * root * t) * 0.24
                    + sin(twoPi * root * 1.5 * t) * 0.13
                    + sin(twoPi * root * 2.01 * t) * 0.07
                let breath = sin(twoPi * 110 * t) * 0.018
                sample = (shimmer * envelope + breath) * 0.62
            }

            let fadeIn = min(1, t / 0.02)
            let fadeOut = min(1, (duration - t) / 0.08)
            let faded = max(-0.92, min(0.92, sample * min(fadeIn, fadeOut)))
            data.appendLittleEndian(Int16(faded * Float(Int16.max)))
            data.appendLittleEndian(Int16(faded * 0.96 * Float(Int16.max)))
        }

        return data
    }

    private func configureAlarmSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if WhistleDetector.hasLiveMic {
                // A live mic tap is running (timer alarm during listening): changing
                // the category would kill it, and .playAndRecord+.defaultToSpeaker
                // already plays audibly. Just make sure the session is active.
                try session.setActive(true)
            } else if session.category == .playAndRecord {
                // Mic→alarm handoff: keep the category (a category change re-routes
                // audio hardware and costs 1-2s) and only leave .measurement mode,
                // which is what makes playback quiet. The speaker route is retained
                // by .defaultToSpeaker. Never deactivate — iOS refuses background
                // re-activation.
                try session.setMode(.default)
                try session.setActive(true)
            } else {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
            }
        } catch {
            // Fall back to the system sound path if the dedicated alarm session is unavailable.
        }
        #endif
    }

    private func forcePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: Int16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
