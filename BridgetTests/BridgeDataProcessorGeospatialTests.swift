@testable import Bridget
import Testing

final class AllSeattleBridgesGeospatialValidationTests {
  /// Known bridge IDs for validation
  private let knownBridgeIDs = Set([
    "1", "2", "3", "4", "6", "21", "29",
  ])

  private let bridgeLocations: [String: (lat: Double, lon: Double)] = [
    "1": (47.542213439941406, -122.33446502685547), // 1st Ave South
    "2": (47.65981674194336, -122.37619018554688),  // Ballard
    "3": (47.64760208129883, -122.3497314453125),   // Fremont
    "4": (47.64728546142578, -122.3045883178711),   // Montlake
    "6": (47.57137680053711, -122.35354614257812),  // Lower Spokane St
    "21": (47.652652740478516, -122.32042694091797), // University
    "29": (47.52923583984375, -122.31411743164062),  // South Park
  ]

  // Helper to create a test record
  func testRecord(entityid: String, lat: String, lon: String) -> BridgeOpeningRecord {
    BridgeOpeningRecord(entitytype: "Bridge",
                        entityname: "Test",
                        entityid: entityid,
                        opendatetime: "2025-01-03T10:12:00.000",
                        closedatetime: "2025-01-03T10:20:00.000",
                        minutesopen: "8",
                        latitude: lat,
                        longitude: lon)
  }

  // Test for each bridge with valid coordinates
  @Test func test1stAveSouth() {
    let record = testRecord(entityid: "1", lat: "47.542213439941406", lon: "-122.33446502685547")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for 1st Ave South")
  }

  @Test func ballard() {
    let record = testRecord(entityid: "2", lat: "47.65981674194336", lon: "-122.37619018554688")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for Ballard")
  }

  @Test func fremont() {
    let record = testRecord(entityid: "3", lat: "47.64760208129883", lon: "-122.3497314453125")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for Fremont")
  }

  @Test func montlake() {
    let record = testRecord(entityid: "4", lat: "47.64728546142578", lon: "-122.3045883178711")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for Montlake")
  }

  @Test func lowerSpokaneSt() {
    let record = testRecord(entityid: "6", lat: "47.57137680053711", lon: "-122.35354614257812")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for Lower Spokane St")
  }

  @Test func university() {
    let record = testRecord(entityid: "21", lat: "47.652652740478516", lon: "-122.32042694091797")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for University")
  }

  @Test func southPark() {
    let record = testRecord(entityid: "29", lat: "47.52923583984375", lon: "-122.31411743164062")
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    #expect(result == nil, "Should accept matching coordinates for South Park")
  }

  // Optionally, add a rejection test for each bridge
  @Test func test1stAveSouthGeospatialMismatch() {
    let record = testRecord(entityid: "1", lat: "48.0", lon: "-123.0") // Far away
    let result = BridgeDataProcessor.shared.validationFailureReason(for: record)
    switch result {
    case .geospatialMismatch?:
      break // Pass: mismatch detected
    default:
      fatalError("Should have failed with .geospatialMismatch for 1st Ave South")
    }
  }
}
