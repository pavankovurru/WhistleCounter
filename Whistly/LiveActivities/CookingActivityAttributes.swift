import ActivityKit
import Foundation

struct CookingActivityAttributes: ActivityAttributes {
    enum Mode: String, Codable, Hashable {
        case whistle
        case timer
    }

    struct ContentState: Codable, Hashable {
        var mode: Mode
        var title: String
        var status: String
        var count: Int
        var target: Int
        var startedAt: Date
        var endsAt: Date?
        var isFinished: Bool
    }

    var id: UUID
    var mode: Mode
}
