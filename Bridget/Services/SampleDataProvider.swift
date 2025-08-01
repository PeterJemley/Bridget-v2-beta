//
//  SampleDataProvider.swift
//  Bridget
//
//  Purpose: Provides sample data for testing and development
//  Dependencies: Foundation (Calendar, Date), BridgeStatusModel
//  Integration Points:
//    - Generates mock bridge data for testing scenarios
//    - Keeps sample data isolated from production code
//    - Called by BridgeDataService for fallback data
//

import Foundation

// MARK: - Sample Data Provider

class SampleDataProvider {
  static let shared = SampleDataProvider()

  private init() {}

  // MARK: - Sample Data Generation

  /// Generates sample bridge data for testing and development
  ///
  /// This method creates realistic sample data that mimics the structure
  /// of real bridge opening data, but with controlled timestamps for
  /// consistent testing scenarios.
  ///
  /// - Returns: Array of BridgeStatusModel instances with sample data
  func loadSampleData() -> [BridgeStatusModel] {
    let calendar = Calendar.current
    let now = Date()

    // Create sample bridge data for testing
    let sampleBridges = [
      ("Fremont Bridge",
       [
         calendar.date(byAdding: .hour, value: -2, to: now)!,
         calendar.date(byAdding: .hour, value: -4, to: now)!,
         calendar.date(byAdding: .hour, value: -6, to: now)!,
       ]),
      ("Ballard Bridge",
       [
         calendar.date(byAdding: .hour, value: -1, to: now)!,
         calendar.date(byAdding: .hour, value: -3, to: now)!,
         calendar.date(byAdding: .hour, value: -5, to: now)!,
         calendar.date(byAdding: .hour, value: -7, to: now)!,
       ]),
      ("University Bridge",
       [
         calendar.date(byAdding: .hour, value: -2, to: now)!,
         calendar.date(byAdding: .hour, value: -8, to: now)!,
       ]),
    ]

    return sampleBridges.map { bridgeID, openings in
      BridgeStatusModel(bridgeID: bridgeID, historicalOpenings: openings)
    }
  }

  // MARK: - Sample Route Generation

  /// Generates sample routes for testing route management functionality
  ///
  /// - Parameter bridges: Array of BridgeStatusModel instances to create routes from
  /// - Returns: Array of RouteModel instances with sample route data
  func generateSampleRoutes(from bridges: [BridgeStatusModel]) -> [RouteModel] {
    return [
      RouteModel(routeID: "Route-1",
                 bridges: Array(bridges.prefix(2)),
                 score: 0.0),
      RouteModel(routeID: "Route-2",
                 bridges: Array(bridges.suffix(2)),
                 score: 0.0),
      RouteModel(routeID: "Route-3", bridges: bridges, score: 0.0),
    ]
  }
}
