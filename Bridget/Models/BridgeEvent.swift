//
//  BridgeEvent.swift
//  Bridget
//
//  Purpose: SwiftData model for persisting individual bridge opening events
//  Dependencies: Foundation (Date), SwiftData framework
//  Integration Points:
//    - Used by BridgeDataService to cache API responses locally
//    - Queried to build BridgeStatusModel instances with historical data
//    - Enables offline functionality and historical analysis
//    - Future: Will support Core ML training data preparation
//  Key Features:
//    - @Model annotation for SwiftData persistence
//    - Stores individual bridge opening/closing events from Seattle API
//    - Includes validation metadata and geospatial data
//    - Supports efficient querying by bridge ID and date ranges
//

import Foundation
import SwiftData

/// A persistent model representing a single bridge opening/closing event from the Seattle API.
///
/// This model stores individual bridge events in SwiftData for local caching, offline support,
/// and historical analysis. Each event represents one complete opening/closing cycle with
/// timestamps, duration, and location data.
///
/// ## Overview
///
/// `BridgeEvent` serves as the persistent storage layer for bridge opening data, enabling:
/// - Local caching of API responses for offline functionality
/// - Historical analysis and pattern recognition
/// - Efficient querying by bridge, date range, or duration
/// - Future Core ML model training data preparation
///
/// ## Usage
///
/// ```swift
/// // Create from API data
/// let event = BridgeEvent(
///   bridgeID: "3",
///   bridgeName: "Fremont Bridge",
///   openDateTime: openDate,
///   closeDateTime: closeDate,
///   minutesOpen: 8,
///   latitude: 47.6426,
///   longitude: -122.3508
/// )
///
/// // Query historical events
/// let descriptor = FetchDescriptor<BridgeEvent>(
///   predicate: #Predicate { $0.bridgeID == "3" && $0.openDateTime > lastWeek }
/// )
/// ```
@Model
final class BridgeEvent {
  // MARK: - Core Properties

  /// The API bridge identifier (e.g., "1", "2", "3")
  var bridgeID: String

  /// The human-readable bridge name (e.g., "Fremont Bridge", "Ballard Bridge")
  var bridgeName: String

  /// The timestamp when the bridge started opening
  var openDateTime: Date

  /// The timestamp when the bridge finished closing (optional for incomplete events)
  var closeDateTime: Date?

  /// The duration the bridge was open in minutes
  var minutesOpen: Int

  // MARK: - Location Properties

  /// The latitude coordinate of the bridge
  var latitude: Double

  /// The longitude coordinate of the bridge
  var longitude: Double

  // MARK: - Metadata Properties

  /// The timestamp when this event was stored locally
  var createdAt: Date

  /// The API entity type (typically "Bridge")
  var entityType: String

  /// Whether this event passed validation when imported
  var isValidated: Bool

  // MARK: - Initialization

  /// Creates a new bridge event for SwiftData persistence.
  ///
  /// - Parameters:
  ///   - bridgeID: The API bridge identifier
  ///   - bridgeName: The human-readable bridge name
  ///   - openDateTime: When the bridge started opening
  ///   - closeDateTime: When the bridge finished closing (optional)
  ///   - minutesOpen: Duration the bridge was open in minutes
  ///   - latitude: Bridge latitude coordinate
  ///   - longitude: Bridge longitude coordinate
  ///   - entityType: API entity type (defaults to "Bridge")
  ///   - isValidated: Whether this event passed validation (defaults to true)
  init(bridgeID: String,
       bridgeName: String,
       openDateTime: Date,
       closeDateTime: Date? = nil,
       minutesOpen: Int,
       latitude: Double,
       longitude: Double,
       entityType: String = "Bridge",
       isValidated: Bool = true)
  {
    self.bridgeID = bridgeID
    self.bridgeName = bridgeName
    self.openDateTime = openDateTime
    self.closeDateTime = closeDateTime
    self.minutesOpen = minutesOpen
    self.latitude = latitude
    self.longitude = longitude
    self.entityType = entityType
    self.isValidated = isValidated
    self.createdAt = Date()
  }

  // MARK: - Convenience Methods

  /// The duration the bridge was open as a TimeInterval in seconds.
  var durationInSeconds: TimeInterval {
    return TimeInterval(minutesOpen * 60)
  }

  /// Whether this event represents a completed opening/closing cycle.
  var isComplete: Bool {
    return closeDateTime != nil
  }

  /// A convenience accessor for the BridgeID enum if the ID is recognized.
  var bridgeIDEnum: BridgeID? {
    return BridgeID(rawValue: bridgeID)
  }
}

// MARK: - Factory Methods

extension BridgeEvent {
  /// Creates a BridgeEvent from a BridgeOpeningRecord (API response).
  ///
  /// This factory method converts the raw API data structure into a persistent
  /// SwiftData model, handling date parsing and validation status.
  ///
  /// - Parameters:
  ///   - record: The raw API record to convert
  ///   - isValidated: Whether the record passed validation (defaults to true)
  /// - Returns: A new BridgeEvent instance, or nil if required data is missing
  static func from(record: BridgeOpeningRecord,
                   isValidated: Bool = true) -> BridgeEvent?
  {
    guard let openDate = record.openDate,
          let latitude = record.latitudeValue,
          let longitude = record.longitudeValue,
          let minutesOpen = record.minutesOpenValue
    else {
      return nil
    }

    return BridgeEvent(bridgeID: record.entityid,
                       bridgeName: record.entityname,
                       openDateTime: openDate,
                       closeDateTime: record.closeDate,
                       minutesOpen: minutesOpen,
                       latitude: latitude,
                       longitude: longitude,
                       entityType: record.entitytype,
                       isValidated: isValidated)
  }
}
