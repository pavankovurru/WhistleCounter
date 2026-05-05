import AVFoundation
import AudioToolbox
import Combine
import Foundation

@MainActor
final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    @Published private(set) var isAlarmPlaying = false

    private var backgroundPlayer: AVAudioPlayer?
    private var backgroundEngine: AVAudioEngine?
    private var backgroundNode: AVAudioPlayerNode?
    private var backgroundBuffer: AVAudioPCMBuffer?
    private var alarmPlayer: AVAudioPlayer?
    private var alarmEngine: AVAudioEngine?
    private var alarmNode: AVAudioPlayerNode?
    private var alarmBuffer: AVAudioPCMBuffer?
    private var alarmStopTask: Task<Void, Never>?

    func startBackgroundMusic(enabled: Bool) {
        guard enabled else {
            stopBackgroundMusic()
            return
        }
        configureSession(playAndRecord: false)
        guard let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") else {
            startProceduralBackgroundMusic()
            return
        }
        do {
            stopProceduralBackgroundMusic()
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1
            backgroundPlayer?.volume = 0
            backgroundPlayer?.play()
            backgroundPlayer?.setVolume(0.32, fadeDuration: 1.2)
        } catch {
            backgroundPlayer = nil
            startProceduralBackgroundMusic()
        }
    }

    func stopBackgroundMusic() {
        backgroundPlayer?.setVolume(0, fadeDuration: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.backgroundPlayer?.stop()
            self?.backgroundPlayer = nil
        }
        stopProceduralBackgroundMusic()
    }

    func playWhistle() {
        playResource(name: "whistle_boing", fallback: 1104)
    }

    func playCelebration() {
        playResource(name: "celebration", fallback: 1025)
    }

    func playAlarm(pack: SoundPack) {
        configureAlarmSession()
        stopAlarm()
        let resourceName = "alarm_\(pack.rawValue.lowercased())"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            alarmPlayer = player
            alarmPlayer?.numberOfLoops = 2
            alarmPlayer?.volume = 1
            alarmPlayer?.play()
            isAlarmPlaying = true
            alarmStopTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(14))
                stopAlarm()
            }
        } else {
            startProceduralAlarm(pack: pack)
        }
    }

    func stopAlarm() {
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
    }

    private func playResource(name: String, fallback: SystemSoundID) {
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.play()
        } else {
            AudioServicesPlaySystemSound(fallback)
        }
    }

    private func configureSession(playAndRecord: Bool) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if playAndRecord {
                try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            } else {
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            // Audio is additive polish; the core app remains usable if the session is unavailable.
        }
        #endif
    }

    private func startProceduralBackgroundMusic() {
        guard backgroundNode?.isPlaying != true else { return }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        guard let format, let buffer = makeProceduralLoop(format: format) else { return }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.42

        do {
            try engine.start()
            node.volume = 0.72
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
            backgroundEngine = engine
            backgroundNode = node
            backgroundBuffer = buffer
        } catch {
            backgroundEngine = nil
            backgroundNode = nil
            backgroundBuffer = nil
        }
    }

    private func stopProceduralBackgroundMusic() {
        backgroundNode?.stop()
        backgroundEngine?.stop()
        backgroundEngine?.reset()
        backgroundNode = nil
        backgroundEngine = nil
        backgroundBuffer = nil
    }

    private func makeProceduralLoop(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            return nil
        }

        buffer.frameLength = frameCount
        let chords: [[Float]] = [
            [261.63, 329.63, 392.00],
            [220.00, 329.63, 392.00],
            [293.66, 349.23, 440.00],
            [196.00, 246.94, 392.00]
        ]
        let twoPi = Float.pi * 2

        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / sampleRate
            let chordIndex = min(chords.count - 1, Int(t / 2) % chords.count)
            let chord = chords[chordIndex]
            let beatPulse = 0.78 + 0.22 * sin(twoPi * 0.5 * t)
            let fadeIn = min(1, t / 0.18)
            let fadeOut = min(1, (duration - t) / 0.18)
            let fade = min(fadeIn, fadeOut)

            var sample: Float = 0
            for (index, frequency) in chord.enumerated() {
                let detune: Float = index == 1 ? 1.004 : 1
                let phase = twoPi * frequency * detune * t
                let tone = sin(phase)
                sample += tone * 0.024
            }
            let bassPhase = twoPi * (chord[0] / 2) * t
            let sparklePhase = twoPi * 880 * t
            let sparkleGate = max(Float(0), sin(twoPi * 0.25 * t))
            sample += sin(bassPhase) * 0.030
            sample += sin(sparklePhase) * 0.006 * sparkleGate
            sample *= beatPulse * fade

            channels[0][frame] = sample
            if Int(format.channelCount) > 1 {
                channels[1][frame] = sample * 0.92
            }
        }

        return buffer
    }

    private func startProceduralAlarm(pack: SoundPack) {
        guard let data = makeProceduralAlarmWAV(pack: pack),
              let player = try? AVAudioPlayer(data: data) else {
            AudioServicesPlaySystemSound(1005)
            return
        }

        player.numberOfLoops = 2
        player.volume = pack == .zen ? 0.9 : 1
        player.prepareToPlay()
        alarmPlayer = player
        player.play()
        isAlarmPlaying = true
        alarmStopTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(14))
            stopAlarm()
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
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Fall back to the system sound path if the dedicated alarm session is unavailable.
        }
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
