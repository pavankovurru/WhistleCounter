import ActivityKit
import WidgetKit
import SwiftUI

struct WhistlyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(WhistleLiveColor.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandStatusBadge(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    IslandCenterStatus(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    IslandMetric(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    IslandExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.mode.iconName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(WhistleLiveColor.orange)
            } compactTrailing: {
                CompactMetricText(state: context.state)
            } minimal: {
                Image(systemName: context.state.mode.iconName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(WhistleLiveColor.orange)
            }
            .keylineTint(WhistleLiveColor.orange)
        }
    }
}

private struct LockScreenActivityView: View {
    var state: CookingActivityAttributes.ContentState

    // Timer needs room for "1:23:45"; whistle needs room for "20/20"
    private var metricWidth: CGFloat { state.isTimer ? 116 : 72 }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ActivityIcon(mode: state.mode, isFinished: state.isFinished)

            // VStack expands to fill all remaining space between icon and metric
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(state.simpleStatus)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Explicit fixed width prevents Text(timerInterval:) from requesting
            // unbounded ideal width and collapsing the VStack to zero.
            lockScreenMetric
                .frame(width: metricWidth, alignment: .trailing)
                .padding(.trailing, state.isTimer ? 0 : 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var lockScreenMetric: some View {
        Group {
            if let range = state.countdownRange {
                Text(timerInterval: range, countsDown: true)
            } else {
                Text(state.primaryValue)
            }
        }
        .font(.system(size: state.isTimer ? 34 : 30, weight: .black, design: .rounded))
        .foregroundStyle(.primary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

private struct ActivityIcon: View {
    var mode: CookingActivityAttributes.Mode
    var isFinished: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill((isFinished ? WhistleLiveColor.mint : WhistleLiveColor.orange).opacity(0.18))
                .frame(width: 48, height: 48)
            Circle()
                .fill(isFinished ? WhistleLiveColor.mint : WhistleLiveColor.orange)
                .frame(width: 36, height: 36)
            Image(systemName: isFinished ? "checkmark" : mode.iconName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(mode == .timer && isFinished ? WhistleLiveColor.charcoal : .white)
        }
    }
}

private struct DeliveryStyleProgress: View {
    var state: CookingActivityAttributes.ContentState
    var height: CGFloat
    var showsPercent: Bool

    var body: some View {
        HStack(spacing: 9) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let clamped = min(1, max(0, state.progress))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WhistleLiveColor.track)
                    Capsule()
                        .fill(state.isFinished ? WhistleLiveColor.mint : WhistleLiveColor.orange)
                        .frame(width: max(height, width * clamped))
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(stepColor(index: index, progress: clamped))
                                .frame(width: height + 4, height: height + 4)
                            if index < 2 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .frame(height: height + 4)

            if showsPercent {
                Text(state.progressLabel)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(WhistleLiveColor.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private func stepColor(index: Int, progress: Double) -> Color {
        let threshold = Double(index) / 2.0
        if progress >= threshold || (index == 0 && progress > 0) {
            return state.isFinished ? WhistleLiveColor.mint : WhistleLiveColor.orange
        }
        return .white
    }
}

private struct IslandStatusBadge: View {
    var state: CookingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.mode.iconName)
                .font(.system(size: 13, weight: .black))
                .frame(width: 22, height: 22)
                .background(WhistleLiveColor.orange.opacity(0.20), in: Circle())
            Text(state.isTimer ? "Timer" : "Whistles")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(WhistleLiveColor.orange)
    }
}

private struct IslandCenterStatus: View {
    var state: CookingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 1) {
            Text(state.statusTitle)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(WhistleLiveColor.orange)
                .lineLimit(1)
            Text(state.simpleStatus)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }
}

private struct IslandMetric: View {
    var state: CookingActivityAttributes.ContentState

    var body: some View {
        LiveMetricText(state: state, color: .white, fontSize: 21)
    }
}

private struct LiveMetricText: View {
    var state: CookingActivityAttributes.ContentState
    var color: Color
    var fontSize: CGFloat

    var body: some View {
        Group {
            if let countdownRange = state.countdownRange {
                Text(timerInterval: countdownRange, countsDown: true)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(state.primaryValue)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .foregroundStyle(color)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .contentTransition(.numericText())
    }
}

private struct CompactMetricText: View {
    var state: CookingActivityAttributes.ContentState

    var body: some View {
        Group {
            if let countdownRange = state.countdownRange {
                Text(timerInterval: countdownRange, countsDown: true)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(state.primaryValue)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(.system(size: 12, weight: .black, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.58)
    }
}

private struct IslandExpandedBottom: View {
    var state: CookingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(state.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 6)

                if let countdownRange = state.countdownRange {
                    Text(timerInterval: countdownRange, countsDown: true)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WhistleLiveColor.mint)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text(state.progressLabel)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(WhistleLiveColor.mint)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.top, 2)
    }
}

private extension CookingActivityAttributes.ContentState {
    var isTimer: Bool { mode == .timer }

    var progress: Double {
        guard target > 0 else { return 0 }
        if mode == .timer {
            return min(1, max(0, Double(target - count) / Double(target)))
        }
        return min(1, max(0, Double(count) / Double(target)))
    }

    var progressLabel: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var statusTitle: String {
        if isFinished {
            return "Ready"
        }
        return isTimer ? "Cooking timer" : "Pressure cooker"
    }

    var metricCaption: String {
        if isTimer {
            return isFinished ? "done" : "remaining"
        }
        return "\(remainingWhistles) left"
    }

    var secondaryValue: String {
        if isTimer {
            return isFinished ? "done" : "remaining"
        }
        return "\(remainingWhistles) left"
    }

    var detailLine: String {
        if isTimer {
            return isFinished ? "Timer finished" : "Time remaining"
        }
        return "\(count) counted, \(remainingWhistles) remaining"
    }

    var simpleStatus: String {
        if isTimer {
            return isFinished ? "Done" : "Running"
        }
        return "\(remainingWhistles) more"
    }

    var remainingWhistles: Int {
        max(0, target - count)
    }

    var shouldRenderLiveCountdown: Bool {
        guard isTimer, !isFinished, let endsAt else { return false }
        return endsAt.timeIntervalSinceNow > 1
    }

    var countdownRange: ClosedRange<Date>? {
        guard shouldRenderLiveCountdown, let endsAt else { return nil }
        // Text(timerInterval:) needs the range to start at NOW, not at startedAt —
        // using startedAt as the lower bound causes the countdown text to render blank.
        return Date.now...endsAt
    }

    var primaryValue: String {
        if mode == .timer {
            let seconds = max(0, count)
            let minutes = seconds / 60
            let hours = minutes / 60
            let remainder = seconds % 60
            if hours > 0 {
                return String(format: "%d:%02d", hours, minutes % 60)
            }
            return String(format: "%d:%02d", minutes, remainder)
        }
        return "\(count)/\(target)"
    }

    var shortTimerValue: String {
        let seconds = max(0, count)
        if seconds >= 3600 {
            return "\(Int(ceil(Double(seconds) / 3600.0)))h"
        }
        if seconds >= 60 {
            return "\(Int(ceil(Double(seconds) / 60.0)))m"
        }
        return "\(seconds)s"
    }
}

private extension CookingActivityAttributes.Mode {
    var iconName: String {
        switch self {
        case .whistle: "waveform"
        case .timer: "timer"
        }
    }
}

private enum WhistleLiveColor {
    static let sunny = Color(hex: 0xFFD93D)
    static let orange = Color(hex: 0xFF6B35)
    static let mint = Color(hex: 0x6BCB77)
    static let cream = Color(hex: 0xFFF8F0)
    static let charcoal = Color(hex: 0x2D2D2D)
    static let secondary = Color(hex: 0x8A7A6A)
    static let track = Color(hex: 0xF1DDC9)
}

private extension Color {
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
