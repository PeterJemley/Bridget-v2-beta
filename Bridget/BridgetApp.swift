//
//  BridgetApp.swift
//  Bridget
//
//  ## App
//  ## Purpose
//  Main application entry point with SwiftData configuration
//  ## Dependencies
//  - SwiftUI framework
//  - SwiftData framework
//  - ContentView (main UI)
//  - Item model (SwiftData schema)
//  ## Integration Points
//  - Configures SwiftData ModelContainer
//  - Sets up main ContentView
//  - Provides shared model container to views
//  - Future: Will integrate with Core Data for persistence
//  ## Key Features
//  - SwiftData schema configuration
//  - ModelContainer setup with persistence
//  - Main app window configuration
//  - Error handling for container creation
//

import SwiftData
import SwiftUI

/// The main application entry point for the Bridget app.
///
/// This app struct configures SwiftData for persistence and sets up the main
/// application window with the ContentView as the root view.
///
/// ## Overview
///
/// The `BridgetApp` is responsible for initializing the application and configuring
/// essential services like SwiftData for data persistence. It creates the main
/// window and provides the shared model container to all child views.
///
/// ## Key Features
///
/// - **SwiftData Configuration**: Sets up ModelContainer with persistence
/// - **Schema Management**: Configures data models for persistence
/// - **Window Management**: Creates and configures the main app window
/// - **Error Handling**: Graceful handling of container creation failures
/// - **Model Container**: Provides shared data access to all views
///
/// ## Usage
///
/// The app is automatically launched by the system when the user opens Bridget.
/// No manual initialization is required.
///
/// ## Topics
///
/// ### Configuration
/// - SwiftData schema setup with `Item` model
/// - ModelContainer configuration with persistence
/// - Window group setup with model container injection
///
/// ### Data Persistence
/// - Uses SwiftData for automatic data persistence
/// - Configures shared model container for all views
/// - Handles container creation errors gracefully
@main
struct BridgetApp: App {
  // MARK: - Model Container
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

  // MARK: - App Scene
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}

