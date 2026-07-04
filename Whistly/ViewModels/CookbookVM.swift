import Combine
import Foundation
import SwiftData

@MainActor
final class CookbookVM: ObservableObject {
    private static let didNormalizeKey = "didNormalizeDefaultCookbooksV1"
    private static let didFixIdlyEmojiKey = "didFixIdlyEmojiV1"

    func seedIfNeeded(cookbooks: [Cookbook], context: ModelContext) {
        fixLegacyIdlyEmoji(context: context)
        if !cookbooks.isEmpty {
            // One-shot migration of the originally seeded cookbooks. It matches by
            // name, so running it repeatedly would overwrite the user's edits and
            // delete user-created cookbooks that happen to share those names.
            guard !UserDefaults.standard.bool(forKey: Self.didNormalizeKey) else { return }
            UserDefaults.standard.set(true, forKey: Self.didNormalizeKey)
            normalizeDefaultCookbooks(cookbooks: cookbooks, context: context)
            return
        }

        UserDefaults.standard.set(true, forKey: Self.didNormalizeKey)
        [
            Cookbook(name: "Toor Dal", whistleTarget: 6, notes: "Soak 30 min. Salt at the end.", emoji: "🍛"),
            Cookbook(name: "Rajma", whistleTarget: 6, notes: "Soak overnight.", emoji: "🫘"),
            Cookbook(name: "Eggs", timerDuration: 6 * 60, notes: "Ice bath right after.", emoji: "🥚"),
            Cookbook(name: "Chicken", timerDuration: 20 * 60, notes: "Marinate first.", emoji: "🍗"),
            Cookbook(name: "Idly", timerDuration: 10 * 60, notes: "Steam until soft.", emoji: "🍚")
        ].forEach(context.insert)
    }

    // Early builds stored the literal text "idly" in the emoji field; it rendered
    // as a word wherever the emoji shows, including old History rows.
    private func fixLegacyIdlyEmoji(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: Self.didFixIdlyEmojiKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.didFixIdlyEmojiKey)
        let sessions = (try? context.fetch(FetchDescriptor<CookingSession>())) ?? []
        for session in sessions where session.emoji == "idly" {
            session.emoji = "🍚"
        }
        let books = (try? context.fetch(FetchDescriptor<Cookbook>())) ?? []
        for book in books where book.emoji == "idly" {
            book.emoji = "🍚"
        }
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
                cookbook.emoji = "🍚"
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
            context.insert(Cookbook(name: "Idly", timerDuration: 10 * 60, notes: "Steam until soft.", emoji: "🍚"))
        }
    }
}
