import CoreHaptics
import SwiftUI

enum HapticManager {
    static func tap(enabled: Bool) {
        guard enabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func selection(enabled: Bool) {
        guard enabled else { return }
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success(enabled: Bool) {
        guard enabled else { return }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning(enabled: Bool) {
        guard enabled else { return }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func celebration(enabled: Bool) {
        guard enabled else { return }
        #if os(iOS)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.12),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
            ], relativeTime: 0.25, duration: 0.35)
        ]

        do {
            try engine.start()
            try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}
