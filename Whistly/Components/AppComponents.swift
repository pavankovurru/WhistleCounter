import SwiftUI

struct PlayfulScreenBackground: View {
    var dark: Bool

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)

            // Yellow ambient glow anchored in top-left corner — center is off-screen,
            // only the soft aura bleeds in
            Circle()
                .fill(WhistleTheme.sunny.opacity(dark ? 0.22 : 0.32))
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: -180, y: -270)

            // Mint ambient glow anchored in bottom-right corner
            Circle()
                .fill(WhistleTheme.mint.opacity(dark ? 0.18 : 0.26))
                .frame(width: 340, height: 340)
                .blur(radius: 60)
                .offset(x: 170, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct FlowNavigationBar: View {
    var title: String
    var dark: Bool
    var haptics: Bool
    var onBack: () -> Void
    var onReset: () -> Void

    var body: some View {
        ZStack {
            HStack {
                navButton(systemImage: "chevron.left", action: onBack)
                Spacer()
                navButton(systemImage: "arrow.counterclockwise", action: onReset)
            }

            Text(title)
                .font(.fredoka(19, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background {
                    ZStack {
                        Capsule()
                            .fill(WhistleTheme.charcoal.darkened(0.42).opacity(dark ? 0.70 : 0.60))
                            .offset(y: 2.5)
                        Capsule()
                            .fill(WhistleTheme.charcoal)
                    }
                }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(height: 70)
        .zIndex(2)
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap(enabled: haptics)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .frame(width: 46, height: 46)
                .background {
                    ZStack {
                        Circle()
                            .fill(navButtonFill.darkened(0.42).opacity(dark ? 0.58 : 0.68))
                            .offset(y: 3)
                        Circle()
                            .fill(navButtonFill)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var navButtonFill: Color {
        WhistleTheme.sunny
    }

}

struct ChunkyButton: View {
    var title: String
    var systemImage: String?
    var emoji: String?
    var color: Color = WhistleTheme.orange
    var shadowColor: Color? = nil
    var fontSize: CGFloat = 17
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 14
    var cornerRadius: CGFloat = 24
    var fullWidth = false
    var activeGlow = false
    var minTitleWidth: CGFloat? = nil
    var iconWidth: CGFloat? = nil
    var action: () -> Void

    @State private var pressed = false
    @State private var glowPulse = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                pressed = false
                action()
            }
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: iconWidth)
                }
                if let emoji {
                    Text(emoji)
                        .frame(width: iconWidth)
                }
                Text(title)
                    .frame(minWidth: minTitleWidth)
            }
            .font(.fredoka(fontSize, weight: .bold))
            .foregroundStyle(color == WhistleTheme.sunny || color == WhistleTheme.mint ? WhistleTheme.charcoal : .white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(shadowColor ?? color.darkened(0.42).opacity(0.72))
                        .offset(y: pressed ? 2 : 5.5)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                        .overlay {
                            if activeGlow {
                                RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                                    .strokeBorder(.white.opacity(glowPulse ? 0.42 : 0.16), lineWidth: 1.6)
                                    .padding(2)
                            }
                        }
                }
            }
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: glowPulse)
            .onAppear {
                if activeGlow {
                    glowPulse = true
                }
            }
            .onChange(of: activeGlow) { _, isActive in
                glowPulse = false
                if isActive {
                    DispatchQueue.main.async {
                        glowPulse = true
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct DeleteConfirmationOverlay: View {
    var title: String
    var message: String
    var confirmTitle: String
    var dark: Bool
    var haptics: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay {
                    Color.black.opacity(dark ? 0.50 : 0.24)
                        .ignoresSafeArea()
                }
                .onTapGesture(perform: cancel)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(WhistleTheme.orange.darkened(0.38).opacity(0.55))
                        .frame(width: 72, height: 72)
                        .offset(y: 4)
                    Circle()
                        .fill(WhistleTheme.orange)
                        .frame(width: 72, height: 72)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 7) {
                    Text(title)
                        .font(.fredoka(25, weight: .black))
                        .foregroundStyle(WhistleTheme.text(dark: dark))
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.nunito(14, weight: .black))
                        .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button(action: cancel) {
                        Text("Keep")
                            .font(.fredoka(16, weight: .black))
                            .foregroundStyle(WhistleTheme.charcoal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(WhistleTheme.mint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: confirm) {
                        Text(confirmTitle)
                            .font(.fredoka(16, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(WhistleTheme.orange, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(WhistleTheme.card(dark: dark))
                    .shadow(color: WhistleTheme.raisedShadow(dark: dark), radius: 18, y: 8)
            }
            .padding(.horizontal, 28)
            .scaleEffect(visible ? 1 : 0.88)
            .opacity(visible ? 1 : 0)
        }
        .onAppear {
            HapticManager.warning(enabled: haptics)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                visible = true
            }
        }
    }

    private func cancel() {
        HapticManager.tap(enabled: haptics)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onCancel()
        }
    }

    private func confirm() {
        HapticManager.warning(enabled: haptics)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onConfirm()
        }
    }
}

struct AppActionSheetAction: Identifiable {
    let id = UUID()
    var title: String
    var systemImage: String
    var color: Color
    var isDestructive = false
    var action: () -> Void
}

struct AppActionSheetOverlay: View {
    var title: String
    var subtitle: String
    var emoji: String
    var actions: [AppActionSheetAction]
    var dark: Bool
    var haptics: Bool
    var onDismiss: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay {
                    Color.black.opacity(dark ? 0.44 : 0.22)
                        .ignoresSafeArea()
                }
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    headerIcon

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.fredoka(23, weight: .black))
                            .foregroundStyle(WhistleTheme.text(dark: dark))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(subtitle)
                            .font(.nunito(13, weight: .black))
                            .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                            .lineLimit(2)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(actions) { item in
                        actionRow(item)
                    }
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(WhistleTheme.card(dark: dark))
                    .shadow(color: WhistleTheme.raisedShadow(dark: dark), radius: 18, y: 8)
            }
            .padding(.horizontal, 24)
            .scaleEffect(visible ? 1 : 0.88)
            .opacity(visible ? 1 : 0)
        }
        .onAppear {
            HapticManager.tap(enabled: haptics)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                visible = true
            }
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        if emoji.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("idly") == .orderedSame {
            IdlyPiecesIcon(size: 43)
                .frame(width: 58, height: 58)
                .background(WhistleTheme.sunny, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 58, height: 58)
                .background(WhistleTheme.sunny, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func actionRow(_ item: AppActionSheetAction) -> some View {
        Button {
            perform(item.action, warning: item.isDestructive)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(item.color == WhistleTheme.sunny || item.color == WhistleTheme.mint ? WhistleTheme.charcoal : .white)
                    .frame(width: 42, height: 42)
                    .background(item.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(item.title)
                    .font(.fredoka(17, weight: .black))
                    .foregroundStyle(item.isDestructive ? WhistleTheme.orange : WhistleTheme.text(dark: dark))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
            }
            .padding(10)
            .background(WhistleTheme.background(dark: dark), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dismiss() {
        HapticManager.tap(enabled: haptics)
        close()
    }

    private func perform(_ action: @escaping () -> Void, warning: Bool) {
        if warning {
            HapticManager.warning(enabled: haptics)
        } else {
            HapticManager.tap(enabled: haptics)
        }
        close(after: action)
    }

    private func close(after action: (() -> Void)? = nil) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            onDismiss()
            action?()
        }
    }
}

struct ChipButton: View {
    var title: String
    var active: Bool
    var dark = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.fredoka(14, weight: .bold))
                .foregroundStyle(active ? WhistleTheme.charcoal : WhistleTheme.secondaryText(dark: dark))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    let fill = active ? WhistleTheme.sunny : WhistleTheme.card(dark: dark)
                    ZStack {
                        Capsule()
                            .fill(active ? fill.darkened(0.38).opacity(0.64) : WhistleTheme.shadow(dark: dark))
                            .offset(y: active ? 2.5 : 1.2)
                        Capsule()
                            .fill(fill)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct BottomTabBar: View {
    @Binding var activeTab: AppTab
    var dark: Bool
    var haptics: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases) { tab in
                        Button {
                            HapticManager.tap(enabled: haptics)
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                activeTab = tab
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: activeTab == tab ? tab.selectedIcon : tab.icon)
                                    .font(.system(size: 18, weight: .bold))
                                Text(tab.title)
                                    .font(.fredoka(10, weight: .black))
                            }
                            .foregroundStyle(activeTab == tab ? WhistleTheme.charcoal : WhistleTheme.secondaryText(dark: dark))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                if activeTab == tab {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(WhistleTheme.sunny.darkened(0.38).opacity(0.62))
                                            .offset(y: 2.5)
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(WhistleTheme.sunny)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(dark ? Color(hex: 0x252542) : .white)
                        .shadow(color: dark ? .black.opacity(0.62) : WhistleTheme.charcoal.opacity(0.18), radius: 11, x: 0, y: 4)
                        .shadow(color: dark ? .black.opacity(0.40) : WhistleTheme.charcoal.opacity(0.10), radius: 2, x: 0, y: 2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, max(-6, proxy.safeAreaInsets.bottom - 40))
            }
        }
        .frame(height: 82)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct SlotPickerView: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String
    var tint: Color
    var haptics: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                HapticManager.tap(enabled: haptics)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    value = max(range.lowerBound, value - 1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 36, height: 36)
                    .background(WhistleTheme.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(title)
                .font(.nunito(13, weight: .bold))
                .foregroundStyle(Color(hex: 0x8A7A6A))

            Text("\(value)")
                .font(.fredoka(28, weight: .black))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .frame(minWidth: 38)

            Text(suffix)
                .font(.nunito(13, weight: .bold))

            Button {
                HapticManager.tap(enabled: haptics)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    value = min(range.upperBound, value + 1)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 36, height: 36)
                    .background(WhistleTheme.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .foregroundStyle(tint)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.darkened(0.36).opacity(0.52))
                .offset(y: 3)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        }
    }
}

struct RecentSetupsStrip: View {
    var cookbooks: [Cookbook]
    var mode: CookbookMode
    var onSelect: (Cookbook) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filtered.prefix(5)) { cookbook in
                    Button {
                        onSelect(cookbook)
                    } label: {
                        HStack(spacing: 7) {
                            Text(cookbook.emoji)
                            Text(cookbook.name)
                                .lineLimit(1)
                            Text(cookbook.detailText)
                                .foregroundStyle(Color(hex: 0x8A7A6A))
                        }
                        .font(.fredoka(13, weight: .bold))
                        .foregroundStyle(WhistleTheme.charcoal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.black.opacity(0.16))
                                    .offset(y: 2.5)
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
        }
    }

    private var filtered: [Cookbook] {
        cookbooks
            .filter {
                switch mode {
                case .whistles: $0.whistleTarget != nil
                case .timers: $0.timerDuration != nil
                default: true
                }
            }
            .sorted {
                ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt)
            }
    }
}

struct ConfettiView: View {
    @State private var animate = false
    private let colors = [WhistleTheme.sunny, WhistleTheme.orange, WhistleTheme.mint, WhistleTheme.rose, WhistleTheme.blue]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<46, id: \.self) { index in
                    ConfettiPiece(index: index, color: colors[index % colors.count], animate: animate, size: proxy.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: View {
    var index: Int
    var color: Color
    var animate: Bool
    var size: CGSize

    var body: some View {
        let width = 8 + CGFloat(index % 4)
        let height = 12 + CGFloat(index % 3)
        let rotation = animate ? Double(index * 37 + 220) : Double(index * 11)
        let x = animate ? CGFloat((index * 53) % max(1, Int(size.width))) - size.width / 2 : 0
        let y = animate ? size.height * 0.72 : -size.height * 0.45

        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .opacity(animate ? 0 : 1)
            .animation(.easeIn(duration: 2.7).delay(Double(index % 9) * 0.045), value: animate)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case cookbooks
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .cookbooks: "Cookbooks"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "fork.knife"
        case .cookbooks: "menucard"
        case .history: "clock"
        case .settings: "slider.horizontal.3"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "fork.knife.circle.fill"
        case .cookbooks: "menucard.fill"
        case .history: "clock.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}
