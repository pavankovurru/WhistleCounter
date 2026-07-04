import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class WhistlyCounterVM: ObservableObject {
    @Published var target: Int
    @Published var count = 0
    @Published var showReadyPopup = false
    @Published var showConfetti = false
    @Published var mascotState: WhistlyState = .idle
    @Published var milestone = "Choose a target, then start listening."

    let detector = WhistleDetector()
    var sourceCookbook: Cookbook?

    private var cancellables: Set<AnyCancellable> = []
    private var hasLiveActivity = false
    private var isRequestingLiveActivity = false
    private var wantsLiveActivity = false
    private var keepAliveTask: Task<Void, Never>?
    private var activeSoundPack: SoundPack = .classic
    private var countGapSeconds: TimeInterval = AppSettings.defaultWhistleCountGapSeconds
    private var lastIncrementAt = Date.distantPast

    init(cookbook: Cookbook?) {
        self.sourceCookbook = cookbook
        self.target = cookbook?.whistleTarget ?? 3
        detector.onWhistle = { [weak self] in
            Task { @MainActor in
                self?.increment()
            }
        }
        detector.onListeningRecovered = { [weak self] in
            Task { @MainActor in
                self?.handleListeningRecovered()
            }
        }
        detector.$isListening
            .dropFirst()
            .sink { [weak self] isListening in
                self?.handleListeningChanged(isListening)
                self?.refreshMilestone()
            }
            .store(in: &cancellables)
        detector.$isStarting
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshMilestone()
            }
            .store(in: &cancellables)
        refreshMilestone()
    }

    func startListening(sensitivity: WhistleSensitivity, countGapSeconds: TimeInterval, soundPack: SoundPack) {
        let normalizedGap = AppSettings.normalizedWhistleCountGapSeconds(countGapSeconds)
        self.countGapSeconds = normalizedGap
        self.activeSoundPack = soundPack
        detector.start(sensitivity: sensitivity, countGapSeconds: normalizedGap)
        mascotState = .bouncing
        // Ask now so the target-reached notification can be delivered later,
        // when the app may be backgrounded or the phone locked.
        Task {
            _ = await NotificationPermissions.ensureDeliveryAllowed()
        }
        Task { @MainActor [weak self] in
            await self?.startLiveActivityWhenListening()
        }
        // Only show "Setting up" if mic isn't already authorized and active
        if !detector.isListening {
            milestone = "Setting up the microphone..."
        }
    }

    func stopListening() {
        detector.stop()
        endLiveActivity(finalStatus: count >= target ? "Target reached" : "Stopped", dismissalDelay: count >= target ? 30 : 5)
        mascotState = .idle
        refreshMilestone()
    }

    func toggleListening(sensitivity: WhistleSensitivity, countGapSeconds: TimeInterval, soundPack: SoundPack) {
        detector.isListening ? stopListening() : startListening(sensitivity: sensitivity, countGapSeconds: countGapSeconds, soundPack: soundPack)
    }

    func updateCountGap(_ seconds: TimeInterval) {
        let normalizedGap = AppSettings.normalizedWhistleCountGapSeconds(seconds)
        countGapSeconds = normalizedGap
        detector.updateCountGap(normalizedGap)
    }

    func increment() {
        guard count < target else { return }
        // The alarm and preview tones are pure bells inside the whistle frequency
        // band — never count the app's own sounds as cooker whistles.
        guard !AudioPlayer.shared.isAlarmPlaying, AudioPlayer.shared.previewingPack == nil else { return }
        let now = Date()
        guard now.timeIntervalSince(lastIncrementAt) >= countGapSeconds else {
            let remaining = max(0, countGapSeconds - now.timeIntervalSince(lastIncrementAt))
            milestone = "Whistle gap active: \(Int(ceil(remaining)))s before the next count."
            return
        }
        lastIncrementAt = now
        count += 1
        mascotState = .bouncing
        refreshMilestone()
        startLiveActivityIfNeeded()
        if hasLiveActivity {
            LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: detector.isListening, isFinished: count >= target)
        }

        if count >= target {
            detector.stop()
            endLiveActivity(finalStatus: "Target reached")
            mascotState = .celebrating
            showConfetti = true
            showReadyPopup = true
            playTargetReachedAlarm()
            notifyTargetReached()
        }
    }

    // The alarm is played from the VM, not the view: SwiftUI onChange isn't
    // guaranteed to fire while the app is listening in the background, and this is
    // the moment the whole app exists for.
    private func playTargetReachedAlarm() {
        let pack = activeSoundPack
        Task { @MainActor in
            // Give the detector's audio session a moment to deactivate before the
            // alarm claims a playback session, or the alarm can be cut off.
            try? await Task.sleep(for: .milliseconds(200))
            AudioPlayer.shared.playAlarm(pack: pack)
        }
    }

    private func notifyTargetReached() {
        let completedTarget = target
        Task {
            guard await NotificationPermissions.ensureDeliveryAllowed() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Cooker is ready!"
            content.body = "\(completedTarget) whistles counted. Time to take it off the heat."
            // No notification sound: this only fires while the app is running (it
            // just detected a whistle), and the in-app alarm is already playing.
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: "WhistlyWhistleTarget", content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func reset() {
        detector.stop()
        endLiveActivity(finalStatus: "Reset", dismissalDelay: 5)
        count = 0
        lastIncrementAt = .distantPast
        mascotState = .idle
        showReadyPopup = false
        showConfetti = false
        refreshMilestone()
    }

    func setTarget(_ newTarget: Int) {
        let wasComplete = count >= target
        target = min(100, max(1, newTarget))
        count = min(count, target)
        let isComplete = count >= target
        if wasComplete && !isComplete {
            AudioPlayer.shared.stopAlarm()
            showReadyPopup = false
            showConfetti = false
            mascotState = detector.isListening ? .bouncing : .idle
        } else if isComplete {
            detector.stop()
            endLiveActivity(finalStatus: "Target reached")
            mascotState = .celebrating
            showConfetti = true
            showReadyPopup = true
            if !wasComplete {
                playTargetReachedAlarm()
            }
        }
        refreshMilestone()
        if hasLiveActivity {
            LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: detector.isListening, isFinished: count >= target)
        }
    }

    private func handleListeningChanged(_ isListening: Bool) {
        if isListening {
            startLiveActivityIfNeeded()
        } else if count < target {
            endLiveActivity(finalStatus: "Stopped", dismissalDelay: 5)
        }
    }

    private func startLiveActivityIfNeeded() {
        guard !hasLiveActivity, !isRequestingLiveActivity, detector.isListening, count < target else { return }
        wantsLiveActivity = true
        isRequestingLiveActivity = true
        LiveActivityManager.shared.startWhistle(title: sourceCookbook?.name ?? "Whistly", count: count, target: target) { [weak self] didStart in
            guard let self else { return }
            self.isRequestingLiveActivity = false
            let shouldKeepActivity = didStart && self.wantsLiveActivity && self.detector.isListening && self.count < self.target
            self.hasLiveActivity = shouldKeepActivity
            if didStart && !shouldKeepActivity {
                if self.count >= self.target {
                    LiveActivityManager.shared.endWhistle(count: self.count, target: self.target, finalStatus: "Target reached", dismissalDelay: 30)
                } else {
                    LiveActivityManager.shared.endWhistle(finalStatus: "Stopped", dismissalDelay: 5)
                }
            } else if shouldKeepActivity {
                LiveActivityManager.shared.updateWhistle(count: self.count, target: self.target, isListening: self.detector.isListening, isFinished: false)
                self.startLiveActivityKeepAlive()
            }
        }
    }

    // Refreshes the activity before its rolling staleDate lapses, so it only ever
    // goes stale when the app was killed and genuinely stopped counting.
    private func startLiveActivityKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, self.hasLiveActivity, !Task.isCancelled else { return }
                LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: detector.isListening, isFinished: false)
            }
        }
    }

    private func startLiveActivityWhenListening() async {
        for _ in 0..<30 {
            if detector.isListening {
                startLiveActivityIfNeeded()
                return
            }
            if !detector.isStarting {
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func endLiveActivity(finalStatus: String, dismissalDelay: TimeInterval = 30) {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        wantsLiveActivity = false
        guard hasLiveActivity || isRequestingLiveActivity else { return }
        isRequestingLiveActivity = false
        hasLiveActivity = false
        if count >= target {
            LiveActivityManager.shared.endWhistle(count: count, target: target, finalStatus: finalStatus, dismissalDelay: dismissalDelay)
        } else {
            LiveActivityManager.shared.endWhistle(finalStatus: finalStatus, dismissalDelay: dismissalDelay)
        }
    }

    private func handleListeningRecovered() {
        guard count < target else { return }
        milestone = "Listening was briefly interrupted — please verify count."
    }

    private func refreshMilestone() {
        if count >= target {
            milestone = "Target reached. Your food is ready."
        } else if count == 0 {
            if detector.isListening {
                milestone = "Listening for the first cooker whistle."
            } else if detector.isStarting {
                milestone = "Setting up the microphone..."
            } else {
                milestone = "Choose a target, then start listening."
            }
        } else if count == target - 1 {
            milestone = "One more whistle to go."
        } else if count == 1 {
            let remaining = target - count
            milestone = "One whistle counted. \(remaining) more to go."
        } else if count >= max(1, target / 2) {
            let remaining = target - count
            milestone = "Halfway there. \(remaining) whistles to go."
        } else {
            milestone = "\(count) of \(target) whistles counted. Keep going."
        }
    }
}
