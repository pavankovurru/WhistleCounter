import Foundation
import SwiftData

@Model
final class Cookbook {
    var id: UUID
    var name: String
    var whistleTarget: Int?
    var timerDuration: TimeInterval?
    var notes: String
    var emoji: String
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        whistleTarget: Int? = nil,
        timerDuration: TimeInterval? = nil,
        notes: String = "",
        emoji: String = "🍲",
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.whistleTarget = whistleTarget
        self.timerDuration = timerDuration
        self.notes = notes
        self.emoji = emoji
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var mode: CookbookMode {
        if whistleTarget != nil { return .whistles }
        return .timers
    }

    var detailText: String {
        var parts: [String] = []
        if let whistleTarget {
            parts.append("\(whistleTarget) whistles")
        }
        if let timerDuration {
            parts.append(timerDuration.shortDurationText)
        }
        return parts.isEmpty ? "No setup" : parts.joined(separator: " + ")
    }
}

enum CookbookMode: String, CaseIterable, Identifiable {
    case all = "All"
    case whistles = "Whistles"
    case timers = "Timers"

    var id: String { rawValue }
}
