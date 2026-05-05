@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentWhistleActivity: Activity<CookingActivityAttributes>?
    private var currentTimerActivity: Activity<CookingActivityAttributes>?

    private init() {}

    func startWhistle(title: String, count: Int, target: Int, completion: ((Bool) -> Void)? = nil) {
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
        start(mode: .whistle, state: state, completion: completion)
    }

    func updateWhistle(count: Int, target: Int, isListening: Bool, isFinished: Bool) {
        guard let activity = activity(for: .whistle) else { return }
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
                startedAt: activity.content.state.startedAt,
                endsAt: nil,
                isFinished: isFinished
            )
        )
    }

    func startTimer(title: String, remaining: TimeInterval, total: TimeInterval, completion: ((Bool) -> Void)? = nil) {
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
            staleDate: endsAt,
            completion: completion
        )
    }

    func updateTimer(remaining: TimeInterval, total: TimeInterval, isRunning: Bool, isFinished: Bool) {
        guard let activity = activity(for: .timer) else { return }
        let now = Date()
        let endsAt = isRunning && !isFinished ? now.addingTimeInterval(max(1, remaining)) : nil
        update(
            .init(
                mode: .timer,
                title: "Kitchen Timer",
                status: isFinished ? "Time's up" : (isRunning ? "Timer running" : "Timer paused"),
                count: Int(max(0, remaining).rounded()),
                target: Int(max(1, total).rounded()),
                startedAt: activity.content.state.startedAt,
                endsAt: endsAt,
                isFinished: isFinished
            ),
            staleDate: endsAt
        )
    }

    func endWhistle(finalStatus: String? = nil, dismissalDelay: TimeInterval = 30) {
        end(mode: .whistle, finalStatus: finalStatus, dismissalDelay: dismissalDelay)
    }

    func endTimer(finalStatus: String? = nil, dismissalDelay: TimeInterval = 30) {
        end(mode: .timer, finalStatus: finalStatus, dismissalDelay: dismissalDelay)
    }

    func end(finalStatus: String? = nil, dismissalDelay: TimeInterval = 30) {
        endWhistle(finalStatus: finalStatus, dismissalDelay: dismissalDelay)
        endTimer(finalStatus: finalStatus, dismissalDelay: dismissalDelay)
    }

    private func start(mode: CookingActivityAttributes.Mode, state: CookingActivityAttributes.ContentState, staleDate: Date? = nil, completion: ((Bool) -> Void)? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            completion?(false)
            return
        }

        let attributes = CookingActivityAttributes(id: UUID(), mode: mode)
        let content = ActivityContent(state: state, staleDate: staleDate)
        Task { @MainActor in
            await endExistingActivities(mode: mode, finalStatus: "Ended")
            do {
                let activity = try Activity<CookingActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                setActivity(activity, for: mode)
                completion?(true)
            } catch {
                setActivity(nil, for: mode)
                completion?(false)
            }
        }
    }

    private func update(_ state: CookingActivityAttributes.ContentState, staleDate: Date? = nil) {
        guard let activity = activity(for: state.mode) else { return }
        let content = ActivityContent(state: state, staleDate: staleDate)
        Task { @MainActor in
            await activity.update(content)
        }
    }

    private func end(mode: CookingActivityAttributes.Mode, finalStatus: String?, dismissalDelay: TimeInterval) {
        guard let activity = activity(for: mode) else { return }
        setActivity(nil, for: mode)
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

    private func activity(for mode: CookingActivityAttributes.Mode) -> Activity<CookingActivityAttributes>? {
        let cached: Activity<CookingActivityAttributes>? = switch mode {
        case .whistle:
            currentWhistleActivity
        case .timer:
            currentTimerActivity
        }
        if let cached {
            return cached
        }
        let restored = Activity<CookingActivityAttributes>.activities.first { $0.attributes.mode == mode }
        setActivity(restored, for: mode)
        return restored
    }

    private func setActivity(_ activity: Activity<CookingActivityAttributes>?, for mode: CookingActivityAttributes.Mode) {
        switch mode {
        case .whistle:
            currentWhistleActivity = activity
        case .timer:
            currentTimerActivity = activity
        }
    }

    private func endExistingActivities(mode: CookingActivityAttributes.Mode, finalStatus: String) async {
        setActivity(nil, for: mode)
        for activity in Activity<CookingActivityAttributes>.activities {
            guard activity.attributes.mode == mode else { continue }
            var state = activity.content.state
            state.isFinished = true
            state.status = finalStatus
            let content = ActivityContent(state: state, staleDate: Date())
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }
}
