import SwiftData
import SwiftUI

struct CookbooksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Cookbook.createdAt, order: .reverse) private var cookbooks: [Cookbook]

    @Bindable var settings: AppSettings
    var onCook: (Cookbook) -> Void

    // Identifiable wrapper so the editor uses sheet(item:) — presenting via a
    // separate isPresented flag can race the state write and open a blank editor.
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let cookbook: Cookbook?
    }

    @State private var filter: CookbookMode = .all
    @State private var editorTarget: EditorTarget?
    @State private var pendingDeleteCookbook: Cookbook?
    @State private var actionCookbook: Cookbook?

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CookbookMode.allCases) { mode in
                            ChipButton(title: mode.rawValue, active: filter == mode, dark: dark) {
                                HapticManager.tap(enabled: settings.hapticsEnabled)
                                filter = mode
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                }

                ScrollView(showsIndicators: false) {
                    if filteredCookbooks.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(filteredCookbooks.enumerated()), id: \.element.id) { index, cookbook in
                                CookbookCard(
                                    cookbook: cookbook,
                                    colorIndex: index,
                                    dark: dark,
                                    onCook: { onCook(cookbook) },
                                    onEdit: {
                                        edit(cookbook)
                                    },
                                    onDelete: {
                                        pendingDeleteCookbook = cookbook
                                    },
                                    onActions: {
                                        actionCookbook = cookbook
                                    },
                                    onLongPress: {
                                        actionCookbook = cookbook
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                                    removal: .scale(scale: 0.82).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: filteredCookbooks.map(\.id))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 106)
                    }
                }
            }

            if let actionCookbook {
                AppActionSheetOverlay(
                    title: actionCookbook.name,
                    subtitle: actionCookbook.detailText,
                    emoji: actionCookbook.emoji,
                    actions: cookbookActions(for: actionCookbook),
                    dark: dark,
                    haptics: settings.hapticsEnabled,
                    onDismiss: { self.actionCookbook = nil }
                )
                .transition(.opacity)
                .zIndex(3)
            }

            if let pendingDeleteCookbook {
                DeleteConfirmationOverlay(
                    title: "Delete cookbook?",
                    message: "\(pendingDeleteCookbook.name) will be removed from your saved cookbooks.",
                    confirmTitle: "Delete",
                    dark: dark,
                    haptics: settings.hapticsEnabled,
                    onCancel: { self.pendingDeleteCookbook = nil },
                    onConfirm: { delete(pendingDeleteCookbook) }
                )
                .transition(.opacity)
                .zIndex(4)
            }
        }
        .sheet(item: $editorTarget) { target in
            CookbookEditorSheet(settings: settings, cookbook: target.cookbook) { draft in
                if let cookbook = target.cookbook {
                    cookbook.name = draft.name
                    cookbook.emoji = draft.emoji
                    cookbook.whistleTarget = draft.whistleTarget
                    cookbook.timerDuration = draft.timerDuration
                    cookbook.notes = draft.notes
                } else {
                    modelContext.insert(draft)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(settings.darkModeEnabled ? .dark : nil)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your kitchen")
                    .font(.nunito(13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .textCase(.uppercase)
                Text("Cookbooks")
                    .font(.fredoka(32, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }
            Spacer()
            ChunkyButton(
                title: "New Cookbook",
                systemImage: "plus",
                color: WhistleTheme.sunny,
                fontSize: 14.3,
                horizontalPadding: 13.2,
                verticalPadding: 9.9,
                cornerRadius: 19.8
            ) {
                editorTarget = EditorTarget(cookbook: nil)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private func delete(_ cookbook: Cookbook) {
        pendingDeleteCookbook = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            modelContext.delete(cookbook)
        }
    }

    private func edit(_ cookbook: Cookbook) {
        editorTarget = EditorTarget(cookbook: cookbook)
    }

    private func cookbookActions(for cookbook: Cookbook) -> [AppActionSheetAction] {
        [
            AppActionSheetAction(title: "Cook This", systemImage: "flame.fill", color: WhistleTheme.mint) {
                onCook(cookbook)
            },
            AppActionSheetAction(title: "Edit", systemImage: "pencil", color: WhistleTheme.sunny) {
                edit(cookbook)
            },
            AppActionSheetAction(title: "Delete", systemImage: "trash.fill", color: WhistleTheme.orange, isDestructive: true) {
                pendingDeleteCookbook = cookbook
            }
        ]
    }

    private var filteredCookbooks: [Cookbook] {
        orderedCookbooks.filter { cookbook in
            switch filter {
            case .all: true
            // A cookbook with both setups belongs in both filters.
            case .whistles: cookbook.whistleTarget != nil
            case .timers: cookbook.timerDuration != nil
            }
        }
    }

    private var orderedCookbooks: [Cookbook] {
        cookbooks.sorted { lhs, rhs in
            let leftRank = defaultOrderRank(lhs)
            let rightRank = defaultOrderRank(rhs)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return (lhs.lastUsedAt ?? lhs.createdAt) > (rhs.lastUsedAt ?? rhs.createdAt)
        }
    }

    private func defaultOrderRank(_ cookbook: Cookbook) -> Int {
        switch cookbook.name.lowercased() {
        case "toor dal": 0
        case "rajma": 1
        case "eggs": 2
        case "idly": 3
        case "chicken": 4
        default: 100
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            WhistlyMascot(state: .reading, theme: MascotTheme.resolved(from: settings.mascotTheme), size: 150)
            Text("No cookbooks yet!")
                .font(.fredoka(22, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
            Text("Save your first cook, Chef!")
                .font(.nunito(14, weight: .bold))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
        }
    }
}

struct CookbookCard: View {
    var cookbook: Cookbook
    var colorIndex: Int
    var dark: Bool
    var onCook: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onActions: () -> Void
    var onLongPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardColor)
                    .frame(height: 82)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 1.2)
                    }
                    .overlay {
                        if cookbook.isIdly {
                            IdlyPiecesIcon(size: 64)
                        } else {
                            Text(cookbook.emoji)
                                .font(.system(size: 58))
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        }
                    }

                Button(action: onActions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(WhistleTheme.charcoal)
                        .frame(width: 30, height: 30)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(7)
            }

            titleRow

            ChunkyButton(
                title: "Cook This!",
                emoji: "🍲",
                color: WhistleTheme.orange,
                fontSize: 13,
                horizontalPadding: 10,
                verticalPadding: 9,
                cornerRadius: 16,
                fullWidth: true,
                action: onCook
            )
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                            lineWidth: 1
                        )
                }
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            onLongPress()
        }
    }

    private var cardColor: Color {
        CookbookPalette.color(for: colorIndex)
    }

    private var cardStrokeColor: Color {
        CookbookPalette.strokeColor(for: colorIndex)
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(cookbook.name)
                .font(.fredoka(17, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if let whistleTarget = cookbook.whistleTarget {
                    metricPill(systemImage: "mic.fill", title: "\(whistleTarget)", color: WhistleTheme.sunny.opacity(0.72))
                }
                if let timerDuration = cookbook.timerDuration {
                    metricPill(systemImage: "timer", title: timerDuration.shortDurationText, color: WhistleTheme.mint.opacity(0.62))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 25)
    }

    private func metricPill(systemImage: String, title: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 8.8, weight: .black))
            Text(title)
                .font(.fredoka(10.5, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
            .foregroundStyle(WhistleTheme.charcoal)
            .padding(.horizontal, 5.5)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct IdlyPiecesIcon: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            idlyPiece(width: size * 0.52, height: size * 0.36)
                .offset(x: -size * 0.16, y: size * 0.08)
            idlyPiece(width: size * 0.52, height: size * 0.36)
                .offset(x: size * 0.17, y: size * 0.09)
            idlyPiece(width: size * 0.56, height: size * 0.38)
                .offset(y: -size * 0.14)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
    }

    private func idlyPiece(width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.white, Color(hex: 0xFFF8EE), Color(hex: 0xECE4D8)],
                    center: UnitPoint(x: 0.36, y: 0.28),
                    startRadius: 1,
                    endRadius: width
                )
            )
            .frame(width: width, height: height)
            .overlay {
                Ellipse()
                    .stroke(.white.opacity(0.8), lineWidth: 1.2)
            }
    }
}

