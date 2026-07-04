//
//  WhistlyApp.swift
//  Whistly: Cooker Counter
//
//  Created by Pavan Kovurru on 5/4/26.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct WhistlyApp: App {
    init() {
        configureSystemControlAppearance()
        configureTabBarAppearance()
        WhistlyNotificationDelegate.configure()
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Cookbook.self,
            CookingSession.self,
            AppSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    applyDefaultSystemControlTint()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

private func configureSystemControlAppearance() {
    UIView.appearance().tintColor = nil
    UIWindow.appearance().tintColor = nil
}

private func configureTabBarAppearance() {
    let selectedColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1)
    let normalColor = UIColor.secondaryLabel
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

    [
        appearance.stackedLayoutAppearance,
        appearance.inlineLayoutAppearance,
        appearance.compactInlineLayoutAppearance
    ].forEach { itemAppearance in
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        itemAppearance.normal.iconColor = normalColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
    }

    UITabBar.appearance().tintColor = selectedColor
    UITabBar.appearance().unselectedItemTintColor = normalColor
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}

@MainActor
private func applyDefaultSystemControlTint() {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .forEach { window in
            window.tintColor = nil
        }
}
