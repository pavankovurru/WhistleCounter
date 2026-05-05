import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Cookbook.createdAt, order: .reverse) private var cookbooks: [Cookbook]

    @Bindable var settings: AppSettings
    var isVisible: Bool
    var onStartWhistles: () -> Void
    var onStartTimer: () -> Void
    var onOpenCookbook: (Cookbook) -> Void

    @State private var mascotState: WhistlyState = .idle

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            PlayfulScreenBackground(dark: dark)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)

                    VStack(spacing: 20) {
                        WhistlyMascot(
                            state: mascotState,
                            theme: MascotTheme.resolved(from: settings.mascotTheme),
                            size: mascotSize(for: proxy.size.height),
                            showsSteamPuffs: true,
                            isAnimated: true,
                            keepsBodyPosition: true
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

                            if !recentCookbooks.isEmpty {
                                recentSection
                                    .padding(.top, 8)
                            }
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
        .task(id: isVisible) {
            guard isVisible else { return }
            mascotState = .idle
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 7...11)))
                guard !Task.isCancelled, isVisible else { break }
                mascotState = .waving
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { break }
                mascotState = .idle
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hey, Chef")
                .font(.nunito(13, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .textCase(.uppercase)
            Text("What are we cooking?")
                .font(.fredoka(28, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent cookbooks")
                .font(.nunito(12, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recentCookbooks.prefix(6).enumerated()), id: \.element.id) { index, cookbook in
                        Button {
                            onOpenCookbook(cookbook)
                        } label: {
                            recentChip(cookbook, colorIndex: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 4)  // room for the raised-shadow offset at chip bottom
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recentChip(_ cookbook: Cookbook, colorIndex: Int) -> some View {
        let color = CookbookPalette.color(for: colorIndex)
        let stroke = CookbookPalette.strokeColor(for: colorIndex)
        let fg: Color = color == WhistleTheme.charcoal || color == WhistleTheme.orange ? .white : WhistleTheme.charcoal

        return HStack(spacing: 7) {
            if cookbook.isIdly {
                IdlyPiecesIcon(size: 24)
            } else {
                Text(cookbook.emoji)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(cookbook.name)
                    .font(.fredoka(13, weight: .bold))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                Text(cookbook.detailText)
                    .font(.nunito(10, weight: .bold))
                    .foregroundStyle(fg.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.darkened(0.38).opacity(0.62))
                    .offset(y: 2)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(stroke, lineWidth: 1)
                    }
            }
        }
    }

    private var recentCookbooks: [Cookbook] {
        cookbooks.sorted {
            ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt)
        }
    }

    private func mascotSize(for height: CGFloat) -> CGFloat {
        min(186, max(148, height * 0.23))
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
