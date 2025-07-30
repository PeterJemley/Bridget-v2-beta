//
//  Item.swift
//  Bridget
//
//  Module: Models
//  Purpose: SwiftData model for persistent data storage
//  Dependencies:
//    - Foundation (Date)
//    - SwiftData framework
//  Integration Points:
//    - Used by BridgetApp for SwiftData schema
//    - Provides persistent storage capability
//    - Future: Will be extended for user preferences and history
//  Key Features:
//    - @Model annotation for SwiftData
//    - Timestamp tracking for data persistence
//    - Extensible model structure
//    - Automatic persistence management
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
