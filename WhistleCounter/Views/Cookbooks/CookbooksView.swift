import SwiftData
import SwiftUI

struct CookbooksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Cookbook.createdAt, order: .reverse) private var cookbooks: [Cookbook]

    @Bindable var settings: AppSettings
    var onCook: (Cookbook) -> Void

    @State private var filter: CookbookMode = .all
    @State private var editorCookbook: Cookbook?
    @State private var showEditor = false
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
                            ForEach(filteredCookbooks) { cookbook in
                                CookbookCard(
                                    cookbook: cookbook,
                                    dark: dark,
                                    onCook: { onCook(cookbook) },
                                    onEdit: {
                                        editorCookbook = cookbook
                                        showEditor = true
                                    },
                                    onDelete: {
                                        pendingDeleteCookbook = cookbook
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
        .sheet(isPresented: $showEditor) {
            CookbookEditorSheet(settings: settings, cookbook: editorCookbook) { draft in
                if let editorCookbook {
                    editorCookbook.name = draft.name
                    editorCookbook.emoji = draft.emoji
                    editorCookbook.whistleTarget = draft.whistleTarget
                    editorCookbook.timerDuration = draft.timerDuration
                    editorCookbook.notes = draft.notes
                } else {
                    modelContext.insert(draft)
                }
                self.editorCookbook = nil
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
                color: WhistleTheme.orange,
                fontSize: 14.3,
                horizontalPadding: 13.2,
                verticalPadding: 9.9,
                cornerRadius: 19.8
            ) {
                editorCookbook = nil
                showEditor = true
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
        editorCookbook = cookbook
        showEditor = true
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
            case .whistles: cookbook.whistleTarget != nil && cookbook.timerDuration == nil
            case .timers: cookbook.timerDuration != nil && cookbook.whistleTarget == nil
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
        case "soft eggs": 2
        case "chicken curry": 3
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
    var dark: Bool
    var onCook: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onLongPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardColor)
                    .frame(height: 86)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 1.2)
                    }
                    .overlay {
                        Text(cookbook.emoji)
                            .font(.system(size: 58))
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    }

                Menu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(WhistleTheme.charcoal)
                        .frame(width: 30, height: 30)
                        .background(WhistleTheme.sunny, in: Circle())
                }
                .padding(7)
            }

            Text(cookbook.name)
                .font(.fredoka(17, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: 5) {
                if let whistleTarget = cookbook.whistleTarget {
                    tag("🎙 \(whistleTarget)", color: WhistleTheme.sunny.opacity(0.65))
                }
                if let timerDuration = cookbook.timerDuration {
                    tag("⏱ \(timerDuration.shortDurationText)", color: WhistleTheme.mint.opacity(0.55))
                }
            }

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
                .padding(.top, 2)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .shadow(color: WhistleTheme.shadow(dark: dark), radius: 9, y: 4)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            onLongPress()
        }
    }

    private var cardColor: Color {
        CookbookPalette.color(for: cookbook)
    }

    private var cardStrokeColor: Color {
        CookbookPalette.strokeColor(for: cookbook)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.fredoka(11, weight: .black))
            .foregroundStyle(WhistleTheme.charcoal)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    @State private var setupMode = CookbookSetupMode.whistles
    @State private var whistleTarget = 3
    @State private var minutes = 15
    @State private var notes = ""

    private let emojis = [
        "🍲", "🍛", "🫘", "🥚", "🍗", "🍖", "🥘", "🥣", "🍜", "🍝",
        "🍚", "🍙", "🍘", "🥟", "🥗", "🥬", "🥦", "🥕", "🌽", "🥔",
        "🍠", "🫛", "🧄", "🧅", "🌶", "🍅", "🥥", "🍋", "🥭", "🍌",
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        editorHeader
                        dishCard
                        setupCard
                        notesCard
                        saveButton
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(WhistleTheme.orange)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.fredoka(14, weight: .black))
                            .foregroundStyle(WhistleTheme.charcoal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(WhistleTheme.sunny, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear {
                guard let cookbook else { return }
                name = cookbook.name
                emoji = cookbook.emoji
                setupMode = cookbook.timerDuration != nil && cookbook.whistleTarget == nil ? .timer : .whistles
                whistleTarget = cookbook.whistleTarget ?? 3
                minutes = Int((cookbook.timerDuration ?? 15 * 60) / 60)
                notes = cookbook.notes
            }
        }
        .background(WhistleTheme.background(dark: dark))
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cookbook == nil ? "New recipe" : "Edit recipe")
                .font(.nunito(13, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .textCase(.uppercase)
            Text(cookbook == nil ? "Add Cookbook" : "Tune Cookbook")
                .font(.fredoka(32, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
            Text("Save one simple setup: either whistles or a timer.")
                .font(.nunito(14, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
        }
    }

    private var dishCard: some View {
        editorCard(title: "Dish", icon: "fork.knife", tint: WhistleTheme.mint) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 25))
                    .frame(width: 52, height: 52)
                    .background(WhistleTheme.charcoal, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: WhistleTheme.shadow(dark: dark), radius: 4, y: 2)

                TextField("Toor dal, soft eggs...", text: $name)
                    .font(.fredoka(20, weight: .bold))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
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

    private var setupCard: some View {
        editorCard(title: "Setup", icon: setupMode == .whistles ? "mic.fill" : "timer", tint: accentColor) {
            HStack(spacing: 10) {
                setupModeButton(.whistles)
                setupModeButton(.timer)
            }

            HStack(spacing: 14) {
                valueButton(systemImage: "minus") {
                    adjustSetupValue(by: -1)
                }

                VStack(spacing: 2) {
                    Text(setupMode == .whistles ? "\(whistleTarget)" : "\(minutes)")
                        .font(.fredoka(42, weight: .black))
                        .foregroundStyle(WhistleTheme.charcoal)
                    Text(setupMode == .whistles ? "whistles" : "minutes")
                        .font(.nunito(13, weight: .black))
                        .foregroundStyle(WhistleTheme.charcoal.opacity(0.72))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(valuePanelColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                valueButton(systemImage: "plus") {
                    adjustSetupValue(by: 1)
                }
            }
        }
    }

    private var notesCard: some View {
        editorCard(title: "Notes", icon: "text.alignleft", tint: WhistleTheme.mint) {
            TextEditor(text: $notes)
                .font(.nunito(16, weight: .bold))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .frame(minHeight: 96)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(WhistleTheme.background(dark: dark), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var saveButton: some View {
        ChunkyButton(
            title: cookbook == nil ? "Save Cookbook" : "Save Changes",
            systemImage: "checkmark",
            color: WhistleTheme.mint,
            fontSize: 19,
            horizontalPadding: 18,
            verticalPadding: 17,
            cornerRadius: 26,
            fullWidth: true
        ) {
            saveDraft()
        }
        .padding(.top, 2)
    }

    private func editorCard<Content: View>(title: String, icon: String, tint: Color, fill: Color? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(iconForegroundColor(for: tint))
                    .frame(width: 34, height: 34)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.fredoka(19, weight: .black))
                    .foregroundStyle(fill == nil ? WhistleTheme.text(dark: dark) : WhistleTheme.charcoal)
            }

            content()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(fill ?? WhistleTheme.card(dark: dark))
                .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
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
                    let fill = emoji == option ? editorPaletteColor(for: index) : WhistleTheme.charcoal
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(emoji == option ? fill.darkened(0.38).opacity(0.62) : .black.opacity(0.58))
                            .offset(y: emoji == option ? 2.5 : 1.2)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(fill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(emoji == option ? 0.24 : 0.10), lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func setupModeButton(_ mode: CookbookSetupMode) -> some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            setupMode = mode
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode == .whistles ? "mic.fill" : "timer")
                Text(mode.title)
            }
            .font(.fredoka(15, weight: .black))
            .foregroundStyle(setupMode == mode ? setupModeForeground(for: mode) : WhistleTheme.secondaryText(dark: dark))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                let fill = setupMode == mode ? setupModeColor(for: mode) : WhistleTheme.background(dark: dark)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(setupMode == mode ? fill.darkened(0.38).opacity(0.62) : WhistleTheme.shadow(dark: dark))
                        .offset(y: setupMode == mode ? 2.5 : 1.2)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func valueButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(WhistleTheme.charcoal)
                .frame(width: 52, height: 58)
                .background(accentColor.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My Cookbook" : trimmed
    }

    private var setupSummary: String {
        setupMode == .whistles ? "\(whistleTarget) whistles" : "\(minutes) minutes"
    }

    private var accentColor: Color {
        setupMode == .whistles ? WhistleTheme.orange : WhistleTheme.mint
    }

    private var valuePanelColor: Color {
        setupMode == .whistles ? WhistleTheme.cream : WhistleTheme.mint.lightened(0.12)
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

    private func adjustSetupValue(by delta: Int) {
        if setupMode == .whistles {
            whistleTarget = min(20, max(1, whistleTarget + delta))
        } else {
            minutes = min(180, max(1, minutes + delta))
        }
    }

    private func saveDraft() {
        let draft = Cookbook(
            id: cookbook?.id ?? UUID(),
            name: displayName,
            whistleTarget: setupMode == .whistles ? whistleTarget : nil,
            timerDuration: setupMode == .timer ? TimeInterval(minutes * 60) : nil,
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
