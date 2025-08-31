//
//  RoutePreference.swift
//  Bridget
//
//  Purpose: SwiftData model for persisting user route preferences and settings
//  Dependencies: Foundation (Date), SwiftData framework
//  Integration Points:
//    - Used by route recommendation engine to personalize suggestions
//    - Stores user's preferred routes, avoided bridges, and routing settings
//    - Enables offline route preferences and cross-session persistence
//    - Future: Will integrate with Core ML for personalized route scoring
//  Key Features:
//    - @Model annotation for SwiftData persistence
//    - User-specific route preferences and avoidance settings
//    - Priority weighting for different route factors
//    - Supports efficient querying by user preferences
//

import Foundation
import SwiftData

/// A persistent model representing user preferences for route selection and navigation.
///
/// This model stores user-specific routing preferences, including preferred routes,
/// bridges to avoid, and weighting factors for route scoring. It enables personalized
/// route recommendations and maintains user preferences across app sessions.
///
/// ## Overview
///
/// `RoutePreference` serves as the persistent storage layer for user routing preferences, enabling:
/// - Personalized route recommendations based on user history
/// - Bridge avoidance preferences (e.g., avoiding specific problematic bridges)
/// - Custom weighting for route scoring factors (time vs. reliability)
/// - Cross-session persistence of user routing behavior
///
/// ## Usage
///
/// ```swift
/// // Create user preference
/// let preference = RoutePreference(
///   preferredRouteIDs: ["route_1", "route_3"],
///   avoidedBridgeIDs: ["2"], // Avoid Ballard Bridge
///   timeWeight: 0.7,
///   reliabilityWeight: 0.9
/// )
///
/// // Query user preferences
/// let descriptor = FetchDescriptor<RoutePreference>(
///   predicate: #Predicate { $0.isActive == true }
/// )
/// ```
@Model
final class RoutePreference {
  // MARK: - Core Properties

  /// Unique identifier for this preference set
  var preferenceID: String

  /// User's preferred route IDs (from RouteModel.routeID)
  var preferredRouteIDs: [String]

  /// Bridge IDs the user wants to avoid (from BridgeID enum)
  var avoidedBridgeIDs: [String]

  /// Bridge IDs the user particularly prefers/trusts
  var preferredBridgeIDs: [String]

  // MARK: - Scoring Weights

  /// Weight for travel time in route scoring (0.0 - 1.0)
  var timeWeight: Double

  /// Weight for route reliability/predictability in scoring (0.0 - 1.0)
  var reliabilityWeight: Double

  /// Weight for avoiding bridge openings in scoring (0.0 - 1.0)
  var bridgeAvoidanceWeight: Double

  /// Weight for avoiding traffic slowdowns in scoring (0.0 - 1.0)
  var trafficAvoidanceWeight: Double

  // MARK: - User Behavior Settings

  /// Whether user prefers routes with fewer bridges (even if longer)
  var preferFewerBridges: Bool

  /// Whether user wants real-time traffic updates during navigation
  var enableRealTimeUpdates: Bool

  /// Whether user wants notifications about bridge openings on their route
  var enableBridgeNotifications: Bool

  /// Maximum acceptable additional travel time to avoid bridge openings (in minutes)
  var maxDetourMinutes: Int

  // MARK: - Metadata Properties

  /// When this preference set was created
  var createdAt: Date

  /// When this preference set was last updated
  var lastUpdated: Date

  /// Whether this preference set is currently active
  var isActive: Bool

  /// Number of times routes based on these preferences were used
  var usageCount: Int

  /// Optional name/label for this preference set (e.g., "Work Commute", "Weekend Trips")
  var preferenceLabel: String?

  // MARK: - Initialization

