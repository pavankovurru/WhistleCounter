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
    @Published var lastConcentration: Float = 0
    @Published var lastRejectionReason: String = "Listening for whistles…"
    @Published var errorMessage: String?

    // Rate-limit the displayed reason. Without this, the UI updates 11×/s
    // and the user can't read individual messages.
    private var lastReasonShownAt: Date = .distantPast
    private var lastMeaningfulReasonAt: Date = .distantPast
    private let reasonMinInterval: TimeInterval = 0.45
    private let listeningHoldAfterAudio: TimeInterval = 1.2

    var onWhistle: (() -> Void)?
    var onListeningRecovered: (() -> Void)?

    private let audioController = WhistleAudioController()
    private var whistleStart: Date?
    private var lastWhistleCandidateAt = Date.distantPast
    private var lastCountedWhistleEndedAt = Date.distantPast
    private var candidatePeakBin: Int?
    private var candidatePeakHistory: [Int] = []
    private var lastSensitivity: WhistleSensitivity?
    private var notificationObservers: [NSObjectProtocol] = []
    private var wasInterrupted = false

    private let whistleFrequencyRange: ClosedRange<Float> = 750...7_000
    private let minimumCompletedWhistleDuration: TimeInterval = 0.55
    private let minimumSilenceBeforeCompletedWhistle: TimeInterval = 0.45
    private var countGapSeconds: TimeInterval = AppSettings.defaultWhistleCountGapSeconds
    private let minimumCandidateFrames = 6
    private let maximumCandidateHistoryFrames = 64
    private let maxPeakDriftBins = 32
    private let maxCandidateBinStdDev: Float = 24

    func updateSensitivity(_ sensitivity: WhistleSensitivity) {
        guard isListening, lastSensitivity != sensitivity else {
            lastSensitivity = sensitivity
            return
        }
        lastSensitivity = sensitivity
        restartListeningInPlace()
    }

    func updateCountGap(_ seconds: TimeInterval) {
        countGapSeconds = AppSettings.normalizedWhistleCountGapSeconds(seconds)
    }

    func start(sensitivity: WhistleSensitivity, countGapSeconds: TimeInterval) {
        guard !isListening, !isStarting else { return }
        isStarting = true
        errorMessage = nil
        lastSensitivity = sensitivity
        updateCountGap(countGapSeconds)
        clearCandidate()
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
        candidatePeakBin = nil
        candidatePeakHistory.removeAll()
        lastCountedWhistleEndedAt = .distantPast
        wasInterrupted = false
        lastSensitivity = nil
    }

    private func restartListeningInPlace() {
        guard let sensitivity = lastSensitivity else { return }
        audioController.stop(deactivateSession: false)
        whistleStart = nil
        candidatePeakBin = nil
        candidatePeakHistory.removeAll()
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
                    self.lastConcentration = result.concentration
                    self.updateDisplayedReason(result.rejectionReason, isWhistle: result.isWhistle)
                    self.recordDiagnostic(result)
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
            },
            onStaleAudio: { [weak self] in
                Task { @MainActor in
                    guard let self, self.isListening, !self.wasInterrupted else { return }
                    self.restartListeningInPlace()
                    self.onListeningRecovered?()
                }
            }
        )
    }

    // Fix #14: keep the last 60 candidate snapshots so the user can dump
    // diagnostic data when reporting a missed/false whistle.
    private var diagnosticBuffer: [WhistleAnalysisResult] = []
    private let diagnosticCapacity = 60

    private func updateDisplayedReason(_ newReason: String, isWhistle: Bool) {
        // No rate limit — show what's happening on every frame. The view
        // text now also includes live mic level and frequency, so the
        // user can immediately see whether the mic is capturing audio.
        lastRejectionReason = newReason
    }

    private func recordDiagnostic(_ result: WhistleAnalysisResult) {
        diagnosticBuffer.append(result)
        if diagnosticBuffer.count > diagnosticCapacity {
            diagnosticBuffer.removeFirst(diagnosticBuffer.count - diagnosticCapacity)
        }
    }

    func recentDiagnostics() -> [WhistleAnalysisResult] {
        diagnosticBuffer
    }

    private func handleWhistleCandidate(peakBin: Int) {
        let now = Date()
        lastWhistleCandidateAt = now

        if let previousPeakBin = candidatePeakBin, abs(peakBin - previousPeakBin) > maxPeakDriftBins {
            whistleStart = now
            candidatePeakBin = peakBin
            candidatePeakHistory = [peakBin]
            updateDisplayedReason("Pitch is shifting like speech, not a cooker whistle", isWhistle: false)
            return
        }

        candidatePeakBin = peakBin
        candidatePeakHistory.append(peakBin)
        if candidatePeakHistory.count > maximumCandidateHistoryFrames {
            candidatePeakHistory.removeFirst(candidatePeakHistory.count - maximumCandidateHistoryFrames)
        }

        if whistleStart == nil {
            whistleStart = now
        }
    }

    private func handleNonWhistleCandidate() {
        let now = Date()
        guard now.timeIntervalSince(lastWhistleCandidateAt) >= minimumSilenceBeforeCompletedWhistle else { return }
        guard let whistleStart else {
            clearCandidate()
            return
        }

        let whistleEndedAt = lastWhistleCandidateAt
        let duration = whistleEndedAt.timeIntervalSince(whistleStart)
        let gapSinceLastCount = whistleEndedAt.timeIntervalSince(lastCountedWhistleEndedAt)
        let stability = candidatePeakStdDev()

        guard duration >= minimumCompletedWhistleDuration else {
            updateDisplayedReason("Short cooker sound ignored — waiting for a complete whistle", isWhistle: false)
            clearCandidate()
            return
        }

        guard candidatePeakHistory.count >= minimumCandidateFrames else {
            updateDisplayedReason("Possible whistle ended too quickly", isWhistle: false)
            clearCandidate()
            return
        }

        guard stability <= maxCandidateBinStdDev else {
            updateDisplayedReason("Pitch wobbled like voice or music", isWhistle: false)
            clearCandidate()
            return
        }

        guard gapSinceLastCount >= countGapSeconds else {
            let remaining = max(0, countGapSeconds - gapSinceLastCount)
            updateDisplayedReason("Whistle gap active (\(Int(ceil(remaining)))s)", isWhistle: false)
            clearCandidate()
            return
        }

        lastCountedWhistleEndedAt = whistleEndedAt
        clearCandidate()
        updateDisplayedReason("Completed cooker whistle counted", isWhistle: true)
        onWhistle?()
    }

    private func clearCandidate() {
        whistleStart = nil
        candidatePeakBin = nil
        candidatePeakHistory.removeAll()
    }

    private func candidatePeakStdDev() -> Float {
        guard !candidatePeakHistory.isEmpty else { return 0 }
        let mean = Float(candidatePeakHistory.reduce(0, +)) / Float(candidatePeakHistory.count)
        var sumSq: Float = 0
        for bin in candidatePeakHistory {
            let diff = Float(bin) - mean
            sumSq += diff * diff
        }
        return sqrt(sumSq / Float(candidatePeakHistory.count))
    }

}

