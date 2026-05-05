import Combine
import Foundation
import UserNotifications

@MainActor
final class TimerVM: ObservableObject {
    @Published var totalDuration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var isRunning = false
    @Published var isDone = false
    @Published var showDonePopup = false
    @Published var showConfetti = false

    var sourceCookbook: Cookbook?
    private var ticker: Timer?
    private var expectedEndDate: Date?
    private var activeSoundPack: SoundPack = .classic
    private var activeHaptics = true

    init(cookbook: Cookbook?) {
        let duration = cookbook?.timerDuration ?? 15 * 60
        self.sourceCookbook = cookbook
        self.totalDuration = duration
        self.remaining = duration
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return remaining / totalDuration
    }

    func setDuration(_ duration: TimeInterval) {
        let clamped = min(max(duration, 1), 12 * 60 * 60)
        expectedEndDate = nil
        LiveActivityManager.shared.end(finalStatus: "Timer reset", dismissalDelay: 1)
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
        LiveActivityManager.shared.startTimer(title: sourceCookbook?.name ?? "Kitchen Timer", remaining: remaining, total: totalDuration)
        scheduleNotification()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(soundPack: soundPack, haptics: haptics)
            }
        }
    }

    func pause() {
        refreshRemainingFromClock(finishIfNeeded: false)
        isRunning = false
        expectedEndDate = nil
        LiveActivityManager.shared.updateTimer(remaining: remaining, total: totalDuration, isRunning: false, isFinished: false)
        ticker?.invalidate()
        ticker = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["WhistleCounterTimer"])
    }

    func toggle(soundPack: SoundPack, haptics: Bool) {
        isRunning ? pause() : start(soundPack: soundPack, haptics: haptics)
    }

    func reset() {
        pause()
        AudioPlayer.shared.stopAlarm()
        expectedEndDate = nil
        LiveActivityManager.shared.end(finalStatus: "Timer reset")
        remaining = totalDuration
        isDone = false
        showDonePopup = false
        showConfetti = false
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
        LiveActivityManager.shared.updateTimer(remaining: remaining, total: totalDuration, isRunning: isRunning, isFinished: false)
        if finishIfNeeded, isRunning, remaining <= 0 {
            finish(soundPack: activeSoundPack, haptics: activeHaptics)
        }
    }

    private func finish(soundPack: SoundPack, haptics: Bool) {
        isRunning = false
        expectedEndDate = nil
        ticker?.invalidate()
        ticker = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["WhistleCounterTimer"])
        isDone = true
        showDonePopup = true
        showConfetti = true
        LiveActivityManager.shared.end(finalStatus: "Time's up")
        AudioPlayer.shared.playAlarm(pack: soundPack)
        HapticManager.warning(enabled: haptics)
    }

    private func scheduleNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = "WAKE UP!"
        content.body = "Something smells amazing!"
        content.sound = .defaultCritical
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)
        let request = UNNotificationRequest(identifier: "WhistleCounterTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

}
