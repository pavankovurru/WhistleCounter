import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CookingSession.completedAt, order: .reverse) private var sessions: [CookingSession]

    @Bindable var settings: AppSettings
    var onRerun: (CookingSession) -> Void
    @State private var editingSession: CookingSession?
    @State private var pendingDeleteSession: CookingSession?
    @State private var actionSession: CookingSession?
    @State private var confirmingClearAll = false

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if sessions.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .frame(height: max(280, proxy.size.height - 176), alignment: .center)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                if let first = sessions.first {
                                    ShareableSessionCard(session: first)
                                }

                                VStack(spacing: 10) {
                                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                        HistoryRow(session: session, colorIndex: index, dark: dark) {
                                            onRerun(session)
                                        } onEdit: {
                                            editingSession = session
                                        } onDelete: {
                                            pendingDeleteSession = session
                                        } onSave: {
                                            saveAsCookbook(session)
                                        } onLongPress: {
                                            actionSession = session
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .scale(scale: 0.88)).combined(with: .opacity)
                                        ))
                                    }
                                }
                                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: sessions.map(\.id))
                            }
                            .padding(.bottom, 106)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
            }

            if confirmingClearAll {
                DeleteConfirmationOverlay(
                    title: "Clear all history?",
                    message: "This removes every cooking adventure from History. Your saved cookbooks stay safe.",
                    confirmTitle: "Clear All",
                    dark: dark,
                    haptics: settings.hapticsEnabled,
                    onCancel: { confirmingClearAll = false },
                    onConfirm: clearAll
                )
                .transition(.opacity)
                .zIndex(4)
            }

            if let actionSession {
                AppActionSheetOverlay(
                    title: actionSession.title,
                    subtitle: actionSession.summary,
                    emoji: actionSession.emoji,
                    actions: historyActions(for: actionSession),
                    dark: dark,
                    haptics: settings.hapticsEnabled,
                    onDismiss: { self.actionSession = nil }
                )
                .transition(.opacity)
                .zIndex(5)
            }

            if let pendingDeleteSession {
                DeleteConfirmationOverlay(
                    title: "Delete this item?",
                    message: "\(pendingDeleteSession.title) will be removed from History.",
                    confirmTitle: "Delete",
                    dark: dark,
                    haptics: settings.hapticsEnabled,
                    onCancel: { self.pendingDeleteSession = nil },
                    onConfirm: { delete(pendingDeleteSession) }
                )
                .transition(.opacity)
                .zIndex(6)
            }
        }
        .sheet(item: $editingSession) { session in
            HistoryEditorSheet(session: session, dark: dark)
                .presentationDetents([.height(250)])
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Past adventures")
                    .font(.nunito(13, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .textCase(.uppercase)
                Text("History")
                    .font(.fredoka(32, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
            }

            Spacer()

            if !sessions.isEmpty {
                ChunkyButton(
                    title: "Clear All",
                    systemImage: "trash.fill",
                    color: WhistleTheme.orange,
                    fontSize: 13,
                    horizontalPadding: 12,
                    verticalPadding: 9,
                    cornerRadius: 18
                ) {
                    confirmingClearAll = true
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            WhistlyMascot(
                state: .idle,
                theme: MascotTheme.resolved(from: settings.mascotTheme),
                size: 150,
                showsSteamPuffs: false,
                isAnimated: false
            )
            Text("No cooking history yet")
                .font(.fredoka(22, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
            Text("Let's get steaming! 🫕")
                .font(.nunito(14, weight: .bold))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
        }
    }

    private func delete(_ session: CookingSession) {
        pendingDeleteSession = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            modelContext.delete(session)
        }
    }

    private func clearAll() {
        confirmingClearAll = false
        let sessionsToDelete = sessions
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            sessionsToDelete.forEach(modelContext.delete)
        }
    }

    private func saveAsCookbook(_ session: CookingSession) {
        let name = session.title
        let target = session.targetWhistles ?? (session.whistleCount > 0 ? session.whistleCount : nil)
        let duration = session.timerDuration
        // Repeat taps must not pile up duplicate cookbooks.
        let existing = (try? modelContext.fetch(FetchDescriptor<Cookbook>())) ?? []
        guard !existing.contains(where: { $0.name == name && $0.whistleTarget == target && $0.timerDuration == duration }) else {
            HapticManager.tap(enabled: settings.hapticsEnabled)
            return
        }
        HapticManager.success(enabled: settings.hapticsEnabled)
        modelContext.insert(Cookbook(
            name: name,
            whistleTarget: target,
            timerDuration: duration,
            notes: "Saved from history.",
            emoji: session.emoji
        ))
    }

    private func historyActions(for session: CookingSession) -> [AppActionSheetAction] {
        [
            AppActionSheetAction(title: "Cook Again", systemImage: "arrow.clockwise", color: WhistleTheme.mint) {
                onRerun(session)
            },
            AppActionSheetAction(title: "Edit Name", systemImage: "pencil", color: WhistleTheme.sunny) {
                editingSession = session
            },
            AppActionSheetAction(title: "Save to Cookbook", systemImage: "square.and.arrow.down.fill", color: WhistleTheme.blue) {
                saveAsCookbook(session)
            },
            AppActionSheetAction(title: "Delete", systemImage: "trash.fill", color: WhistleTheme.orange, isDestructive: true) {
                pendingDeleteSession = session
            }
        ]
    }
}

struct HistoryRow: View {
    var session: CookingSession
    var colorIndex: Int
    var dark: Bool
    var onRerun: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onSave: () -> Void
    var onLongPress: () -> Void
    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            swipeButtons

            rowContent
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
                .simultaneousGesture(
                    ExclusiveGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                guard horizontalOffset == 0 else { return }
                                onLongPress()
                            },
                        TapGesture()
                            .onEnded {
                                if horizontalOffset < 0 {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                        horizontalOffset = 0
                                    }
                                } else {
                                    onRerun()
                                }
                            }
                    )
                )

            // Sits outside rowContent so the parent TapGesture never fires
            // when the 3-dot is tapped — same pattern as CookbookCard.
            Button(action: onLongPress) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 34, height: 34)
                    .background(WhistleTheme.sunny, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 24)
            .offset(x: horizontalOffset)
            .opacity(horizontalOffset == 0 ? 1 : 0)
            .allowsHitTesting(horizontalOffset == 0)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(session.emoji)
                .font(.title2)
                .frame(width: 54, height: 54)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(iconColor)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(iconStrokeColor, lineWidth: 1)
                        }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.fredoka(16, weight: .black))
                    .foregroundStyle(WhistleTheme.text(dark: dark))
                Text("\(session.completedAt.historyDateText) • \(session.summary)")
                    .font(.nunito(12, weight: .black))
                    .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                    .lineLimit(2)
            }

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                            lineWidth: 1
                        )
                }
        }
    }

    private var swipeButtons: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 54, height: 54)
                    .background(WhistleTheme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(WhistleTheme.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 8)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let translation = value.translation.width
                if translation < 0 {
                    horizontalOffset = max(-128, translation)
                } else if horizontalOffset < 0 {
                    horizontalOffset = min(0, -128 + translation)
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    horizontalOffset = horizontalOffset < -56 ? -128 : 0
                }
            }
    }

    private var iconColor: Color {
        HistoryPalette.color(for: colorIndex)
    }

    private var iconStrokeColor: Color {
        HistoryPalette.strokeColor(for: colorIndex)
    }

    private var iconForegroundColor: Color {
        HistoryPalette.foregroundColor(for: colorIndex)
    }
}

