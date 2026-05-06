import SwiftUI

enum WhistlyState {
    case idle
    case waving
    case bouncing
    case sleeping
    case celebrating
    case shocked
    case reading
}

struct WhistlyMascot: View {
    var state: WhistlyState = .idle
    var theme: MascotTheme = .default
    var size: CGFloat = 180
    var showsSteamPuffs = true
    var isAnimated = true
    var keepsBodyPosition = true
    var steamBaseY: CGFloat = 40

    @State private var motion = false

    var body: some View {
        let u = size / 200

        ZStack(alignment: .topLeading) {
            hatOrSteam(u)

            handles(u)
            body(u)
            arms(u)
            feet(u)

            if state == .sleeping {
                zzz(u)
            }

            if state == .shocked {
                Text("!")
                    .font(.system(size: 32 * u, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .position(x: 174 * u, y: 18 * u)
                    .scaleEffect(activeMotion ? 1.18 : 0.92)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isAnimated else { return }
            motion = true
        }
    }

    private var activeMotion: Bool {
        isAnimated && motion
    }

    private var activeBodyMotion: Bool {
        activeMotion && !keepsBodyPosition
    }

    private var colors: WhistlyColors {
        switch theme {
        case .default:
            WhistlyColors(body: WhistleTheme.orange, belly: WhistleTheme.sunny, accent: Color(hex: 0xFFB347))
        case .sunny:
            WhistlyColors(body: WhistleTheme.sunny, belly: Color(hex: 0xFFF0A8), accent: WhistleTheme.orange)
        case .mint:
            WhistlyColors(body: WhistleTheme.mint, belly: Color(hex: 0xDDF8E2), accent: WhistleTheme.sunny)
        case .berry:
            WhistlyColors(body: Color(hex: 0xEF5A7A), belly: Color(hex: 0xFFE4EC), accent: WhistleTheme.sunny)
        }
    }

    private var wrapperScale: CGFloat {
        switch state {
        case .bouncing:
            activeBodyMotion ? 1.04 : 0.98
        case .celebrating:
            activeBodyMotion ? 1.05 : 0.99
        case .shocked:
            1.0
        case .sleeping:
            activeBodyMotion ? 1.025 : 1.0
        default:
            activeBodyMotion ? 1.018 : 1.0
        }
    }

    private var wrapperRotation: Double {
        switch state {
        case .waving:
            activeBodyMotion ? 4 : -4
        case .shocked:
            activeBodyMotion ? 3 : -3
        case .celebrating:
            activeBodyMotion ? 3 : -3
        default:
            0
        }
    }

    private var wrapperYOffset: CGFloat {
        switch state {
        case .bouncing:
            activeBodyMotion ? -12 : 0
        case .celebrating:
            activeBodyMotion ? -16 : 0
        case .sleeping:
            activeBodyMotion ? 2 : 0
        default:
            0
        }
    }

    private var wrapperAnimation: Animation {
        switch state {
        case .bouncing:
            .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        case .celebrating:
            .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        case .shocked:
            .easeInOut(duration: 0.18).repeatForever(autoreverses: true)
        case .sleeping:
            .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
        case .waving:
            .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        default:
            .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
        }
    }

    @ViewBuilder
    private func hatOrSteam(_ u: CGFloat) -> some View {
        SteamWhistleExact(u: u, colors: colors, state: state, showsSteamPuffs: showsSteamPuffs, steamBaseY: steamBaseY)
    }

    @ViewBuilder
    private func body(_ u: CGFloat) -> some View {
        let bodyRect = CGRect(x: 25 * u, y: 58 * u, width: 150 * u, height: 130 * u)

        CookerBodyShape()
            .fill(
                RadialGradient(
                    colors: [colors.body.lightened(0.18), colors.body, colors.body.darkened(0.12)],
                    center: UnitPoint(x: 0.30, y: 0.25),
                    startRadius: 4 * u,
                    endRadius: 150 * u
                )
            )
            .frame(width: bodyRect.width, height: bodyRect.height)
            .position(x: bodyRect.midX, y: bodyRect.midY)
            .shadow(color: .black.opacity(0.12), radius: 20 * u, y: 8 * u)
            .overlay {
                CookerBodyShape()
                    .stroke(colors.body.lightened(0.20).opacity(0.45), lineWidth: 2 * u)
                    .frame(width: bodyRect.width - 7 * u, height: bodyRect.height - 7 * u)
                    .position(x: bodyRect.midX - 2 * u, y: bodyRect.midY - 2 * u)
                    .blendMode(.screen)
            }

        Ellipse()
            .fill(colors.belly.opacity(0.92))
            .frame(width: 117 * u, height: 60 * u)
            .position(x: 100 * u, y: 137.5 * u)
            .shadow(color: .white.opacity(0.55), radius: 3 * u, y: -2 * u)

        face(u)

        Ellipse()
            .fill(colors.body.darkened(0.22))
            .frame(width: 141 * u, height: 14 * u)
            .position(x: 100 * u, y: 189 * u)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(colors.body.darkened(0.35).opacity(0.6))
                    .frame(width: 128 * u, height: 2 * u)
                    .offset(y: 182 * u)
            }

        if state == .reading {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34 * u, weight: .black))
                .foregroundStyle(WhistleTheme.sunny)
                .position(x: 100 * u, y: 166 * u)
        }
    }

