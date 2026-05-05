//
//  WhistleCounterApp.swift
//  WhistleCounter
//
//  Created by Pavan Kovurru on 5/4/26.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct WhistleCounterApp: App {
    init() {
        // Set tab bar tint via UIKit so the glass material doesn't wash out the color
        UITabBar.appearance().tintColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1)
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
        }
        .modelContainer(sharedModelContainer)
    }
}
