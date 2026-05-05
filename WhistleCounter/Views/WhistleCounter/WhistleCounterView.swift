import SwiftData
import SwiftUI

struct WhistleCounterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    @StateObject private var vm: WhistleCounterVM
    @State private var didLogCompletion = false
    @ObservedObject private var audioPlayer = AudioPlayer.shared
    var onClose: () -> Void
    var onStartLinkedTimer: (Cookbook) -> Void

    init(settings: AppSettings, cookbook: Cookbook?, onClose: @escaping () -> Void, onStartLinkedTimer: @escaping (Cookbook) -> Void) {
        self.settings = settings
        self.onClose = onClose
        self.onStartLinkedTimer = onStartLinkedTimer
        _vm = StateObject(wrappedValue: WhistleCounterVM(cookbook: cookbook))
    }

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }
    private var sensitivity: WhistleSensitivity { WhistleSensitivity(rawValue: settings.sensitivity) ?? .medium }
    private var soundPack: SoundPack { SoundPack(rawValue: settings.soundPack) ?? .classic }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PlayfulScreenBackground(dark: dark)

                VStack(spacing: 0) {
                    header

                    Spacer()

                    VStack(spacing: 20) {
                        SlotPickerView(title: "Target", value: targetBinding, range: 1...20, suffix: "whistles", tint: WhistleTheme.orange, haptics: settings.hapticsEnabled)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(vm.count)")
                                .font(.fredoka(128, weight: .black))
                                .foregroundStyle(WhistleTheme.text(dark: dark))
                                .contentTransition(.numericText())
                                .minimumScaleFactor(0.72)
                            Text("/\(vm.target)")
                                .font(.fredoka(48, weight: .black))
                                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                        }
                        .animation(.spring(response: 0.28, dampingFraction: 0.52), value: vm.count)

                        WhistleMilestoneLabel(text: vm.milestone)

                        WhistlyMascot(state: vm.mascotState, theme: MascotTheme.resolved(from: settings.mascotTheme), size: 174)
                            .frame(height: 170)

                        ChunkyButton(
                            title: listeningButtonTitle,
                            systemImage: listeningButtonIcon,
                            color: audioPlayer.isAlarmPlaying || vm.detector.isListening || vm.detector.isStarting ? WhistleTheme.orange : WhistleTheme.charcoal,
                            fontSize: 17,
                            fullWidth: true,
                            activeGlow: vm.detector.isListening && !audioPlayer.isAlarmPlaying
                        ) {
                            HapticManager.tap(enabled: settings.hapticsEnabled)
                            if audioPlayer.isAlarmPlaying {
                                AudioPlayer.shared.stopAlarm()
                            } else {
                                vm.toggleListening(sensitivity: sensitivity)
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
        .onDisappear {
            AudioPlayer.shared.stopAlarm()
            vm.stopListening()
        }
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
            title: "Whistle Counter",
            dark: dark,
            haptics: settings.hapticsEnabled,
            onBack: onClose,
            onReset: { vm.reset() }
        )
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
            let frequency = Int(vm.detector.lastDetectedFrequency)
            if frequency > 0 {
                let confidence = Int((vm.detector.lastConfidence * 100).rounded())
                let level = Int((min(vm.detector.lastInputLevel * 100, 1) * 100).rounded())
                return "Listening live. \(frequency) Hz tone, \(confidence)% match, \(level)% level"
            }
            let level = Int((min(vm.detector.lastInputLevel * 100, 1) * 100).rounded())
            return level > 0 ? "Listening live. Audio level \(level)%, no whistle yet." : "Listening live. Waiting for cooker steam."
        }

        if vm.count > 0 {
            return "\(vm.count) of \(vm.target) whistles counted."
        }

        return "Automatic counter is off."
    }

    private var listeningButtonTitle: String {
        if audioPlayer.isAlarmPlaying {
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
        if audioPlayer.isAlarmPlaying {
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

    private func saveSetup() {
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
