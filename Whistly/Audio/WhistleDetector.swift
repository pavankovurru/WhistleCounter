@preconcurrency import AVFoundation
import Accelerate
import Combine
import Foundation
import UIKit

@MainActor
final class WhistleDetector: ObservableObject {
    @Published var isListening = false
    @Published var isStarting = false
    @Published var permissionDenied = false
    @Published var lastDetectedFrequency: Float = 0
    @Published var lastConfidence: Float = 0
    @Published var lastInputLevel: Float = 0
    @Published var lastHarmonicRatio: Float = 0
    @Published var lastVoicingScore: Float = 0
    @Published var errorMessage: String?

    var onWhistle: (() -> Void)?
    var onListeningRecovered: (() -> Void)?

    private let audioController = WhistleAudioController()
    private var whistleStart: Date?
    private var isInsideWhistle = false
    private var lastWhistleCandidateAt = Date.distantPast
    private var lastCountedAt = Date.distantPast
    private var candidatePeakBin: Int?
    private var lastSensitivity: WhistleSensitivity?
    private var notificationObservers: [NSObjectProtocol] = []
    private var wasInterrupted = false

    private let whistleFrequencyRange: ClosedRange<Float> = 1500...4500
    private let minimumWhistleDuration: TimeInterval = 0.25
    private let minimumSilenceBetweenWhistles: TimeInterval = 0.26
    private let cooldownPeriod: TimeInterval = 0.95
    private let maxPeakDriftBins = 4

