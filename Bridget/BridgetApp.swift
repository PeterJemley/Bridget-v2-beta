//
//  BridgetApp.swift
//  Bridget
//
//  Module: App
//  Purpose: Main application entry point with SwiftData configuration
//  Dependencies:
//    - SwiftUI framework
//    - SwiftData framework
//    - ContentView (main UI)
//    - Item model (SwiftData schema)
//  Integration Points:
//    - Configures SwiftData ModelContainer
//    - Sets up main ContentView
//    - Provides shared model container to views
//    - Future: Will integrate with Core Data for persistence
//  Key Features:
//    - SwiftData schema configuration
//    - ModelContainer setup with persistence
//    - Main app window configuration
//    - Error handling for container creation
//

import SwiftUI
import SwiftData

@main
struct BridgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
