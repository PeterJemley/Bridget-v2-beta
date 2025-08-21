// BridgeRecordValidatorTests.swift
// Ensures BridgeRecordValidator correctly validates bridge opening records using Swift's modern Testing framework

@testable import Bridget
import Foundation
import Testing

/// Tests for the BridgeRecordValidator to ensure proper validation of bridge opening records.
@Suite("Bridge Record Validator Tests")
struct BridgeRecordValidatorTests {
  // MARK: - Test Data Fixtures

  private func makeValidRecord() -> BridgeOpeningRecord {
    BridgeOpeningRecord(entitytype: "Bridge",
                        entityname: "1st Ave South",
                        entityid: "1",
                        opendatetime: "2024-06-01T12:00:00.000",
                        closedatetime: "2024-06-01T12:05:00.000",
                        minutesopen: "5",
                        latitude: "47.542213439941406",
                        longitude: "-122.33446502685547")
  }

  // MARK: - Test Suite

  @Test("validates correct bridge record")
  func validatesCorrectRecord() async throws {
    let record = makeValidRecord()
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [
                                            "1": (47.542213439941406, -122.33446502685547),
                                          ],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == nil, "Valid record should pass validation")
  }

  @Test("rejects empty entity ID")
  func rejectsEmptyEntityID() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .emptyEntityID, "Empty entity ID should be rejected")
  }

  @Test("rejects unknown bridge ID")
  func rejectsUnknownBridgeID() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "Unknown Bridge",
                                     entityid: "100",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .unknownBridgeID("100"), "Unknown bridge ID should be rejected")
  }

  @Test("rejects malformed open date")
  func rejectsMalformedOpenDate() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "not-a-date",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .malformedOpenDate("not-a-date"), "Malformed open date should be rejected")
  }

  @Test("rejects out of range open date")
  func rejectsOutOfRangeOpenDate() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2000-01-01T00:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    let expectedDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    #expect(result == .outOfRangeOpenDate(expectedDate), "Out of range open date should be rejected")
  }

  @Test("rejects malformed close date")
  func rejectsMalformedCloseDate() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "not-a-date",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .malformedCloseDate("not-a-date"), "Malformed close date should be rejected")
  }

  @Test("rejects close date not after open date")
  func rejectsCloseDateNotAfterOpenDate() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T11:59:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    let openDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 12, minute: 0, second: 0)) ?? Date()
    let closeDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 11, minute: 59, second: 0)) ?? Date()
    #expect(result == .closeDateNotAfterOpenDate(open: openDate, close: closeDate), "Close date not after open date should be rejected")
  }

  @Test("rejects invalid latitude")
  func rejectsInvalidLatitude() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "100.0",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .invalidLatitude(100.0), "Invalid latitude should be rejected")
  }

  @Test("rejects invalid longitude")
  func rejectsInvalidLongitude() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.542213439941406",
                                     longitude: "-190")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .invalidLongitude(-190.0), "Invalid longitude should be rejected")
  }

  @Test("rejects negative minutes open")
  func rejectsNegativeMinutesOpen() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "-5",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .negativeMinutesOpen(-5), "Negative minutes open should be rejected")
  }

  @Test("rejects minutes open mismatch")
  func rejectsMinutesOpenMismatch() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "10",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: [:],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .minutesOpenMismatch(reported: 10, actual: 5), "Minutes open mismatch should be rejected")
  }

  @Test("rejects geospatial mismatch")
  func rejectsGeospatialMismatch() async throws {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2024-06-01T12:00:00.000",
                                     closedatetime: "2024-06-01T12:05:00.000",
                                     minutesopen: "5",
                                     latitude: "47.0",
                                     longitude: "-122.0")
    let validator = BridgeRecordValidator(knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
                                          bridgeLocations: ["1": (47.542213439941406, -122.33446502685547)],
                                          validEntityTypes: Set(["Bridge"]),
                                          minDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                                          maxDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    let result = validator.validationFailure(for: record)
    #expect(result == .geospatialMismatch(expectedLat: 47.542213439941406, expectedLon: -122.33446502685547, actualLat: 47.0, actualLon: -122.0), "Geospatial mismatch should be rejected")
  }
}
