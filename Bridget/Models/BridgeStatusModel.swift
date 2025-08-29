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

/// A model representing the historical and real-time status of a specific bridge.
///
/// This model stores a historical record of discrete bridge opening events as a list of timestamps.
/// It may also include real-time delay estimates. The model supports caching and conforms to
/// SwiftUI’s Observation framework for reactive UI updates.
@Observable
class BridgeStatusModel: Codable {
  // MARK: - Bridge Properties

  /// The human-readable business identifier for the bridge, using descriptive bridge names.
  ///
  /// This property stores the bridge name (e.g., "Fremont Bridge", "Ballard Bridge")
  /// as the primary business identifier. While the API uses numeric IDs (1-10),
  /// the business layer uses descriptive names for user-facing operations and display.
  let bridgeName: String

  /// The raw API identifier for the bridge, used for traceability and mapping to API data.
  ///
  /// This optional property stores the numeric or string ID used by the API to uniquely identify the bridge.
  var apiBridgeID: BridgeID?

  /// The list of past dates and times when the bridge was recorded as open.
  var historicalOpenings: [Date]

  /// An optional estimate (in seconds) of the current delay due to the bridge being open.
  var realTimeDelay: TimeInterval?

  // MARK: - Cache Metadata (Internal Only)

  /// The timestamp when the cache was last updated.
  @ObservationIgnored
  var lastCacheUpdate: Date?

  /// A string indicating the version of the cached dataset.
  @ObservationIgnored
  var cacheVersion: String?

  /// A Boolean value indicating whether the cached data is considered stale.
  @ObservationIgnored
  var isStale: Bool = false

  // MARK: - Initialization

  /// Creates a new bridge status model with optional historical data and real-time delay.
  ///
  /// - Parameters:
  ///   - bridgeName: The human-readable business identifier of the bridge (e.g., "Fremont Bridge").
  ///   - apiBridgeID: The raw API identifier of the bridge for traceability (e.g., .fremont).
  ///   - historicalOpenings: An array of dates representing previous opening events.
  ///   - realTimeDelay: An optional time interval indicating real-time delay (in seconds).
  init(
    bridgeName: String,
    apiBridgeID: BridgeID? = nil,
    historicalOpenings: [Date] = [],
    realTimeDelay: TimeInterval? = nil
  ) {
    self.bridgeName = bridgeName
    self.apiBridgeID = apiBridgeID
    self.historicalOpenings = historicalOpenings
    self.realTimeDelay = realTimeDelay
    self.lastCacheUpdate = Date()
    self.cacheVersion = "1.0"
    self.isStale = false
  }

  // MARK: - Codable Implementation

  enum CodingKeys: String, CodingKey {
    case bridgeName
    case apiBridgeID
    case historicalOpenings
    case realTimeDelay
    case lastCacheUpdate
    case cacheVersion
    case isStale
  }

