//
//  BridgeStatusModel.swift
//  Bridget
//
//  Module: Models
//  Purpose: Represents the status and historical data for a single bridge
//  Integration Points: 
//    - Used by RouteModel to aggregate bridge data
//    - Updated by BridgeDataService with historical openings
//    - Displayed in RouteListView for bridge details
//    - Future: Will be updated by real-time traffic data
//

import Foundation
import Observation

@Observable
class BridgeStatusModel {
    let bridgeID: String
    var historicalOpenings: [Date]
    var realTimeDelay: TimeInterval?
    
    init(bridgeID: String, historicalOpenings: [Date] = [], realTimeDelay: TimeInterval? = nil) {
        self.bridgeID = bridgeID
        self.historicalOpenings = historicalOpenings
        self.realTimeDelay = realTimeDelay
    }
    
    // Computed property for opening frequency analysis
    var openingFrequency: [String: Int] {
        let calendar = Calendar.current
        var frequency: [String: Int] = [:]
        
        for opening in historicalOpenings {
            let hour = calendar.component(.hour, from: opening)
            let hourKey = "\(hour):00"
            frequency[hourKey, default: 0] += 1
        }
        
        return frequency
    }
    
    // Total number of historical openings
    var totalOpenings: Int {
        return historicalOpenings.count
    }
} 