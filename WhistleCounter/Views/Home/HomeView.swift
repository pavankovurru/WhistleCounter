import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    var onStartWhistles: () -> Void
    var onStartTimer: () -> Void

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            PlayfulScreenBackground(dark: dark)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)

                    VStack(spacing: 24) {
                        WhistlyMascot(
                            state: .idle,
                            theme: MascotTheme.resolved(from: settings.mascotTheme),
                            size: mascotSize(for: proxy.size.height)
                        )
                            .frame(maxWidth: .infinity)
                            .frame(height: mascotSize(for: proxy.size.height))

                        VStack(spacing: 14) {
                            heroAction(
                                title: "Count Whistles",
                                subtitle: "Listen for those toots",
                                icon: "mic.fill",
                                color: WhistleTheme.orange,
                                action: onStartWhistles
                            )
                            heroAction(
                                title: "Set Timer",
                                subtitle: "Tick-tock, snack time",
                                icon: "timer",
                                color: WhistleTheme.mint,
                                action: onStartTimer
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 108)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .onAppear {
            AudioPlayer.shared.startBackgroundMusic(enabled: settings.backgroundMusicEnabled)
        }
        .onChange(of: settings.backgroundMusicEnabled) { _, enabled in
            enabled ? AudioPlayer.shared.startBackgroundMusic(enabled: true) : AudioPlayer.shared.stopBackgroundMusic()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey, Chef")
                    .font(.nunito(13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .textCase(.uppercase)
                Text("What are we cooking?")
                    .font(.fredoka(28, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }
            Spacer()
            Button {
                HapticManager.tap(enabled: settings.hapticsEnabled)
                settings.backgroundMusicEnabled.toggle()
            } label: {
                Image(systemName: settings.backgroundMusicEnabled ? "music.note" : "speaker.slash.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 50, height: 50)
                    .background {
                        let fill = settings.backgroundMusicEnabled ? WhistleTheme.sunny : WhistleTheme.card(dark: dark)
                        ZStack {
                            Circle()
                                .fill(settings.backgroundMusicEnabled ? fill.darkened(0.42).opacity(0.68) : WhistleTheme.shadow(dark: dark))
                                .offset(y: 3)
                            Circle()
                                .fill(fill)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func mascotSize(for height: CGFloat) -> CGFloat {
        min(202, max(168, height * 0.25))
    }

    private func heroAction(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.fredoka(21, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(subtitle)
                        .font(.nunito(13, weight: .black))
                        .opacity(0.82)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .layoutPriority(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(color.darkened(0.43).opacity(0.74))
                        .offset(y: 5.5)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(color)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
