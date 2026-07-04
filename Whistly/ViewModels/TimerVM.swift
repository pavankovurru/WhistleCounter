import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class TimerVM: ObservableObject {
    @Published var totalDuration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var isRunning = false
    @Published var isDone = false
    @Published var showDonePopup = false
    @Published var showConfetti = false

    var sourceCookbook: Cookbook?
    // Set when a timer finishes; the view consumes it to log the session. Lives on
    // the VM (not the view) so a finish that happens off-screen still gets logged.
    var needsCompletionLog = false
    private var ticker: Timer?
    private var expectedEndDate: Date?
    private var activeSoundPack: SoundPack = .classic
    private var activeHaptics = true

    private var alarmAckCancellable: AnyCancellable?

    init(cookbook: Cookbook?) {
        let duration = cookbook?.timerDuration ?? 30 * 60
        self.sourceCookbook = cookbook
        self.totalDuration = duration
        self.remaining = duration
        alarmAckCancellable = NotificationCenter.default.publisher(for: .whistlyAlarmNotificationAcknowledged)
            .sink { [weak self] note in
                guard let identifier = note.userInfo?["identifier"] as? String,
                      identifier.hasPrefix("WhistlyTimer") else { return }
                self?.acknowledgeAlarmNotification()
            }
    }

    /// Clearing or tapping the timer notification acknowledges the completed timer:
    /// reset it so the screen doesn't sit on "Stop Sound", and so opening the app
    /// doesn't immediately start the alarm for a timer the user already dismissed.
    private func acknowledgeAlarmNotification() {
        // Only reset a *completed* timer — a stale notification tapped later must
        // not kill a fresh running timer.
        let expired = expectedEndDate.map { $0.timeIntervalSinceNow <= 0 } ?? false
        guard isDone || (isRunning && expired) else { return }
        let pendingLog = needsCompletionLog || !isDone
        reset()
        needsCompletionLog = pendingLog
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return remaining / totalDuration
    }

    func setDuration(_ duration: TimeInterval) {
        let clamped = min(max(duration, 1), 12 * 60 * 60)
        expectedEndDate = nil
        // Do NOT touch LiveActivity here — setDuration is called on every ring drag frame.
        // LiveActivity lifecycle is managed only by start / pause / reset.
        totalDuration = clamped
        remaining = clamped
        isDone = false
        showDonePopup = false
    }

    func start(soundPack: SoundPack, haptics: Bool) {
        guard remaining > 0 else { return }
        activeSoundPack = soundPack
        activeHaptics = haptics
        expectedEndDate = Date().addingTimeInterval(remaining)
        isRunning = true
        isDone = false
        LiveActivityManager.shared.startTimer(title: sourceCookbook?.name, remaining: remaining, total: totalDuration)
        scheduleNotification()
        startTicker()
    }

    /// Reattaches to a timer that was still counting when the app was killed. Its
    /// Live Activity and completion notification are both still live, so the timer
    /// simply picks up where it left off instead of being forgotten.
    func restoreOrphanedTimer(soundPack: SoundPack, haptics: Bool) {
        guard !isRunning, let restored = LiveActivityManager.shared.restorableRunningTimer() else { return }
        activeSoundPack = soundPack
        activeHaptics = haptics
        totalDuration = restored.total
        expectedEndDate = restored.endsAt
        remaining = max(0, restored.endsAt.timeIntervalSinceNow.rounded(.up))
        isRunning = true
        isDone = false
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tick(soundPack: self.activeSoundPack, haptics: self.activeHaptics)
            }
        }
    }

    func pause() {
        pause(keepLiveActivity: true)
    }

    private static let notificationIdentifiers = ["WhistlyTimer", "WhistlyTimerNudge1", "WhistlyTimerNudge2"]

    private func pause(keepLiveActivity: Bool) {
        // Snap remaining to clock BEFORE changing isRunning so the LA update is accurate
        if let end = expectedEndDate {
            remaining = max(0, end.timeIntervalSinceNow.rounded(.up))
        }
        isRunning = false
        expectedEndDate = nil
        ticker?.invalidate()
        ticker = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.notificationIdentifiers)
        if keepLiveActivity {
            // Keep the activity alive in a paused state; ending and re-requesting on
            // resume makes the Dynamic Island replay its expanded intro animation.
            LiveActivityManager.shared.updateTimer(remaining: remaining, total: totalDuration, isRunning: false, isFinished: false)
        }
    }

    func toggle(soundPack: SoundPack, haptics: Bool) {
        isRunning ? pause() : start(soundPack: soundPack, haptics: haptics)
    }

    /// Called when the timer screen (re)opens. Applies the tapped cookbook's setup
    /// unless a timer is already running — the running timer keeps priority.
    /// Returns false when the tapped cookbook was NOT applied, so the view can tell
    /// the user why they're looking at a different timer.
    @discardableResult
    func adopt(cookbook: Cookbook?) -> Bool {
        guard let cookbook else { return true }  // quick timer: keep whatever is in progress
        guard !isRunning else { return sourceCookbook?.id == cookbook.id }
        sourceCookbook = cookbook
        setDuration(cookbook.timerDuration ?? totalDuration)
        return true
    }

    func reset() {
        pause(keepLiveActivity: false)
        AudioPlayer.shared.stopAlarm()
        expectedEndDate = nil
        LiveActivityManager.shared.endTimer(finalStatus: "Timer reset")
        remaining = totalDuration
        isDone = false
        showDonePopup = false
        showConfetti = false
        needsCompletionLog = false
    }

    private func tick(soundPack: SoundPack, haptics: Bool) {
        guard isRunning else { return }
        refreshRemainingFromClock(finishIfNeeded: false)
        if remaining <= 0 {
            remaining = 0
            finish(soundPack: soundPack, haptics: haptics)
        }
    }

    func refreshRemainingFromClock(finishIfNeeded: Bool = true) {
        guard let expectedEndDate else { return }
        remaining = max(0, expectedEndDate.timeIntervalSinceNow.rounded(.up))
        // No Live Activity update here: this runs every tick, and pushing a freshly
        // recomputed endsAt each second makes the system countdown stutter. The LA
        // counts down on its own; it only needs updates on start/pause/resume/finish.
        if finishIfNeeded, isRunning, remaining <= 0 {
            finish(soundPack: activeSoundPack, haptics: activeHaptics)
        }
    }

    private func finish(soundPack: SoundPack, haptics: Bool) {
        isRunning = false
        expectedEndDate = nil
        ticker?.invalidate()
        ticker = nil
        // The app is alive and ringing, so the un-fired follow-up nudges are noise.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.notificationIdentifiers)
        isDone = true
        showDonePopup = true
        showConfetti = true
        needsCompletionLog = true
        LiveActivityManager.shared.endTimer(finalStatus: "Time's up")
        AudioPlayer.shared.playAlarm(pack: soundPack)
        HapticManager.warning(enabled: haptics)
    }

    private func scheduleNotification() {
        guard let endDate = expectedEndDate else { return }
        Task { @MainActor in
            guard await NotificationPermissions.ensureDeliveryAllowed() else { return }
            // The permission prompt can stay up for a while — bail if the user
            // paused or reset the timer in the meantime.
            guard isRunning, expectedEndDate == endDate else { return }
            let center = UNUserNotificationCenter.current()
            let sound = activeSoundPack.notificationSound
            // Main alert at 0:00, plus two follow-up nudges in case the first one
            // was missed — a kitchen timer can't afford a single 2-second chime.
            // All are cancelled when the app itself handles the finish.
            let alerts: [(id: String, delay: TimeInterval, title: String, body: String)] = [
                ("WhistlyTimer", 0, "WAKE UP!", "Something smells amazing!"),
                ("WhistlyTimerNudge1", 45, "Still cooking?", "Your timer finished a minute ago."),
                ("WhistlyTimerNudge2", 150, "Don't forget the stove!", "Your timer finished a while ago.")
            ]
            for alert in alerts {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.body
                content.sound = sound
                content.interruptionLevel = .timeSensitive
                content.categoryIdentifier = WhistlyNotificationDelegate.alarmCategoryID
                let fireIn = max(1, endDate.timeIntervalSinceNow + alert.delay)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
                let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

}
