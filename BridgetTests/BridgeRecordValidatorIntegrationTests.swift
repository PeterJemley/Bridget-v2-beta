import XCTest
@testable import Bridget

final class BridgeRecordValidatorIntegrationTests: XCTestCase {
    
    var validator: BridgeRecordValidator!
    
    override func setUpWithError() throws {
        // Create validator with known bridge data and real coordinate transformation service
        let knownBridgeIDs: Set<String> = ["1", "6"]
        let bridgeLocations: [String: (lat: Double, lon: Double)] = [
            "1": (47.598, -122.332),  // First Avenue South Bridge
            "6": (47.58, -122.35)     // Lower Spokane Street Bridge
        ]
        let validEntityTypes: Set<String> = ["bridge"]
        let minDate = Date(timeIntervalSince1970: 0)
        let maxDate = Date(timeIntervalSince1970: 2000000000)
        
        validator = BridgeRecordValidator(
            knownBridgeIDs: knownBridgeIDs,
            bridgeLocations: bridgeLocations,
            validEntityTypes: validEntityTypes,
            minDate: minDate,
            maxDate: maxDate,
            coordinateTransformService: DefaultCoordinateTransformService(enableLogging: true)
        )
    }
    
    override func tearDownWithError() throws {
        validator = nil
    }
    
    // MARK: - Integration Tests
    
    func testBridge1WithTransformation() throws {
        // Create a record with API coordinates that would fail without transformation
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
        
        // Should pass validation with coordinate transformation
        let failure = validator.validationFailure(for: record)
        XCTAssertNil(failure, "Bridge 1 should pass validation with coordinate transformation")
    }
    
    func testBridge6WithTransformation() throws {
        // Create a record with API coordinates that would fail without transformation
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
        
        // Should pass validation with coordinate transformation
        let failure = validator.validationFailure(for: record)
        XCTAssertNil(failure, "Bridge 6 should pass validation with coordinate transformation")
    }
    
    func testBridge1WithoutTransformation() throws {
        // Create a record with coordinates that are too far even with transformation
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.0",  // Very far from expected location
            longitude: "-122.0"
        )
        
        // Should fail validation (distance > 500m even with transformation)
        let failure = validator.validationFailure(for: record)
        XCTAssertNotNil(failure, "Bridge 1 should fail validation with very far coordinates")
        
        if case .geospatialMismatch = failure {
            // Expected failure
        } else {
            XCTFail("Expected geospatialMismatch failure")
        }
    }
    
    func testValidCoordinatesWithoutTransformation() throws {
        // Create a record with coordinates that are already in the reference system
        // These coordinates should not need transformation
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598",  // Already in reference system
            longitude: "-122.332"
        )
        
        // Should pass validation (coordinates are already correct)
        let failure = validator.validationFailure(for: record)
        XCTAssertNil(failure, "Should pass validation with coordinates already in reference system")
    }
    
    func testIdentityTransformation() throws {
        // Create a record with coordinates that are very close to the expected location
        // This should trigger an identity transformation (no change)
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-01T10:00:00.000",
            closedatetime: "2024-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598001",  // Very close to expected (47.598, -122.332)
            longitude: "-122.332001"
        )
        
        // Should pass validation (very close coordinates)
        let failure = validator.validationFailure(for: record)
        XCTAssertNil(failure, "Should pass validation with very close coordinates")
    }
    
    func testUnknownBridgeWithTransformation() throws {
        // Create a record for unknown bridge
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
        
        // Should fail validation due to unknown bridge ID
        let failure = validator.validationFailure(for: record)
        XCTAssertNotNil(failure, "Unknown bridge should fail validation")
        
        if case .unknownBridgeID = failure {
            // Expected failure
        } else {
            XCTFail("Expected unknownBridgeID failure")
        }
    }
    
    func testInvalidDateRange() throws {
        // Create a record with invalid date
        let record = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "1900-01-01T10:00:00.000",  // Very old date
            closedatetime: "1900-01-01T10:05:00.000",
            minutesopen: "5",
            latitude: "47.598",
            longitude: "-122.332"
        )
        
        // Should fail validation due to out of range date
        let failure = validator.validationFailure(for: record)
        XCTAssertNotNil(failure, "Should fail validation with out of range date")
        
        if case .outOfRangeOpenDate = failure {
            // Expected failure
        } else {
            XCTFail("Expected outOfRangeOpenDate failure")
        }
    }
}
