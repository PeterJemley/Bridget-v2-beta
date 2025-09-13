import Foundation
import Testing

@testable import Bridget

@Suite("BridgeRecordValidator Integration Tests")
struct BridgeRecordValidatorIntegrationTests {
    // MARK: - Stored Properties

    private var validator: BridgeRecordValidator!

    // MARK: - Suite Lifecycle

    @MainActor init() throws {
        // Create validator with known bridge data
        let knownBridgeIDs: Set<String> = ["1", "6"]
        let bridgeLocations: [String: (lat: Double, lon: Double)] = [
            "1": (47.598, -122.332),  // First Avenue South Bridge
            "6": (47.58, -122.35),  // Lower Spokane Street Bridge
        ]
        let validEntityTypes: Set<String> = ["bridge"]
        let minDate = Date(timeIntervalSince1970: 0)
        let maxDate = Date(timeIntervalSince1970: 2_000_000_000)

        validator = BridgeRecordValidator(
            knownBridgeIDs: knownBridgeIDs,
            bridgeLocations: bridgeLocations,
            validEntityTypes: validEntityTypes,
            minDate: minDate,
            maxDate: maxDate
        )
    }

    // MARK: - Integration Tests

    @MainActor
    @Test("Bridge 1 should pass validation with coordinate transformation")
    func bridge1WithTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )

        let failure = validator.validationFailure(for: record)
        #expect(
            failure == nil,
            "Bridge 1 should pass validation with coordinate transformation"
        )
    }

    @MainActor
    @Test("Bridge 6 should pass validation with coordinate transformation")
    func bridge6WithTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "Lower Spokane Street Bridge",
            entityid: "6",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.57137680053711",
            longitude: "-122.35354614257812"
        )

        let failure = validator.validationFailure(for: record)
        #expect(
            failure == nil,
            "Bridge 6 should pass validation with coordinate transformation"
        )
    }

    @MainActor
    @Test(
        "Bridge 1 should fail for very far coordinates (no transformation can help)"
    )
    func bridge1WithoutTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.0",
            longitude: "-122.0"
        )

        let failure = validator.validationFailure(for: record)
        #expect(
            failure != nil,
            "Bridge 1 should fail validation with very far coordinates"
        )

        if let reason = failure {
            switch reason {
            case .geospatialMismatch:
                // Expected failure
                break
            default:
                Issue.record(
                    "Expected geospatialMismatch failure, got: \(reason)"
                )
            }
        }
    }

    @MainActor
    @Test(
        "Valid reference-system coordinates should pass without transformation"
    )
    func validCoordinatesWithoutTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598",
            longitude: "-122.332"
        )

        let failure = validator.validationFailure(for: record)
        #expect(
            failure == nil,
            "Should pass validation with coordinates already in reference system"
        )
    }

    @MainActor
    @Test("Identity transformation path should accept very close coordinates")
    func identityTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598001",
            longitude: "-122.332001"
        )

        let failure = validator.validationFailure(for: record)
        #expect(
            failure == nil,
            "Should pass validation with very close coordinates"
        )
    }

    @MainActor @Test("Unknown bridge should fail validation")
    func unknownBridgeWithTransformation() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "Unknown Bridge",
            entityid: "999",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.5",
            longitude: "-122.3"
        )

        let failure = validator.validationFailure(for: record)
        #expect(failure != nil, "Unknown bridge should fail validation")

        if let reason = failure {
            switch reason {
            case .unknownBridgeID:
                // Expected failure
                break
            default:
                Issue.record("Expected unknownBridgeID failure, got: \(reason)")
            }
        }
    }

    @MainActor @Test("Out-of-range dates should fail validation")
    func invalidDateRange() throws {
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "1900-01-01T10:00:00.000",
            closedatetime: "1900-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598",
            longitude: "-122.332"
        )

        let failure = validator.validationFailure(for: record)
        #expect(failure != nil, "Should fail validation with out of range date")

        if let reason = failure {
            switch reason {
            case .outOfRangeOpenDate:
                // Expected failure
                break
            default:
                Issue.record(
                    "Expected outOfRangeOpenDate failure, got: \(reason)"
                )
            }
        }
    }
}
