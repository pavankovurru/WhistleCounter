import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    settingsCard {
                        Toggle("Background music 🎵", isOn: $settings.backgroundMusicEnabled)
                        Toggle("Haptic feedback ✋", isOn: $settings.hapticsEnabled)
                        Toggle("Always use dark mode 🌙", isOn: $settings.darkModeEnabled)
                    }

                    cardLabel("Alert sound pack")
                    settingsCard {
                        HStack(spacing: 8) {
                            ForEach(SoundPack.allCases) { pack in
                                optionButton(title: pack.rawValue, emoji: pack.emoji, active: settings.soundPack == pack.rawValue) {
                                    settings.soundPack = pack.rawValue
                                    AudioPlayer.shared.playAlarm(pack: pack)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    cardLabel("Whistle sensitivity")
                    settingsCard {
                        HStack(spacing: 8) {
                            sensitivityButton(.low)
                            sensitivityButton(.medium)
                            sensitivityButton(.high)
                        }
                        .padding(.vertical, 4)
                    }

                    cardLabel("Whistly color")
                    settingsCard {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(MascotTheme.allCases) { theme in
                                    Button {
                                        HapticManager.tap(enabled: settings.hapticsEnabled)
                                        settings.mascotTheme = theme.rawValue
                                    } label: {
                                        VStack(spacing: 5) {
                                            WhistlyMascot(state: .idle, theme: theme, size: 72)
                                            Text(theme.rawValue)
                                                .font(.fredoka(12, weight: .black))
                                        }
                                        .foregroundStyle(WhistleTheme.text(dark: dark))
                                        .frame(width: 86)
                                        .padding(.vertical, 8)
                                        .background(MascotTheme.resolved(from: settings.mascotTheme) == theme ? WhistleTheme.sunny : WhistleTheme.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    settingsCard {
                        Button("Replay onboarding") {
                            settings.hasCompletedOnboarding = false
                        }
                        .font(.fredoka(16, weight: .bold))
                        .foregroundStyle(WhistleTheme.orange)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 106)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tweaks")
                .font(.nunito(13, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .textCase(.uppercase)
            Text("Settings")
                .font(.fredoka(32, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .font(.fredoka(16, weight: .bold))
        .foregroundStyle(WhistleTheme.text(dark: dark))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
        }
    }

    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.fredoka(12, weight: .black))
            .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
            .textCase(.uppercase)
            .padding(.top, 4)
            .padding(.horizontal, 8)
    }

    private func optionButton(title: String, emoji: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(title)
                    .font(.fredoka(13, weight: .black))
            }
            .foregroundStyle(WhistleTheme.charcoal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                let fill = active ? WhistleTheme.sunny : WhistleTheme.cream
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(active ? fill.darkened(0.38).opacity(0.66) : WhistleTheme.shadow(dark: dark))
                        .offset(y: active ? 3 : 2)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sensitivityButton(_ level: WhistleSensitivity) -> some View {
        let active = settings.sensitivity == level.rawValue
        return Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                settings.sensitivity = level.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sensitivityIcon(level))
                    .font(.system(size: 18, weight: .black))
                Text(level.rawValue)
                    .font(.fredoka(13, weight: .black))
            }
            .foregroundStyle(active ? WhistleTheme.charcoal : WhistleTheme.secondaryText(dark: dark))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                let fill = active ? sensitivityColor(level) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active ? fill.darkened(0.40).opacity(0.68) : WhistleTheme.shadow(dark: dark))
                        .offset(y: active ? 3 : 2)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                }
            }
            .scaleEffect(active ? 1.02 : 1)
        }
        .buttonStyle(.plain)
    }

    private func sensitivityIcon(_ level: WhistleSensitivity) -> String {
        switch level {
        case .low: "tortoise.fill"
        case .medium: "waveform"
        case .high: "bolt.fill"
        }
    }

    private func sensitivityColor(_ level: WhistleSensitivity) -> Color {
        switch level {
        case .low: WhistleTheme.mint
        case .medium: WhistleTheme.sunny
        case .high: WhistleTheme.orange
        }
    }
}
