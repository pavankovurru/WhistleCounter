//
//  WhistleCounterApp.swift
//  WhistleCounter
//
//  Created by Pavan Kovurru on 5/4/26.
//

import SwiftUI
import SwiftData

@main
struct WhistleCounterApp: App {
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