    @ViewBuilder
    private func face(_ u: CGFloat) -> some View {
        let faceTop = 90.5 * u
        let faceCenterX = 100 * u

        eyes(u, faceTop: faceTop, faceCenterX: faceCenterX)
        mouth(u, faceTop: faceTop, faceCenterX: faceCenterX)

        if state != .sleeping && state != .shocked {
            cheek(u, x: 66 * u, y: 129.5 * u)
            cheek(u, x: 134 * u, y: 129.5 * u)
        }
    }

    @ViewBuilder
    private func eyes(_ u: CGFloat, faceTop: CGFloat, faceCenterX: CGFloat) -> some View {
        let eyeY = faceTop + 20.8 * u
        let x1 = faceCenterX - 22 * u
        let x2 = faceCenterX + 22 * u

        switch state {
        case .sleeping:
            closedEye(u, x: x1, y: eyeY)
            closedEye(u, x: x2, y: eyeY)
        case .shocked:
            openEye(u, x: x1, y: faceTop + 18.2 * u, width: 26, height: 28, pupilWidth: 15, pupilHeight: 17)
            openEye(u, x: x2, y: faceTop + 18.2 * u, width: 26, height: 28, pupilWidth: 15, pupilHeight: 17)
        case .celebrating:
            arcEye(u, x: x1, y: eyeY)
            arcEye(u, x: x2, y: eyeY)
        default:
            openEye(u, x: x1, y: eyeY, width: 20, height: 22, pupilWidth: 11, pupilHeight: 13)
            openEye(u, x: x2, y: eyeY, width: 20, height: 22, pupilWidth: 11, pupilHeight: 13)
        }
    }

