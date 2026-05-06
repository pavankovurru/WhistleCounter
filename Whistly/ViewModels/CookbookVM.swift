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
            Cookbook(name: "Rajma", whistleTarget: 6, notes: "Soak overnight.", emoji: "🫘"),
            Cookbook(name: "Eggs", timerDuration: 6 * 60, notes: "Ice bath right after.", emoji: "🥚"),
            Cookbook(name: "Chicken", timerDuration: 20 * 60, notes: "Marinate first.", emoji: "🍗"),
            Cookbook(name: "Idly", timerDuration: 10 * 60, notes: "Steam until soft.", emoji: "idly")
        ].forEach(context.insert)
    }

    private func normalizeDefaultCookbooks(cookbooks: [Cookbook], context: ModelContext) {
        var hasIdly = false
        for cookbook in cookbooks {
            switch cookbook.name.lowercased() {
            case "toor dal":
                cookbook.whistleTarget = 6
                cookbook.timerDuration = nil
                cookbook.emoji = "🍛"
            case "rajma":
                cookbook.whistleTarget = 6
                cookbook.timerDuration = nil
                cookbook.emoji = "🫘"
            case "soft eggs":
                cookbook.name = "Eggs"
                cookbook.timerDuration = 6 * 60
                cookbook.whistleTarget = nil
                cookbook.emoji = "🥚"
            case "eggs":
                cookbook.timerDuration = 6 * 60
                cookbook.whistleTarget = nil
                cookbook.emoji = "🥚"
            case "chicken curry":
                cookbook.name = "Chicken"
                cookbook.whistleTarget = nil
                cookbook.timerDuration = 20 * 60
                cookbook.emoji = "🍗"
            case "chicken":
                cookbook.whistleTarget = nil
                cookbook.timerDuration = 20 * 60
                cookbook.emoji = "🍗"
            case "idly":
                hasIdly = true
                cookbook.whistleTarget = nil
                cookbook.timerDuration = 10 * 60
                cookbook.emoji = "idly"
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
        if !hasIdly {
            context.insert(Cookbook(name: "Idly", timerDuration: 10 * 60, notes: "Steam until soft.", emoji: "idly"))
        }
    }
}