    func start(sensitivity: WhistleSensitivity) {
        guard !isListening, !isStarting else { return }
        isStarting = true
        errorMessage = nil
        lastSensitivity = sensitivity
        registerSessionObservers()

        requestPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.isStarting = false
                    self.permissionDenied = true
                    self.errorMessage = "Microphone permission is needed to count whistles automatically."
                    self.unregisterSessionObservers()
                    self.lastSensitivity = nil
                    return
                }
                self.permissionDenied = false
                self.errorMessage = nil
                self.startAudioController(sensitivity: sensitivity)
            }
        }
    }

    func stop() {
        unregisterSessionObservers()
        audioController.stop(deactivateSession: true)
        isListening = false
        isStarting = false
        whistleStart = nil
        isInsideWhistle = false
        candidatePeakBin = nil
        wasInterrupted = false
        lastSensitivity = nil
    }

    private func restartListeningInPlace() {
        guard let sensitivity = lastSensitivity else { return }
        audioController.stop(deactivateSession: false)
        whistleStart = nil
        isInsideWhistle = false
        candidatePeakBin = nil
        startAudioController(sensitivity: sensitivity)
    }

    private func registerSessionObservers() {
        guard notificationObservers.isEmpty else { return }
        let center = NotificationCenter.default

        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let typeValue = (userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            let optionsValue = (userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }

        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let reasonValue = (userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Task { @MainActor in
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }

        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDidBecomeActive()
            }
        }

        notificationObservers = [interruption, routeChange, didBecomeActive]
    }

    private func unregisterSessionObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            wasInterrupted = true
        case .ended:
            guard wasInterrupted else { return }
            wasInterrupted = false
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard options.contains(.shouldResume) else { return }
            restartListeningInPlace()
            onListeningRecovered?()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonValue: UInt) {
        guard isListening || wasInterrupted else { return }
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange, .override:
            restartListeningInPlace()
        default:
            break
        }
    }

    private func handleDidBecomeActive() {
        guard isListening, !wasInterrupted else { return }
        audioController.checkEngineHealth { [weak self] isHealthy in
            Task { @MainActor in
                guard let self, !isHealthy else { return }
                self.restartListeningInPlace()
                self.onListeningRecovered?()
            }
        }
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
                    self.lastInputLevel = result.inputLevel
                    self.lastHarmonicRatio = result.harmonicRatio
                    self.lastVoicingScore = result.voicingScore
                    if result.isWhistle {
                        self.handleWhistleCandidate(peakBin: result.peakBin)
                    } else {
                        self.handleNonWhistleCandidate()
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

    private func handleWhistleCandidate(peakBin: Int) {
        let now = Date()
        lastWhistleCandidateAt = now
        guard !isInsideWhistle else { return }

        if let previousPeakBin = candidatePeakBin, abs(peakBin - previousPeakBin) > maxPeakDriftBins {
            whistleStart = now
            candidatePeakBin = peakBin
            return
        }

        candidatePeakBin = peakBin

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
        isInsideWhistle = true
        onWhistle?()
    }

    private func handleNonWhistleCandidate() {
        let now = Date()
        guard now.timeIntervalSince(lastWhistleCandidateAt) >= minimumSilenceBetweenWhistles else { return }
        whistleStart = nil
        isInsideWhistle = false
        candidatePeakBin = nil
    }

}

private final class WhistleAudioController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.whistlewatch.audio-engine")
    nonisolated(unsafe) private var engine: AVAudioEngine?
    nonisolated(unsafe) private var tapInstalled = false

    nonisolated func start(
        sensitivity: WhistleSensitivity,
        range: ClosedRange<Float>,
        onAnalysis: @escaping @Sendable (WhistleAnalysisResult) -> Void,
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
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
                if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try? session.setPreferredInput(builtInMic)
                }
                try session.setPreferredSampleRate(44_100)
                try session.setPreferredIOBufferDuration(0.032)
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

    nonisolated func checkEngineHealth(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [weak self] in
            let running = self?.engine?.isRunning ?? false
            completion(running)
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
    ) -> WhistleAnalysisResult {
        guard sampleRate > 0, let channelData = buffer.floatChannelData else { return .empty }

        let fftSize = 4096
        let usableFrameCount = min(Int(buffer.frameLength), fftSize)
        guard usableFrameCount >= 512 else { return .empty }

        var samples = [Float](repeating: 0, count: fftSize)
        let channelCount = max(1, min(Int(buffer.format.channelCount), 2))
        for channel in 0..<channelCount {
            let source = channelData[channel]
            for index in 0..<usableFrameCount {
                samples[index] += source[index] / Float(channelCount)
            }
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(usableFrameCount))
        guard rms >= minimumAmplitude else { return .silent(inputLevel: rms) }

        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(usableFrameCount))
        var negativeMean = -mean
        vDSP_vsadd(samples, 1, &negativeMean, &samples, 1, vDSP_Length(usableFrameCount))

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(usableFrameCount), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(usableFrameCount))

        let halfSize = fftSize / 2
        var real = [Float](repeating: 0, count: halfSize)
        var imaginary = [Float](repeating: 0, count: halfSize)
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else { return .silent(inputLevel: rms) }
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
        guard startBin < endBin else { return .silent(inputLevel: rms) }

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
        let localStart = max(startBin, peakIndex - 18)
        let localEnd = min(endBin, peakIndex + 18)
        var localPower: Float = 0
        var localBins = 0
        for index in localStart...localEnd where abs(index - peakIndex) > 2 {
            localPower += magnitudes[index]
            localBins += 1
        }
        let localAveragePower = localPower / Float(max(localBins, 1))
        let dominance = peakPower / max(averagePower, 0.000_001)
        let localDominance = peakPower / max(localAveragePower, 0.000_001)
        let bandRatio = bandPower / max(totalPower, 0.000_001)
        let peakShare = peakPower / max(bandPower, 0.000_001)
        let frequency = Float(peakIndex) * frequencyPerBin

        // Harmonic-stack rejection: a real whistle is nearly sinusoidal, so
        // the 2nd and 3rd harmonics are far below the fundamental. Voiced
        // vowels (and most music) carry strong harmonic content here.
        let harmonicRatio = harmonicStackRatio(magnitudes: magnitudes, peakIndex: peakIndex, peakPower: peakPower, halfSize: halfSize)

        // Spectral-comb (voicing) rejection: when the peak is itself a
        // formant-amplified harmonic of a lower fundamental f0 (the case
        // when someone says "whistle"), bins at peak ± k·f0 carry energy.
        // A pure whistle has no such neighbors.
        let voicingScore = spectralCombScore(magnitudes: magnitudes, peakIndex: peakIndex, peakPower: peakPower, frequencyPerBin: frequencyPerBin, halfSize: halfSize)

        let dominanceScore = min(max((dominance - 1.8) / 6.0, 0), 1)
        let localDominanceScore = min(max((localDominance - 4.0) / 14.0, 0), 1)
        let bandScore = min(max((bandRatio - 0.045) / 0.30, 0), 1)
        let peakScore = min(max((peakShare - 0.025) / 0.11, 0), 1)
        let amplitudeScore = min(max((rms - minimumAmplitude) / max(minimumAmplitude * 3, 0.001), 0), 1)
        let purityScore = min(max((0.20 - harmonicRatio) / 0.18, 0), 1)
        let unvoicedScore = min(max((0.16 - voicingScore) / 0.14, 0), 1)
        let confidence = (dominanceScore * 0.18) + (localDominanceScore * 0.16) + (bandScore * 0.10) + (peakScore * 0.08) + (amplitudeScore * 0.08) + (purityScore * 0.22) + (unvoicedScore * 0.18)

        let hasTonalPeak = dominance >= 2.2 || localDominance >= 5.8
        let hasFocusedBandEnergy = bandRatio >= 0.055 || peakShare >= 0.035
        let isHarmonicallyClean = harmonicRatio < 0.20
        let isUnvoiced = voicingScore < 0.16

        let isWhistle = hasTonalPeak
            && hasFocusedBandEnergy
            && isHarmonicallyClean
            && isUnvoiced
            && confidence >= minimumConfidence
            && range.contains(frequency)

        return WhistleAnalysisResult(
            isWhistle: isWhistle,
            frequency: frequency,
            confidence: confidence,
            inputLevel: rms,
            harmonicRatio: harmonicRatio,
            voicingScore: voicingScore,
            peakBin: peakIndex
        )
    }

    nonisolated private static func harmonicStackRatio(magnitudes: [Float], peakIndex: Int, peakPower: Float, halfSize: Int) -> Float {
        guard peakPower > 0 else { return 0 }
        let secondHarmonic = peakBandMax(magnitudes: magnitudes, center: peakIndex * 2, halfSize: halfSize)
        let thirdHarmonic = peakBandMax(magnitudes: magnitudes, center: peakIndex * 3, halfSize: halfSize)
        return (secondHarmonic + thirdHarmonic) / peakPower
    }

    nonisolated private static func peakBandMax(magnitudes: [Float], center: Int, halfSize: Int) -> Float {
        guard center > 0, center < halfSize else { return 0 }
        let lo = max(1, center - 2)
        let hi = min(halfSize - 1, center + 2)
        guard lo <= hi else { return 0 }
        var best: Float = 0
        for index in lo...hi {
            if magnitudes[index] > best { best = magnitudes[index] }
        }
        return best
    }

    nonisolated private static func spectralCombScore(magnitudes: [Float], peakIndex: Int, peakPower: Float, frequencyPerBin: Float, halfSize: Int) -> Float {
        guard peakPower > 0, frequencyPerBin > 0 else { return 0 }
        let minF0Bins = max(1, Int((80.0 / frequencyPerBin).rounded(.up)))
        let maxF0Bins = max(minF0Bins, Int((340.0 / frequencyPerBin).rounded(.down)))
        var best: Float = 0
        for f0Bins in minF0Bins...maxF0Bins {
            let lower = peakIndex - f0Bins
            let upper = peakIndex + f0Bins
            guard lower >= 1, upper < halfSize else { continue }
            let lowerPower = magnitudes[lower]
            let upperPower = magnitudes[upper]
            let neighbor = min(lowerPower, upperPower)
            let score = neighbor / peakPower
            if score > best { best = score }
        }
        return best
    }
}

nonisolated struct WhistleAnalysisResult: Sendable {
    let isWhistle: Bool
    let frequency: Float
    let confidence: Float
    let inputLevel: Float
    let harmonicRatio: Float
    let voicingScore: Float
    let peakBin: Int

    static let empty = WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: 0, harmonicRatio: 0, voicingScore: 0, peakBin: 0)

    static func silent(inputLevel: Float) -> WhistleAnalysisResult {
        WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: inputLevel, harmonicRatio: 0, voicingScore: 0, peakBin: 0)
    }
}
