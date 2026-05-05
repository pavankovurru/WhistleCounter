@preconcurrency import AVFoundation
import Accelerate
import Combine
import Foundation

@MainActor
final class WhistleDetector: ObservableObject {
    @Published var isListening = false
    @Published var isStarting = false
    @Published var permissionDenied = false
    @Published var lastDetectedFrequency: Float = 0
    @Published var lastConfidence: Float = 0
    @Published var errorMessage: String?

    var onWhistle: (() -> Void)?

    private let audioController = WhistleAudioController()
    private var whistleStart: Date?
    private var lastCountedAt = Date.distantPast

    private let whistleFrequencyRange: ClosedRange<Float> = 700...5000
    private let minimumWhistleDuration: TimeInterval = 0.22
    private let cooldownPeriod: TimeInterval = 1.25

    func start(sensitivity: WhistleSensitivity) {
        guard !isListening, !isStarting else { return }
        isStarting = true
        errorMessage = nil

        requestPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.isStarting = false
                    self.permissionDenied = true
                    self.errorMessage = "Microphone permission is needed to count whistles automatically."
                    return
                }
                self.permissionDenied = false
                self.errorMessage = nil
                self.startAudioController(sensitivity: sensitivity)
            }
        }
    }

    func stop() {
        audioController.stop(deactivateSession: true)
        isListening = false
        isStarting = false
        whistleStart = nil
    }

    private func requestPermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        }
        #else
        completion(true)
        #endif
    }

    private func startAudioController(sensitivity: WhistleSensitivity) {
        audioController.start(
            sensitivity: sensitivity,
            range: whistleFrequencyRange,
            onAnalysis: { [weak self] result in
                Task { @MainActor in
                    guard let self, self.isListening else { return }
                    self.lastDetectedFrequency = result.frequency
                    self.lastConfidence = result.confidence
                    if result.isWhistle {
                        self.handleWhistleCandidate()
                    } else {
                        self.whistleStart = nil
                    }
                }
            },
            onStarted: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.isListening = true
                    self.isStarting = false
                    self.errorMessage = nil
                }
            },
            onFailed: { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    self.isListening = false
                    self.isStarting = false
                    self.errorMessage = message
                }
            }
        )
    }

    private func handleWhistleCandidate() {
        let now = Date()
        if whistleStart == nil {
            whistleStart = now
            return
        }

        guard let whistleStart,
              now.timeIntervalSince(whistleStart) >= minimumWhistleDuration,
              now.timeIntervalSince(lastCountedAt) >= cooldownPeriod else {
            return
        }

        lastCountedAt = now
        self.whistleStart = nil
        onWhistle?()
    }

}