  /// Creates a bridge status model from a decoder.
  ///
  /// This initializer is required for `Codable` conformance and handles
  /// decoding from JSON or other serialized formats. It decodes all properties
  /// including cache metadata, with appropriate fallbacks for optional values.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` if the data is corrupted or missing required fields.
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bridgeName = try container.decode(String.self, forKey: .bridgeName)
    let apiBridgeIDString = try container.decodeIfPresent(
      String.self,
      forKey: .apiBridgeID
    )
    if let rawValue = apiBridgeIDString {
      apiBridgeID = BridgeID(rawValue: rawValue)
    } else {
      apiBridgeID = nil
    }
    historicalOpenings = try container.decode(
      [Date].self,
      forKey: .historicalOpenings
    )
    realTimeDelay = try container.decodeIfPresent(
      TimeInterval.self,
      forKey: .realTimeDelay
    )
    lastCacheUpdate = try container.decodeIfPresent(
      Date.self,
      forKey: .lastCacheUpdate
    )
    cacheVersion = try container.decodeIfPresent(
      String.self,
      forKey: .cacheVersion
    )
    isStale =
      try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? false
  }

  /// Encodes the bridge status model to an encoder.
  ///
  /// This method is required for `Codable` conformance and handles
  /// encoding to JSON or other serialized formats. It encodes all properties
  /// including cache metadata, with appropriate handling of optional values.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: `EncodingError` if the data cannot be encoded.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(bridgeName, forKey: .bridgeName)
    try container.encodeIfPresent(
      apiBridgeID?.rawValue,
      forKey: .apiBridgeID
    )
    try container.encode(historicalOpenings, forKey: .historicalOpenings)
    try container.encodeIfPresent(realTimeDelay, forKey: .realTimeDelay)
    try container.encodeIfPresent(lastCacheUpdate, forKey: .lastCacheUpdate)
    try container.encodeIfPresent(cacheVersion, forKey: .cacheVersion)
    try container.encode(isStale, forKey: .isStale)
  }

  // MARK: - Computed Properties

  /// The total number of historical opening events recorded for this bridge.
  ///
  /// This computed property returns the count of all historical opening timestamps
  /// stored in the `historicalOpenings` array.
  ///
  /// - Returns: The total count of opening events, or 0 if no openings are recorded.
  var totalOpenings: Int {
    return historicalOpenings.count
  }

  /// A dictionary mapping hour-of-day to the number of openings that occurred during that hour.
  ///
  /// This computed property analyzes all historical openings and groups them by hour of day.
  /// The result is a dictionary where keys are hour strings (e.g., "14:00") and values
  /// are the count of openings that occurred during that hour.
  ///
  /// - Returns: A dictionary with hour strings as keys and opening counts as values.
  ///   Returns an empty dictionary if no historical openings exist.
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

  /// The most recent bridge opening event, if any historical openings exist.
  ///
  /// This computed property finds the latest timestamp from all historical opening events.
  /// Useful for determining when the bridge was last opened.
  ///
  /// - Returns: The most recent opening date, or `nil` if no historical openings exist.
  var lastOpening: Date? {
    return historicalOpenings.max()
  }

  /// The average number of bridge openings per day over the last 30 days.
  ///
  /// This computed property calculates the daily average by counting openings
  /// in the past 30 days and dividing by 30. This provides a recent trend
  /// rather than a long-term average.
  ///
  /// - Returns: The average openings per day as a Double. Returns 0.0 if no
  ///   historical openings exist or if no openings occurred in the last 30 days.
  var averageOpeningsPerDay: Double {
    if historicalOpenings.isEmpty { return 0.0 }

    let calendar = Calendar.current
    let now = Date()
    let thirtyDaysAgo =
      calendar.date(byAdding: .day, value: -30, to: now) ?? now

    let recentOpenings = historicalOpenings.filter { $0 >= thirtyDaysAgo }
    return Double(recentOpenings.count) / 30.0
  }

  /// Returns a sanitized array of historical opening dates, filtering out out-of-range or duplicate entries.
  ///
  /// - Removes dates more than 10 years in the past or more than 1 year in the future from now.
  /// - Removes duplicate dates.
  /// - Returns: An array of unique, in-range opening dates, sorted chronologically.
  var sanitizedHistoricalOpenings: [Date] {
    let calendar = Calendar.current
    let now = Date()
    let minDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
    let maxDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now
    let filtered = historicalOpenings.filter {
      $0 >= minDate && $0 <= maxDate
    }
    let unique = Array(Set(filtered))
    return unique.sorted()
  }

  // MARK: - Cache Management

  /// Updates the cache metadata to reflect a fresh data update.
  ///
  /// This method is called when new data is successfully loaded or processed.
  /// It sets the `lastCacheUpdate` timestamp to the current time and marks
  /// the data as not stale.
  func updateCacheMetadata() {
    lastCacheUpdate = Date()
    isStale = false
  }

  /// Marks the cached data as stale, indicating it should be refreshed.
  ///
  /// This method is called when the cache is being used as a fallback
  /// after a network failure, or when the data is known to be outdated.
  /// Stale data may still be used but should be refreshed when possible.
  func markAsStale() {
    isStale = true
  }

  /// A Boolean value indicating whether the cached data is still considered valid.
  ///
  /// This computed property checks both the cache age and staleness flag.
  /// Cache is considered valid if:
  /// - It has been updated within the last 5 minutes (300 seconds)
  /// - The data is not marked as stale
  ///
  /// - Returns: `true` if the cache is valid and fresh, `false` otherwise.
  var isCacheValid: Bool {
    guard let lastUpdate = lastCacheUpdate else { return false }
    let cacheAge = Date().timeIntervalSince(lastUpdate)
    return cacheAge < 300 && !isStale  // 5 minutes cache validity
  }

  /// The age of the cached data in seconds since the last update.
  ///
  /// This computed property calculates the time interval between now and
  /// the last cache update. Useful for debugging cache behavior or
  /// implementing custom cache validation logic.
  ///
  /// - Returns: The cache age in seconds, or `nil` if no cache update
  ///   timestamp exists.
  var cacheAge: TimeInterval? {
    guard let lastUpdate = lastCacheUpdate else { return nil }
    return Date().timeIntervalSince(lastUpdate)
  }
}
