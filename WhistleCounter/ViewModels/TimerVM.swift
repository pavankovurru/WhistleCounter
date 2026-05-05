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
        totalDuration = clamped
        remaining = clamped
        isDone = false
        showDonePopup = false
    }

    func start(soundPack: SoundPack, haptics: Bool) {
        guard remaining > 0 else { return }
        isRunning = true
        isDone = false
        scheduleNotification()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(soundPack: soundPack, haptics: haptics)
            }
        }
    }

    func pause() {
        isRunning = false
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
        remaining = totalDuration
        isDone = false
        showDonePopup = false
        showConfetti = false
    }

    private func tick(soundPack: SoundPack, haptics: Bool) {
        guard isRunning else { return }
        if remaining <= 1 {
            remaining = 0
            finish(soundPack: soundPack, haptics: haptics)
        } else {
            remaining -= 1
        }
    }

    private func finish(soundPack: SoundPack, haptics: Bool) {
        pause()
        isDone = true
        showDonePopup = true
        showConfetti = true
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
