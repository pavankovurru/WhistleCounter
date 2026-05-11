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

    var suggestedDistance: String {
        switch self {
        case .low:    "~0.5–1m away"
        case .medium: "~0.5–2m away"
        case .high:   "~up to 3m away"
        }
    }

    nonisolated var minimumAmplitude: Float {
        switch self {
        case .low: 0.022    // requires a loud, close sound — very conservative
        case .medium: 0.012 // filters out quiet ambient speech; real whistles are much louder
        case .high: 0.006   // allows quieter sounds through; confidence gate does the work
        }
    }

    nonisolated var minimumConfidence: Float {
        switch self {
        case .low: 0.70     // very strict — only a clear, dominant tonal signal passes
        case .medium: 0.58  // speech peaks at 0.30–0.50; real whistles hit 0.80+; gap is safe
        case .high: 0.46    // still above typical speech; far below any genuine whistle
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
