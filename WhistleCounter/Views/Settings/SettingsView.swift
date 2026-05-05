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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    quickTogglesCard
                    soundPackCard
                    sensitivityCard
                    whistlyColorCard
                    replayCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 106)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Make it yours")
                    .font(.nunito(13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .textCase(.uppercase)
                Text("Settings")
                    .font(.fredoka(32, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WhistleTheme.sunny)
                WhistlyMascot(
                    state: .idle,
                    theme: MascotTheme.resolved(from: settings.mascotTheme),
                    size: 68,
                    showsSteamPuffs: false,
                    isAnimated: false
                )
                    .offset(y: -3)
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var quickTogglesCard: some View {
        settingsSection(title: "Kitchen Feel", icon: "slider.horizontal.3", tint: WhistleTheme.mint) {
            VStack(spacing: 10) {
                settingToggleRow(
                    title: "Haptic feedback",
                    subtitle: settings.hapticsEnabled ? "Taps and wheels feel alive" : "No vibration feedback",
                    systemImage: "hand.tap.fill",
                    color: WhistleTheme.sunny,
                    isOn: $settings.hapticsEnabled
                )
                settingToggleRow(
                    title: "Dark mode",
                    subtitle: settings.darkModeEnabled ? "Always use the night kitchen" : "Follow your iPhone setting",
                    systemImage: "moon.stars.fill",
                    color: WhistleTheme.charcoal,
                    isOn: $settings.darkModeEnabled
                )
            }
        }
    }

    private var soundPackCard: some View {
        settingsSection(title: "Alert Sound", icon: "speaker.wave.2.fill", tint: WhistleTheme.orange) {
            VStack(spacing: 10) {
                HStack(spacing: 9) {
                    ForEach(SoundPack.allCases) { pack in
                        packButton(pack)
                    }
                }

                Text("Used by both whistle counter and kitchen timer alarms.")
                    .font(.nunito(12, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sensitivityCard: some View {
        settingsSection(title: "Whistle Sensitivity", icon: "waveform", tint: WhistleTheme.sunny) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    sensitivityButton(.low)
                    sensitivityButton(.medium)
                    sensitivityButton(.high)
                }

                GeometryReader { proxy in
                    let levels = WhistleSensitivity.allCases
                    let activeIndex = levels.firstIndex { $0.rawValue == settings.sensitivity } ?? 1
                    let width = max(proxy.size.width, 1)
                    let progress = CGFloat(activeIndex + 1) / CGFloat(levels.count)
                    let fillWidth = width * progress

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(WhistleTheme.background(dark: dark))
                            .frame(height: 12)
                        Capsule()
                            .fill(sensitivityColor(levels[activeIndex]))
                            .frame(width: max(16, fillWidth), height: 12)
                        Circle()
                            .fill(WhistleTheme.card(dark: dark))
                            .frame(width: 26, height: 26)
                            .overlay {
                                Circle()
                                    .fill(sensitivityColor(levels[activeIndex]))
                                    .frame(width: 16, height: 16)
                            }
                            .shadow(color: WhistleTheme.shadow(dark: dark), radius: 5, y: 2)
                            .offset(x: max(0, min(width - 26, fillWidth - 13)))
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: settings.sensitivity)
                }
                .frame(height: 28)
            }
        }
    }

    private var whistlyColorCard: some View {
        settingsSection(title: "Whistly Color", icon: "paintpalette.fill", tint: themeFill(MascotTheme.resolved(from: settings.mascotTheme))) {
            HStack(spacing: 9) {
                ForEach(MascotTheme.allCases) { theme in
                    mascotButton(theme)
                }
            }
        }
    }

    private var replayCard: some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            settings.hasCompletedOnboarding = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 44, height: 44)
                    .background(WhistleTheme.sunny, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Replay onboarding")
                        .font(.fredoka(18, weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                    Text("See the welcome screens again")
                        .font(.nunito(12, weight: .black))
                        .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WhistleTheme.card(dark: dark))
                    .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private func settingsSection<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(tint == WhistleTheme.orange || tint == WhistleTheme.charcoal ? .white : WhistleTheme.charcoal)
                    .frame(width: 34, height: 34)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.fredoka(19, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
        }
    }

    private func settingToggleRow(title: String, subtitle: String, systemImage: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(color == WhistleTheme.sunny || color == WhistleTheme.mint ? WhistleTheme.charcoal : .white)
                    .frame(width: 42, height: 42)
                    .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.fredoka(16, weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                    Text(subtitle)
                        .font(.nunito(12, weight: .black))
                        .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                togglePill(isOn: isOn.wrappedValue)
            }
            .padding(10)
            .background(WhistleTheme.background(dark: dark), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func togglePill(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? WhistleTheme.mint : WhistleTheme.secondaryText(dark: dark).opacity(0.24))
                .frame(width: 52, height: 32)
            Circle()
                .fill(isOn ? WhistleTheme.charcoal : WhistleTheme.card(dark: dark))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 4)
        }
    }

    private func packButton(_ pack: SoundPack) -> some View {
        let active = settings.soundPack == pack.rawValue
        return Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                settings.soundPack = pack.rawValue
            }
            AudioPlayer.shared.previewAlarm(pack: pack, duration: 2)
        } label: {
            VStack(spacing: 6) {
                Text(pack.emoji)
                    .font(.title2)
                Text(pack.rawValue)
                    .font(.fredoka(13, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(packColor(pack) == WhistleTheme.charcoal ? .white : WhistleTheme.charcoal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                let fill = active ? packColor(pack) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active ? fill.darkened(0.38).opacity(0.64) : WhistleTheme.shadow(dark: dark))
                        .offset(y: active ? 3 : 1.5)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            .foregroundStyle(active ? sensitivityForeground(level) : WhistleTheme.secondaryText(dark: dark))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                let fill = active ? sensitivityColor(level) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active ? fill.darkened(0.40).opacity(0.68) : WhistleTheme.shadow(dark: dark))
                        .offset(y: active ? 3 : 1.5)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func mascotButton(_ theme: MascotTheme) -> some View {
        let active = MascotTheme.resolved(from: settings.mascotTheme) == theme
        return Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                settings.mascotTheme = theme.rawValue
            }
        } label: {
            VStack(spacing: 5) {
                WhistlyMascot(
                    state: .idle,
                    theme: theme,
                    size: 58,
                    showsSteamPuffs: false,
                    isAnimated: false
                )
                    .frame(height: 54)
                Text(theme.rawValue)
                    .font(.fredoka(11, weight: .black))
                    .lineLimit(1)
            }
            .foregroundStyle(themeFill(theme) == WhistleTheme.charcoal ? .white : WhistleTheme.charcoal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                let fill = active ? themeFill(theme) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active ? fill.darkened(0.38).opacity(0.64) : WhistleTheme.shadow(dark: dark))
                        .offset(y: active ? 3 : 1.5)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func packColor(_ pack: SoundPack) -> Color {
        switch pack {
        case .classic: WhistleTheme.sunny
        case .funny: WhistleTheme.orange
        case .zen: WhistleTheme.mint
        }
    }

    private func sensitivityIcon(_ level: WhistleSensitivity) -> String {
        switch level {
        case .low: "ear"
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

    private func sensitivityForeground(_ level: WhistleSensitivity) -> Color {
        level == .high ? .white : WhistleTheme.charcoal
    }

    private func themeFill(_ theme: MascotTheme) -> Color {
        switch theme {
        case .default: WhistleTheme.sunny
        case .sunny: WhistleTheme.orange
        case .mint: WhistleTheme.mint
        case .berry: WhistleTheme.rose
        }
    }
}
