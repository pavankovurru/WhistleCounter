@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<CookingActivityAttributes>?

    private init() {}

    func startWhistle(title: String, count: Int, target: Int) {
        let state = CookingActivityAttributes.ContentState(
            mode: .whistle,
            title: title,
            status: count == 0 ? "Listening for cooker whistles" : "\(count) of \(target) whistles counted",
            count: count,
            target: target,
            startedAt: Date(),
            endsAt: nil,
            isFinished: false
        )
        start(mode: .whistle, state: state)
    }

    func updateWhistle(count: Int, target: Int, isListening: Bool, isFinished: Bool) {
        guard currentActivity?.attributes.mode == .whistle else { return }
        let status: String
        if isFinished {
            status = "Target reached"
        } else if isListening {
            status = count == 0 ? "Listening for cooker whistles" : "\(count) of \(target) whistles counted"
        } else {
            status = "Whistle counter paused"
        }
        update(
            .init(
                mode: .whistle,
                title: "Whistle Counter",
                status: status,
                count: count,
                target: target,
                startedAt: currentActivity?.content.state.startedAt ?? Date(),
                endsAt: nil,
                isFinished: isFinished
            )
        )
    }

    func startTimer(title: String, remaining: TimeInterval, total: TimeInterval) {
        let now = Date()
        let endsAt = now.addingTimeInterval(max(1, remaining))
        start(
            mode: .timer,
            state: .init(
                mode: .timer,
                title: title,
                status: "Timer running",
                count: Int(max(0, remaining).rounded()),
                target: Int(max(1, total).rounded()),
                startedAt: now,
                endsAt: endsAt,
                isFinished: false
            ),
            staleDate: endsAt
        )
    }

    func updateTimer(remaining: TimeInterval, total: TimeInterval, isRunning: Bool, isFinished: Bool) {
        guard currentActivity?.attributes.mode == .timer else { return }
        let now = Date()
        let endsAt = isRunning && !isFinished ? now.addingTimeInterval(max(1, remaining)) : nil
        update(
            .init(
                mode: .timer,
                title: "Kitchen Timer",
                status: isFinished ? "Time's up" : (isRunning ? "Timer running" : "Timer paused"),
                count: Int(max(0, remaining).rounded()),
                target: Int(max(1, total).rounded()),
                startedAt: currentActivity?.content.state.startedAt ?? now,
                endsAt: endsAt,
                isFinished: isFinished
            ),
            staleDate: endsAt
        )
    }

    func end(finalStatus: String? = nil, dismissalDelay: TimeInterval = 30) {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task { @MainActor in
            var state = activity.content.state
            state.isFinished = true
            if let finalStatus {
                state.status = finalStatus
            }
            let content = ActivityContent(state: state, staleDate: Date())
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(dismissalDelay)))
        }
    }

    private func start(mode: CookingActivityAttributes.Mode, state: CookingActivityAttributes.ContentState, staleDate: Date? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end(finalStatus: "Ended", dismissalDelay: 1)

        let attributes = CookingActivityAttributes(id: UUID(), mode: mode)
        let content = ActivityContent(state: state, staleDate: staleDate)
        Task { @MainActor in
            do {
                currentActivity = try Activity<CookingActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                currentActivity = nil
            }
        }
    }

    private func update(_ state: CookingActivityAttributes.ContentState, staleDate: Date? = nil) {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: state, staleDate: staleDate)
        Task { @MainActor in
            await activity.update(content)
        }
    }
}
