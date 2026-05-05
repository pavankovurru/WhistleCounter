import Combine
import Foundation
import SwiftData

@MainActor
final class HistoryVM: ObservableObject {
    func logWhistles(cookbook: Cookbook?, target: Int, count: Int, context: ModelContext) {
        context.insert(CookingSession(
            cookbookName: cookbook?.name,
            emoji: cookbook?.emoji ?? "🎙",
            whistleCount: count,
            targetWhistles: target,
            timerDuration: cookbook?.timerDuration,
            reaction: count >= target ? "Ready" : "Stopped"
        ))
        cookbook?.lastUsedAt = Date()
    }

    func logTimer(cookbook: Cookbook?, duration: TimeInterval, context: ModelContext) {
        context.insert(CookingSession(
            cookbookName: cookbook?.name,
            emoji: cookbook?.emoji ?? "⏱",
            timerDuration: duration,
            reaction: "Timed"
        ))
        cookbook?.lastUsedAt = Date()
    }
}