struct HistoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var session: CookingSession
    var dark: Bool
    @State private var draftName: String

    init(session: CookingSession, dark: Bool) {
        self.session = session
        self.dark = dark
        _draftName = State(initialValue: session.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit History")
                .font(.fredoka(24, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))

            TextField("Cook name", text: $draftName)
                .font(.fredoka(18, weight: .bold))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .padding(14)
                .background(WhistleTheme.card(dark: dark), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            ChunkyButton(title: "Done", systemImage: "checkmark", color: WhistleTheme.mint, fullWidth: true) {
                commitAndDismiss()
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WhistleTheme.background(dark: dark))
    }

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedDraftName.isEmpty
    }

    private func commitAndDismiss() {
        guard canSave else { return }
        session.cookbookName = trimmedDraftName
        dismiss()
    }
}

struct ShareableSessionCard: View {
    var session: CookingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's brag")
                .font(.fredoka(12, weight: .black))
                .foregroundStyle(.white.opacity(0.82))
                .textCase(.uppercase)
            Text("I cooked \(session.title) with \(session.summary)!")
                .font(.fredoka(22, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(3)
            ShareLink(item: "I cooked \(session.title) with Whistly: \(session.summary).") {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.fredoka(12, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: [WhistleTheme.sunny, WhistleTheme.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .bottomTrailing) {
            Text(session.emoji)
                .font(.system(size: 72))
                .opacity(0.22)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
