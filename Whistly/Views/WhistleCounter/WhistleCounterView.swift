import SwiftData
import SwiftUI

struct WhistlyCounterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    @StateObject private var vm: WhistlyCounterVM
    @State private var didLogCompletion = false
    @State private var didSaveCookbook = false
    @ObservedObject private var audioPlayer = AudioPlayer.shared
    var onClose: () -> Void
    var onStartLinkedTimer: (Cookbook) -> Void

    init(settings: AppSettings, cookbook: Cookbook?, onClose: @escaping () -> Void, onStartLinkedTimer: @escaping (Cookbook) -> Void) {
        self.settings = settings
        self.onClose = onClose
        self.onStartLinkedTimer = onStartLinkedTimer
        _vm = StateObject(wrappedValue: WhistlyCounterVM(cookbook: cookbook))
    }

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }
    private var sensitivity: WhistleSensitivity { WhistleSensitivity(rawValue: settings.sensitivity) ?? .medium }
    private var soundPack: SoundPack { SoundPack(rawValue: settings.soundPack) ?? .classic }
    private var countGapSeconds: TimeInterval { settings.resolvedWhistleCountGapSeconds }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PlayfulScreenBackground(dark: dark)

                VStack(spacing: 0) {
                    header

                    Spacer().frame(maxHeight: 32)

                    VStack(spacing: 20) {
                        SlotPickerView(title: "Target", value: targetBinding, range: 1...100, suffix: "whistles", tint: WhistleTheme.orange, haptics: settings.hapticsEnabled)

                        VStack(spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(vm.count)")
                                    .font(.fredoka(156, weight: .black))
                                    .foregroundStyle(WhistleTheme.text(dark: dark))
                                    .contentTransition(.numericText())
                                    .minimumScaleFactor(0.72)
                                Text("/\(vm.target)")
                                    .font(.fredoka(48, weight: .black))
                                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                            }
                            .animation(.spring(response: 0.28, dampingFraction: 0.52), value: vm.count)

                            WhistleMilestoneLabel(text: vm.milestone)
                        }

                        WhistlyMascot(
                            state: vm.mascotState,
                            theme: MascotTheme.resolved(from: settings.mascotTheme),
                            size: 174,
                            showsSteamPuffs: true,
                            isAnimated: true,
                            keepsBodyPosition: true,
                            steamBaseY: 58
                        )
                        .frame(height: 174)

                        ChunkyButton(
                            title: listeningButtonTitle,
                            systemImage: listeningButtonIcon,
                            color: listeningButtonColor,
                            fontSize: 17,
                            fullWidth: true,
                            activeGlow: vm.detector.isListening && !audioPlayer.isAlarmPlaying,
                            minTitleWidth: 132,
                            iconWidth: 20
                        ) {
                            HapticManager.tap(enabled: settings.hapticsEnabled)
                            if audioPlayer.isAlarmPlaying {
                                AudioPlayer.shared.stopAlarm()
                            } else if vm.count >= vm.target {
                                return
                            } else {
                                vm.toggleListening(sensitivity: sensitivity, countGapSeconds: countGapSeconds)
                            }
                        }
                        .padding(.horizontal, 38)

                        detectorStatus

                        ChunkyButton(title: "Save to Cookbook", systemImage: "square.and.arrow.down.fill", color: WhistleTheme.sunny) {
                            saveSetup()
                        }
                        .frame(maxWidth: 235)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                if vm.showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                }

                edgeSwipeBack
            }
        }
        .onChange(of: vm.showReadyPopup) { _, showing in
            if showing {
                if !didLogCompletion {
                    logSession()
                    didLogCompletion = true
                }
                AudioPlayer.shared.playAlarm(pack: soundPack)
                HapticManager.celebration(enabled: settings.hapticsEnabled)
            }
        }
        .onChange(of: vm.count) { _, newCount in
            if newCount == 0 {
                didLogCompletion = false
            }
        }
        .onChange(of: sensitivity) { _, newSensitivity in
            vm.detector.updateSensitivity(newSensitivity)
        }
        .onChange(of: countGapSeconds) { _, newGap in
            vm.updateCountGap(newGap)
        }
        .onDisappear {
            AudioPlayer.shared.stopAlarm()
        }
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
                                closeScreen()
                            }
                        }
                )
            Spacer()
        }
        .ignoresSafeArea()
        .zIndex(99)
    }

    private var targetBinding: Binding<Int> {
        Binding {
            vm.target
        } set: { newValue in
            vm.setTarget(newValue)
        }
    }

    private var header: some View {
        FlowNavigationBar(
            title: "Count Whistles",
            dark: dark,
            haptics: settings.hapticsEnabled,
            onBack: closeScreen,
            onReset: { vm.reset() }
        )
    }

    private func closeScreen() {
        AudioPlayer.shared.stopAlarm()
        vm.stopListening()
        onClose()
    }

    @ViewBuilder
    private var detectorStatus: some View {
        if let errorMessage = vm.detector.errorMessage {
            Text(errorMessage)
                .font(.nunito(12, weight: .bold))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(minHeight: 18)
                .padding(.horizontal, 36)
        } else {
            Text(detectorStatusText)
                .font(.nunito(12, weight: .bold))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .frame(minHeight: 18)
        }
    }

    private var detectorStatusText: String {
        if vm.detector.isStarting {
            return "Preparing microphone access..."
        }

        if vm.detector.isListening {
            let level = Int((vm.detector.lastInputLevel * 100).rounded())
            let freq = Int(vm.detector.lastDetectedFrequency.rounded())
            let reason = vm.detector.lastRejectionReason
            if freq > 0 {
                return "lvl \(level)% • \(freq)Hz • \(reason)"
            }
            return "lvl \(level)% • \(reason)"
        }

        if vm.count > 0 {
            return "\(vm.count) of \(vm.target) whistles counted."
        }

        return "Automatic counter is off."
    }

    private var listeningButtonTitle: String {
        if audioPlayer.isAlarmPlaying || vm.showReadyPopup {
            return "Stop Sound"
        }
        if vm.detector.isListening {
            return "Stop Listening"
        }
        if vm.detector.isStarting {
            return "Listening..."
        }
        return "Start Listening"
    }

    private var listeningButtonIcon: String {
        if audioPlayer.isAlarmPlaying || vm.showReadyPopup {
            return "speaker.slash.fill"
        }
        if vm.detector.isListening {
            return "stop.fill"
        }
        if vm.detector.isStarting {
            return "waveform"
        }
        return "mic.fill"
    }

    private var listeningButtonColor: Color {
        if audioPlayer.isAlarmPlaying || vm.showReadyPopup || vm.detector.isListening || vm.detector.isStarting {
            return WhistleTheme.orange
        }
        return WhistleTheme.charcoal
    }

    private func saveSetup() {
        guard !didSaveCookbook else { return }
        didSaveCookbook = true
        HapticManager.success(enabled: settings.hapticsEnabled)
        modelContext.insert(Cookbook(name: "Quick \(vm.target)", whistleTarget: vm.target, emoji: "🎙", createdAt: Date()))
    }

    private func logSession() {
        modelContext.insert(CookingSession(
            cookbookName: vm.sourceCookbook?.name,
            emoji: vm.sourceCookbook?.emoji ?? "🎙",
            whistleCount: vm.count,
            targetWhistles: vm.target,
            timerDuration: vm.sourceCookbook?.timerDuration,
            reaction: "Ready"
        ))
        vm.sourceCookbook?.lastUsedAt = Date()
    }
}

struct WhistleMilestoneLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.fredoka(16, weight: .bold))
            .foregroundStyle(WhistleTheme.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: text)
    }
}
