import Foundation
import MapKit

/// Represents the type of a traffic incident affecting a bridge.
public enum IncidentType: String {
  /// Construction work causing delays or closures.
  case construction
  /// Accident or collision.
  case accident
  /// Full or partial closure.
  case closure
  /// Any other or unknown incident type.
  case other
}

/// The severity of a traffic incident.
public enum IncidentSeverity: String {
  case minor
  case moderate
  case major
}

/// Metadata about a traffic incident relevant to bridge passability.
public struct TrafficIncident {
  public let type: IncidentType
  public let description: String
  public let severity: IncidentSeverity

  public init(
    type: IncidentType,
    description: String,
    severity: IncidentSeverity
  ) {
    self.type = type
    self.description = description
    self.severity = severity
  }
}

/// Real-time traffic and passability status for a bridge location.
/// This struct aggregates congestion, delay, incident, and reliability data for inference.
public struct TrafficStatus {
  public enum CongestionLevel: String {
    case low, moderate, high, unknown
  }

  public let bridgeID: String
  public let lastUpdated: Date
  public let congestion: CongestionLevel
  public let isPassable: Bool
  public let mapRegion: MKCoordinateRegion
  /// Estimated additional delay in seconds over baseline travel time.
  public let estimatedDelay: TimeInterval?
  /// Relevant traffic incidents affecting this bridge.
  public let incidents: [TrafficIncident]
  /// Score (0-1) reflecting confidence in congestion/passability inference.
  public let confidence: Double?

  public init(
    bridgeID: String,
    lastUpdated: Date,
    congestion: CongestionLevel,
    isPassable: Bool,
    mapRegion: MKCoordinateRegion,
    estimatedDelay: TimeInterval?,
    incidents: [TrafficIncident],
    confidence: Double?
  ) {
    self.bridgeID = bridgeID
    self.lastUpdated = lastUpdated
    self.congestion = congestion
    self.isPassable = isPassable
    self.mapRegion = mapRegion
    self.estimatedDelay = estimatedDelay
    self.incidents = incidents
    self.confidence = confidence
  }
}