    private func openEye(_ u: CGFloat, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, pupilWidth: CGFloat, pupilHeight: CGFloat) -> some View {
        Ellipse()
            .fill(.white)
            .frame(width: width * u, height: height * u)
            .shadow(color: .black.opacity(0.15), radius: 1 * u, y: 1 * u)
            .overlay {
                Ellipse()
                    .fill(WhistleTheme.charcoal)
                    .frame(width: pupilWidth * u, height: pupilHeight * u)
                    .offset(y: 1.5 * u)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(.white)
                            .frame(width: 3.4 * u, height: 3.4 * u)
                            .offset(x: -2 * u, y: 2 * u)
                    }
            }
            .position(x: x, y: y)
    }

    private func closedEye(_ u: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        ClosedEyeShape()
            .stroke(WhistleTheme.charcoal, style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
            .frame(width: 22 * u, height: 8 * u)
            .position(x: x, y: y)
    }

    private func arcEye(_ u: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        HappyEyeShape()
            .stroke(WhistleTheme.charcoal, style: StrokeStyle(lineWidth: 3 * u, lineCap: .round, lineJoin: .round))
            .frame(width: 22 * u, height: 12 * u)
            .position(x: x, y: y)
    }

    @ViewBuilder
    private func mouth(_ u: CGFloat, faceTop: CGFloat, faceCenterX: CGFloat) -> some View {
        switch state {
        case .sleeping:
            Capsule()
                .fill(WhistleTheme.charcoal)
                .frame(width: 16 * u, height: 3 * u)
                .position(x: faceCenterX, y: faceTop + 48.1 * u)
        case .shocked:
            Ellipse()
                .fill(WhistleTheme.charcoal)
                .frame(width: 18 * u, height: 20 * u)
                .position(x: faceCenterX, y: faceTop + 54.2 * u)
        case .celebrating:
            SmileMouthShape()
                .fill(WhistleTheme.charcoal)
                .frame(width: 36 * u, height: 20 * u)
                .position(x: faceCenterX, y: faceTop + 54.2 * u)
        default:
            SmileMouthShape()
                .fill(WhistleTheme.charcoal)
                .frame(width: 28 * u, height: 14 * u)
                .position(x: faceCenterX, y: faceTop + 52.5 * u)
        }
    }

    private func cheek(_ u: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(Color(red: 1, green: 0.41, blue: 0.51).opacity(0.65))
            .frame(width: 14 * u, height: 8 * u)
            .blur(radius: 1 * u)
            .position(x: x, y: y)
    }

    @ViewBuilder
    private func handles(_ u: CGFloat) -> some View {
        HandleShape(side: .left)
            .fill(colors.body.darkened(0.22))
            .frame(width: 22 * u, height: 38 * u)
            .position(x: 22 * u, y: 123.8 * u)

        HandleShape(side: .right)
            .fill(colors.body.darkened(0.22))
            .frame(width: 22 * u, height: 38 * u)
            .position(x: 178 * u, y: 123.8 * u)
    }

    @ViewBuilder
    private func feet(_ u: CGFloat) -> some View {
        Ellipse()
            .fill(colors.body.darkened(0.30))
            .frame(width: 28 * u, height: 14 * u)
            .position(x: 82 * u, y: 189 * u)

        Ellipse()
            .fill(colors.body.darkened(0.30))
            .frame(width: 28 * u, height: 14 * u)
            .position(x: 118 * u, y: 189 * u)
    }

    @ViewBuilder
    private func arms(_ u: CGFloat) -> some View {
        if state == .waving {
            RoundedRectangle(cornerRadius: 99 * u, style: .continuous)
                .fill(colors.body.darkened(0.05))
                .frame(width: 20 * u, height: 40 * u)
                .rotationEffect(.degrees(-10), anchor: .topTrailing)
                .position(x: 12 * u, y: 128 * u)

            armWithHand(u, x: 184 * u, y: 83 * u, angle: activeMotion ? 34 : 56)
        } else if state == .celebrating {
            armWithHand(u, x: 16 * u, y: 78 * u, angle: activeMotion ? -50 : -30)
            armWithHand(u, x: 184 * u, y: 78 * u, angle: activeMotion ? 50 : 30)
        }
    }

    private func armWithHand(_ u: CGFloat, x: CGFloat, y: CGFloat, angle: Double) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 99 * u, style: .continuous)
                .fill(colors.body)
                .frame(width: 20 * u, height: 54 * u)
                .shadow(color: colors.body.darkened(0.18), radius: 0, y: -2 * u)
            Circle()
                .fill(colors.body)
                .frame(width: 22 * u, height: 22 * u)
                .offset(y: -10 * u)
                .shadow(color: colors.body.darkened(0.15), radius: 0, x: -2 * u, y: -2 * u)
        }
        .frame(width: 28 * u, height: 66 * u)
        .rotationEffect(.degrees(angle), anchor: .bottom)
        .position(x: x, y: y)
        .animation(isAnimated ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true) : nil, value: motion)
    }

    private func zzz(_ u: CGFloat) -> some View {
        Text("z")
            .font(.system(size: 28 * u, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: 0x94B5E6))
            .overlay(alignment: .trailing) {
                Text("z")
                    .font(.system(size: 22 * u, weight: .black, design: .rounded))
                    .offset(x: 14 * u, y: 2 * u)
            }
            .overlay(alignment: .trailing) {
                Text("z")
                    .font(.system(size: 16 * u, weight: .black, design: .rounded))
                    .offset(x: 27 * u, y: 6 * u)
            }
            .position(x: 166 * u, y: activeMotion ? -2 * u : 16 * u)
            .opacity(activeMotion ? 0.05 : 1)
            .animation(isAnimated ? .easeOut(duration: 2.0).repeatForever(autoreverses: false) : nil, value: motion)
    }
}

