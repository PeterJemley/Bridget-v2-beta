//
//  BridgeStatusModel.swift
//  Bridget
//
//  Purpose: Historical bridge opening data model with caching support
//  Dependencies: Foundation (Date, TimeInterval), Observation framework
//  Integration Points:
//    - Used by BridgeDataService to represent historical bridge opening records
//    - Used by RouteModel to compose routes with historical bridge data
//    - Used by views for displaying historical bridge opening information
//    - Future: Will integrate with real-time bridge status (if available)
//  Key Features:
//    - Codable conformance for JSON caching of historical data
//    - Custom CodingKeys for JSON serialization of historical records
//    - Maintains @Observable compliance for reactive UI updates
//    - Historical analysis capabilities for past opening patterns
//    - Cache metadata for offline support of historical data
//

import Foundation
import Observation

@Observable
class BridgeStatusModel: Codable {
  let bridgeID: String
  var historicalOpenings: [Date]
  var realTimeDelay: TimeInterval?

  // MARK: - Cache Metadata (Internal Only)

  @ObservationIgnored
  var lastCacheUpdate: Date?

  @ObservationIgnored
  var cacheVersion: String?

  @ObservationIgnored
  var isStale: Bool = false

  init(bridgeID: String, historicalOpenings: [Date] = [], realTimeDelay: TimeInterval? = nil) {
    self.bridgeID = bridgeID
    self.historicalOpenings = historicalOpenings
    self.realTimeDelay = realTimeDelay
    self.lastCacheUpdate = Date()
    self.cacheVersion = "1.0"
    self.isStale = false
  }

  // MARK: - Codable Implementation

  enum CodingKeys: String, CodingKey {
    case bridgeID
    case historicalOpenings
    case realTimeDelay
    case lastCacheUpdate
    case cacheVersion
    case isStale
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bridgeID = try container.decode(String.self, forKey: .bridgeID)
    historicalOpenings = try container.decode([Date].self, forKey: .historicalOpenings)
    realTimeDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .realTimeDelay)
    lastCacheUpdate = try container.decodeIfPresent(Date.self, forKey: .lastCacheUpdate)
    cacheVersion = try container.decodeIfPresent(String.self, forKey: .cacheVersion)
    isStale = try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? false
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(bridgeID, forKey: .bridgeID)
    try container.encode(historicalOpenings, forKey: .historicalOpenings)
    try container.encodeIfPresent(realTimeDelay, forKey: .realTimeDelay)
    try container.encodeIfPresent(lastCacheUpdate, forKey: .lastCacheUpdate)
    try container.encodeIfPresent(cacheVersion, forKey: .cacheVersion)
    try container.encode(isStale, forKey: .isStale)
  }

  // MARK: - Computed Properties

  var totalOpenings: Int {
    return historicalOpenings.count
  }

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

  var lastOpening: Date? {
    return historicalOpenings.max()
  }

  var averageOpeningsPerDay: Double {
    guard !historicalOpenings.isEmpty else { return 0.0 }

    let calendar = Calendar.current
    let now = Date()
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

    let recentOpenings = historicalOpenings.filter { $0 >= thirtyDaysAgo }
    return Double(recentOpenings.count) / 30.0
  }

  // MARK: - Cache Management

  func updateCacheMetadata() {
    lastCacheUpdate = Date()
    isStale = false
  }

  func markAsStale() {
    isStale = true
  }

  var isCacheValid: Bool {
    guard let lastUpdate = lastCacheUpdate else { return false }
    let cacheAge = Date().timeIntervalSince(lastUpdate)
    return cacheAge < 300 && !isStale // 5 minutes cache validity
  }

  var cacheAge: TimeInterval? {
    guard let lastUpdate = lastCacheUpdate else { return nil }
    return Date().timeIntervalSince(lastUpdate)
  }
}
