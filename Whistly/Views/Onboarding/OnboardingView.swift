import SwiftUI

struct OnboardingView: View {
    @Bindable var settings: AppSettings
    @State private var step = 0

    private enum SlideContent {
        case standard(subtitle: String)
        case sensitivity
    }

    private struct Slide {
        var title: String
        var content: SlideContent
        var mascotState: WhistlyState
        var color: Color
    }

    private let slides: [Slide] = [
        Slide(title: "Hi! I'm Whistly!",
              content: .standard(subtitle: "I listen to your cooker so you don't have to."),
              mascotState: .waving, color: WhistleTheme.sunny),
        Slide(title: "Count those whistles!",
              content: .standard(subtitle: "Tell me your number. I'll do the rest."),
              mascotState: .bouncing, color: WhistleTheme.orange),
        Slide(title: "I'll scream when it's done.",
              content: .standard(subtitle: "Nicely. Set a timer, take a nap, I'll do the worrying."),
              mascotState: .sleeping, color: WhistleTheme.mint),
    ]

    private var isDarkSlide: Bool { slides[step].color == WhistleTheme.charcoal }

    var body: some View {
        ZStack {
            slides[step].color
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: step)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                    .font(.fredoka(15, weight: .bold))
                    .foregroundStyle(isDarkSlide ? .white : WhistleTheme.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(isDarkSlide ? .white.opacity(0.18) : .white.opacity(0.45), in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.25), value: isDarkSlide)

                TabView(selection: $step) {
                    ForEach(slides.indices, id: \.self) { index in
                        slideView(slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                step = index
                            }
                        } label: {
                            Capsule()
                                .fill(index == step
                                      ? (isDarkSlide ? .white : WhistleTheme.charcoal)
                                      : (isDarkSlide ? .white.opacity(0.30) : WhistleTheme.charcoal.opacity(0.24)))
                                .frame(width: index == step ? 34 : 12, height: 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to onboarding page \(index + 1)")
                    }
                }
                .padding(.bottom, 18)
                .animation(.easeInOut(duration: 0.25), value: isDarkSlide)

                ChunkyButton(
                    title: step == slides.count - 1 ? "Let's Cook!" : "Next",
                    emoji: step == slides.count - 1 ? "🍲" : nil,
                    color: isDarkSlide ? WhistleTheme.sunny : WhistleTheme.charcoal,
                    fontSize: 22,
                    horizontalPadding: 22,
                    verticalPadding: 19,
                    cornerRadius: 30,
                    fullWidth: true
                ) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                        if step < slides.count - 1 {
                            step += 1
                        } else {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 38)
                .animation(.easeInOut(duration: 0.25), value: isDarkSlide)
            }
        }
    }

    @ViewBuilder
    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            WhistlyMascot(
                state: slide.mascotState,
                theme: MascotTheme.resolved(from: settings.mascotTheme),
                size: 200
            )
            .transition(.scale.combined(with: .opacity))

            Text(slide.title)
                .font(.fredoka(38, weight: .black))
                .foregroundStyle(slide.color == WhistleTheme.charcoal ? Color(hex: 0xFFE7C9) : WhistleTheme.charcoal)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            switch slide.content {
            case .standard(let subtitle):
                Text(subtitle)
                    .font(.nunito(18, weight: .bold))
                    .foregroundStyle(Color(hex: 0x5A4A3A))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 34)
                    .padding(.top, 8)

            case .sensitivity:
                sensitivityContent
            }

            Spacer(minLength: 18)
        }
    }

    private var sensitivityContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                sensitivityCard(
                    icon: "ear",
                    level: "Low",
                    desc: "Quiet kitchen, right next to the cooker",
                    color: WhistleTheme.mint
                )
                sensitivityCard(
                    icon: "waveform",
                    level: "Medium",
                    desc: "Most homes — best place to start",
                    color: WhistleTheme.sunny
                )
                sensitivityCard(
                    icon: "bolt.fill",
                    level: "High",
                    desc: "Noisy kitchen or cooker far away",
                    color: WhistleTheme.orange
                )
            }
            // equal-height cards: HStack stretches all cards to the tallest one
            .fixedSize(horizontal: false, vertical: true)

            Text("Change anytime in Settings.")
                .font(.nunito(12, weight: .black))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private func sensitivityCard(icon: String, level: String, desc: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(color == WhistleTheme.sunny || color == WhistleTheme.mint ? WhistleTheme.charcoal : .white)
                .frame(width: 44, height: 44)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color.darkened(0.38).opacity(0.62))
                            .offset(y: 3)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color)
                    }
                }

            Text(level)
                .font(.fredoka(14, weight: .black))
                .foregroundStyle(.white)

            Text(desc)
                .font(.nunito(10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                }
        }
    }
}