private struct WhistlyColors {
    var body: Color
    var belly: Color
    var accent: Color
}

private struct SteamWhistleExact: View {
    var u: CGFloat
    var colors: WhistlyColors
    var state: WhistlyState
    var showsSteamPuffs: Bool
    var steamBaseY: CGFloat = 40
    @State private var puff = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
                .fill(colors.body.darkened(0.45))
                .frame(width: 18 * u, height: 22 * u)
                .shadow(color: colors.body.darkened(0.55), radius: 0, x: -2 * u)
                .position(x: 100 * u, y: 77 * u)

            RoundedRectangle(cornerRadius: 4 * u, style: .continuous)
                .fill(colors.body.darkened(0.35))
                .frame(width: 40 * u, height: 10 * u)
                .shadow(color: colors.body.darkened(0.50), radius: 0, y: -2 * u)
                .position(x: 100 * u, y: 91 * u)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [colors.body.darkened(0.25), colors.body.darkened(0.50)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40 * u, height: 22 * u)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 2 * u)
                .position(x: 100 * u, y: 59 * u)

            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 6 * u, bottomLeading: 3 * u, bottomTrailing: 3 * u, topTrailing: 6 * u))
                .fill(colors.body.darkened(0.55))
                .frame(width: 10 * u, height: 8 * u)
                .position(x: 100 * u, y: 44 * u)

            if showsSteamPuffs {
                ForEach(0..<3, id: \.self) { index in
                    SteamPuff(
                        u: u,
                        x: puffX(index) * u,
                        baseY: steamBaseY * u,
                        phase: puff
                    )
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(index) * 0.4), value: puff)
                }
            }
        }
        .frame(width: 200 * u, height: 200 * u, alignment: .topLeading)
        .onAppear { puff = true }
        .onChange(of: showsSteamPuffs) { _, show in
            puff = false
            if show { puff = true }
        }
    }

    private func puffX(_ index: Int) -> CGFloat {
        switch index {
        case 0: 63.6
        case 1: 100
        default: 136.4
        }
    }
}

private struct SteamPuff: View {
    var u: CGFloat
    var x: CGFloat
    var baseY: CGFloat
    var phase: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: 0xFFF1D0).opacity(0.94))
            .frame(width: 20 * u, height: 20 * u)
            .overlay {
                Circle()
                    .stroke(WhistleTheme.sunny.darkened(0.18).opacity(0.36), lineWidth: 1.4 * u)
            }
            .shadow(color: WhistleTheme.orange.opacity(0.12), radius: 6 * u, y: 2 * u)
            .scaleEffect(phase ? 1.42 : 0.42)
            .opacity(phase ? 0 : 0.92)
            .position(x: x, y: phase ? baseY - 40 * u : baseY)
    }
}

