import Combine
import Foundation
import UserNotifications

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

    private let milestones = [
        0: "Choose a target, then start listening.",
        1: "One whistle counted. Keep the phone nearby.",
        2: "Halfway there, superstar! ⭐",
        3: "Almost there. Stay close to the cooker.",
        4: "One more whistle to go.",
        5: "Target reached. Your food is ready."
    ]

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

    func startListening(sensitivity: WhistleSensitivity) {
        detector.start(sensitivity: sensitivity)
        mascotState = .bouncing
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

    func toggleListening(sensitivity: WhistleSensitivity) {
        detector.isListening ? stopListening() : startListening(sensitivity: sensitivity)
    }

    func increment() {
        guard count < target else { return }
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
            notifyTargetReached()
        }
    }

    private func notifyTargetReached() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
        let content = UNMutableNotificationContent()
        content.title = "Cooker is ready!"
        content.body = "\(target) whistles counted. Time to take it off the heat."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "WhistlyWhistleTarget", content: content, trigger: nil)
        center.add(request)
    }

    func reset() {
        detector.stop()
        endLiveActivity(finalStatus: "Reset", dismissalDelay: 5)
        count = 0
        mascotState = .idle
        showReadyPopup = false
        showConfetti = false
        refreshMilestone()
    }

    func setTarget(_ newTarget: Int) {
        target = min(20, max(1, newTarget))
        count = min(count, target)
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
                LiveActivityManager.shared.endWhistle(finalStatus: self.count >= self.target ? "Target reached" : "Stopped", dismissalDelay: self.count >= self.target ? 30 : 5)
            } else if shouldKeepActivity {
                LiveActivityManager.shared.updateWhistle(count: self.count, target: self.target, isListening: self.detector.isListening, isFinished: false)
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
        wantsLiveActivity = false
        guard hasLiveActivity || isRequestingLiveActivity else { return }
        isRequestingLiveActivity = false
        hasLiveActivity = false
        LiveActivityManager.shared.endWhistle(finalStatus: finalStatus, dismissalDelay: dismissalDelay)
    }

    private func handleListeningRecovered() {
        guard count < target else { return }
        milestone = "Listening was briefly interrupted — please verify count."
    }

    private func refreshMilestone() {
        if count >= target {
            milestone = milestones[5] ?? "Done!"
        } else if count == 0 {
            if detector.isListening {
                milestone = "Listening for the first cooker whistle."
            } else if detector.isStarting {
                milestone = "Setting up the microphone..."
            } else {
                milestone = milestones[0] ?? "Choose a target, then start listening."
            }
        } else if count == target - 1 {
            milestone = milestones[4] ?? "One more..."
        } else if count >= max(1, target / 2) {
            milestone = milestones[2] ?? "Halfway there!"
        } else {
            milestone = milestones[count] ?? "Keep going!"
        }
    }
}
