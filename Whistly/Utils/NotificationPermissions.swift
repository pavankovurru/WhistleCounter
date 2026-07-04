import UserNotifications

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
