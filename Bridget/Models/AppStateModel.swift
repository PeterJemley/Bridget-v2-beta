//
//  AppStateModel.swift
//  Bridget
//
//  Module: Models
//  Purpose: Global application state manager for routes and UI state
//  Integration Points:
//    - Single source of truth for all route data
//    - Passed to RouteListView via @Bindable
//    - Updated by BridgeDataService with loaded routes
//    - Future: Will be updated by real-time traffic and ML scoring services
//

import Foundation
import Observation

@Observable
class AppStateModel {
    var routes: [RouteModel]
    var isLoading: Bool
    var selectedRouteID: String?
    
    init() {
        self.routes = []
        self.isLoading = false
        self.selectedRouteID = nil
        
        // Start loading data immediately
        Task {
            await loadSampleData()
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadSampleData() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let bridges = BridgeDataService.shared.loadSampleData()
        let routes = BridgeDataService.shared.generateRoutes(from: bridges)
        
        self.routes = routes
        self.isLoading = false
    }
    
    // MARK: - Computed Properties
    
    // Computed property to get the selected route
    var selectedRoute: RouteModel? {
        guard let selectedRouteID = selectedRouteID else { return nil }
        return routes.first { $0.routeID == selectedRouteID }
    }
    
    // Computed property for total routes count
    var totalRoutes: Int {
        return routes.count
    }
    
    // MARK: - Methods
    
    // Method to select a route
    func selectRoute(withID routeID: String) {
        selectedRouteID = routeID
    }
    
    // Method to clear route selection
    func clearRouteSelection() {
        selectedRouteID = nil
    }
} 