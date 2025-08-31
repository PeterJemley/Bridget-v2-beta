//
//  SeattleDrawbridges.swift
//  Bridget
//
//  Single source of truth for Seattle drawbridge information
//  Based on actual Seattle geography and bridge operations
//  Last updated: August 29, 2025
//

import CoreLocation
import Foundation

/// Single source of truth for Seattle drawbridge information
///
/// This file contains the canonical data for all Seattle drawbridges,
/// including their IDs, names, coordinates, and connections.
/// All other parts of the application should reference this file
/// for Seattle bridge information.
public enum SeattleDrawbridges {
  /// Seattle drawbridge ID enumeration
  /// Maps to Seattle Open Data API bridge IDs
  public enum BridgeID: String, CaseIterable, Equatable {
    case firstAveSouth = "1"
    case ballard = "2"
    case fremont = "3"
    case montlake = "4"
    case lowerSpokane = "6"
    case university = "21"
    case southPark = "29"

    /// All known IDs as a Set (for efficient lookup)
    public static var allIDs: Set<String> {
      Set(allCases.map { $0.rawValue })
    }
  }

  /// Canonical bridge information
  public struct BridgeInfo {
    public let id: BridgeID
    public let name: String
    public let coordinate: CLLocationCoordinate2D
    public let connections: String
    public let waterway: String
    public let notes: String

    public init(id: BridgeID, name: String, coordinate: CLLocationCoordinate2D, connections: String,
                waterway: String, notes: String)
    {
      self.id = id
      self.name = name
      self.coordinate = coordinate
      self.connections = connections
      self.waterway = waterway
      self.notes = notes
    }
  }

  /// All Seattle drawbridges with canonical information
  public static let allBridges: [BridgeInfo] = [
    BridgeInfo(id: .ballard,
               name: "Ballard Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.6598, longitude: -122.3762),
               connections: "Ballard ⇆ Interbay",
               waterway: "Lake Washington Ship Canal",
               notes: "15th Avenue NW bridge across Lake Washington Ship Canal"),
    BridgeInfo(id: .fremont,
               name: "Fremont Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.6475, longitude: -122.3497),
               connections: "Fremont ⇆ Queen Anne",
               waterway: "Lake Washington Ship Canal",
               notes: "Historic bridge connecting Fremont to Queen Anne across Lake Washington Ship Canal"),
    BridgeInfo(id: .montlake,
               name: "Montlake Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.6473, longitude: -122.3047),
               connections: "Montlake ⇆ University District",
               waterway: "Lake Washington Ship Canal",
               notes: "Bridge connecting Montlake to University District across Lake Washington Ship Canal"),
    BridgeInfo(id: .university,
               name: "University Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.6531, longitude: -122.3200),
               connections: "University District ⇆ Eastlake",
               waterway: "Lake Washington Ship Canal",
               notes: "Bridge connecting University District to Eastlake across Lake Washington Ship Canal"),
    BridgeInfo(id: .firstAveSouth,
               name: "First Avenue South Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.5980, longitude: -122.3320),
               connections: "SODO ⇆ Georgetown",
               waterway: "Duwamish Waterway",
               notes: "Major arterial bridge connecting SODO to Georgetown across Duwamish Waterway"),
    BridgeInfo(id: .lowerSpokane,
               name: "Lower Spokane Street Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.5800, longitude: -122.3500),
               connections: "West Seattle ⇆ Harbor Island/SODO",
               waterway: "Duwamish Waterway",
               notes:
               "Spokane Street Swing Bridge connecting West Seattle (Delridge/Pigeon Point) to Harbor Island/SODO"),
    BridgeInfo(id: .southPark,
               name: "South Park Bridge",
               coordinate: CLLocationCoordinate2D(latitude: 47.5293, longitude: -122.3141),
               connections: "South Park ⇆ Georgetown",
               waterway: "Duwamish Waterway",
               notes: "14th Avenue South bridge connecting South Park to Georgetown across Duwamish Waterway"),
  ]

  /// Bridge locations as dictionary for compatibility with existing code
  public static let bridgeLocations: [String: (lat: Double, lon: Double)] = Dictionary(
    uniqueKeysWithValues: allBridges.map { bridge in
      (bridge.id.rawValue, (lat: bridge.coordinate.latitude, lon: bridge.coordinate.longitude))
    })

  /// Bridge names as dictionary for compatibility with existing code
  public static let bridgeNames: [String: String] = Dictionary(
    uniqueKeysWithValues: allBridges.map { bridge in
      (bridge.id.rawValue, bridge.name)
    })

  /// Get bridge info by ID
  public static func bridgeInfo(for id: BridgeID) -> BridgeInfo? {
    allBridges.first { $0.id == id }
  }

  /// Get bridge info by string ID (handles both internal IDs and API IDs)
  public static func bridgeInfo(for id: String) -> BridgeInfo? {
    // If it's already an internal ID, look it up directly
    if let bridgeID = SeattleDrawbridges.BridgeID(rawValue: id) {
      return bridgeInfo(for: bridgeID)
    }

    return nil
  }

  /// Check if a bridge ID is valid (accepts both internal IDs and API IDs)
  public static func isValidBridgeID(_ id: String) -> Bool {
    // Check if it's a valid internal ID
    if SeattleDrawbridges.BridgeID(rawValue: id) != nil {
      return true
    }

    // Check if it's a valid API ID (numeric format)
    let validApiIDs = ["1", "2", "3", "4", "6", "21", "29"]
    if validApiIDs.contains(id) {
      return true
    }

    return false
  }

  /// Check if a bridge ID is a canonical Seattle bridge ID
  public static func isCanonicalBridgeID(_ id: String) -> Bool {
    return BridgeID(rawValue: id) != nil
  }

  /// Check if a bridge ID is a synthetic test ID (e.g., "bridge1", "bridge2")
  public static func isSyntheticTestBridgeID(_ id: String) -> Bool {
    return id.hasPrefix("bridge") && id.count > 6 && id.dropFirst(6).allSatisfy { $0.isNumber }
  }

  /// Check if a bridge ID is accepted based on policy
  /// - Parameter id: The bridge ID to check
  /// - Parameter allowSynthetic: Whether to accept synthetic test IDs
  /// - Returns: True if the ID is accepted according to the policy
  public static func isAcceptedBridgeID(_ id: String, allowSynthetic: Bool = false) -> Bool {
    if isCanonicalBridgeID(id) {
      return true
    }
    if allowSynthetic && isSyntheticTestBridgeID(id) {
      return true
    }
    return false
  }

  /// Get all bridge IDs as strings
  public static var allBridgeIDs: [String] {
    BridgeID.allCases.map { $0.rawValue }
  }

  /// Total number of Seattle drawbridges
  public static let count = 7
}

// MARK: - Extensions for compatibility

public extension SeattleDrawbridges.BridgeID {
  /// Human-readable name for the bridge
  var displayName: String {
    SeattleDrawbridges.bridgeInfo(for: self)?.name ?? rawValue
  }

  /// Coordinate for the bridge
  var coordinate: CLLocationCoordinate2D {
    SeattleDrawbridges.bridgeInfo(for: self)?.coordinate ?? CLLocationCoordinate2D()
  }
}