private struct CookerBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.48),
            control1: CGPoint(x: rect.minX + w * 0.82, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.86, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.78),
            control2: CGPoint(x: rect.minX + w * 0.98, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + w * 0.14, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.48),
            control1: CGPoint(x: rect.minX + w * 0.02, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.18),
            control2: CGPoint(x: rect.minX + w * 0.18, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct HandleShape: Shape {
    enum Side {
        case left
        case right
    }

    var side: Side

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if side == .left {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.minX, y: rect.minY), control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.20))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control1: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.20), control2: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.maxX, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.20))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.20), control2: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct ClosedEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

private struct HappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY * 0.72),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

private struct SmileMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private struct ChefHatExact: View {
    var u: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11 * u, style: .continuous)
                .fill(Color.white)
                .frame(width: 78 * u, height: 30 * u)
                .position(x: 43 * u, y: 38 * u)
                .shadow(color: .black.opacity(0.08), radius: 5 * u, y: 2 * u)

            Circle()
                .fill(Color.white)
                .frame(width: 37 * u, height: 37 * u)
                .position(x: 22 * u, y: 21 * u)

            Circle()
                .fill(Color.white)
                .frame(width: 42 * u, height: 42 * u)
                .position(x: 43 * u, y: 16 * u)

            Circle()
                .fill(Color.white)
                .frame(width: 36 * u, height: 36 * u)
                .position(x: 65 * u, y: 22 * u)

            Path { path in
                path.move(to: CGPoint(x: 24 * u, y: 36 * u))
                path.addQuadCurve(to: CGPoint(x: 62 * u, y: 36 * u), control: CGPoint(x: 43 * u, y: 44 * u))
            }
            .stroke(WhistleTheme.charcoal.opacity(0.10), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))

            RoundedRectangle(cornerRadius: 10 * u, style: .continuous)
                .stroke(WhistleTheme.charcoal.opacity(0.10), lineWidth: 1.5 * u)
                .frame(width: 78 * u, height: 30 * u)
                .position(x: 43 * u, y: 38 * u)
        }
        .frame(width: 88 * u, height: 64 * u)
    }
}

private struct SantaHatExact: View {
    var u: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            SantaCapShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFF4B55), Color(hex: 0xC82032)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 76 * u, height: 56 * u)
                .position(x: 42 * u, y: 28 * u)
                .shadow(color: .black.opacity(0.12), radius: 4 * u, y: 2 * u)

            Capsule()
                .fill(.white)
                .frame(width: 86 * u, height: 18 * u)
                .position(x: 43 * u, y: 49 * u)
                .shadow(color: .black.opacity(0.08), radius: 3 * u, y: 2 * u)

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 13 * u, height: 13 * u)
                    .position(x: CGFloat(15 + index * 18) * u, y: 47 * u)
            }

            Circle()
                .fill(.white)
                .frame(width: 22 * u, height: 22 * u)
                .position(x: 72 * u, y: 8 * u)
                .shadow(color: .black.opacity(0.10), radius: 3 * u, y: 2 * u)
        }
        .frame(width: 90 * u, height: 72 * u)
        .rotationEffect(.degrees(11))
    }
}

private struct ChefApronDetails: View {
    var u: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15 * u, style: .continuous)
                .fill(Color.white.opacity(0.48))
                .frame(width: 72 * u, height: 34 * u)
                .position(x: 100 * u, y: 168 * u)
                .overlay {
                    RoundedRectangle(cornerRadius: 15 * u, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 2 * u)
                        .frame(width: 72 * u, height: 34 * u)
                        .position(x: 100 * u, y: 168 * u)
                }

            Capsule()
                .fill(WhistleTheme.charcoal.opacity(0.14))
                .frame(width: 31 * u, height: 4 * u)
                .position(x: 100 * u, y: 158 * u)

            Path { path in
                path.move(to: CGPoint(x: 73 * u, y: 166 * u))
                path.addQuadCurve(to: CGPoint(x: 127 * u, y: 166 * u), control: CGPoint(x: 100 * u, y: 178 * u))
            }
            .stroke(WhistleTheme.charcoal.opacity(0.12), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
        }
    }
}

