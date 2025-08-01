//
//  RouteModel.swift
//  Bridget
//
//  Module: Models
//  Purpose: Route representation with multiple bridges and scoring information
//  Dependencies:
//    - Foundation (TimeInterval)
//    - Observation framework
//    - BridgeStatusModel (for bridge data)
//  Integration Points:
//    - Contains multiple BridgeStatusModel instances
//    - Used by AppStateModel to manage route collection
//    - Displayed in RouteListView for route details
//    - Scored by RouteScoringService with ML predictions (future)
//    - Future: Will integrate with real-time traffic optimization
//  Key Features:
//    - Route complexity calculation
//    - Total potential delay computation
//    - Historical opening aggregation
//    - @Observable compliance for UI updates
//    - ML-ready scoring system
//

import Foundation
import Observation

@Observable
class RouteModel: Codable {
  let routeID: String
  var bridges: [BridgeStatusModel]
  var score: Double

  // MARK: - Cache Metadata (Internal Only)

  @ObservationIgnored
  var lastScoreUpdate: Date?

  @ObservationIgnored
  var scoreVersion: String?

  @ObservationIgnored
  var isScoreStale: Bool = false

  init(routeID: String, bridges: [BridgeStatusModel] = [], score: Double = 0.0) {
    self.routeID = routeID
    self.bridges = bridges
    self.score = score
    self.lastScoreUpdate = Date()
    self.scoreVersion = "1.0"
    self.isScoreStale = false
  }

  // MARK: - Codable Implementation

  enum CodingKeys: String, CodingKey {
    case routeID
    case bridges
    case score
    case lastScoreUpdate
    case scoreVersion
    case isScoreStale
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    routeID = try container.decode(String.self, forKey: .routeID)
    bridges = try container.decode([BridgeStatusModel].self, forKey: .bridges)
    score = try container.decode(Double.self, forKey: .score)
    lastScoreUpdate = try container.decodeIfPresent(Date.self, forKey: .lastScoreUpdate)
    scoreVersion = try container.decodeIfPresent(String.self, forKey: .scoreVersion)
    isScoreStale = try container.decodeIfPresent(Bool.self, forKey: .isScoreStale) ?? false
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(routeID, forKey: .routeID)
    try container.encode(bridges, forKey: .bridges)
    try container.encode(score, forKey: .score)
    try container.encodeIfPresent(lastScoreUpdate, forKey: .lastScoreUpdate)
    try container.encodeIfPresent(scoreVersion, forKey: .scoreVersion)
    try container.encode(isScoreStale, forKey: .isScoreStale)
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

  // MARK: - Cache Management

  func updateScoreMetadata() {
    lastScoreUpdate = Date()
    isScoreStale = false
  }

  func markScoreAsStale() {
    isScoreStale = true
  }

  var isScoreValid: Bool {
    guard let lastUpdate = lastScoreUpdate else { return false }
    let scoreAge = Date().timeIntervalSince(lastUpdate)
    return scoreAge < 600 && !isScoreStale // 10 minutes score validity
  }

  var scoreAge: TimeInterval? {
    guard let lastUpdate = lastScoreUpdate else { return nil }
    return Date().timeIntervalSince(lastUpdate)
  }
}
