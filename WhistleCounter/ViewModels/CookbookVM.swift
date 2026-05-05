import Combine
import Foundation
import SwiftData

@MainActor
final class CookbookVM: ObservableObject {
    func seedIfNeeded(cookbooks: [Cookbook], context: ModelContext) {
        if !cookbooks.isEmpty {
            normalizeDefaultCookbooks(cookbooks: cookbooks, context: context)
            return
        }

        [
            Cookbook(name: "Toor Dal", whistleTarget: 6, notes: "Soak 30 min. Salt at the end.", emoji: "🍛"),
            Cookbook(name: "Rajma", timerDuration: 30 * 60, notes: "Soak overnight.", emoji: "🫘"),
            Cookbook(name: "Soft Eggs", timerDuration: 6 * 60, notes: "Ice bath right after.", emoji: "🥚"),
            Cookbook(name: "Chicken Curry", timerDuration: 20 * 60, notes: "Marinate first.", emoji: "🍗")
        ].forEach(context.insert)
    }

    private func normalizeDefaultCookbooks(cookbooks: [Cookbook], context: ModelContext) {
        for cookbook in cookbooks {
            switch cookbook.name.lowercased() {
            case "toor dal":
                cookbook.whistleTarget = 6
                cookbook.timerDuration = nil
                cookbook.emoji = "🍛"
            case "rajma":
                cookbook.whistleTarget = nil
                cookbook.timerDuration = 30 * 60
                cookbook.emoji = "🫘"
            case "chicken curry":
                cookbook.whistleTarget = nil
                cookbook.timerDuration = 20 * 60
                cookbook.emoji = "🍗"
            case "khichdi", "kichindi":
                context.delete(cookbook)
            case "pasta", "lamb":
                context.delete(cookbook)
            default:
                if cookbook.whistleTarget != nil, cookbook.timerDuration != nil {
                    cookbook.timerDuration = nil
                }
                break
            }
        }
    }
}
