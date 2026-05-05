import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Cookbook.createdAt, order: .reverse) private var cookbooks: [Cookbook]
    @Query(sort: \AppSettings.id) private var settingsRows: [AppSettings]

    @StateObject private var cookbookVM = CookbookVM()
    @State private var activeTab: AppTab = .home
    @State private var activeFlow: ActiveFlow?

    var body: some View {
        Group {
            if let settings = settingsRows.first {
                ZStack(alignment: .bottom) {
                    if settings.hasCompletedOnboarding {
                        mainTabs(settings: settings)
                    } else {
                        OnboardingView(settings: settings)
                    }
                }
                .preferredColorScheme(settings.darkModeEnabled ? .dark : nil)
            } else {
                ProgressView()
                    .task { ensureSettings() }
            }
        }
        .task {
            ensureSettings()
            cookbookVM.seedIfNeeded(cookbooks: cookbooks, context: modelContext)
        }
    }

    @ViewBuilder
    private func mainTabs(settings: AppSettings) -> some View {
        TabView(selection: $activeTab) {
            NavigationStack {
                HomeView(
                    settings: settings,
                    isVisible: activeTab == .home,
                    onStartWhistles: { activeFlow = .whistles(nil) },
                    onStartTimer: { activeFlow = .timer(nil) },
                    onOpenCookbook: open
                )
            }
            .tag(AppTab.home)
            .tabItem { Label(AppTab.home.title, systemImage: activeTab == .home ? AppTab.home.selectedIcon : AppTab.home.icon) }

            NavigationStack {
                CookbooksView(settings: settings) { cookbook in
                    open(cookbook)
                }
            }
            .tag(AppTab.cookbooks)
            .tabItem { Label(AppTab.cookbooks.title, systemImage: activeTab == .cookbooks ? AppTab.cookbooks.selectedIcon : AppTab.cookbooks.icon) }

            NavigationStack {
                HistoryView(settings: settings) { session in
                    let cookbook = Cookbook(
                        name: session.title,
                        whistleTarget: session.targetWhistles ?? (session.whistleCount > 0 ? session.whistleCount : nil),
                        timerDuration: session.timerDuration,
                        emoji: session.emoji
                    )
                    if cookbook.whistleTarget != nil {
                        activeFlow = .whistles(cookbook)
                    } else {
                        activeFlow = .timer(cookbook)
                    }
                }
            }
            .tag(AppTab.history)
            .tabItem { Label(AppTab.history.title, systemImage: activeTab == .history ? AppTab.history.selectedIcon : AppTab.history.icon) }

            NavigationStack {
                SettingsView(settings: settings)
            }
            .tag(AppTab.settings)
            .tabItem { Label(AppTab.settings.title, systemImage: activeTab == .settings ? AppTab.settings.selectedIcon : AppTab.settings.icon) }
        }
        .tint(Color(red: 1.0, green: 0.75, blue: 0.0))
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .onChange(of: activeTab) { _, _ in
            HapticManager.selection(enabled: settings.hapticsEnabled)
        }
        .fullScreenCover(item: $activeFlow) { flow in
            switch flow {
            case .whistles(let cookbook):
                WhistleCounterView(
                    settings: settings,
                    cookbook: cookbook,
                    onClose: { activeFlow = nil },
                    onStartLinkedTimer: { linkedCookbook in activeFlow = .timer(linkedCookbook) }
                )
            case .timer(let cookbook):
                TimerView(settings: settings, cookbook: cookbook) {
                    activeFlow = nil
                }
            }
        }
    }

    private func ensureSettings() {
        if settingsRows.isEmpty {
            modelContext.insert(AppSettings())
        }
    }

    private func open(_ cookbook: Cookbook) {
        cookbook.lastUsedAt = Date()
        if cookbook.whistleTarget != nil {
            activeFlow = .whistles(cookbook)
        } else {
            activeFlow = .timer(cookbook)
        }
    }
}

enum ActiveFlow: Identifiable {
    case whistles(Cookbook?)
    case timer(Cookbook?)

    var id: String {
        switch self {
        case .whistles(let cookbook):
            "whistles-\(cookbook?.id.uuidString ?? "quick")"
        case .timer(let cookbook):
            "timer-\(cookbook?.id.uuidString ?? "quick")"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Cookbook.self, CookingSession.self, AppSettings.self], inMemory: true)
}
