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
        mascotState = .bouncing
        milestone = "Setting up the microphone..."
    }

    func stopListening() {
        detector.stop()
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

        if count >= target {
            detector.stop()
            mascotState = .celebrating
            showConfetti = true
            showReadyPopup = true
        }
    }

    func reset() {
        detector.stop()
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