private struct AstronautHelmet: View {
    var u: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 45 * u, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 8 * u)
                .frame(width: 124 * u, height: 100 * u)
                .position(x: 100 * u, y: 111 * u)
                .shadow(color: .black.opacity(0.14), radius: 6 * u, y: 3 * u)

            RoundedRectangle(cornerRadius: 38 * u, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xCDEBFF).opacity(0.30), Color(hex: 0x7BB7FF).opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 108 * u, height: 83 * u)
                .position(x: 100 * u, y: 112 * u)
                .overlay {
                    RoundedRectangle(cornerRadius: 38 * u, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 2 * u)
                        .frame(width: 108 * u, height: 83 * u)
                        .position(x: 100 * u, y: 112 * u)
                }

            Capsule()
                .fill(Color.white.opacity(0.72))
                .frame(width: 36 * u, height: 7 * u)
                .rotationEffect(.degrees(-18))
                .position(x: 75 * u, y: 82 * u)

            Circle()
                .fill(Color(hex: 0xDDEEFF))
                .frame(width: 18 * u, height: 18 * u)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 3 * u)
                }
                .position(x: 40 * u, y: 117 * u)

            Circle()
                .fill(Color(hex: 0xDDEEFF))
                .frame(width: 18 * u, height: 18 * u)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 3 * u)
                }
                .position(x: 160 * u, y: 117 * u)
        }
    }
}

private struct AstronautSuitDetails: View {
    var u: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16 * u, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .frame(width: 74 * u, height: 38 * u)
                .position(x: 100 * u, y: 158 * u)
                .overlay {
                    RoundedRectangle(cornerRadius: 16 * u, style: .continuous)
                        .stroke(WhistleTheme.charcoal.opacity(0.11), lineWidth: 1.5 * u)
                        .frame(width: 74 * u, height: 38 * u)
                        .position(x: 100 * u, y: 158 * u)
                }

            Circle()
                .fill(WhistleTheme.orange)
                .frame(width: 8 * u, height: 8 * u)
                .position(x: 84 * u, y: 156 * u)

            Circle()
                .fill(WhistleTheme.mint.darkened(0.16))
                .frame(width: 8 * u, height: 8 * u)
                .position(x: 100 * u, y: 156 * u)

            RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
                .fill(WhistleTheme.charcoal.opacity(0.62))
                .frame(width: 20 * u, height: 7 * u)
                .position(x: 119 * u, y: 156 * u)
        }
    }
}

private struct SantaCoatDetails: View {
    var u: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.88))
                .frame(width: 13 * u, height: 36 * u)
                .position(x: 100 * u, y: 166 * u)

            Capsule()
                .fill(Color(hex: 0x2D2D2D).opacity(0.82))
                .frame(width: 76 * u, height: 12 * u)
                .position(x: 100 * u, y: 166 * u)

            RoundedRectangle(cornerRadius: 4 * u, style: .continuous)
                .stroke(WhistleTheme.sunny, lineWidth: 3 * u)
                .frame(width: 22 * u, height: 14 * u)
                .position(x: 100 * u, y: 166 * u)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6 * u, height: 6 * u)
                    .position(x: 100 * u, y: CGFloat(153 + index * 13) * u)
            }
        }
    }
}

private struct SantaCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY * 0.92))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.84, y: rect.minY + rect.height * 0.06),
            control1: CGPoint(x: rect.width * 0.34, y: rect.height * 0.20),
            control2: CGPoint(x: rect.width * 0.58, y: -rect.height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.72, y: rect.maxY * 0.86),
            control1: CGPoint(x: rect.width * 0.95, y: rect.height * 0.30),
            control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.66)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY * 0.92),
            control: CGPoint(x: rect.width * 0.38, y: rect.height * 1.04)
        )
        path.closeSubpath()
        return path
    }
}
