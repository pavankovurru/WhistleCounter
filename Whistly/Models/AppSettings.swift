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
    @Attribute(originalName: "whistleCountDelaySeconds")
    var whistleCountGapSeconds: Double = 2

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        hapticsEnabled: Bool = true,
        darkModeEnabled: Bool = false,
        soundPack: String = SoundPack.classic.rawValue,
        sensitivity: String = WhistleSensitivity.medium.rawValue,
        mascotTheme: String = MascotTheme.default.rawValue,
        whistleCountGapSeconds: Double = 2
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hapticsEnabled = hapticsEnabled
        self.darkModeEnabled = darkModeEnabled
        self.soundPack = soundPack
        self.sensitivity = sensitivity
        self.mascotTheme = mascotTheme
        self.whistleCountGapSeconds = Self.normalizedWhistleCountGapSeconds(whistleCountGapSeconds)
    }

    static let defaultWhistleCountGapSeconds: Double = 2
    static let minimumWhistleCountGapSeconds: Double = 0
    static let maximumWhistleCountGapSeconds: Double = 30
    private static let legacyDefaultWhistleCountGapSeconds: Set<Double> = [3, 4]

    var resolvedWhistleCountGapSeconds: Double {
        Self.resolvedWhistleCountGapSeconds(whistleCountGapSeconds)
    }

    func repairStoredValuesIfNeeded() {
        let resolvedGap = Self.resolvedWhistleCountGapSeconds(whistleCountGapSeconds)
        if Self.legacyDefaultWhistleCountGapSeconds.contains(resolvedGap) {
            whistleCountGapSeconds = Self.defaultWhistleCountGapSeconds
        } else if whistleCountGapSeconds != resolvedGap {
            whistleCountGapSeconds = resolvedGap
        }
    }

    static func resolvedWhistleCountGapSeconds(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return defaultWhistleCountGapSeconds }
        let rounded = seconds.rounded()
        guard rounded >= minimumWhistleCountGapSeconds else { return defaultWhistleCountGapSeconds }
        return min(maximumWhistleCountGapSeconds, rounded)
    }

    static func normalizedWhistleCountGapSeconds(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return defaultWhistleCountGapSeconds }
        let rounded = seconds.rounded()
        return min(maximumWhistleCountGapSeconds, max(minimumWhistleCountGapSeconds, rounded))
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
        case .low: 0.020
        case .medium: 0.010
        case .high: 0.006
        }
    }

    nonisolated var minimumConfidence: Float {
        switch self {
        case .low: 0.66
        case .medium: 0.52
        case .high: 0.42
        }
    }

    nonisolated var minimumConcentration: Float {
        switch self {
        case .low: 0.24
        case .medium: 0.18
        case .high: 0.13
        }
    }

    nonisolated var maximumSpeechEnergyRatio: Float {
        switch self {
        case .low: 0.24
        case .medium: 0.34
        case .high: 0.46
        }
    }

    nonisolated var maximumVocalHarmonicCount: Int {
        switch self {
        case .low: 3
        case .medium: 5
        case .high: 7
        }
    }

    nonisolated var maximumHarmonicRatio: Float {
        switch self {
        case .low: 0.65
        case .medium: 0.95
        case .high: 1.30
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
