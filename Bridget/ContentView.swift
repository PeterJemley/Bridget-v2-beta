//
//  ContentView.swift
//  Bridget
//
//  Module: Views
//  Purpose: Main content view that coordinates app state and routing
//  Dependencies:
//    - SwiftUI framework
//    - AppStateModel (for state management)
//    - RouteListView (for route display)
//  Integration Points:
//    - Initializes and manages AppStateModel
//    - Coordinates with RouteListView for UI display
//    - Provides app state to child views
//    - Future: Will integrate with navigation and settings
//  Key Features:
//    - App state initialization and management
//    - View coordination and routing
//    - Bindable state propagation
//    - Clean separation of concerns
//

import SwiftUI

/// The main content view that coordinates app state and routing.
///
/// This view serves as the root view of the application, initializing and managing
/// the global app state and coordinating with child views for UI display.
///
/// ## Overview
///
/// The `ContentView` is responsible for setting up the application's state management
/// and providing the main navigation structure. It initializes the `AppStateModel`
/// and passes it to child views using the Observation framework.
///
/// ## Key Features
///
/// - **State Management**: Initializes and manages the global `AppStateModel`
/// - **View Coordination**: Coordinates with `RouteListView` for UI display
/// - **Bindable State**: Uses `@Bindable` for reactive state propagation
/// - **Clean Architecture**: Maintains separation of concerns between state and UI
///
/// ## Usage
///
/// ```swift
/// ContentView()
/// ```
///
/// ## Topics
///
/// ### State Management
/// - Initializes `AppStateModel` on app launch
/// - Provides state to child views via `@Bindable`
/// - Coordinates reactive updates across the view hierarchy
///
/// ### View Hierarchy
/// - Root view of the application
/// - Contains `RouteListView` as the main content
/// - Future: Will integrate navigation and settings views
struct ContentView: View {
  // MARK: - Properties
  @Bindable private var appState: AppStateModel

  // MARK: - Initialization
  init() {
    self.appState = AppStateModel()
  }

  // MARK: - View Body
  var body: some View {
    RouteListView(appState: appState)
  }
}

#Preview {
  ContentView()
}
