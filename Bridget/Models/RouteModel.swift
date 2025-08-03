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

/// A model representing a route with multiple bridges and associated scoring information.
///
/// This model aggregates multiple `BridgeStatusModel` instances to represent a complete
/// route through the city. It provides computed properties for route analysis, complexity
/// assessment, and potential delay calculations. The model supports caching and conforms
/// to SwiftUI's Observation framework for reactive UI updates.
///
/// ## Overview
///
/// The `RouteModel` represents a complete route that may contain multiple bridges.
/// It aggregates bridge data to provide route-level insights and scoring for
/// optimization and user decision-making.
///
/// ## Key Features
///
/// - **Route Composition**: Contains multiple bridge status models
/// - **Delay Calculation**: Computes total potential delays across all bridges
/// - **Complexity Analysis**: Provides route complexity metrics
/// - **Historical Aggregation**: Combines historical opening data from all bridges
/// - **ML-Ready Scoring**: Supports machine learning-based route scoring
/// - **Caching**: Full cache support for score metadata and validation
///
/// ## Usage
///
/// ```swift
/// let route = RouteModel(
///     routeID: "ROUTE_A",
///     bridges: [bridge1, bridge2, bridge3],
///     score: 0.85
/// )
///
/// print(route.totalPotentialDelay) // 450.0 seconds
/// print(route.complexity) // 3 bridges
/// print(route.totalHistoricalOpenings) // 15 openings
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``routeID``
/// - ``bridges``
/// - ``score``
///
/// ### Route Analysis
/// - ``totalPotentialDelay``
/// - ``complexity``
/// - ``totalHistoricalOpenings``
///
/// ### Score Management
/// - ``updateScoreMetadata()``
/// - ``markScoreAsStale()``
/// - ``isScoreValid``
/// - ``scoreAge``
@Observable
class RouteModel: Codable {
  /// The unique identifier for this route.
  ///
  /// This identifier is used to distinguish between different routes in the system.
  /// It should be descriptive and follow a consistent naming convention.
  let routeID: String

  /// The collection of bridges that make up this route.
  ///
  /// This array contains `BridgeStatusModel` instances representing each bridge
  /// along the route. The order of bridges in the array may represent the
  /// sequence of bridges encountered when traveling the route.
  var bridges: [BridgeStatusModel]

  /// The calculated score for this route, typically between 0.0 and 1.0.
  ///
  /// This score represents the overall quality or efficiency of the route,
  /// taking into account factors like delays, complexity, and historical data.
  /// Higher scores indicate better routes.
  var score: Double

  // MARK: - Cache Metadata (Internal Only)

  @ObservationIgnored
  var lastScoreUpdate: Date?

  @ObservationIgnored
  var scoreVersion: String?

  @ObservationIgnored
  var isScoreStale: Bool = false

  /// Creates a new route model with the specified bridges and initial score.
  ///
  /// This initializer creates a route with the given identifier and bridge collection.
  /// The score is initialized to the provided value, and cache metadata is set up
  /// with current timestamp and version information.
  ///
  /// - Parameters:
  ///   - routeID: The unique identifier for the route.
  ///   - bridges: An array of bridge status models representing the route's bridges.
  ///     Defaults to an empty array.
  ///   - score: The initial score for the route. Defaults to 0.0.
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