private final class WhistleAudioController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.whistlewatch.audio-engine")
    nonisolated(unsafe) private var engine: AVAudioEngine?
    nonisolated(unsafe) private var tapInstalled = false
    // Fix #1: cached FFT setup, created once per controller lifetime.
    nonisolated(unsafe) private var fftSetup: FFTSetup?
    nonisolated static let fftSize = 4096
    // Fix #3: watchdog tracks last analysis frame; fires onStaleAudio if gone silent.
    nonisolated(unsafe) private var lastFrameAt: Date = .distantPast
    nonisolated(unsafe) private var watchdogTimer: DispatchSourceTimer?
    nonisolated(unsafe) private var onStaleAudio: (@Sendable () -> Void)?

    nonisolated func start(
        sensitivity: WhistleSensitivity,
        range: ClosedRange<Float>,
        onAnalysis: @escaping @Sendable (WhistleAnalysisResult) -> Void,
        onStarted: @escaping @Sendable () -> Void,
        onFailed: @escaping @Sendable (String) -> Void,
        onStaleAudio: @escaping @Sendable () -> Void
    ) {
        let minimumAmplitude = sensitivity.minimumAmplitude
        let minimumConfidence = sensitivity.minimumConfidence
        let minimumConcentration = sensitivity.minimumConcentration
        let maximumSpeechEnergyRatio = sensitivity.maximumSpeechEnergyRatio
        let maximumVocalHarmonicCount = sensitivity.maximumVocalHarmonicCount
        let maximumHarmonicRatio = sensitivity.maximumHarmonicRatio

        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked(deactivateSession: false)
            self.onStaleAudio = onStaleAudio

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

            // Fix #1: build the FFT setup once and reuse for every audio frame.
            if self.fftSetup == nil {
                let log2Size = vDSP_Length(log2(Float(Self.fftSize)))
                self.fftSetup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2))
            }
            guard let setup = self.fftSetup else {
                onFailed("Could not initialize the audio analyzer. Please try again.")
                return
            }

            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                onFailed("No microphone input is available. Try reconnecting the microphone.")
                return
            }

            self.lastFrameAt = Date()
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                self?.lastFrameAt = Date()
                let result = Self.analyze(
                    buffer: buffer,
                    sampleRate: Float(buffer.format.sampleRate),
                    range: range,
                    minimumAmplitude: minimumAmplitude,
                    minimumConfidence: minimumConfidence,
                    minimumConcentration: minimumConcentration,
                    maximumSpeechEnergyRatio: maximumSpeechEnergyRatio,
                    maximumVocalHarmonicCount: maximumVocalHarmonicCount,
                    maximumHarmonicRatio: maximumHarmonicRatio,
                    fftSetup: setup
                )
                onAnalysis(result)
            }
            self.engine = engine
            self.tapInstalled = true

            do {
                engine.prepare()
                try engine.start()
                self.startWatchdog()
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
            guard let self else { completion(false); return }
            // Fix #3: "running" engines can still be silently broken (mic gone, format mismatch).
            // Treat as unhealthy if no analysis frame arrived in the last 2 seconds.
            let running = self.engine?.isRunning ?? false
            let recent = Date().timeIntervalSince(self.lastFrameAt) < 2.0
            completion(running && recent)
        }
    }

    nonisolated private func startWatchdog() {
        watchdogTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self, self.engine?.isRunning == true else { return }
            if Date().timeIntervalSince(self.lastFrameAt) > 2.0 {
                self.onStaleAudio?()
            }
        }
        watchdogTimer = timer
        timer.resume()
    }

    nonisolated private func stopLocked(deactivateSession: Bool) {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        onStaleAudio = nil
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

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    nonisolated private static func analyze(
        buffer: AVAudioPCMBuffer,
        sampleRate: Float,
        range: ClosedRange<Float>,
        minimumAmplitude: Float,
        minimumConfidence: Float,
        minimumConcentration: Float,
        maximumSpeechEnergyRatio: Float,
        maximumVocalHarmonicCount: Int,
        maximumHarmonicRatio: Float,
        fftSetup: FFTSetup
    ) -> WhistleAnalysisResult {
        guard sampleRate > 0, let channelData = buffer.floatChannelData else { return .empty }

        let fftSize = Self.fftSize
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

        var peakAbs: Float = 0
        vDSP_maxmgv(samples, 1, &peakAbs, vDSP_Length(usableFrameCount))
        let crestFactor = peakAbs / max(rms, 0.000_001)
        let clippedInput = peakAbs > 0.96 && crestFactor < 1.65

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

        windowed.withUnsafeBufferPointer { pointer in
            pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPointer in
                real.withUnsafeMutableBufferPointer { realPointer in
                    imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                        var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                        vDSP_ctoz(complexPointer, 2, &split, 1, vDSP_Length(halfSize))
                        vDSP_fft_zrip(fftSetup, &split, 1, log2Size, FFTDirection(FFT_FORWARD))
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

        let speechStartBin = max(1, Int((80.0 / frequencyPerBin).rounded(.down)))
        let speechEndBin = min(startBin - 1, Int((750.0 / frequencyPerBin).rounded(.up)))
        var speechPower: Float = 0
        if speechStartBin <= speechEndBin {
            for index in speechStartBin...speechEndBin {
                speechPower += magnitudes[index]
            }
        }

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
        let dominanceScore = min(max((dominance - 1.8) / 6.0, 0), 1)
        let localDominanceScore = min(max((localDominance - 4.5) / 14.0, 0), 1)
        let bandScore = min(max((bandRatio - 0.04) / 0.28, 0), 1)
        let peakScore = min(max((peakShare - 0.025) / 0.10, 0), 1)
        let amplitudeScore = min(max((rms - minimumAmplitude) / max(minimumAmplitude * 3, 0.001), 0), 1)
        let confidence = (dominanceScore * 0.32) + (localDominanceScore * 0.26) + (bandScore * 0.20) + (peakScore * 0.12) + (amplitudeScore * 0.10)
        let hasTonalPeak = dominance >= 2.1 || localDominance >= 5.2
        let hasFocusedBandEnergy = bandRatio >= 0.045 || peakShare >= 0.028

        let concentration = concentrationAtPeak(magnitudes: magnitudes, peakIndex: peakIndex, bandPower: bandPower, halfSize: halfSize)
        let harmonicRatio = harmonicStackRatio(magnitudes: magnitudes, peakIndex: peakIndex, peakPower: peakPower, halfSize: halfSize)
        let vocalHarmonicCount = vocalHarmonicCount(magnitudes: magnitudes, peakIndex: peakIndex, peakPower: peakPower, frequencyPerBin: frequencyPerBin, halfSize: halfSize)
        let speechEnergyRatio = speechPower / max(speechPower + bandPower, 0.000_001)
        let isConcentrated = concentration >= minimumConcentration
        let minimumStrongBandConcentration = max(0.07, minimumConcentration * 0.45)
        let strongCookerBand = bandRatio >= 0.10
            && localDominance >= 5.0
            && confidence >= max(0, minimumConfidence - 0.08)
            && concentration >= minimumStrongBandConcentration
        let speechDominated = speechEnergyRatio > maximumSpeechEnergyRatio
        let vocalHarmonics = vocalHarmonicCount > maximumVocalHarmonicCount && speechEnergyRatio > 0.10
        let musicOrVoiceHarmonics = harmonicRatio > maximumHarmonicRatio && vocalHarmonicCount >= 3 && speechEnergyRatio > 0.08
        let clippedSpeech = clippedInput && (speechEnergyRatio > 0.10 || vocalHarmonicCount >= 4)
        let inRange = range.contains(frequency)
        let confidentEnough = confidence >= minimumConfidence
        let isWhistle = inRange
            && confidentEnough
            && hasTonalPeak
            && hasFocusedBandEnergy
            && (isConcentrated || strongCookerBand)
            && !speechDominated
            && !vocalHarmonics
            && !musicOrVoiceHarmonics
            && !clippedSpeech
        let freqHz = Int(frequency.rounded())
        let reason: String
        if isWhistle {
            reason = "Whistle confirmed at \(freqHz) Hz"
        } else if clippedSpeech {
            reason = "Close voice is clipping the mic"
        } else if !inRange {
            reason = "Tone at \(freqHz) Hz is outside cooker range"
        } else if speechDominated {
            reason = "Human voice energy detected"
        } else if vocalHarmonics {
            reason = "Speech or music harmonics detected"
        } else if musicOrVoiceHarmonics {
            reason = "Harmonic tone looks like voice or music"
        } else if !isConcentrated {
            reason = "High-frequency sound is too broad"
        } else if !hasTonalPeak {
            reason = "Sound is too noisy, not a clear tone"
        } else if !hasFocusedBandEnergy {
            reason = "Energy spread across many frequencies"
        } else if !confidentEnough {
            reason = "Tone too weak to be sure"
        } else {
            reason = "Possible whistle, confirming…"
        }

        return WhistleAnalysisResult(
            isWhistle: isWhistle,
            frequency: frequency,
            confidence: confidence,
            inputLevel: rms,
            harmonicRatio: harmonicRatio,
            voicingScore: Float(vocalHarmonicCount),
            concentration: concentration,
            peakBin: peakIndex,
            rejectionReason: reason
        )
    }

    nonisolated private static func concentrationAtPeak(magnitudes: [Float], peakIndex: Int, bandPower: Float, halfSize: Int) -> Float {
        guard bandPower > 0 else { return 0 }
        let lo = max(1, peakIndex - 5)
        let hi = min(halfSize - 1, peakIndex + 5)
        guard lo <= hi else { return 0 }
        var windowPower: Float = 0
        for index in lo...hi {
            windowPower += magnitudes[index]
        }
        return windowPower / bandPower
    }

    nonisolated private static func harmonicStackRatio(magnitudes: [Float], peakIndex: Int, peakPower: Float, halfSize: Int) -> Float {
        guard peakPower > 0 else { return 0 }
        let secondHarmonic = peakBandMax(magnitudes: magnitudes, center: peakIndex * 2, halfSize: halfSize, halfWidth: 2)
        let thirdHarmonic = peakBandMax(magnitudes: magnitudes, center: peakIndex * 3, halfSize: halfSize, halfWidth: 2)
        return (secondHarmonic + thirdHarmonic) / peakPower
    }

    nonisolated private static func vocalHarmonicCount(magnitudes: [Float], peakIndex: Int, peakPower: Float, frequencyPerBin: Float, halfSize: Int) -> Int {
        guard peakPower > 0, frequencyPerBin > 0 else { return 0 }
        let minF0Bins = max(2, Int((70.0 / frequencyPerBin).rounded(.up)))
        let maxF0Bins = max(minF0Bins, Int((450.0 / frequencyPerBin).rounded(.down)))
        let harmonicThreshold = peakPower * 0.10
        var bestCount = 0

        for f0Bins in minF0Bins...maxF0Bins {
            var count = 0
            for harmonic in 1...22 {
                let bin = harmonic * f0Bins
                if bin >= halfSize - 1 { break }
                if abs(bin - peakIndex) <= 1 { continue }
                if peakBandMax(magnitudes: magnitudes, center: bin, halfSize: halfSize, halfWidth: 1) >= harmonicThreshold {
                    count += 1
                }
            }
            if count > bestCount {
                bestCount = count
            }
        }

        return bestCount
    }

    nonisolated private static func peakBandMax(magnitudes: [Float], center: Int, halfSize: Int, halfWidth: Int) -> Float {
        guard center > 0, center < halfSize else { return 0 }
        let lo = max(1, center - halfWidth)
        let hi = min(halfSize - 1, center + halfWidth)
        guard lo <= hi else { return 0 }
        var best: Float = 0
        for index in lo...hi {
            if magnitudes[index] > best {
                best = magnitudes[index]
            }
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
    let concentration: Float
    let peakBin: Int
    let rejectionReason: String

    static let empty = WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: 0, harmonicRatio: 0, voicingScore: 0, concentration: 0, peakBin: 0, rejectionReason: "Listening for whistles…")

    static func silent(inputLevel: Float) -> WhistleAnalysisResult {
        let levelPct = Int((inputLevel * 100).rounded())
        return WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: inputLevel, harmonicRatio: 0, voicingScore: 0, concentration: 0, peakBin: 0, rejectionReason: "Listening for whistles… (mic level \(levelPct)%)")
    }

    static func quiet(inputLevel: Float) -> WhistleAnalysisResult {
        WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: inputLevel, harmonicRatio: 0, voicingScore: 0, concentration: 0, peakBin: 0, rejectionReason: "Background sounds — too quiet to be a whistle")
    }

    static func clipped(inputLevel: Float) -> WhistleAnalysisResult {
        WhistleAnalysisResult(isWhistle: false, frequency: 0, confidence: 0, inputLevel: inputLevel, harmonicRatio: 0, voicingScore: 0, concentration: 0, peakBin: 0, rejectionReason: "Audio is clipping — lower the volume")
    }

    func withRejection(_ newReason: String) -> WhistleAnalysisResult {
        WhistleAnalysisResult(isWhistle: false, frequency: frequency, confidence: confidence, inputLevel: inputLevel, harmonicRatio: harmonicRatio, voicingScore: voicingScore, concentration: concentration, peakBin: peakBin, rejectionReason: newReason)
    }
}
