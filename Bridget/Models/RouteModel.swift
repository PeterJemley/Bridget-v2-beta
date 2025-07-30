//
//  RouteModel.swift
//  Bridget
//
//  Module: Models
//  Purpose: Represents a route with multiple bridges and scoring information
//  Integration Points:
//    - Contains multiple BridgeStatusModel instances
//    - Used by AppStateModel to manage route collection
//    - Displayed in RouteListView for route details
//    - Future: Will be scored by RouteScoringService with ML predictions
//

import Foundation
import Observation

@Observable
class RouteModel {
    let routeID: String
    var bridges: [BridgeStatusModel]
    var score: Double
    
    init(routeID: String, bridges: [BridgeStatusModel] = [], score: Double = 0.0) {
        self.routeID = routeID
        self.bridges = bridges
        self.score = score
    }
    
    // Computed property to calculate total potential delays
    var totalPotentialDelay: TimeInterval {
        return bridges.compactMap { $0.realTimeDelay }.reduce(0, +)
    }
    
    // Computed property for route complexity (number of bridges)
    var complexity: Int {
        return bridges.count
    }
    
    // Computed property for historical opening frequency across all bridges
    var totalHistoricalOpenings: Int {
        return bridges.reduce(0) { $0 + $1.totalOpenings }
    }
} 