  /// Creates a new route preference configuration.
  ///
  /// - Parameters:
  ///   - preferenceID: Unique identifier for this preference set
  ///   - preferredRouteIDs: Array of preferred route IDs
  ///   - avoidedBridgeIDs: Array of bridge IDs to avoid
  ///   - preferredBridgeIDs: Array of bridge IDs user prefers
  ///   - timeWeight: Weight for travel time in scoring
  ///   - reliabilityWeight: Weight for route reliability in scoring
  ///   - bridgeAvoidanceWeight: Weight for avoiding bridge openings
  ///   - trafficAvoidanceWeight: Weight for avoiding traffic slowdowns
  ///   - preferFewerBridges: Whether to prefer routes with fewer bridges
  ///   - enableRealTimeUpdates: Whether to enable real-time traffic updates
  ///   - enableBridgeNotifications: Whether to enable bridge opening notifications
  ///   - maxDetourMinutes: Maximum detour time to avoid bridges
  ///   - preferenceLabel: Optional label for this preference set
  init(preferenceID: String = UUID().uuidString,
       preferredRouteIDs: [String] = [],
       avoidedBridgeIDs: [String] = [],
       preferredBridgeIDs: [String] = [],
       timeWeight: Double = 0.5,
       reliabilityWeight: Double = 0.5,
       bridgeAvoidanceWeight: Double = 0.7,
       trafficAvoidanceWeight: Double = 0.8,
       preferFewerBridges: Bool = false,
       enableRealTimeUpdates: Bool = true,
       enableBridgeNotifications: Bool = true,
       maxDetourMinutes: Int = 10,
       preferenceLabel: String? = nil)
  {
    self.preferenceID = preferenceID
    self.preferredRouteIDs = preferredRouteIDs

    // Validate bridge IDs against SeattleDrawbridges as single source of truth
    // RoutePreference only accepts canonical bridge IDs (no synthetic test IDs for user preferences)
    let validAvoidedBridgeIDs = avoidedBridgeIDs.filter { bridgeID in
      if SeattleDrawbridges.isCanonicalBridgeID(bridgeID) {
        return true
      } else {
        print(
          "⚠️ RoutePreference: Non-canonical avoided bridge ID '\(bridgeID)' ignored. Must be one of: \(SeattleDrawbridges.BridgeID.allIDs)"
        )
        return false
      }
    }

    let validPreferredBridgeIDs = preferredBridgeIDs.filter { bridgeID in
      if SeattleDrawbridges.isCanonicalBridgeID(bridgeID) {
        return true
      } else {
        print(
          "⚠️ RoutePreference: Non-canonical preferred bridge ID '\(bridgeID)' ignored. Must be one of: \(SeattleDrawbridges.BridgeID.allIDs)"
        )
        return false
      }
    }

    self.avoidedBridgeIDs = validAvoidedBridgeIDs
    self.preferredBridgeIDs = validPreferredBridgeIDs
    self.timeWeight = timeWeight
    self.reliabilityWeight = reliabilityWeight
    self.bridgeAvoidanceWeight = bridgeAvoidanceWeight
    self.trafficAvoidanceWeight = trafficAvoidanceWeight
    self.preferFewerBridges = preferFewerBridges
    self.enableRealTimeUpdates = enableRealTimeUpdates
    self.enableBridgeNotifications = enableBridgeNotifications
    self.maxDetourMinutes = maxDetourMinutes
    self.preferenceLabel = preferenceLabel
    self.createdAt = Date()
    self.lastUpdated = Date()
    self.isActive = true
    self.usageCount = 0
  }

  // MARK: - Convenience Methods

  /// Updates the last modified timestamp and increments usage count
  func recordUsage() {
    lastUpdated = Date()
    usageCount += 1
  }

  /// Marks this preference set as inactive
  func deactivate() {
    isActive = false
    lastUpdated = Date()
  }

  /// Adds a route to the preferred routes list if not already present
  func addPreferredRoute(_ routeID: String) {
    if !preferredRouteIDs.contains(routeID) {
      preferredRouteIDs.append(routeID)
      lastUpdated = Date()
    }
  }

  /// Removes a route from the preferred routes list
  func removePreferredRoute(_ routeID: String) {
    preferredRouteIDs.removeAll { $0 == routeID }
    lastUpdated = Date()
  }

  /// Adds a bridge to the avoidance list if not already present
  func addAvoidedBridge(_ bridgeID: String) {
    // Validate bridge ID against SeattleDrawbridges as single source of truth
    guard SeattleDrawbridges.isCanonicalBridgeID(bridgeID) else {
      print(
        "⚠️ RoutePreference: Cannot add non-canonical bridge ID '\(bridgeID)' to avoided bridges. Must be one of: \(SeattleDrawbridges.BridgeID.allIDs)"
      )
      return
    }

    if !avoidedBridgeIDs.contains(bridgeID) {
      avoidedBridgeIDs.append(bridgeID)
      lastUpdated = Date()
    }
  }

  /// Removes a bridge from the avoidance list
  func removeAvoidedBridge(_ bridgeID: String) {
    avoidedBridgeIDs.removeAll { $0 == bridgeID }
    lastUpdated = Date()
  }

  /// Adds a bridge to the preferred bridges list if not already present
  func addPreferredBridge(_ bridgeID: String) {
    // Validate bridge ID against SeattleDrawbridges as single source of truth
    guard SeattleDrawbridges.isCanonicalBridgeID(bridgeID) else {
      print(
        "⚠️ RoutePreference: Cannot add non-canonical bridge ID '\(bridgeID)' to preferred bridges. Must be one of: \(SeattleDrawbridges.BridgeID.allIDs)"
      )
      return
    }

    if !preferredBridgeIDs.contains(bridgeID) {
      preferredBridgeIDs.append(bridgeID)
      lastUpdated = Date()
    }
  }

  /// Removes a bridge from the preferred bridges list
  func removePreferredBridge(_ bridgeID: String) {
    preferredBridgeIDs.removeAll { $0 == bridgeID }
    lastUpdated = Date()
  }
}

// MARK: - Factory Methods

extension RoutePreference {
  /// Creates a default preference configuration optimized for commuting
  static func defaultCommutingPreferences() -> RoutePreference {
    return RoutePreference(timeWeight: 0.8,
                           reliabilityWeight: 0.9,
                           bridgeAvoidanceWeight: 0.8,
                           trafficAvoidanceWeight: 0.9,
                           preferFewerBridges: true,
                           maxDetourMinutes: 15,
                           preferenceLabel: "Commuting")
  }

  /// Creates a preference configuration optimized for leisure travel
  static func leisurePreferences() -> RoutePreference {
    return RoutePreference(timeWeight: 0.4,
                           reliabilityWeight: 0.6,
                           bridgeAvoidanceWeight: 0.5,
                           trafficAvoidanceWeight: 0.6,
                           preferFewerBridges: false,
                           maxDetourMinutes: 20,
                           preferenceLabel: "Leisure")
  }
}