private final class WhistleAudioController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.whistlewatch.audio-engine")
    nonisolated(unsafe) private var engine: AVAudioEngine?
    nonisolated(unsafe) private var tapInstalled = false

    nonisolated func start(
        sensitivity: WhistleSensitivity,
        range: ClosedRange<Float>,
        onAnalysis: @escaping @Sendable ((isWhistle: Bool, frequency: Float, confidence: Float)) -> Void,
        onStarted: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable (String) -> Void
    ) {
        let minimumAmplitude = sensitivity.minimumAmplitude
        let minimumConfidence = sensitivity.minimumConfidence

        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked(deactivateSession: false)

            #if os(iOS)
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP])
                try session.setPreferredSampleRate(44_100)
                try session.setPreferredIOBufferDuration(0.046)
                try session.setActive(true)
            } catch {
                onFailed("Microphone setup failed. Check microphone access and try again.")
                return
            }
            #endif

            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                onFailed("No microphone input is available. Try reconnecting the microphone.")
                return
            }

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                let result = Self.analyze(
                    buffer: buffer,
                    sampleRate: Float(buffer.format.sampleRate),
                    range: range,
                    minimumAmplitude: minimumAmplitude,
                    minimumConfidence: minimumConfidence
                )
                onAnalysis(result)
            }
            self.engine = engine
            self.tapInstalled = true

            do {
                engine.prepare()
                try engine.start()
                onStarted()
            } catch {
                self.stopLocked(deactivateSession: true)
                onFailed("Could not start microphone listening. Please try again.")
            }
        }
    }

    nonisolated func stop(deactivateSession: Bool) {
        queue.async { [weak self] in
            self?.stopLocked(deactivateSession: deactivateSession)
        }
    }

    nonisolated private func stopLocked(deactivateSession: Bool) {
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine?.stop()
        engine?.reset()
        engine = nil

        #if os(iOS)
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    nonisolated private static func analyze(
        buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        range: ClosedRange<Float>,
        minimumAmplitude: Float,
        minimumConfidence: Float
    ) -> (isWhistle: Bool, frequency: Float, confidence: Float) {
        guard sampleRate > 0, let channelData = buffer.floatChannelData else { return (false, 0, 0) }

        let fftSize = 4096
        let frameCount = min(Int(buffer.frameLength), fftSize)
        guard frameCount >= fftSize else { return (false, 0, 0) }

        var samples = [Float](repeating: 0, count: fftSize)
        let channelCount = max(1, min(Int(buffer.format.channelCount), 2))
        for channel in 0..<channelCount {
            let source = channelData[channel]
            for index in 0..<fftSize {
                samples[index] += source[index] / Float(channelCount)
            }
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(fftSize))
        guard rms >= minimumAmplitude else { return (false, 0, 0) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        let halfSize = fftSize / 2
        var real = [Float](repeating: 0, count: halfSize)
        var imaginary = [Float](repeating: 0, count: halfSize)
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else { return (false, 0, 0) }
        defer { vDSP_destroy_fftsetup(setup) }

        windowed.withUnsafeBufferPointer { pointer in
            pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPointer in
                real.withUnsafeMutableBufferPointer { realPointer in
                    imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                        var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                        vDSP_ctoz(complexPointer, 2, &split, 1, vDSP_Length(halfSize))
                        vDSP_fft_zrip(setup, &split, 1, log2Size, FFTDirection(FFT_FORWARD))
                    }
                }
            }
        }

        var magnitudes = [Float](repeating: 0, count: halfSize)
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        let frequencyPerBin = sampleRate / Float(fftSize)
        let startBin = max(1, Int(range.lowerBound / frequencyPerBin))
        let endBin = min(halfSize - 1, Int(range.upperBound / frequencyPerBin))
        guard startBin < endBin else { return (false, 0, 0) }

        var peakPower: Float = 0
        var peakIndex = startBin
        var bandPower: Float = 0
        var totalPower: Float = 0

        for index in 1..<halfSize {
            totalPower += magnitudes[index]
        }

        for index in startBin...endBin {
            let power = magnitudes[index]
            bandPower += power
            if power > peakPower {
                peakPower = power
                peakIndex = index
            }
        }

        let averagePower = bandPower / Float(endBin - startBin + 1)
        let dominance = peakPower / max(averagePower, 0.000_001)
        let bandRatio = bandPower / max(totalPower, 0.000_001)
        let frequency = Float(peakIndex) * frequencyPerBin
        let dominanceScore = min(max((dominance - 2.2) / 7.0, 0), 1)
        let bandScore = min(max((bandRatio - 0.18) / 0.42, 0), 1)
        let amplitudeScore = min(max((rms - minimumAmplitude) / max(minimumAmplitude * 3, 0.001), 0), 1)
        let confidence = (dominanceScore * 0.48) + (bandScore * 0.34) + (amplitudeScore * 0.18)
        let hasTonalPeak = dominance >= 3.0
        let hasFocusedBandEnergy = bandRatio >= 0.20

        return (hasTonalPeak && hasFocusedBandEnergy && confidence >= minimumConfidence && range.contains(frequency), frequency, confidence)
    }
}
