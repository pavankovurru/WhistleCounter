import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    @StateObject private var vm: TimerVM
    @State private var didLogCompletion = false
    var onClose: () -> Void

    private let maxRingMinutes = 180

    init(settings: AppSettings, cookbook: Cookbook?, onClose: @escaping () -> Void) {
        self.settings = settings
        self.onClose = onClose
        _vm = StateObject(wrappedValue: TimerVM(cookbook: cookbook))
    }

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }
    private var soundPack: SoundPack { SoundPack(rawValue: settings.soundPack) ?? .classic }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760
            let ringDiameter = ringSize(for: proxy.size, compact: compact)

            ZStack {
                WhistleTheme.background(dark: dark)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    VStack(spacing: 0) {
                        Spacer(minLength: compact ? 10 : 18)

                        timerStage(compact: compact, ringSize: ringDiameter)

                        Spacer(minLength: compact ? 12 : 20)

                        presetPills(compact: compact)

                        Spacer(minLength: compact ? 14 : 22)

                        actionButtons(compact: compact)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if vm.showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                }
            }
        }
        .onChange(of: vm.isDone) { _, isDone in
            if isDone, !didLogCompletion {
                logTimer()
                didLogCompletion = true
            } else if !isDone {
                didLogCompletion = false
            }
        }
        .onDisappear {
            AudioPlayer.shared.stopAlarm()
            vm.pause()
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(WhistleTheme.text(dark: dark))
                    .background {
                        Circle()
                            .fill(WhistleTheme.card(dark: dark))
                            .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Kitchen Timer")
                .font(.fredoka(20, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))

            Spacer()

            Button {
                HapticManager.tap(enabled: settings.hapticsEnabled)
                vm.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(WhistleTheme.text(dark: dark))
                    .background {
                        Circle()
                            .fill(WhistleTheme.card(dark: dark))
                            .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 0)
        .padding(.bottom, 8)
        .offset(y: -10)
        .zIndex(2)
    }

    private func timerStage(compact: Bool, ringSize: CGFloat) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                InteractiveTimerRing(
                    progress: ringProgress,
                    tint: WhistleTheme.mint,
                    dark: dark,
                    isEnabled: !vm.isRunning && !vm.isDone,
                    haptics: settings.hapticsEnabled,
                    maxMinutes: maxRingMinutes
                ) { duration in
                    vm.setDuration(duration)
                }
                .frame(width: ringSize, height: ringSize)

                VStack(spacing: compact ? 4 : 7) {
                    WhistlyMascot(
                        state: vm.isDone ? .shocked : (vm.isRunning ? .sleeping : .idle),
                        theme: MascotTheme.resolved(from: settings.mascotTheme),
                        size: compact ? 86 : 104,
                        showsSteamPuffs: false
                    )
                    .frame(height: compact ? 76 : 92)

                    Text(vm.remaining.clockText)
                        .font(.fredoka(compact ? 45 : 56, weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text(statusText)
                        .font(.fredoka(compact ? 13 : 15, weight: .black))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(width: ringSize * 0.66)
            }

            Text(ringInstructionText)
                .font(.nunito(compact ? 12 : 13, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
    }

    private func durationWheels(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "dial.medium.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
                    .background(WhistleTheme.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Set Time")
                    .font(.fredoka(compact ? 17 : 19, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))

                Spacer()

                Text(vm.totalDuration.shortDurationText)
                    .font(.nunito(compact ? 12 : 13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .lineLimit(1)
            }

            HStack(spacing: compact ? 7 : 9) {
                TimerWheelColumn(title: "Hour", value: hoursBinding, range: 0...12, tint: WhistleTheme.orange, dark: dark, haptics: settings.hapticsEnabled, isEnabled: !vm.isRunning, compact: compact)
                TimerWheelColumn(title: "Minute", value: minutesBinding, range: 0...59, tint: WhistleTheme.mint, dark: dark, haptics: settings.hapticsEnabled, isEnabled: !vm.isRunning, compact: compact)
                TimerWheelColumn(title: "Second", value: secondsBinding, range: 0...59, tint: WhistleTheme.sunny, dark: dark, haptics: settings.hapticsEnabled, isEnabled: !vm.isRunning, compact: compact)
            }
        }
    }

    private func presetPills(compact: Bool) -> some View {
        let presets: [(String, String, TimeInterval, Color)] = [
            ("2 min", "☕", 2 * 60, WhistleTheme.mint),
            ("15 min", "🥚", 15 * 60, WhistleTheme.sunny),
            ("30 min", "🍗", 30 * 60, WhistleTheme.orange),
            ("1 hr", "🍖", 60 * 60, WhistleTheme.charcoal)
        ]

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 28, height: 28)
                    .background(WhistleTheme.sunny, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Quick starts")
                    .font(.fredoka(compact ? 14 : 16, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.0) { preset in
                    Button {
                        guard !vm.isRunning else { return }
                        HapticManager.tap(enabled: settings.hapticsEnabled)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                            vm.setDuration(preset.2)
                        }
                    } label: {
                        let active = vm.totalDuration == preset.2
                        Text("\(preset.1) \(preset.0)")
                            .font(.fredoka(12, weight: .black))
                            .foregroundStyle(presetTextColor(color: preset.3, active: active))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, compact ? 9 : 11)
                            .background {
                                let fill = active ? preset.3 : WhistleTheme.card(dark: dark)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(active ? fill.darkened(0.42).opacity(0.68) : WhistleTheme.shadow(dark: dark))
                                        .offset(y: active ? 3 : 1.5)
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(fill)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .opacity(vm.isRunning ? 0.56 : 1)
                }
            }
        }
    }

    private func actionButtons(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 12) {
            ChunkyButton(
                title: primaryButtonTitle,
                systemImage: primaryButtonIcon,
                color: primaryButtonColor,
                fontSize: compact ? 16 : 18,
                horizontalPadding: 18,
                verticalPadding: compact ? 13 : 16,
                cornerRadius: 26,
                fullWidth: true
            ) {
                HapticManager.tap(enabled: settings.hapticsEnabled)
                if vm.isDone {
                    vm.reset()
                } else {
                    vm.toggle(soundPack: soundPack, haptics: settings.hapticsEnabled)
                }
            }

            ChunkyButton(
                title: "Save to Cookbook",
                systemImage: "square.and.arrow.down.fill",
                color: WhistleTheme.sunny,
                fontSize: 17,
                horizontalPadding: 18,
                verticalPadding: 14,
                cornerRadius: 24
            ) {
                saveTimer()
            }
            .frame(maxWidth: 235)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func presetTextColor(color: Color, active: Bool) -> Color {
        if active {
            return color == WhistleTheme.charcoal || color == WhistleTheme.orange ? .white : WhistleTheme.charcoal
        }
        return WhistleTheme.text(dark: dark)
    }

    private func ringSize(for size: CGSize, compact: Bool) -> CGFloat {
        let widthBased = size.width - 46
        let heightBased = size.height * (compact ? 0.40 : 0.43)
        return min(compact ? 306 : 352, max(compact ? 268 : 314, min(widthBased, heightBased)))
    }

    private var ringProgress: Double {
        if vm.isRunning || vm.isDone {
            return vm.progress
        }
        let minutes = max(1, vm.totalDuration / 60)
        return min(1, max(0.01, minutes / Double(maxRingMinutes)))
    }

    private var ringInstructionText: String {
        if vm.isDone {
            return "Alarm is playing"
        }
        if vm.isRunning {
            return "Timer is running"
        }
        return "Drag the mint ring to set minutes"
    }

    private var statusText: String {
        if vm.isDone {
            return "Time's up"
        }
        if vm.isRunning {
            return "Cooking in progress"
        }
        return "Ready when you are"
    }

    private var statusColor: Color {
        if vm.isDone {
            return WhistleTheme.orange
        }
        if vm.isRunning {
            return WhistleTheme.mint
        }
        return WhistleTheme.secondaryText(dark: dark)
    }

    private var primaryButtonTitle: String {
        if vm.isRunning {
            return "Pause Timer"
        }
        if vm.isDone {
            return "Stop Sound"
        }
        return "Start Timer"
    }

    private var primaryButtonIcon: String {
        if vm.isRunning {
            return "pause.fill"
        }
        if vm.isDone {
            return "speaker.slash.fill"
        }
        return "play.fill"
    }

    private var primaryButtonColor: Color {
        if vm.isRunning || vm.isDone {
            return WhistleTheme.orange
        }
        return WhistleTheme.mint
    }

    private var hoursBinding: Binding<Int> {
        Binding {
            Int(vm.totalDuration) / 3600
        } set: { newHours in
            updateDuration(hours: newHours)
        }
    }

    private var minutesBinding: Binding<Int> {
        Binding {
            (Int(vm.totalDuration) % 3600) / 60
        } set: { newMinutes in
            updateDuration(minutes: newMinutes)
        }
    }

    private var secondsBinding: Binding<Int> {
        Binding {
            Int(vm.totalDuration) % 60
        } set: { newSeconds in
            updateDuration(seconds: newSeconds)
        }
    }

    private func updateDuration(hours: Int? = nil, minutes: Int? = nil, seconds: Int? = nil) {
        guard !vm.isRunning else { return }
        let total = Int(vm.totalDuration)
        let h = hours ?? total / 3600
        let m = minutes ?? (total % 3600) / 60
        let s = seconds ?? total % 60
        vm.setDuration(TimeInterval(max(1, h * 3600 + m * 60 + s)))
    }

    private func saveTimer() {
        HapticManager.success(enabled: settings.hapticsEnabled)
        modelContext.insert(Cookbook(name: "Quick \(vm.totalDuration.shortDurationText)", timerDuration: vm.totalDuration, emoji: "⏱", createdAt: Date()))
    }

    private func logTimer() {
        modelContext.insert(CookingSession(
            cookbookName: vm.sourceCookbook?.name,
            emoji: vm.sourceCookbook?.emoji ?? "⏱",
            timerDuration: vm.totalDuration,
            reaction: "Timed"
        ))
        vm.sourceCookbook?.lastUsedAt = Date()
    }
}

struct InteractiveTimerRing: View {
    var progress: Double
    var tint: Color
    var dark: Bool
    var isEnabled: Bool
    var haptics: Bool
    var maxMinutes: Int
    var onDurationChange: (TimeInterval) -> Void

    @State private var activeDrag = false
    @State private var lastHapticBucket: Int?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(20, size * 0.072)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = (size - lineWidth) / 2
            let clampedProgress = min(1, max(0.006, progress))
            let knobPoint = point(center: center, radius: radius, progress: clampedProgress)

            ZStack {
                ForEach(0..<24, id: \.self) { index in
                    let tickProgress = Double(index) / 24.0
                    let tick = point(center: center, radius: radius, progress: tickProgress)
                    Circle()
                        .fill(tickColor(for: index))
                        .frame(width: index.isMultiple(of: 6) ? 7 : 4, height: index.isMultiple(of: 6) ? 7 : 4)
                        .position(tick)
                }

                Canvas { context, canvasSize in
                    let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let canvasRadius = (min(canvasSize.width, canvasSize.height) - lineWidth) / 2

                    var track = Path()
                    track.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                    context.stroke(
                        track,
                        with: .color(dark ? tint.opacity(0.22) : tint.opacity(0.20)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                    var ring = Path()
                    ring.addArc(
                        center: canvasCenter,
                        radius: canvasRadius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * clampedProgress),
                        clockwise: false
                    )
                    context.stroke(
                        ring,
                        with: .color(tint),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                Circle()
                    .fill(WhistleTheme.orange.darkened(0.42).opacity(0.62))
                    .frame(width: lineWidth * 1.16, height: lineWidth * 1.16)
                    .position(x: knobPoint.x, y: knobPoint.y + (activeDrag ? 3 : 5))

                Circle()
                    .fill(WhistleTheme.orange)
                    .frame(width: lineWidth * 1.16, height: lineWidth * 1.16)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.32))
                            .frame(width: lineWidth * 0.42, height: lineWidth * 0.42)
                            .offset(x: -lineWidth * 0.14, y: -lineWidth * 0.14)
                    }
                    .position(knobPoint)
                    .scaleEffect(activeDrag ? 1.08 : 1)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        activeDrag = true
                        updateDuration(from: value.location, center: center)
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        activeDrag = false
                        lastHapticBucket = nil
                        HapticManager.tap(enabled: haptics)
                    }
            )
            .opacity(isEnabled ? 1 : 0.92)
            .animation(.spring(response: 0.26, dampingFraction: 0.74), value: activeDrag)
            .animation(.linear(duration: 0.25), value: progress)
        }
    }

    private func updateDuration(from location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) + (.pi / 2)
        if angle < 0 {
            angle += 2 * .pi
        }

        let rawProgress = angle / (2 * .pi)
        let minutes = min(maxMinutes, max(1, Int((rawProgress * Double(maxMinutes)).rounded())))
        onDurationChange(TimeInterval(minutes * 60))

        let hapticBucket = minutes / 5
        if hapticBucket != lastHapticBucket {
            lastHapticBucket = hapticBucket
            HapticManager.selection(enabled: haptics)
        }
    }

    private func point(center: CGPoint, radius: CGFloat, progress: Double) -> CGPoint {
        let angle = (-90 + 360 * progress) * .pi / 180
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    private func tickColor(for index: Int) -> Color {
        if index.isMultiple(of: 6) {
            return WhistleTheme.orange.opacity(dark ? 0.90 : 0.82)
        }
        return WhistleTheme.mint.opacity(dark ? 0.38 : 0.34)
    }
}

struct TimerWheelColumn: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var tint: Color
    var dark: Bool
    var haptics: Bool
    var isEnabled: Bool
    var compact: Bool = false

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            Text(title)
                .font(.nunito(compact ? 10 : 11, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                wheelStepButton(systemImage: "chevron.up") {
                    adjust(by: 1)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(tint.darkened(0.42).opacity(0.70))
                        .offset(y: 3)
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(tint)

                    VStack(spacing: 0) {
                        Text(formatted(previousValue))
                            .font(.fredoka(compact ? 14 : 17, weight: .black))
                            .foregroundStyle(wheelForeground.opacity(0.42))
                            .frame(height: compact ? 21 : 26)
                        Text(formatted(value))
                            .font(.fredoka(compact ? 28 : 34, weight: .black))
                            .foregroundStyle(wheelForeground)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(height: compact ? 35 : 42)
                        Text(formatted(nextValue))
                            .font(.fredoka(compact ? 14 : 17, weight: .black))
                            .foregroundStyle(wheelForeground.opacity(0.42))
                            .frame(height: compact ? 21 : 26)
                    }
                    .offset(y: dragOffset * 0.18)
                }
                .frame(height: compact ? 88 : 106)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            dragOffset = max(-40, min(40, gesture.translation.height))
                        }
                        .onEnded { gesture in
                            guard isEnabled else { return }
                            if gesture.translation.height < -18 {
                                adjust(by: 1)
                            } else if gesture.translation.height > 18 {
                                adjust(by: -1)
                            }
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.74)) {
                                dragOffset = 0
                            }
                        }
                )

                wheelStepButton(systemImage: "chevron.down") {
                    adjust(by: -1)
                }
            }
            .opacity(isEnabled ? 1 : 0.62)
        }
    }

    private func wheelStepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 10 : 12, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 22 : 28)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var wheelForeground: Color {
        tint == WhistleTheme.orange || tint == WhistleTheme.charcoal ? .white : WhistleTheme.charcoal
    }

    private var previousValue: Int {
        value == range.lowerBound ? range.upperBound : value - 1
    }

    private var nextValue: Int {
        value == range.upperBound ? range.lowerBound : value + 1
    }

    private func adjust(by delta: Int) {
        guard isEnabled else { return }
        HapticManager.tap(enabled: haptics)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
            let next = value + delta
            if next > range.upperBound {
                value = range.lowerBound
            } else if next < range.lowerBound {
                value = range.upperBound
            } else {
                value = next
            }
        }
    }

    private func formatted(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

struct CircularTimerRing: View {
    var progress: Double
    var tint: Color
    var dark: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
            let lineWidth: CGFloat = 18
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(rect.width, rect.height) / 2

            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(track, with: .color(dark ? tint.opacity(0.20) : tint.opacity(0.18)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            var ring = Path()
            ring.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
            context.stroke(ring, with: .color(tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .animation(.linear(duration: 0.35), value: progress)
    }
}