  /// Creates a route model from a decoder.
  ///
  /// This initializer is required for `Codable` conformance and handles
  /// decoding from JSON or other serialized formats. It decodes all properties
  /// including score metadata, with appropriate fallbacks for optional values.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` if the data is corrupted or missing required fields.
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    routeID = try container.decode(String.self, forKey: .routeID)
    bridges = try container.decode([BridgeStatusModel].self, forKey: .bridges)
    score = try container.decode(Double.self, forKey: .score)
    lastScoreUpdate = try container.decodeIfPresent(Date.self, forKey: .lastScoreUpdate)
    scoreVersion = try container.decodeIfPresent(String.self, forKey: .scoreVersion)
    isScoreStale = try container.decodeIfPresent(Bool.self, forKey: .isScoreStale) ?? false
  }

  /// Encodes the route model to an encoder.
  ///
  /// This method is required for `Codable` conformance and handles
  /// encoding to JSON or other serialized formats. It encodes all properties
  /// including score metadata, with appropriate handling of optional values.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: `EncodingError` if the data cannot be encoded.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(routeID, forKey: .routeID)
    try container.encode(bridges, forKey: .bridges)
    try container.encode(score, forKey: .score)
    try container.encodeIfPresent(lastScoreUpdate, forKey: .lastScoreUpdate)
    try container.encodeIfPresent(scoreVersion, forKey: .scoreVersion)
    try container.encode(isScoreStale, forKey: .isScoreStale)
  }

  /// The total potential delay (in seconds) across all bridges in this route.
  ///
  /// This computed property sums up all real-time delays from bridges that
  /// currently have delay estimates. Only bridges with non-nil `realTimeDelay`
  /// values contribute to this total.
  ///
  /// - Returns: The total potential delay in seconds, or 0 if no bridges
  ///   have current delay estimates.
  var totalPotentialDelay: TimeInterval {
    return bridges.compactMap { $0.realTimeDelay }.reduce(0, +)
  }

  /// The number of bridges in this route, indicating route complexity.
  ///
  /// This computed property provides a simple measure of route complexity
  /// based on the number of bridges that must be traversed. Higher complexity
  /// generally indicates more potential for delays and route planning challenges.
  ///
  /// - Returns: The total number of bridges in the route.
  var complexity: Int {
    return bridges.count
  }

  /// The total number of historical openings across all bridges in this route.
  ///
  /// This computed property aggregates the historical opening data from all
  /// bridges in the route. It provides insight into the overall historical
  /// activity level of the route's bridges.
  ///
  /// - Returns: The sum of all historical openings from all bridges in the route.
  var totalHistoricalOpenings: Int {
    return bridges.reduce(0) { $0 + $1.totalOpenings }
  }

  // MARK: - Cache Management

  /// Updates the score metadata to reflect a fresh score calculation.
  ///
  /// This method is called when the route score has been recalculated or updated.
  /// It sets the `lastScoreUpdate` timestamp to the current time and marks
  /// the score as not stale.
  func updateScoreMetadata() {
    lastScoreUpdate = Date()
    isScoreStale = false
  }

  /// Marks the route score as stale, indicating it should be recalculated.
  ///
  /// This method is called when the score is known to be outdated or when
  /// the route data has changed significantly. Stale scores may still be used
  /// but should be refreshed when possible.
  func markScoreAsStale() {
    isScoreStale = true
  }

  /// A Boolean value indicating whether the route score is still considered valid.
  ///
  /// This computed property checks both the score age and staleness flag.
  /// Score is considered valid if:
  /// - It has been updated within the last 10 minutes (600 seconds)
  /// - The score is not marked as stale
  ///
  /// - Returns: `true` if the score is valid and fresh, `false` otherwise.
  var isScoreValid: Bool {
    guard let lastUpdate = lastScoreUpdate else { return false }
    let scoreAge = Date().timeIntervalSince(lastUpdate)
    return scoreAge < 600 && !isScoreStale // 10 minutes score validity
  }

  /// The age of the route score in seconds since the last update.
  ///
  /// This computed property calculates the time interval between now and
  /// the last score update. Useful for debugging score behavior or
  /// implementing custom score validation logic.
  ///
  /// - Returns: The score age in seconds, or `nil` if no score update
  ///   timestamp exists.
  var scoreAge: TimeInterval? {
    guard let lastUpdate = lastScoreUpdate else { return nil }
    return Date().timeIntervalSince(lastUpdate)
  }
}
