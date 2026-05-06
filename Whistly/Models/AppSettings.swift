import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var hasCompletedOnboarding: Bool
    var hapticsEnabled: Bool
    var darkModeEnabled: Bool
    var soundPack: String
    var sensitivity: String
    var mascotTheme: String

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        hapticsEnabled: Bool = true,
        darkModeEnabled: Bool = false,
        soundPack: String = SoundPack.classic.rawValue,
        sensitivity: String = WhistleSensitivity.medium.rawValue,
        mascotTheme: String = MascotTheme.default.rawValue
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hapticsEnabled = hapticsEnabled
        self.darkModeEnabled = darkModeEnabled
        self.soundPack = soundPack
        self.sensitivity = sensitivity
        self.mascotTheme = mascotTheme
    }
}

enum SoundPack: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case funny = "Funny"
    case zen = "Zen"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .classic: "🔔"
        case .funny: "😂"
        case .zen: "🧘"
        }
    }
}

enum WhistleSensitivity: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    nonisolated var minimumAmplitude: Float {
        switch self {
        case .low: 0.012
        case .medium: 0.006
        case .high: 0.0025
        }
    }

    nonisolated var minimumConfidence: Float {
        switch self {
        case .low: 0.66
        case .medium: 0.45
        case .high: 0.32
        }
    }
}

enum MascotTheme: String, CaseIterable, Identifiable {
    case `default` = "Classic"
    case sunny = "Sunny"
    case mint = "Mint"
    case berry = "Berry"

    var id: String { rawValue }

    static func resolved(from storedValue: String) -> MascotTheme {
        if let theme = MascotTheme(rawValue: storedValue) {
            return theme
        }

        switch storedValue {
        case "Default":
            return .default
        case "Chef":
            return .sunny
        case "Astronaut":
            return .mint
        case "Santa":
            return .berry
        default:
            return .default
        }
    }
}
