import AVFoundation
import AudioToolbox
import Combine
import Foundation

@MainActor
final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    @Published private(set) var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    private var alarmEngine: AVAudioEngine?
    private var alarmNode: AVAudioPlayerNode?
    private var alarmBuffer: AVAudioPCMBuffer?
    private var alarmStopTask: Task<Void, Never>?


    func playWhistle() {
        playResource(name: "whistle_boing", fallback: 1104)
    }

    func playCelebration() {
        playResource(name: "celebration", fallback: 1025)
    }

    func playAlarm(pack: SoundPack) {
        stopAlarm()            // stop & clear the old player first
        configureAlarmSession() // then set up a fresh session
        let resourceName = "alarm_\(pack.rawValue.lowercased())"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            alarmPlayer = player
            alarmPlayer?.numberOfLoops = 0  // play once
            alarmPlayer?.volume = 1
            alarmPlayer?.prepareToPlay()
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


    private func startProceduralAlarm(pack: SoundPack) {
        guard let data = makeProceduralAlarmWAV(pack: pack),
              let player = try? AVAudioPlayer(data: data) else {
            AudioServicesPlaySystemSound(1005)
            return
        }

        player.numberOfLoops = 0  // play once
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
