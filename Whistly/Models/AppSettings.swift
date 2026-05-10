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
        case .low: 0.018
        case .medium: 0.008
        case .high: 0.004
        }
    }

    nonisolated var minimumConfidence: Float {
        switch self {
        case .low: 0.62
        case .medium: 0.48
        case .high: 0.36
        }
    }

    nonisolated var harmonicMaxRatio: Float {
        switch self {
        case .low: 0.20
        case .medium: 0.32
        case .high: 0.48
        }
    }

    // Voicing test sums energy at peak ± k·f₀ for k = 1,2,3 across all
    // candidate f₀. Real voiced speech averages 0.20+. Cooker whistles
    // average <0.05 even with reverb.
    nonisolated var voicingMaxScore: Float {
        switch self {
        case .low: 0.08
        case .medium: 0.14
        case .high: 0.22
        }
    }

    // Fraction of band power that must sit in a ±5-bin window around the
    // peak. Pure tones concentrate >0.80 here. Voiced speech with formant
    // peak rarely exceeds 0.50 because harmonics steal energy from the band.
    nonisolated var concentrationMin: Float {
        switch self {
        case .low: 0.65
        case .medium: 0.45
        case .high: 0.28
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
