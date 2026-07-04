import UserNotifications

extension Notification.Name {
    /// Posted when the user clears or taps a Whistly alarm notification; the
    /// userInfo "identifier" carries the notification request identifier so each
    /// feature can reset only its own completed state.
    static let whistlyAlarmNotificationAcknowledged = Notification.Name("whistlyAlarmNotificationAcknowledged")
}

/// Handles alarm-notification interactions: clearing or tapping an alarm
/// notification acknowledges it, so the in-app alarm stops ringing and any
/// pending follow-up nudges are cancelled.
final class WhistlyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WhistlyNotificationDelegate()
    nonisolated static let alarmCategoryID = "WHISTLY_ALARM"

    /// Call once at launch, before any notification can arrive.
    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = shared
        // .customDismissAction is what makes iOS deliver "user cleared this
        // notification" events to didReceive below.
        let alarmCategory = UNNotificationCategory(
            identifier: alarmCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([alarmCategory])
    }

    // Preserve the pre-delegate behavior: no banners while the app is foreground —
    // the in-app alarm and popup are already the alert.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        guard content.categoryIdentifier == Self.alarmCategoryID else {
            completionHandler()
            return
        }
        // Both clearing the notification and tapping it acknowledge the alarm.
        center.removePendingNotificationRequests(withIdentifiers: ["WhistlyTimerNudge1", "WhistlyTimerNudge2"])
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            // If an alarm is ringing, the app is running (audio keeps it alive), so
            // this executes even though the completion is reported synchronously.
            AudioPlayer.shared.stopAlarm()
            NotificationCenter.default.post(
                name: .whistlyAlarmNotificationAcknowledged,
                object: nil,
                userInfo: ["identifier": identifier]
            )
        }
        completionHandler()
    }
}
