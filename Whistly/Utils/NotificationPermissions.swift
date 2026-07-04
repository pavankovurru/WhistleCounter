import UserNotifications

extension SoundPack {
    /// A bundled 29.5s render of this alarm pack — the same synthesis the in-app
    /// alarm uses — so notifications sound like the app, not a 2-second ding.
    var notificationSound: UNNotificationSound {
        let baseName = "timer_alarm_\(rawValue.lowercased())"
        guard Bundle.main.url(forResource: baseName, withExtension: "wav") != nil else {
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName("\(baseName).wav"))
    }
}

enum NotificationPermissions {
    /// Requests notification authorization if the user hasn't been asked yet,
    /// then reports whether Whistly is allowed to deliver notifications.
    static func ensureDeliveryAllowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
