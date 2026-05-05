import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    @StateObject private var vm: TimerVM
    @State private var didLogCompletion = false
    var onClose: () -> Void

    init(settings: AppSettings, cookbook: Cookbook?, onClose: @escaping () -> Void) {
        self.settings = settings
        self.onClose = onClose
        _vm = StateObject(wrappedValue: TimerVM(cookbook: cookbook))
    }

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }
    private var soundPack: SoundPack { SoundPack(rawValue: settings.soundPack) ?? .classic }

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)
                .ignoresSafeArea()

            Circle()
                .fill(WhistleTheme.mint.opacity(0.26))
                .frame(width: 300)
                .blur(radius: 20)
                .offset(y: -270)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 10)

                ZStack {
                    CircularTimerRing(progress: vm.progress, tint: WhistleTheme.mint)
                        .frame(width: 282, height: 282)

                    VStack(spacing: 0) {
                        WhistlyMascot(
                            state: vm.isDone ? .shocked : (vm.isRunning ? .sleeping : .idle),
                            theme: MascotTheme.resolved(from: settings.mascotTheme),
                            size: 106
                        )
                        .frame(height: 104)

                        Text(vm.remaining.clockText)
                            .font(.fredoka(50, weight: .black))
                            .foregroundStyle(WhistleTheme.text(dark: dark))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text(vm.isDone ? "Time's up" : vm.isRunning ? "Timer running" : "Tap to start")
                            .font(.fredoka(14, weight: .bold))
                            .foregroundStyle(vm.isDone ? WhistleTheme.orange : WhistleTheme.mint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(width: 190)
                    }
                }
                .frame(maxWidth: .infinity)

                timeControls
                    .padding(.top, 20)

                presetPills
                    .padding(.top, 14)

                ChunkyButton(
                    title: vm.isRunning ? "Pause" : (vm.isDone ? "Stop Alarm" : "Start"),
                    systemImage: vm.isRunning ? "pause.fill" : (vm.isDone ? "stop.fill" : "play.fill"),
                    color: vm.isRunning ? WhistleTheme.orange : WhistleTheme.mint
                ) {
                    HapticManager.tap(enabled: settings.hapticsEnabled)
                    if vm.isDone {
                        vm.reset()
                    } else {
                        vm.toggle(soundPack: soundPack, haptics: settings.hapticsEnabled)
                    }
                }
                .frame(maxWidth: 210)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 18)

                Spacer(minLength: 18)

                ChunkyButton(title: "Save to Cookbook", systemImage: "square.and.arrow.down.fill", color: WhistleTheme.sunny) {
                    saveTimer()
                }
                .frame(maxWidth: 235)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 28)
            }

            if vm.showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
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
        .padding(.top, 10)
    }

    private var timeControls: some View {
        HStack(spacing: 8) {
            durationStepper(title: "Hour", value: hoursBinding, range: 0...12)
            durationStepper(title: "Minute", value: minutesBinding, range: 0...59)
            durationStepper(title: "Second", value: secondsBinding, range: 0...59)
        }
        .padding(.horizontal, 22)
    }

    private var presetPills: some View {
        let presets: [(String, String, TimeInterval)] = [
            ("5 min", "☕", 5 * 60),
            ("15 min", "🥚", 15 * 60),
            ("30 min", "🍗", 30 * 60),
            ("1 hr", "🍖", 60 * 60)
        ]

        return HStack(spacing: 8) {
            ForEach(presets, id: \.0) { preset in
                Button {
                    HapticManager.tap(enabled: settings.hapticsEnabled)
                    vm.setDuration(preset.2)
                } label: {
                    Text("\(preset.1) \(preset.0)")
                        .font(.fredoka(13, weight: .bold))
                        .foregroundStyle(WhistleTheme.charcoal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            let fill = vm.totalDuration == preset.2 ? WhistleTheme.sunny : .white
                            ZStack {
                                Capsule()
                                    .fill(vm.totalDuration == preset.2 ? fill.darkened(0.38).opacity(0.66) : WhistleTheme.shadow(dark: dark))
                                    .offset(y: vm.totalDuration == preset.2 ? 3 : 2)
                                Capsule()
                                    .fill(fill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func durationStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.nunito(12, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 5) {
                Button {
                    HapticManager.tap(enabled: settings.hapticsEnabled)
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus")
                }
                Text("\(value.wrappedValue)")
                    .font(.fredoka(20, weight: .black))
                    .monospacedDigit()
                    .frame(minWidth: 28)
                Button {
                    HapticManager.tap(enabled: settings.hapticsEnabled)
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus")
                }
            }
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(WhistleTheme.charcoal)
            .padding(.horizontal, 9)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(WhistleTheme.mint.darkened(0.42).opacity(0.72))
                        .offset(y: 3)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(WhistleTheme.mint)
                }
            }
        }
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

struct CircularTimerRing: View {
    var progress: Double
    var tint: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
            let lineWidth: CGFloat = 18
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(rect.width, rect.height) / 2

            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(track, with: .color(tint.opacity(0.15)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            var ring = Path()
            ring.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
            context.stroke(ring, with: .color(WhistleTheme.mint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .animation(.linear(duration: 0.35), value: progress)
    }
}
