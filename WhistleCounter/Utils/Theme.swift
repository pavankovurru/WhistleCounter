import SwiftUI

enum WhistleTheme {
    static let sunny = Color(hex: 0xFFD93D)
    static let orange = Color(hex: 0xFF6B35)
    static let mint = Color(hex: 0x6BCB77)
    static let cream = Color(hex: 0xFFF8F0)
    static let charcoal = Color(hex: 0x2D2D2D)
    static let amber = Color(hex: 0xE8A045)
    static let darkNavy = Color(hex: 0x1A1A2E)
    static let rose = Color(hex: 0xFF9AC1)
    static let blue = Color(hex: 0x5BC0EB)

    static func background(dark: Bool) -> Color {
        dark ? darkNavy : cream
    }

    static func card(dark: Bool) -> Color {
        dark ? Color(hex: 0x252542) : .white
    }

    static func text(dark: Bool) -> Color {
        dark ? Color(hex: 0xFFE7C9) : charcoal
    }

    static func secondaryText(dark: Bool) -> Color {
        dark ? Color(hex: 0xC7B99F) : Color(hex: 0x8A7A6A)
    }

    static func shadow(dark: Bool) -> Color {
        dark ? .black.opacity(0.58) : Color(hex: 0x2D2D2D).opacity(0.22)
    }

    static func raisedShadow(dark: Bool) -> Color {
        dark ? .black.opacity(0.72) : Color(hex: 0x2D2D2D).opacity(0.30)
    }
}

enum CookbookPalette {
    private static let colors = [WhistleTheme.orange, Color.white, WhistleTheme.mint, WhistleTheme.charcoal, WhistleTheme.sunny]

    static func color(for index: Int) -> Color {
        colors[abs(index) % colors.count]
    }

    static func strokeColor(for index: Int) -> Color {
        switch abs(index) % colors.count {
        case 1:
            WhistleTheme.charcoal.opacity(0.16)
        case 3:
            .white.opacity(0.18)
        default:
            WhistleTheme.charcoal.opacity(0.12)
        }
    }

    static func color(for cookbook: Cookbook) -> Color {
        color(for: index(for: cookbook))
    }

    static func strokeColor(for cookbook: Cookbook) -> Color {
        strokeColor(for: index(for: cookbook))
    }

    private static func index(for cookbook: Cookbook) -> Int {
        switch cookbook.name.lowercased() {
        case "toor dal": 0
        case "rajma": 1
        case "soft eggs": 2
        case "chicken curry": 3
        default: abs(cookbook.name.hashValue)
        }
    }
}

enum HistoryPalette {
    static func color(for index: Int) -> Color {
        let colors = [WhistleTheme.orange, WhistleTheme.mint, WhistleTheme.cream, WhistleTheme.charcoal]
        return colors[abs(index) % colors.count]
    }

    static func strokeColor(for index: Int) -> Color {
        abs(index) % 4 == 3 ? .white.opacity(0.20) : WhistleTheme.charcoal.opacity(0.12)
    }

    static func foregroundColor(for index: Int) -> Color {
        abs(index) % 4 == 3 ? .white : WhistleTheme.charcoal
    }

    static func color(for session: CookingSession) -> Color {
        let colors = [WhistleTheme.orange, WhistleTheme.mint, WhistleTheme.cream, WhistleTheme.charcoal]
        return colors[index(for: session) % colors.count]
    }

    static func strokeColor(for session: CookingSession) -> Color {
        index(for: session) % 4 == 3 ? .white.opacity(0.20) : WhistleTheme.charcoal.opacity(0.12)
    }

    static func foregroundColor(for session: CookingSession) -> Color {
        index(for: session) % 4 == 3 ? .white : WhistleTheme.charcoal
    }

    private static func index(for session: CookingSession) -> Int {
        let total = session.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return total % 4
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension Color {
    func darkened(_ amount: Double) -> Color {
        mixed(with: .black, amount: amount)
    }

    func lightened(_ amount: Double) -> Color {
        mixed(with: .white, amount: amount)
    }

    func mixed(with other: Color, amount: Double) -> Color {
        let lhs = UIColor(self)
        let rhs = UIColor(other)
        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0
        var rr: CGFloat = 0
        var rg: CGFloat = 0
        var rb: CGFloat = 0
        var ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)

        let t = CGFloat(amount)
        return Color(
            red: Double(lr + (rr - lr) * t),
            green: Double(lg + (rg - lg) * t),
            blue: Double(lb + (rb - lb) * t),
            opacity: Double(la + (ra - la) * t)
        )
    }
}

extension Font {
    static func fredoka(_ size: CGFloat, weight: Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func nunito(_ size: CGFloat, weight: Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension TimeInterval {
    nonisolated var shortDurationText: String {
        let seconds = max(0, Int(self.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m"
        }
        return "\(secs)s"
    }

    nonisolated var clockText: String {
        let seconds = max(0, Int(self.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

extension Date {
    nonisolated var historyDateText: String {
        if Calendar.current.isDateInToday(self) {
            return "Today, " + formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        return formatted(date: .abbreviated, time: .omitted)
    }
}
