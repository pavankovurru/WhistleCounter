import SwiftUI

struct OnboardingView: View {
    @Bindable var settings: AppSettings
    @State private var step = 0

    private let slides = [
        ("Hi! I'm Whistly!", "I listen to your cooker so you don't have to.", WhistlyState.waving, WhistleTheme.sunny),
        ("Count those whistles!", "Three whistles for dal? I'll keep score and ping you the moment you hit it.", WhistlyState.bouncing, WhistleTheme.orange),
        ("I'll scream when it's done.", "Nicely. Set a timer, take a nap, I'll do the worrying.", WhistlyState.sleeping, WhistleTheme.mint)
    ]

    var body: some View {
        ZStack {
            slides[step].3
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                    .font(.fredoka(15, weight: .bold))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.45), in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                TabView(selection: $step) {
                    ForEach(slides.indices, id: \.self) { index in
                        slideView(slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.72), value: step)

                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                step = index
                            }
                        } label: {
                            Capsule()
                                .fill(index == step ? WhistleTheme.charcoal : WhistleTheme.charcoal.opacity(0.24))
                                .frame(width: index == step ? 34 : 12, height: 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to onboarding page \(index + 1)")
                    }
                }
                .padding(.bottom, 18)

                ChunkyButton(
                    title: step == slides.count - 1 ? "Let's Cook!" : "Next",
                    emoji: step == slides.count - 1 ? "🍲" : nil,
                    color: WhistleTheme.charcoal,
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
            }
        }
    }

    private func slideView(_ slide: (String, String, WhistlyState, Color)) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            WhistlyMascot(state: slide.2, theme: MascotTheme.resolved(from: settings.mascotTheme), size: 232)
                .transition(.scale.combined(with: .opacity))

            Text(slide.0)
                .font(.fredoka(38, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            Text(slide.1)
                .font(.nunito(18, weight: .bold))
                .foregroundStyle(Color(hex: 0x5A4A3A))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 34)
                .padding(.top, 8)

            Spacer(minLength: 18)
        }
    }
}
