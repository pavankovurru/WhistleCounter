import Combine
import Foundation

@MainActor
final class WhistleCounterVM: ObservableObject {
    @Published var target: Int
    @Published var count = 0
    @Published var showReadyPopup = false
    @Published var showConfetti = false
    @Published var mascotState: WhistlyState = .idle
    @Published var milestone = "Choose a target, then start listening."

    let detector = WhistleDetector()
    var sourceCookbook: Cookbook?

    private var cancellables: Set<AnyCancellable> = []

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
        detector.$isListening
            .dropFirst()
            .sink { [weak self] _ in
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
        LiveActivityManager.shared.startWhistle(title: sourceCookbook?.name ?? "Whistle Counter", count: count, target: target)
        mascotState = .bouncing
        // Only show "Setting up" if mic isn't already authorized and active
        if !detector.isListening {
            milestone = "Setting up the microphone..."
        }
    }

    func stopListening() {
        detector.stop()
        LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: false, isFinished: count >= target)
        if count == 0 || count >= target {
            LiveActivityManager.shared.end(finalStatus: count >= target ? "Target reached" : "Stopped")
        }
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
        LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: detector.isListening, isFinished: count >= target)

        if count >= target {
            detector.stop()
            LiveActivityManager.shared.end(finalStatus: "Target reached")
            mascotState = .celebrating
            showConfetti = true
            showReadyPopup = true
        }
    }

    func reset() {
        detector.stop()
        LiveActivityManager.shared.end(finalStatus: "Reset")
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
        LiveActivityManager.shared.updateWhistle(count: count, target: target, isListening: detector.isListening, isFinished: count >= target)
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
