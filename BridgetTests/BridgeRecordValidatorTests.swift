// BridgeRecordValidatorTests.swift
// Ensures BridgeRecordValidator correctly validates bridge opening records using Swift's modern Testing framework

import Foundation
import Testing

@testable import Bridget

/// Tests for the BridgeRecordValidator to ensure proper validation of bridge opening records.
@Suite("Bridge Record Validator Tests")
struct BridgeRecordValidatorTests {
    // MARK: - Test Data Fixtures

    private func makeValidRecord() -> BridgeOpeningRecord {
        BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
    }

    // MARK: - Test Suite

    @MainActor @Test("validates correct bridge record")
    func validatesCorrectRecord() async throws {
        let record = makeValidRecord()
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [
                "1": (47.542213439941406, -122.33446502685547)
            ],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(result == nil, "Valid record should pass validation")
    }

    @MainActor @Test("rejects empty entity ID")
    func rejectsEmptyEntityID() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(result == .emptyEntityID, "Empty entity ID should be rejected")
    }

    @MainActor @Test("rejects unknown bridge ID")
    func rejectsUnknownBridgeID() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "Unknown Bridge",
            entityid: "100",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .unknownBridgeID("100"),
            "Unknown bridge ID should be rejected"
        )
    }

    @MainActor @Test("rejects malformed open date")
    func rejectsMalformedOpenDate() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "not-a-date",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .malformedOpenDate("not-a-date"),
            "Malformed open date should be rejected"
        )
    }

    @MainActor @Test("rejects out of range open date")
    func rejectsOutOfRangeOpenDate() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2000-01-01T00:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        // Use the same date formatter as BridgeOpeningRecord to ensure consistent timezone
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let expectedDate =
            formatter.date(from: "2000-01-01T00:00:00.000") ?? Date()
        #expect(
            result == .outOfRangeOpenDate(expectedDate),
            "Out of range open date should be rejected"
        )
    }

    @MainActor @Test("rejects malformed close date")
    func rejectsMalformedCloseDate() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "not-a-date",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .malformedCloseDate("not-a-date"),
            "Malformed close date should be rejected"
        )
    }

    @MainActor @Test("rejects close date not after open date")
    func rejectsCloseDateNotAfterOpenDate() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T11:59:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        // Use the same date formatter as BridgeOpeningRecord to ensure consistent timezone
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let openDate = formatter.date(from: "2024-06-01T12:00:00.000") ?? Date()
        let closeDate =
            formatter.date(from: "2024-06-01T11:59:00.000") ?? Date()
        #expect(
            result
                == .closeDateNotAfterOpenDate(open: openDate, close: closeDate),
            "Close date not after open date should be rejected"
        )
    }

    @MainActor @Test("rejects invalid latitude")
    func rejectsInvalidLatitude() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "100.0",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .invalidLatitude(100.0),
            "Invalid latitude should be rejected"
        )
    }

    @MainActor @Test("rejects invalid longitude")
    func rejectsInvalidLongitude() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-190"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .invalidLongitude(-190.0),
            "Invalid longitude should be rejected"
        )
    }

    @MainActor @Test("rejects negative minutes open")
    func rejectsNegativeMinutesOpen() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "-5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .negativeMinutesOpen(-5),
            "Negative minutes open should be rejected"
        )
    }

    @MainActor @Test("rejects minutes open mismatch")
    func rejectsMinutesOpenMismatch() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "10",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: [:],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)
        #expect(
            result == .minutesOpenMismatch(reported: 10, actual: 5),
            "Minutes open mismatch should be rejected"
        )
    }

    @MainActor @Test("rejects geospatial mismatch")
    func rejectsGeospatialMismatch() async throws {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2024-06-01T12:00:00.000",
            closedatetime: "2024-06-01T12:05:00.000",
            minutesopen: "5",
            latitude: "47.0",
            longitude: "-122.0"
        )
        let validator = BridgeRecordValidator(
            knownBridgeIDs: Set(["1", "2", "3", "4", "6", "21", "29"]),
            bridgeLocations: ["1": (47.542213439941406, -122.33446502685547)],
            validEntityTypes: Set(["Bridge"]),
            minDate: Calendar.current.date(
                byAdding: .year,
                value: -10,
                to: Date()
            ) ?? Date(),
            maxDate: Calendar.current.date(
                byAdding: .year,
                value: 1,
                to: Date()
            ) ?? Date()
        )
        let result = await validator.validationFailure(for: record)

        // Instead of asserting exact equality on all associated values (which can change
        // due to coordinate transformation), assert that the error case is correct and
        // that expected coordinates match the known bridge location.
        #expect(result != nil, "Expected a geospatial mismatch error")

        if case .geospatialMismatch(
            expectedLat: let expLat,
            expectedLon: let expLon,
            actualLat: _,
            actualLon: _
        )? = result {
            // Verify expected coordinates are those of the known bridge
            let expectedLat = 47.542213439941406
            let expectedLon = -122.33446502685547
            #expect(abs(expLat - expectedLat) < 1e-9)
            #expect(abs(expLon - expectedLon) < 1e-9)
        } else {
            #expect(Bool(false), "Geospatial mismatch should be rejected")
        }
    }
}