extension Cookbook {
    var isIdly: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("idly") == .orderedSame
    }
}

struct CookbookEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var settings: AppSettings
    var cookbook: Cookbook?
    var onSave: (Cookbook) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🍲"
    @State private var wantsWhistles = true
    @State private var wantsTimer = false
    @State private var whistleTarget = 3
    @State private var minutes = 15
    @State private var notes = ""

    private let emojis = [
        "🍲", "🍛", "🫘", "🥚", "🍗", "🍖", "🥘", "🥣", "🍜", "🍝",
        "🍚", "🍙", "🍘", "🥟", "🥗", "🥬", "🥦", "🥕", "🌽", "🥔",
        "🍠", "🫛", "🧄", "🧅", "🌶", "🍅",
        "🍞", "🥐", "🥯", "🫓", "🥞", "🧇", "🧀", "🍳", "🥓", "🍤",
        "🐟", "🍣", "🍱", "🥪", "🌮", "🌯", "🍕", "🍔", "☕️", "🫖",
        "🎙", "⏱"
    ]
    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ZStack {
                WhistleTheme.background(dark: dark)
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let compact = proxy.size.height < 760
                    let verticalGap: CGFloat = compact ? 4 : 6

                    VStack(alignment: .leading, spacing: 0) {
                        editorTopRow(compact: compact)
                        Spacer(minLength: verticalGap)
                        dishCard(compact: compact)
                        Spacer(minLength: verticalGap)
                        setupCard(compact: compact)
                        Spacer(minLength: verticalGap)
                        notesCard(compact: compact)
                        Spacer(minLength: verticalGap)
                        saveButton(compact: compact)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, compact ? 18 : 26)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard let cookbook else { return }
                name = cookbook.name
                emoji = cookbook.emoji
                wantsWhistles = cookbook.whistleTarget != nil
                wantsTimer = cookbook.timerDuration != nil
                if !wantsWhistles && !wantsTimer {
                    wantsWhistles = true
                }
                whistleTarget = cookbook.whistleTarget ?? 3
                minutes = max(1, Int((cookbook.timerDuration ?? 15 * 60) / 60))
                notes = cookbook.notes
            }
        }
        .background(WhistleTheme.background(dark: dark))
    }

    private func editorTopRow(compact: Bool) -> some View {
        ZStack {
            editorHeader(compact: compact)
                .frame(maxWidth: .infinity, alignment: .center)
            closeIconButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func editorHeader(compact: Bool) -> some View {
        VStack(alignment: .center, spacing: compact ? 2 : 4) {
            Text(cookbook == nil ? "Add Cookbook" : "Tune Cookbook")
                .font(.fredoka(compact ? 28 : 32, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .multilineTextAlignment(.center)
        }
    }

    private var closeIconButton: some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .frame(width: 50, height: 50)
                .background {
                    ZStack {
                        Circle()
                            .fill(WhistleTheme.sunny.darkened(0.42).opacity(0.68))
                            .offset(y: 3)
                        Circle()
                            .fill(WhistleTheme.sunny)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func dishCard(compact: Bool) -> some View {
        editorCard(title: "Dish", icon: "fork.knife", tint: WhistleTheme.mint, compact: compact) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: compact ? 22 : 25))
                    .frame(width: compact ? 46 : 52, height: compact ? 46 : 52)
                    .background(WhistleTheme.sunny, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: WhistleTheme.shadow(dark: dark), radius: 4, y: 2)

                TextField("Toor dal, soft eggs...", text: $name)
                    .font(.fredoka(compact ? 18 : 20, weight: .bold))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 11 : 13)
                    .background(WhistleTheme.background(dark: dark), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(emojis.enumerated()), id: \.offset) { index, option in
                        emojiButton(option, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func setupCard(compact: Bool) -> some View {
        editorCard(title: "Setup", icon: "checklist", tint: accentColor, compact: compact) {
            HStack(spacing: 10) {
                setupModeButton(.whistles)
                setupModeButton(.timer)
            }

            // Both can be on: whistles first, then a follow-up timer.
            if wantsWhistles {
                valueRow(compact: compact, value: $whistleTarget, unit: "whistles", range: 1...100, panel: WhistleTheme.cream, accent: WhistleTheme.orange)
            }
            if wantsTimer {
                valueRow(compact: compact, value: $minutes, unit: "minutes", range: 1...720, panel: WhistleTheme.mint.lightened(0.12), accent: WhistleTheme.mint)
            }
        }
    }

    private func valueRow(compact: Bool, value: Binding<Int>, unit: String, range: ClosedRange<Int>, panel: Color, accent: Color) -> some View {
        HStack(spacing: compact ? 10 : 14) {
            valueButton(systemImage: "minus", color: accent) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }

            VStack(spacing: 2) {
                Text("\(value.wrappedValue)")
                    .font(.fredoka(compact ? 32 : 38, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.nunito(12, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal.opacity(0.72))
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 8 : 10)
            .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            valueButton(systemImage: "plus", color: accent) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            }
        }
    }

    private func notesCard(compact: Bool) -> some View {
        editorCard(title: "Notes", icon: "text.alignleft", tint: WhistleTheme.mint, compact: compact) {
            TextField("Tiny note, spice level, soaking time...", text: $notes, axis: .vertical)
                .font(.nunito(16, weight: .bold))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .lineLimit(compact ? 3 : 4, reservesSpace: true)
                .padding(.horizontal, 12)
                .padding(.vertical, compact ? 10 : 13)
                .background(WhistleTheme.background(dark: dark), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func saveButton(compact: Bool) -> some View {
        ChunkyButton(
            title: cookbook == nil ? "Save Cookbook" : "Save Changes",
            systemImage: "checkmark",
            color: WhistleTheme.mint,
            fontSize: 17,
            horizontalPadding: 18,
            verticalPadding: 14,
            cornerRadius: 24
        ) {
            saveDraft()
        }
        .frame(maxWidth: 235)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func editorCard<Content: View>(title: String, icon: String, tint: Color, fill: Color? = nil, compact: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(iconForegroundColor(for: tint))
                    .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.fredoka(compact ? 17 : 19, weight: .black))
                    .foregroundStyle(fill == nil ? WhistleTheme.text(dark: dark) : WhistleTheme.charcoal)
            }

            content()
        }
        .padding(compact ? 12 : 15)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(fill ?? WhistleTheme.card(dark: dark))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                            lineWidth: 1
                        )
                }
        }
    }

    private func emojiButton(_ option: String, index: Int) -> some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            emoji = option
        } label: {
            Text(option)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background {
                    let active = emoji == option
                    let fill = active ? WhistleTheme.mint : WhistleTheme.card(dark: dark)
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(active ? fill.darkened(0.38).opacity(0.62) : WhistleTheme.shadow(dark: dark))
                            .offset(y: active ? 2.5 : 1.2)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(fill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(active ? WhistleTheme.charcoal.opacity(0.12) : WhistleTheme.charcoal.opacity(dark ? 0.0 : 0.06), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func setupModeButton(_ mode: CookbookSetupMode) -> some View {
        let isActive = mode == .whistles ? wantsWhistles : wantsTimer
        return Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            toggleSetupMode(mode)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode == .whistles ? "mic.fill" : "timer")
                Text(mode.title)
            }
            .font(.fredoka(15, weight: .black))
            .foregroundStyle(isActive ? setupModeForeground(for: mode) : WhistleTheme.secondaryText(dark: dark))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                let fill = isActive ? setupModeColor(for: mode) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isActive ? fill.darkened(0.38).opacity(0.62) : WhistleTheme.shadow(dark: dark))
                        .offset(y: isActive ? 2.5 : 1.2)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleSetupMode(_ mode: CookbookSetupMode) {
        // At least one setup must stay on.
        if mode == .whistles {
            if wantsWhistles && !wantsTimer { return }
            wantsWhistles.toggle()
        } else {
            if wantsTimer && !wantsWhistles { return }
            wantsTimer.toggle()
        }
    }

    private func valueButton(systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My Cookbook" : trimmed
    }

    private var accentColor: Color {
        wantsWhistles ? WhistleTheme.orange : WhistleTheme.mint
    }

    private func setupModeColor(for mode: CookbookSetupMode) -> Color {
        mode == .whistles ? WhistleTheme.orange : WhistleTheme.mint
    }

    private func setupModeForeground(for mode: CookbookSetupMode) -> Color {
        mode == .whistles ? .white : WhistleTheme.charcoal
    }

    private func editorPaletteColor(for index: Int) -> Color {
        let colors = [WhistleTheme.orange, WhistleTheme.mint, WhistleTheme.cream, WhistleTheme.charcoal, WhistleTheme.sunny]
        return colors[index % colors.count]
    }

    private func iconForegroundColor(for tint: Color) -> Color {
        tint == WhistleTheme.orange || tint == WhistleTheme.charcoal ? .white : WhistleTheme.charcoal
    }

    private func saveDraft() {
        let draft = Cookbook(
            id: cookbook?.id ?? UUID(),
            name: displayName,
            whistleTarget: wantsWhistles ? whistleTarget : nil,
            timerDuration: wantsTimer ? TimeInterval(minutes * 60) : nil,
            notes: notes,
            emoji: emoji,
            createdAt: cookbook?.createdAt ?? Date(),
            lastUsedAt: cookbook?.lastUsedAt
        )
        onSave(draft)
        dismiss()
    }
}

private enum CookbookSetupMode: String, CaseIterable, Identifiable {
    case whistles
    case timer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whistles: "Whistles"
        case .timer: "Timer"
        }
    }
}
