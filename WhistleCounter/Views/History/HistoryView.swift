import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CookingSession.completedAt, order: .reverse) private var sessions: [CookingSession]

    @Bindable var settings: AppSettings
    var onRerun: (CookingSession) -> Void
    @State private var editingSession: CookingSession?

    private var dark: Bool { settings.darkModeEnabled || colorScheme == .dark }

    var body: some View {
        ZStack {
            WhistleTheme.background(dark: dark)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if let first = sessions.first {
                        ShareableSessionCard(session: first)
                    }

                    if sessions.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 56)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                HistoryRow(session: session, colorIndex: index, dark: dark) {
                                    onRerun(session)
                                } onEdit: {
                                    editingSession = session
                                } onDelete: {
                                    delete(session)
                                } onSave: {
                                    modelContext.insert(Cookbook(
                                        name: session.title,
                                        whistleTarget: session.targetWhistles ?? (session.whistleCount > 0 ? session.whistleCount : nil),
                                        timerDuration: session.timerDuration,
                                        notes: "Saved from history.",
                                        emoji: session.emoji
                                    ))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 106)
            }
        }
        .sheet(item: $editingSession) { session in
            HistoryEditorSheet(session: session, dark: dark)
                .presentationDetents([.height(250)])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Past adventures")
                .font(.nunito(13, weight: .black))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
                .textCase(.uppercase)
            Text("History")
                .font(.fredoka(32, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            WhistlyMascot(state: .idle, theme: MascotTheme.resolved(from: settings.mascotTheme), size: 150)
            Text("No cooking history yet")
                .font(.fredoka(22, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))
            Text("Let's get steaming! 🫕")
                .font(.nunito(14, weight: .bold))
                .foregroundStyle(WhistleTheme.secondaryText(dark: dark))
        }
    }

    private func delete(_ session: CookingSession) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            modelContext.delete(session)
        }
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
    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            swipeButtons

            rowContent
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
                .onTapGesture {
                    if horizontalOffset < 0 {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            horizontalOffset = 0
                        }
                    } else {
                        onRerun()
                    }
                }
                .contextMenu {
                    Button("Cook Again", systemImage: "arrow.clockwise", action: onRerun)
                    Button("Edit Name", systemImage: "pencil", action: onEdit)
                    Button("Save as Cookbook", systemImage: "square.and.arrow.down", action: onSave)
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                }
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

            Menu {
                Button("Cook Again", systemImage: "arrow.clockwise", action: onRerun)
                Button("Edit Name", systemImage: "pencil", action: onEdit)
                Button("Save as Cookbook", systemImage: "square.and.arrow.down", action: onSave)
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(WhistleTheme.charcoal)
                    .frame(width: 34, height: 34)
                    .background(WhistleTheme.sunny, in: Circle())
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WhistleTheme.card(dark: dark))
                .shadow(color: WhistleTheme.shadow(dark: dark), radius: 7, y: 3)
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

    private var shareText: String {
        "I cooked \(session.title) with WhistleCounter: \(session.summary)."
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
    @Bindable var session: CookingSession
    var dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit History")
                .font(.fredoka(24, weight: .black))
                .foregroundStyle(WhistleTheme.text(dark: dark))

            TextField("Cook name", text: nameBinding)
                .font(.fredoka(18, weight: .bold))
                .foregroundStyle(WhistleTheme.text(dark: dark))
                .padding(14)
                .background(WhistleTheme.card(dark: dark), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            ChunkyButton(title: "Done", systemImage: "checkmark", color: WhistleTheme.mint, fullWidth: true) {
                dismiss()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WhistleTheme.background(dark: dark))
    }

    private var nameBinding: Binding<String> {
        Binding {
            session.title
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            session.cookbookName = trimmed.isEmpty ? nil : newValue
        }
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
            ShareLink(item: "I cooked \(session.title) with WhistleCounter: \(session.summary).") {
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [WhistleTheme.sunny, WhistleTheme.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: WhistleTheme.orange.darkened(0.24).opacity(0.42), radius: 12, y: 6)
        )
        .overlay(alignment: .bottomTrailing) {
            Text(session.emoji)
                .font(.system(size: 84))
                .opacity(0.25)
                .offset(x: 8, y: 18)
        }
    }
}
