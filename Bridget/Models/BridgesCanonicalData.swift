import CoreLocation
import Foundation

/// Canonical metadata for all major Seattle bridges.
/// Provides a single, authoritative source for bridge names, ids, coordinates,
/// canonical crossing start and end points, and a baseline travel time estimate.
public struct BridgeCanonicalData {
  public let id: String
  public let name: String
  public let coordinate: CLLocationCoordinate2D

  /// The canonical start coordinate of the bridge crossing.
  /// Represents an approximate location at one end of the bridge,
  /// offset about 50–100 meters from the center coordinate.
  public let startCoordinate: CLLocationCoordinate2D

  /// The canonical end coordinate of the bridge crossing.
  /// Represents an approximate location at the opposite end of the bridge,
  /// offset about 50–100 meters from the center coordinate.
  public let endCoordinate: CLLocationCoordinate2D

  /// A baseline travel time estimate (in seconds) to cross the bridge.
  /// Placeholder value for rough travel duration guidance.
  public let travelTime: TimeInterval

  public init(id: String,
              name: String,
              coordinate: CLLocationCoordinate2D,
              startCoordinate: CLLocationCoordinate2D,
              endCoordinate: CLLocationCoordinate2D,
              travelTime: TimeInterval)
  {
    self.id = id
    self.name = name
    self.coordinate = coordinate
    self.startCoordinate = startCoordinate
    self.endCoordinate = endCoordinate
    self.travelTime = travelTime
  }
}

/// Static canonical list of Seattle bridge locations with extended route details.
public enum BridgesCanonicalData {
  public static let all: [BridgeCanonicalData] = [
    BridgeCanonicalData(id: "1",
                        name: "1st Ave South",
                        coordinate: CLLocationCoordinate2D(latitude: 47.542213439941406,
                                                           longitude: -122.33446502685547),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.542613,
                                                                longitude: -122.334465),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.541813,
                                                              longitude: -122.334465),
                        travelTime: 30),
    BridgeCanonicalData(id: "2",
                        name: "Ballard",
                        coordinate: CLLocationCoordinate2D(latitude: 47.65981674194336,
                                                           longitude: -122.37619018554688),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.660216,
                                                                longitude: -122.376190),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.659417,
                                                              longitude: -122.376190),
                        travelTime: 40),
    BridgeCanonicalData(id: "3",
                        name: "Fremont",
                        coordinate: CLLocationCoordinate2D(latitude: 47.64760208129883,
                                                           longitude: -122.3497314453125),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.647982,
                                                                longitude: -122.349731),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.647222,
                                                              longitude: -122.349731),
                        travelTime: 40),
    BridgeCanonicalData(id: "4",
                        name: "Montlake",
                        coordinate: CLLocationCoordinate2D(latitude: 47.64728546142578,
                                                           longitude: -122.3045883178711),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.647685,
                                                                longitude: -122.304588),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.646885,
                                                              longitude: -122.304588),
                        travelTime: 30),
    BridgeCanonicalData(id: "6",
                        name: "Lower Spokane St",
                        coordinate: CLLocationCoordinate2D(latitude: 47.57137680053711,
                                                           longitude: -122.35354614257812),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.571776,
                                                                longitude: -122.353546),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.570977,
                                                              longitude: -122.353546),
                        travelTime: 45),
    BridgeCanonicalData(id: "21",
                        name: "University",
                        coordinate: CLLocationCoordinate2D(latitude: 47.652652740478516,
                                                           longitude: -122.32042694091797),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.653052,
                                                                longitude: -122.320427),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.652253,
                                                              longitude: -122.320427),
                        travelTime: 35),
    BridgeCanonicalData(id: "29",
                        name: "South Park",
                        coordinate: CLLocationCoordinate2D(latitude: 47.52923583984375,
                                                           longitude: -122.31411743164062),
                        startCoordinate: CLLocationCoordinate2D(latitude: 47.529635,
                                                                longitude: -122.314117),
                        endCoordinate: CLLocationCoordinate2D(latitude: 47.528836,
                                                              longitude: -122.314117),
                        travelTime: 45),
  ]

  /// Lookup by ID
  public static func location(forID id: String) -> BridgeCanonicalData? {
    all.first { $0.id == id }
  }

  /// Lookup by name (case-insensitive)
  public static func location(forName name: String) -> BridgeCanonicalData? {
    all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
  }

  #if DEBUG
    /// DEBUG-only method to verify coordinates against API data.
    public static func verifyCoordinates() async {
      await BridgeCoordinateVerifier.verifyCoordinates()
    }
  #endif
}
