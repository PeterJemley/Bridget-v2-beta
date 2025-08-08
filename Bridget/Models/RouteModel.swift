import Foundation

/// A model representing a route consisting of multiple bridges and a route score.
struct RouteModel: Codable, Identifiable {
    /// The unique identifier for this route.
    let routeID: String
    /// The list of bridges in this route.
    let bridges: [BridgeStatusModel]
    /// The computed/assigned score for this route.
    var score: Double

    /// Identifiable conformance (for use in Lists in SwiftUI)
    var id: String { routeID }

    /// The number of bridges in the route (complexity).
    var complexity: Int { bridges.count }
    /// The total historical openings across all bridges in the route.
    var totalHistoricalOpenings: Int {
        bridges.reduce(0) { $0 + $1.totalOpenings }
    }

    /// Memberwise initializer
    init(routeID: String, bridges: [BridgeStatusModel], score: Double) {
        self.routeID = routeID
        self.bridges = bridges
        self.score = score
    }
}
