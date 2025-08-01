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

struct ContentView: View {
  @Bindable private var appState: AppStateModel

  init() {
    self.appState = AppStateModel()
  }

  var body: some View {
    RouteListView(appState: appState)
  }
}

#Preview {
  ContentView()
}
