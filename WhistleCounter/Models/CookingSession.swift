import Foundation
import SwiftData

@Model
final class CookingSession {
    var id: UUID
    var cookbookName: String?
    var emoji: String
    var whistleCount: Int
    var targetWhistles: Int?
    var timerDuration: TimeInterval?
    var completedAt: Date
    var wasSuccessful: Bool
    var reaction: String

    init(
        id: UUID = UUID(),
        cookbookName: String? = nil,
        emoji: String = "🍲",
        whistleCount: Int = 0,
        targetWhistles: Int? = nil,
        timerDuration: TimeInterval? = nil,
        completedAt: Date = Date(),
        wasSuccessful: Bool = true,
        reaction: String = "Chef's kiss"
    ) {
        self.id = id
        self.cookbookName = cookbookName
        self.emoji = emoji
        self.whistleCount = whistleCount
        self.targetWhistles = targetWhistles
        self.timerDuration = timerDuration
        self.completedAt = completedAt
        self.wasSuccessful = wasSuccessful
        self.reaction = reaction
    }

    var title: String {
        if let cookbookName, !cookbookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cookbookName
        }
        return generatedTitle
    }

    var summary: String {
        var parts: [String] = []
        if whistleCount > 0 {
            parts.append("\(whistleCount) whistles")
        } else if let targetWhistles {
            parts.append("\(targetWhistles) whistles")
        }
        if let timerDuration {
            parts.append(timerDuration.shortDurationText)
        }
        parts.append(reaction)
        return parts.joined(separator: " • ")
    }

    private var generatedTitle: String {
        if timerDuration != nil {
            let names = ["Snack Sprint", "Kitchen Countdown", "Tiny Timer", "Dinner Dash", "Cozy Cook"]
            return names[stableNameIndex(count: names.count)]
        }

        let names = ["Steam Patrol", "Whistle Dash", "Pressure Party", "Chef's Count", "Ready Watch"]
        return names[stableNameIndex(count: names.count)]
    }

    private func stableNameIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        let total = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return total % count
    }
}
