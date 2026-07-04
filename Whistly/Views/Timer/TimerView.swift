import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var settings: AppSettings
    // Owned by ContentView so the timer keeps running when this screen is closed.
    @ObservedObject var vm: TimerVM
    @State private var savedCookbookDuration: TimeInterval?
    @State private var startPulse = false
    @State private var showRunningTimerNotice = false
    private let cookbook: Cookbook?
    var onClose: () -> Void

    private let maxRingMinutes = 240

    init(settings: AppSettings, vm: TimerVM, cookbook: Cookbook?, onClose: @escaping () -> Void) {
        self.settings = settings
        self.vm = vm
        self.cookbook = cookbook
        self.onClose = onClose
    }

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }
    private var soundPack: SoundPack { SoundPack(rawValue: settings.soundPack) ?? .classic }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760
            let ringDiameter = ringSize(for: proxy.size, compact: compact)

            ZStack {
                PlayfulScreenBackground(dark: dark)

                VStack(spacing: 0) {
                    header

                    if showRunningTimerNotice {
                        runningTimerNotice
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 0) {
                        Spacer(minLength: compact ? 10 : 18)

                        timerStage(compact: compact, ringSize: ringDiameter)

                        Spacer(minLength: compact ? 12 : 20)

                        presetPills(compact: compact)

                        Spacer(minLength: compact ? 8 : 10)

                        primaryTimerButton(compact: compact)

                        Spacer()

                        saveCookbookTimerButton()

                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if vm.showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                }

                edgeSwipeBack
            }
        }
        .onAppear {
            if !vm.adopt(cookbook: cookbook) {
                showRunningTimerNotice = true
            }
            consumePendingCompletionLog()
        }
        .task(id: showRunningTimerNotice) {
            guard showRunningTimerNotice else { return }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.3)) {
                showRunningTimerNotice = false
            }
        }
        .onChange(of: vm.isDone) { _, isDone in
            if isDone {
                consumePendingCompletionLog()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                vm.refreshRemainingFromClock()
            }
        }
        .onDisappear {
            // The timer itself keeps running — only silence a ringing alarm.
            AudioPlayer.shared.stopAlarm()
        }
    }

    private var header: some View {
        FlowNavigationBar(
            title: "Kitchen Timer",
            dark: dark,
            haptics: settings.hapticsEnabled,
            onBack: onClose,
            onReset: { vm.reset() }
        )
    }

    private var runningTimerNotice: some View {
        Text("A timer is already running — pause or reset it to start \(cookbook?.name ?? "a new one").")
            .font(.nunito(12, weight: .black))
            .foregroundStyle(WhistleTheme.charcoal)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(WhistleTheme.sunny, in: Capsule())
            .padding(.horizontal, 22)
            .padding(.top, 6)
    }

    private var edgeSwipeBack: some View {
        HStack {
            Color.clear
                .frame(width: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .global)
                        .onEnded { value in
                            let isRightward = value.translation.width > 60
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                            if isRightward && isHorizontal {
                                onClose()
                            }
                        }
                )
            Spacer()
        }
        .ignoresSafeArea()
        .zIndex(99)
    }

    private func timerStage(compact: Bool, ringSize: CGFloat) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                InteractiveTimerRing(
                    progress: isCountdownActive ? countdownFillProgress : ringProgress,
                    totalProgress: isCountdownActive ? 1 : ringTotalProgress,
                    tint: vm.isDone ? WhistleTheme.orange : WhistleTheme.mint,
                    dark: dark,
                    isEnabled: !isCountdownActive,
                    isCountdownMode: isCountdownActive,
                    haptics: settings.hapticsEnabled,
                    maxMinutes: maxRingMinutes
                ) { duration in
                    vm.setDuration(duration)
                }
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(startPulse ? 1.025 : 1)

                VStack(spacing: compact ? 4 : 7) {
                    if !isCountdownActive {
                        WhistlyMascot(
                            state: .idle,
                            theme: MascotTheme.resolved(from: settings.mascotTheme),
                            size: compact ? 86 : 104,
                            showsSteamPuffs: false,
                            isAnimated: false
                        )
                        .frame(height: compact ? 76 : 92)
                    }

                    Text(vm.remaining.clockText)
                        .font(.fredoka(countdownTimeFontSize(compact: compact), weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)

                    Text(statusText)
                        .font(.fredoka(compact ? 13 : 15, weight: .black))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if isCountdownActive {
                        Text("\(Int((countdownFillProgress * 100).rounded()))% done")
                            .font(.nunito(compact ? 12 : 13, weight: .black))
                            .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                            .monospacedDigit()
                    }
                }
                .frame(width: ringSize * 0.66)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isCountdownActive)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: startPulse)

            Text(ringInstructionText)
                .font(.nunito(compact ? 14 : 16, weight: .black))
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

    private func primaryTimerButton(compact: Bool) -> some View {
        ChunkyButton(
            title: primaryButtonTitle,
            systemImage: primaryButtonIcon,
            color: primaryButtonColor,
            fontSize: 17,
            horizontalPadding: 18,
            verticalPadding: 14,
            cornerRadius: 24,
            fullWidth: true
        ) {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            if vm.isDone {
                vm.reset()
            } else {
                if !vm.isRunning {
                    triggerStartPulse()
                }
                vm.toggle(soundPack: soundPack, haptics: settings.hapticsEnabled)
            }
        }
        .padding(.horizontal, 38)
    }

    private func triggerStartPulse() {
        startPulse = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            startPulse = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.25)) {
                startPulse = false
            }
        }
    }

    private func saveCookbookTimerButton() -> some View {
        ChunkyButton(
            title: isCurrentTimerSaved ? "Saved!" : "Save to Cookbook",
            systemImage: isCurrentTimerSaved ? "checkmark" : "square.and.arrow.down.fill",
            color: isCurrentTimerSaved ? WhistleTheme.mint : WhistleTheme.sunny,
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

    // "Saved" tracks the exact duration, so changing the time re-arms the button
    // instead of silently ignoring every tap after the first.
    private var isCurrentTimerSaved: Bool {
        savedCookbookDuration == vm.totalDuration
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

    private var isCountdownActive: Bool {
        vm.isRunning || vm.isDone || vm.remaining < vm.totalDuration
    }

    private func countdownTimeFontSize(compact: Bool) -> CGFloat {
        isCountdownActive ? (compact ? 56 : 66) : (compact ? 45 : 56)
    }

    private var countdownFillProgress: Double {
        guard vm.totalDuration > 0 else { return 1 }
        return min(1, max(0, 1 - (vm.remaining / vm.totalDuration)))
    }

    // Current remaining mapped onto the max-ring scale — no jump on start/pause
    private var ringProgress: Double {
        vm.remaining / (Double(maxRingMinutes) * 60)
    }

    // The fixed "how much of the ring the user set" — stays constant while counting
    private var ringTotalProgress: Double {
        min(1, max(0.01, vm.totalDuration / (Double(maxRingMinutes) * 60)))
    }

    private var ringInstructionText: String {
        if vm.isDone { return "Alarm is playing" }
        if vm.isRunning { return "Ring fills as the timer runs" }
        if vm.remaining < vm.totalDuration { return "Paused with time saved" }
        return "Drag the ring to set your time"
    }

    private var statusText: String {
        if vm.isDone { return "Time's up" }
        if vm.isRunning { return "Cooking in progress" }
        if vm.remaining < vm.totalDuration { return "Paused" }
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
        return WhistleTheme.charcoal
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
        guard !isCurrentTimerSaved else { return }
        savedCookbookDuration = vm.totalDuration
        HapticManager.success(enabled: settings.hapticsEnabled)
        modelContext.insert(Cookbook(name: "Quick \(vm.totalDuration.shortDurationText)", timerDuration: vm.totalDuration, emoji: "⏱", createdAt: Date()))
    }

    private func consumePendingCompletionLog() {
        guard vm.needsCompletionLog else { return }
        vm.needsCompletionLog = false
        logTimer()
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
    var progress: Double           // remaining / maxRingDuration
    var totalProgress: Double      // totalDuration / maxRingDuration (fixed once started)
    var tint: Color
    var dark: Bool
    var isEnabled: Bool
    var isCountdownMode: Bool = false
    var haptics: Bool
    var maxMinutes: Int
    var onDurationChange: (TimeInterval) -> Void

    @State private var activeDrag = false
    @State private var lastHapticBucket: Int?
    @State private var dragFraction: Double = 0   // tracks raw drag angle for set-mode knob

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(20, size * 0.072)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = (size - lineWidth) / 2
            let clampedProgress = min(1, max(0, progress))
            let clampedTotal   = min(1, max(0.006, totalProgress))
            let arcStartFraction = 0.0
            let arcEndFraction = isCountdownMode ? clampedProgress : clampedTotal
            let knobFraction: Double = isCountdownMode
                ? clampedProgress
                : (activeDrag ? dragFraction : clampedTotal)
            let knobPoint = point(center: center, radius: radius, progress: knobFraction)
            let knobColor = isCountdownMode ? tint : WhistleTheme.orange

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

                    let arcStart = -90 + arcStartFraction * 360
                    let arcEnd   = -90 + arcEndFraction * 360

                    var ring = Path()
                    ring.addArc(
                        center: canvasCenter,
                        radius: canvasRadius,
                        startAngle: .degrees(arcStart),
                        endAngle: .degrees(arcEnd),
                        clockwise: false
                    )
                    context.stroke(
                        ring,
                        with: .color(tint),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                Circle()
                    .fill(knobColor.darkened(0.42).opacity(0.62))
                    .frame(width: lineWidth * 1.16, height: lineWidth * 1.16)
                    .position(x: knobPoint.x, y: knobPoint.y + (activeDrag ? 3 : 5))

                Circle()
                    .fill(knobColor)
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
        dragFraction = rawProgress   // keep knob following finger in set mode
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

struct CountdownFillCircle: View {
    var progress: Double
    var timeText: String
    var statusText: String
    var statusColor: Color
    var tint: Color
    var dark: Bool
    var compact: Bool
    var pulse: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let clamped = min(1, max(0, progress))
            let timerShape = TimerGlassShape()

            ZStack {
                timerShape
                    .fill(WhistleTheme.card(dark: dark))
                    .shadow(color: WhistleTheme.shadow(dark: dark), radius: 10, y: 5)

                timerShape
                    .stroke(tint.opacity(dark ? 0.42 : 0.30), lineWidth: max(8, size * 0.028))
                    .padding(size * 0.035)

                timerShape
                    .stroke(.white.opacity(dark ? 0.10 : 0.46), lineWidth: max(2, size * 0.008))
                    .padding(size * 0.065)

                Capsule(style: .continuous)
                    .fill(WhistleTheme.card(dark: dark))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(dark ? 0.48 : 0.34), lineWidth: max(5, size * 0.018))
                    }
                    .frame(width: size * 0.57, height: size * 0.12)
                    .offset(y: -size * 0.36)
                    .shadow(color: .black.opacity(dark ? 0.18 : 0.08), radius: 4, y: 2)

                GeometryReader { fillProxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [tint.lightened(0.14), tint],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: fillProxy.size.height * clamped)
                    }
                }
                .clipShape(timerShape)
                .padding(size * 0.085)
                .overlay {
                    timerShape
                        .stroke(tint.darkened(0.18).opacity(dark ? 0.22 : 0.18), lineWidth: 2)
                        .padding(size * 0.085)
                }

                timerShape
                    .stroke(tint.opacity(pulse ? 0.36 : 0), lineWidth: 5)
                    .scaleEffect(pulse ? 1.06 : 0.92)
                    .padding(size * 0.03)

                VStack(spacing: compact ? 7 : 9) {
                    Text(timeText)
                        .font(.fredoka(compact ? 48 : 58, weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)

                    Text(statusText)
                        .font(.fredoka(compact ? 13 : 15, weight: .black))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("\(Int((clamped * 100).rounded()))%")
                        .font(.nunito(compact ? 12 : 13, weight: .black))
                        .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                        .monospacedDigit()
                }
                .frame(width: size * 0.66)
            }
            .animation(.linear(duration: 0.35), value: progress)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: pulse)
        }
    }
}

private struct TimerGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.17))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.17),
            control1: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.07),
            control2: CGPoint(x: rect.minX + w * 0.66, y: rect.minY + h * 0.07)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.86),
            control1: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.38),
            control2: CGPoint(x: rect.minX + w * 0.81, y: rect.minY + h * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.95),
            control1: CGPoint(x: rect.minX + w * 0.69, y: rect.minY + h * 0.94),
            control2: CGPoint(x: rect.minX + w * 0.59, y: rect.minY + h * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.86),
            control1: CGPoint(x: rect.minX + w * 0.41, y: rect.minY + h * 0.95),
            control2: CGPoint(x: rect.minX + w * 0.31, y: rect.minY + h * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.17),
            control1: CGPoint(x: rect.minX + w * 0.19, y: rect.minY + h * 0.68),
            control2: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.38)
        )
        path.closeSubpath()

        return path
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
